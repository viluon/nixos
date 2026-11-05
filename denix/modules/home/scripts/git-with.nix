{ pkgs }:
pkgs.writeShellApplication {
  name = "git-with";
  runtimeInputs = with pkgs; [ git fzf gawk ];
  text = ''
    fail() { echo "$1" >&2; exit 1; }

    git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"
    git rev-parse --verify --quiet origin/HEAD >/dev/null \
      || fail "origin/HEAD unknown; run: git remote set-head origin --auto"
    base=$(git merge-base HEAD origin/HEAD) || fail "HEAD shares no history with origin/HEAD"

    self=$(git config user.email || true)
    candidates=$(git log --format='%an <%ae>%n%(trailers:key=Co-authored-by,valueonly)' \
      | awk -v self="$self" 'match($0, /<[^>]*>$/) {
          email = substr($0, RSTART + 1, RLENGTH - 2)
          if (email != self && !seen[email]++) print
        }')
    [ -n "$candidates" ] || fail "no other authors or co-authors found in this repository"

    selection=$(fzf --multi --prompt='co-authors> ' --header='TAB to select several' <<< "$candidates") \
      || fail "no co-authors selected"

    amend=(git -c trailer.ifexists=addIfDifferent commit --amend --no-edit --allow-empty)
    while IFS= read -r coauthor; do
      amend+=(--trailer "Co-authored-by: $coauthor")
    done <<< "$selection"

    git rebase --interactive --autostash "$base" --exec "''${amend[*]@Q}"
  '';
}
