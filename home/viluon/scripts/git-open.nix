{ pkgs }:
pkgs.writeShellApplication {
  name = "git-open";
  runtimeInputs = with pkgs; [ gh git coreutils ];
  text = ''
    set -euo pipefail

    fail() { echo "$1" >&2; exit 1; }
    ensure_repo_root() { git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"; }
    ensure_branch() { git symbolic-ref --quiet --short HEAD >/dev/null 2>&1 || fail "detached HEAD state"; }
    current_branch() { git symbolic-ref --quiet --short HEAD; }
    default_branch() { gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'; }
    ensure_feature_branch() {
      local branch default
      branch=$(current_branch)
      default=$(default_branch)
      if [ "$branch" = "$default" ]; then
        fail "cannot create PR from default branch '$default'"
      fi
    }

    branch_remote() {
      local branch=$1
      local remote
      remote=$(git config "branch.$branch.remote" || true)
      if [ -n "$remote" ]; then
        printf '%s\n' "$remote"
        return
      fi

      local remotes
      remotes=$(git remote)
      if [ -z "$remotes" ]; then
        fail "no git remotes configured"
      fi

      for candidate in $remotes; do
        if [ "$candidate" = "origin" ]; then
          printf '%s\n' "$candidate"
          return
        fi
      done

      printf '%s\n' "$(printf '%s\n' "$remotes" | head -n1)"
    }

    push_branch() {
      local branch remote
      branch=$(current_branch)
      remote=$(branch_remote "$branch")
      echo "pushing $branch to $remote"
      git push --set-upstream "$remote" "$branch"
    }

    pr_exists() { gh pr view --json number >/dev/null 2>&1; }

    get_diff_stats() {
      local merge_base additions=0 deletions=0
      merge_base=$(git merge-base HEAD origin/main)

      while IFS=$'\t' read -r add del _; do
        additions=$((additions + add))
        deletions=$((deletions + del))
      done < <(git diff --numstat "$merge_base"..HEAD)

      echo "$additions $deletions"
    }

    get_grug_reply() {
      gh api graphql -f query='
        query {
          viewer {
            savedReplies(first: 10) {
              nodes {
                title
                body
              }
            }
          }
        }' --jq '.data.viewer.savedReplies.nodes[] | select(.title == "grug") | .body'
    }

    create_pr() {
      local stats additions deletions grug_body
      stats=$(get_diff_stats)
      additions=$(echo "$stats" | cut -d' ' -f1)
      deletions=$(echo "$stats" | cut -d' ' -f2)

      # Always create with --fill-first to get proper title
      gh pr new -d --fill-first

      if [ "$deletions" -gt "$additions" ]; then
        grug_body=$(get_grug_reply)
        if [ -n "$grug_body" ]; then
          # Update body with grug reply while keeping the --fill-first title
          gh pr edit --body "$grug_body"
        fi
      fi
    }

    ensure_repo_root
    ensure_branch
    ensure_feature_branch

    push_branch

    if pr_exists; then
      echo "pull request already exists for $(current_branch)"
      exit 0
    fi

    create_pr
  '';
}
