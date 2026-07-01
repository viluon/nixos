# Shared Slack review-request helpers for git-open and git-ready.
# Expects a `fail` function and wl-clipboard, coreutils, gawk on PATH.
''
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
''
