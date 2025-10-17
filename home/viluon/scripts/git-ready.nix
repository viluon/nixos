{ pkgs }:
pkgs.writeShellApplication {
  name = "git-ready";
  runtimeInputs = with pkgs; [ gh git coreutils jq wl-clipboard ];
  text = ''
    set -euo pipefail

    fail() { echo "$1" >&2; exit 1; }
    ensure_repo_root() { git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"; }
    ensure_branch() { git symbolic-ref --quiet --short HEAD >/dev/null 2>&1 || fail "detached HEAD state"; }

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
      local url=$1 repo num
      repo=$(printf '%s' "$url" | awk -F'/pull/' '{print $1}' | awk -F'/energy/' '{print $2}')
      num=$(printf '%s' "$url" | awk -F'/pull/' '{print $2}')
      [ -z "$repo" ] && fail "could not parse repo from url: $url"
      [ -z "$num" ] && fail "could not parse number from url: $url"
      printf '%s#%s' "$repo" "$num"
    }

    build_message() {
      local link_key=$1 url=$2 additions=$3 deletions=$4
      local change_scale=$(( additions > deletions ? additions : deletions ))
      local prefix="please (ping me to :pair-review: pair) review"
      local smol_tag="" grug_tag=""
      if [ "$change_scale" -lt 43 ]; then smol_tag=" the :smol-cat-is-smol: smol"; fi
      if [ "$deletions" -gt "$additions" ]; then grug_tag=":grug:"; fi
      printf '%s%s [%s](%s) %s:super-please::super-please::super-please:' "$prefix" "$smol_tag" "$link_key" "$url" "$grug_tag"
    }

    send_clipboard() { printf '%s' "$1" | wl-copy || fail "failed to write to clipboard"; }

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
    send_clipboard "$message"
    echo "copied review request for pr #$number ($key) to clipboard (additions=$additions deletions=$deletions)"
  '';
}
