{ pkgs }:
pkgs.writeShellApplication {
  name = "git-ready";
  runtimeInputs = with pkgs; [ gh git coreutils jq wl-clipboard ];
  text = ''
    set -euo pipefail

    fail() { echo "$1" >&2; exit 1; }
    ensure_repo_root() { git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"; }
    ensure_branch() { git symbolic-ref --quiet --short HEAD >/dev/null 2>&1 || fail "detached HEAD state"; }
    usage() { fail "usage: git ready [auto]"; }

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

    repo_key() {
      local url=$1 org repo num
      org=$(printf '%s' "$url" | awk -F'https://[^/]+/' '{print $2}' | awk -F'/' '{print $1}')
      repo=$(printf '%s' "$url" | awk -F'https://[^/]+/' '{print $2}' | awk -F'/' '{print $2}')
      num=$(printf '%s' "$url" | awk -F'/pull/' '{print $2}')
      [ -z "$org" ] && fail "could not parse org from url: $url"
      [ -z "$repo" ] && fail "could not parse repo from url: $url"
      [ -z "$num" ] && fail "could not parse number from url: $url"
      printf '%s#%s' "$repo" "$num"
    }

    is_smol() {
      local additions=$1 deletions=$2 change_scale
      change_scale=$(( additions > deletions ? additions : deletions ))
      if [ "$change_scale" -lt 43 ]; then
        return 0
      fi
      return 1
    }

    build_message() {
      local link_key=$1 url=$2 additions=$3 deletions=$4
      local prefix="please (ping me to :pair-review: pair) review"
      local smol_tag="" grug_tag=""
      if is_smol "$additions" "$deletions"; then smol_tag=" the :smol-cat-is-smol: smol"; fi
      if [ "$deletions" -gt "$additions" ]; then grug_tag=":grug:"; fi
      printf '%s%s [%s](%s) %s:super-please::super-please::super-please:' "$prefix" "$smol_tag" "$link_key" "$url" "$grug_tag"
    }

    send_clipboard() { printf '%s' "$1" | wl-copy || fail "failed to write to clipboard"; }

    maybe_enable_auto_merge() {
      local additions=$1 deletions=$2 change_scale
      if [ "$auto_merge_requested" -ne 1 ]; then
        return 0
      fi
      if ! is_smol "$additions" "$deletions"; then
        change_scale=$(( additions > deletions ? additions : deletions ))
        fail "auto merge only available for :smol: changes (<43 lines). current change scale: $change_scale"
      fi
      gh pr merge "$number" --auto --merge >/dev/null 2>&1 || fail "failed to enable auto merge"
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
