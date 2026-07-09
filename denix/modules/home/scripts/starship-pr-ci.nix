{ pkgs }:
pkgs.writeShellApplication {
  name = "starship-pr-ci";
  runtimeInputs = with pkgs; [ gh git jq coreutils util-linux ];
  text = ''
    set -euo pipefail

    ttl=15
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/starship-pr-ci"

    # verdict emits "<state>\t<detail>\t<detailUrl>": detail is the sole winning check's
    # name (else winning-state count); detailUrl links to that sole check's run when unique.
    # shellcheck disable=SC2016
    jq_lib='
      def verdict($c):
        if ($c | length) == 0 then "none\t\t"
        else
          (if ([$c[].st] | index("failure")) then "failure"
           elif ([$c[].st] | index("pending")) then "pending"
           else "success" end) as $w
          | ([$c[] | select(.st == $w)]) as $m
          | (if ($m | length) == 1 then $m[0].name
             else ($m | length | tostring) end) as $detail
          | (if ($m | length) == 1 then ($m[0].url // "") else "" end) as $durl
          | $w + "\t" + $detail + "\t" + $durl
        end;
      def node:
        { name: (.name // .context // "check"),
          url: (.detailsUrl // .targetUrl // ""),
          st: (
            if .__typename == "CheckRun" then
              (if .status != "COMPLETED" then "pending"
               elif (.conclusion | IN("SUCCESS","NEUTRAL","SKIPPED")) then "success"
               else "failure" end)
            elif .__typename == "StatusContext" then
              (if .state == "SUCCESS" then "success"
               elif .state == "PENDING" then "pending"
               else "failure" end)
            else "pending" end) };'

    # shellcheck disable=SC2016
    pr_jq="$jq_lib"'
      if .state != "OPEN" then "none\t\t\t"
      else verdict([.statusCheckRollup[] | node]) + "\t" + .url end'

    # shellcheck disable=SC2016
    head_jq="$jq_lib"'
      verdict([.data.repository.object.statusCheckRollup.contexts.nodes[]? | node]) + "\t"'

    remote_url() {
      git remote get-url \
        "$(git config "branch.$(git symbolic-ref --quiet --short HEAD).remote" 2>/dev/null || echo origin)" \
        2>/dev/null
    }

    query_head() {
      local host=$1 slug=$2 sha owner name
      sha=$(git rev-parse --quiet --verify HEAD 2>/dev/null) || { printf 'none\t\t\t\n'; return; }
      owner=''${slug%%/*}
      name=''${slug#*/}
      # shellcheck disable=SC2016
      GH_HOST="$host" gh api graphql -F owner="$owner" -F name="$name" -F oid="$sha" -f query='
        query($owner:String!,$name:String!,$oid:GitObjectID!){
          repository(owner:$owner,name:$name){
            object(oid:$oid){ ... on Commit {
              statusCheckRollup { contexts(first:100){ nodes {
                __typename
                ... on CheckRun { name status conclusion detailsUrl }
                ... on StatusContext { context state targetUrl }
              } } }
            } }
          }
        }' --jq "$head_jq" 2>/dev/null || printf 'none\t\t\t\n'
    }

    query_ci() {
      local url host slug result
      url=$(remote_url) || { printf 'none\t\t\t\n'; return; }
      [ -n "$url" ] || { printf 'none\t\t\t\n'; return; }
      host=$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#^[^@]+@##; s#[:/].*$##')
      slug=$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#^[^@]+@##; s#^[^/:]+[/:]##; s#\.git$##')
      if [ -z "$host" ] || ! gh auth status --hostname "$host" >/dev/null 2>&1; then
        printf 'none\t\t\t\n'; return
      fi
      result=$(GH_HOST="$host" gh pr view --json state,statusCheckRollup,url --jq "$pr_jq" 2>/dev/null || true)
      case "$result" in
        ""|none$'\t'*) query_head "$host" "$slug" ;;
        *) printf '%s\n' "$result" ;;
      esac
    }

    refresh() {
      local repo_root=$1 head_sha=$2 cache_file=$3 result tmp
      exec 9>>"$cache_file"
      flock -n 9 || exit 0
      cd "$repo_root" 2>/dev/null || exit 0
      result=$(query_ci)
      [ -n "$result" ] || result=$'none\t\t\t'
      tmp=$(mktemp "$cache_file.XXXXXX")
      printf '%s\t%s\n' "$head_sha" "$result" > "$tmp"
      mv -f "$tmp" "$cache_file"
      find "$cache_dir" -maxdepth 1 -type f -mtime +30 -delete 2>/dev/null || true
    }

    # Fast path: cache read + detached refresh; never blocks on the network.
    resolve() {
      local repo_root branch head_sha key cache_file
      repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
      branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || return 1
      head_sha=$(git rev-parse --quiet --verify HEAD 2>/dev/null) || return 1

      key=$(printf '%s\0%s' "$repo_root" "$branch" | sha1sum | cut -d' ' -f1)
      cache_file="$cache_dir/$key"
      mkdir -p "$cache_dir"

      local cached_sha="" cached_state="" cached_detail="" cached_durl="" cached_prurl="" cache_mtime=0
      if [ -r "$cache_file" ]; then
        cached_sha=$(cut -f1 "$cache_file")
        cached_state=$(cut -f2 "$cache_file")
        cached_detail=$(cut -f3 "$cache_file")
        cached_durl=$(cut -f4 "$cache_file")
        cached_prurl=$(cut -f5 "$cache_file")
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
      fi

      if [ "$cached_sha" != "$head_sha" ] || [ "$(( $(date +%s) - cache_mtime ))" -ge "$ttl" ]; then
        setsid -f "$0" __refresh "$repo_root" "$head_sha" "$cache_file" >/dev/null 2>&1
      fi

      printf '%s\t%s\t%s\t%s\n' "''${cached_state:-none}" "$cached_detail" "$cached_durl" "$cached_prurl"
    }

    # osc8 <url> <text>: emit an OSC 8 terminal hyperlink; plain text when url empty.
    osc8() {
      # shellcheck disable=SC1003
      if [ -n "$1" ]; then printf '\033]8;;%s\033\\%s\033]8;;\033\\' "$1" "$2"
      else printf '%s' "$2"; fi
    }

    case "''${1:-read}" in
      __refresh) refresh "$2" "$3" "$4" ;;
      read)      resolve 2>/dev/null | cut -f1 ;;
      detail)
        line=$(resolve 2>/dev/null)
        osc8 "$(printf '%s' "$line" | cut -f3)" "$(printf '%s' "$line" | cut -f2)" ;;
      link)
        prurl=$(resolve 2>/dev/null | cut -f4)
        [ -n "$prurl" ] || exit 0
        osc8 "$prurl" "$(printf '\uf407')" ;;
      is-pr)
        [ -n "$(resolve 2>/dev/null | cut -f4)" ] ;;
      is)        [ "$(resolve 2>/dev/null | cut -f1)" = "$2" ] ;;
      *)         echo "usage: starship-pr-ci [read|detail|link|is-pr|is <state>]" >&2; exit 2 ;;
    esac
  '';
}
