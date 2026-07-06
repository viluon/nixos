{ pkgs }:
let
  slackReview = import ../slack-review.nix;
in
pkgs.writeShellApplication {
  name = "git-ready";
  runtimeInputs = with pkgs; [ gh git coreutils jq wl-clipboard ];
  text = ''
    set -euo pipefail

    fail() { echo "$1" >&2; exit 1; }
    ensure_repo_root() { git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"; }
    ensure_branch() { git symbolic-ref --quiet --short HEAD >/dev/null 2>&1 || fail "detached HEAD state"; }
    usage() { fail "usage: git ready [auto]"; }

    ${slackReview}

    pr_json() {
      gh pr view --json number,url,isDraft,additions,deletions 2>/dev/null >/tmp/git-ready-pr.json || fail "no pull request associated with branch";
      cat /tmp/git-ready-pr.json
    }

    mark_ready_if_draft() {
      if printf '%s' "$json" | jq -e '.isDraft' >/dev/null 2>&1; then
        gh pr ready >/dev/null 2>&1 || fail "failed to mark pr ready";
        json=$(pr_json)
      fi
    }

    pr_number() { jq -r '.number'; }
    pr_url() { jq -r '.url'; }
    pr_additions() { jq -r '.additions'; }
    pr_deletions() { jq -r '.deletions'; }

    maybe_enable_auto_merge() {
      local additions=$1 deletions=$2 change_scale
      if [ "$auto_merge_requested" -ne 1 ]; then
        return 0
      fi
      if ! is_smol "$additions" "$deletions"; then
        change_scale=$(( additions > deletions ? additions : deletions ))
        fail "auto merge only available for :smol: changes (<43 lines). current change scale: $change_scale"
      fi
      gh pr merge "$number" --auto --merge >/dev/null 2>&1 \
        || gh pr merge "$number" --auto --squash >/dev/null 2>&1 \
        || fail "failed to enable auto merge"
    }

    auto_merge_requested=0
    if [ "$#" -gt 1 ]; then usage; fi
    if [ "$#" -eq 1 ]; then
      [ "$1" = "auto" ] || usage
      auto_merge_requested=1
    fi

    ensure_repo_root
    ensure_branch
    json=$(pr_json)
    mark_ready_if_draft
    number=$(printf '%s' "$json" | pr_number)
    url=$(printf '%s' "$json" | pr_url)
    additions=$(printf '%s' "$json" | pr_additions)
    deletions=$(printf '%s' "$json" | pr_deletions)
    key=$(repo_key "$url")
    message=$(build_message "$key" "$url" "$additions" "$deletions")
    maybe_enable_auto_merge "$additions" "$deletions"
    send_clipboard "$message"
    if [ "$auto_merge_requested" -eq 1 ]; then
      echo "copied review request for pr #$number ($key) to clipboard and enabled auto merge (additions=$additions deletions=$deletions)"
    else
      echo "copied review request for pr #$number ($key) to clipboard (additions=$additions deletions=$deletions)"
    fi
  '';
}
