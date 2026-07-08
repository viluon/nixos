{ pkgs }:
pkgs.writeShellApplication {
  name = "starship-pr-ci";
  runtimeInputs = with pkgs; [ gh git jq coreutils util-linux ];
  text = ''
    set -euo pipefail

    ttl=15
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/starship-pr-ci"

    # verdict emits "<state>\t<detail>": detail is the sole failing check's name, else winning-state count.
    # shellcheck disable=SC2016
    jq_lib='
      def verdict($c):
        if ($c | length) == 0 then "none\t"
        else
          (if ([$c[].st] | index("failure")) then "failure"
           elif ([$c[].st] | index("pending")) then "pending"
           else "success" end) as $w
          | ([$c[] | select(.st == $w)]) as $m
          | (if $w == "failure" and ($m | length) == 1 then $m[0].name
             else ($m | length | tostring) end)
          | $w + "\t" + .
        end;
      def node:
        { name: (.name // .context // "check"),
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
      if .state != "OPEN" then "none\t"
      else verdict([.statusCheckRollup[] | node]) end'

    # shellcheck disable=SC2016
    head_jq="$jq_lib"'
      verdict([.data.repository.object.statusCheckRollup.contexts.nodes[]? | node])'

    remote_url() {
      git remote get-url \
        "$(git config "branch.$(git symbolic-ref --quiet --short HEAD).remote" 2>/dev/null || echo origin)" \
        2>/dev/null
    }

    query_head() {
      local host=$1 slug=$2 sha owner name
      sha=$(git rev-parse --quiet --verify HEAD 2>/dev/null) || { printf 'none\t\n'; return; }
      owner=''${slug%%/*}
      name=''${slug#*/}
      # shellcheck disable=SC2016
      GH_HOST="$host" gh api graphql -F owner="$owner" -F name="$name" -F oid="$sha" -f query='
        query($owner:String!,$name:String!,$oid:GitObjectID!){
          repository(owner:$owner,name:$name){
            object(oid:$oid){ ... on Commit {
              statusCheckRollup { contexts(first:100){ nodes {
                __typename
                ... on CheckRun { name status conclusion }
                ... on StatusContext { context state }
              } } }
            } }
          }
        }' --jq "$head_jq" 2>/dev/null || printf 'none\t\n'
    }

    query_ci() {
      local url host slug result
      url=$(remote_url) || { printf 'none\t\n'; return; }
      [ -n "$url" ] || { printf 'none\t\n'; return; }
      host=$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#^[^@]+@##; s#[:/].*$##')
      slug=$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#^[^@]+@##; s#^[^/:]+[/:]##; s#\.git$##')
      if [ -z "$host" ] || ! gh auth status --hostname "$host" >/dev/null 2>&1; then
        printf 'none\t\n'; return
      fi
      result=$(GH_HOST="$host" gh pr view --json state,statusCheckRollup --jq "$pr_jq" 2>/dev/null || true)
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
      [ -n "$result" ] || result=$'none\t'
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

      local cached_sha="" cached_state="" cached_detail="" cache_mtime=0
      if [ -r "$cache_file" ]; then
        IFS=$'\t' read -r cached_sha cached_state cached_detail < "$cache_file" || true
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
      fi

      if [ "$cached_sha" != "$head_sha" ] || [ "$(( $(date +%s) - cache_mtime ))" -ge "$ttl" ]; then
        setsid -f "$0" __refresh "$repo_root" "$head_sha" "$cache_file" >/dev/null 2>&1
      fi

      printf '%s\t%s\n' "''${cached_state:-none}" "$cached_detail"
    }

    case "''${1:-read}" in
      __refresh) refresh "$2" "$3" "$4" ;;
      read)      resolve 2>/dev/null | cut -f1 ;;
      detail)    resolve 2>/dev/null | cut -f2- ;;
      is)        [ "$(resolve 2>/dev/null | cut -f1)" = "$2" ] ;;
      *)         echo "usage: starship-pr-ci [read|detail|is <state>]" >&2; exit 2 ;;
    esac
  '';
}
