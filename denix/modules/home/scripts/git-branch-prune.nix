{ pkgs }:
pkgs.writeShellApplication {
  name = "git-branch-prune";
  runtimeInputs = with pkgs; [ gh git ];
  text = ''
    set -euo pipefail

    fail() { echo "$1" >&2; exit 1; }
    current_branch() { git symbolic-ref --quiet --short HEAD || fail "detached HEAD state"; }
    default_branch() { gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'; }
    ensure_default_branch() {
      local branch default
      branch=$(current_branch)
      default=$(default_branch)
      if [ "$branch" != "$default" ]; then
        fail "must run from default branch '$default', currently on '$branch'"
      fi
    }

    ensure_default_branch

    merged_branches=$(git branch --merged | sed 's/^. //')
    checked_out_branches=$(git worktree list --porcelain | grep '^branch ' | sed 's/^branch refs\/heads\///')
    to_delete=$(comm -23 <(echo "$merged_branches" | sort) <(echo "$checked_out_branches" | sort))

    if [ -z "$to_delete" ]; then
      echo "No merged branches to prune"
      exit 0
    fi

    echo "$to_delete" | while IFS= read -r branch; do
      echo "  $branch"
      git branch --delete "$branch"
    done
  '';
}
