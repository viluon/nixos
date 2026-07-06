{ pkgs }:
pkgs.writeShellApplication {
  name = "git-relocate";
  runtimeInputs = with pkgs; [ git fzf gawk gnused gnugrep coreutils ];
  text = ''
    set -euo pipefail

    fail() { echo "$1" >&2; exit 1; }

    git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"
    if ! git diff --quiet || ! git diff --cached --quiet; then
      fail "uncommitted changes; commit or stash first"
    fi

    new_branch="''${1:-}"
    [ -n "$new_branch" ] || read -rp "new branch name: " new_branch
    [ -n "$new_branch" ] || fail "no branch name given"
    git show-ref --verify --quiet "refs/heads/$new_branch" && fail "branch '$new_branch' already exists"

    current_branch=$(git symbolic-ref --quiet --short HEAD) || fail "detached HEAD"

    default_branch=$(git rev-parse --abbrev-ref origin/HEAD | sed 's|^origin/||')
    merge_base=$(git merge-base HEAD "origin/$default_branch")

    selection=$(git log --oneline --color=always "$merge_base..HEAD" \
      | fzf --ansi --multi --reverse --prompt='relocate> ' \
            --header='select commits to relocate (TAB to multi-select)' \
            --preview='git show --color {1}') || true
    [ -n "$selection" ] || fail "no commits selected"

    shas=$(echo "$selection" | awk '{print $1}' | tac | while read -r s; do git rev-parse "$s^{commit}"; done)

    worktree=$(mktemp -u --tmpdir git-relocate-XXXXXX)
    cleanup() { git worktree remove --force "$worktree" 2>/dev/null || true; rm -rf "$worktree"; }
    trap cleanup EXIT

    git worktree add --quiet -b "$new_branch" "$worktree" "$merge_base"
    while IFS= read -r sha; do
      [ -n "$sha" ] || continue
      if ! git -C "$worktree" cherry-pick "$sha" >/dev/null 2>&1; then
        git -C "$worktree" cherry-pick --abort 2>/dev/null || true
        cleanup
        git branch -D "$new_branch" 2>/dev/null || true
        fail "cherry-pick of $sha failed; aborted, '$current_branch' left untouched"
      fi
    done <<< "$shas"

    drop_file=$(mktemp)
    helper=$(mktemp)
    trap 'cleanup; rm -f "$drop_file" "$helper"' EXIT
    printf '%s\n' "$shas" > "$drop_file"

    cat > "$helper" <<EOF
    #!/usr/bin/env bash
    set -euo pipefail
    todo="\$1"; tmp="\$todo.relocate"
    while IFS= read -r line; do
      case "\$line" in
        "pick "*)
          sha=\$(printf '%s' "\$line" | awk '{print \$2}')
          full=\$(git rev-parse "\$sha^{commit}" 2>/dev/null || true)
          if [ -n "\$full" ] && grep -qx "\$full" "$drop_file"; then
            line=\$(printf '%s' "\$line" | sed 's/^pick /drop /')
          fi ;;
      esac
      printf '%s\n' "\$line"
    done < "\$todo" > "\$tmp"
    mv "\$tmp" "\$todo"
    EOF
    chmod +x "$helper"

    GIT_SEQUENCE_EDITOR="$helper" git rebase -i "$merge_base" \
      || fail "rebase to drop relocated commits hit a conflict; resolve then 'git rebase --continue'. branch '$new_branch' already holds the relocated commits"

    echo "relocated $(printf '%s\n' "$shas" | grep -c .) commit(s) onto '$new_branch' (from $default_branch); cleaned up '$current_branch'"
  '';
}
