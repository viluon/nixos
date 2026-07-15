{ pkgs }:
let
  slackReview = import ../slack-review.nix;
in
pkgs.writeShellApplication {
  name = "git-open";
  runtimeInputs = with pkgs; [ gh git coreutils jq wl-clipboard ];
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

    upstream_branch_exists() {
      local branch remote
      branch=$(current_branch)
      remote=$(branch_remote "$branch")
      git ls-remote --exit-code "$remote" "refs/heads/$branch" >/dev/null 2>&1
    }

    ensure_upstream_deleted() {
      local branch remote
      branch=$(current_branch)
      remote=$(branch_remote "$branch")
      if upstream_branch_exists; then
        fail "remote branch '$remote/$branch' already exists; delete it before creating a new PR"
      fi
    }

    current_pr_state() { gh pr view --state all --json state --jq '.state'; }

    gh_host() {
      local branch remote url host
      branch=$(current_branch)
      remote=$(branch_remote "$branch")
      url=$(git remote get-url "$remote")
      host=$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#^[^@]+@##; s#[:/].*$##')
      [ -n "$host" ] || fail "could not determine git host from remote '$remote'"
      printf '%s\n' "$host"
    }

    get_diff_stats() {
      local merge_base additions=0 deletions=0
      merge_base=$(git merge-base HEAD origin/main)

      while IFS=$'\t' read -r add del _; do
        # Skip binary files (numstat outputs "-" for binary)
        [[ "$add" == "-" || "$del" == "-" ]] && continue
        additions=$((additions + add))
        deletions=$((deletions + del))
      done < <(git diff --numstat "$merge_base"..HEAD)

      echo "$additions $deletions"
    }

    get_grug_reply() {
      gh api graphql --hostname "$(gh_host)" -f query='
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

    mark_ready() { gh pr ready >/dev/null 2>&1 || fail "failed to mark pr ready"; }

    ${slackReview}

    copy_result() {
      local json number url additions deletions key message
      json=$(gh pr view --json number,url,additions,deletions) || fail "failed to read pull request"
      number=$(printf '%s' "$json" | jq -r '.number')
      url=$(printf '%s' "$json" | jq -r '.url')
      additions=$(printf '%s' "$json" | jq -r '.additions')
      deletions=$(printf '%s' "$json" | jq -r '.deletions')
      if [ "$ready_requested" -eq 1 ]; then
        key=$(repo_key "$url")
        message=$(build_message "$key" "$url" "$additions" "$deletions")
        send_clipboard "$message"
        echo "copied review request for pr #$number ($key) to clipboard (additions=$additions deletions=$deletions)"
      else
        send_clipboard "$url"
        echo "copied pr url for #$number to clipboard: $url"
      fi
    }

    enable_auto_merge() {
      local additions=$1 deletions=$2 change_scale
      if ! is_smol "$additions" "$deletions"; then
        change_scale=$(( additions > deletions ? additions : deletions ))
        fail "auto merge only available for :smol: changes (<43 lines). current change scale: $change_scale"
      fi
      gh pr merge --auto --merge >/dev/null 2>&1 \
        || gh pr merge --auto --squash >/dev/null 2>&1 \
        || fail "failed to enable auto merge"
    }

    create_pr() {
      local stats additions deletions grug_body
      stats=$(get_diff_stats)
      additions=$(echo "$stats" | cut -d' ' -f1)
      deletions=$(echo "$stats" | cut -d' ' -f2)

      if [ "$ready_requested" -eq 1 ]; then
        gh pr new --fill-first
      else
        gh pr new -d --fill-first
      fi

      if [ "$deletions" -gt "$additions" ]; then
        grug_body=$(get_grug_reply)
        if [ -n "$grug_body" ]; then
          gh pr edit --body "$grug_body"
        fi
      fi

      if [ "$auto_merge_requested" -eq 1 ]; then
        enable_auto_merge "$additions" "$deletions"
      fi
    }

    usage() { fail "usage: git open [ready [auto]]"; }

    ready_requested=0
    auto_merge_requested=0
    if [ "$#" -gt 2 ]; then usage; fi
    if [ "$#" -ge 1 ]; then [ "$1" = "ready" ] || usage; ready_requested=1; fi
    if [ "$#" -ge 2 ]; then [ "$2" = "auto" ] || usage; auto_merge_requested=1; fi

    ensure_repo_root
    ensure_branch
    ensure_feature_branch

    pr_state=""
    if pr_state=$(current_pr_state 2>/dev/null); then
      :
    else
      pr_state=""
    fi

    case "$pr_state" in
      OPEN)
        push_branch
        if [ "$ready_requested" -eq 1 ]; then mark_ready; fi
        if [ "$auto_merge_requested" -eq 1 ]; then
          open_stats=$(gh pr view --json additions,deletions) || fail "failed to read pull request"
          enable_auto_merge \
            "$(printf '%s' "$open_stats" | jq -r '.additions')" \
            "$(printf '%s' "$open_stats" | jq -r '.deletions')"
        fi
        echo "pull request already exists for $(current_branch)"
        copy_result
        exit 0
        ;;
      CLOSED|MERGED)
        ensure_upstream_deleted
        ;;
    esac

    push_branch
    create_pr
    copy_result
  '';
}
