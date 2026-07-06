{ pkgs }:
pkgs.writeShellApplication {
  name = "git-with";
  runtimeInputs = with pkgs; [ git fzf gnused coreutils gawk ];
  text = ''
    set -euo pipefail

    fail() { echo "$1" >&2; exit 1; }

    git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"

    self=$(git config user.email 2>/dev/null || true)

    candidates=$(git log --format=$'%an\t%ae' \
      | awk -F'\t' -v self="$self" '!seen[$2]++ && $2 != self { print $1 " <" $2 ">" }' \
      | sort)
    [ -n "$candidates" ] || fail "no other committers found in this repository"

    selection=$(printf '%s\n' "$candidates" \
      | fzf --multi --prompt='co-authors> ' \
            --header='select co-authors (TAB to multi-select)') \
      || true
    [ -n "$selection" ] || fail "no co-authors selected"

    trailer_file=$(mktemp)
    helper=$(mktemp)
    trap 'rm -f "$trailer_file" "$helper"' EXIT

    while IFS= read -r entry; do
      [ -n "$entry" ] || continue
      printf 'Co-authored-by: %s\n' "$entry" >> "$trailer_file"
    done <<< "$selection"

    default_branch=$(git rev-parse --abbrev-ref origin/HEAD | sed 's|^origin/||')
    merge_base=$(git merge-base HEAD "origin/$default_branch")

    cat > "$helper" <<EOF
    #!/usr/bin/env bash
    set -euo pipefail
    args=()
    while IFS= read -r line; do
      [ -n "\$line" ] && args+=(--trailer "\$line")
    done < "$trailer_file"
    git commit --amend --no-edit "\''${args[@]}"
    EOF
    chmod +x "$helper"

    git rebase "$merge_base" --exec "$helper"
  '';
}
