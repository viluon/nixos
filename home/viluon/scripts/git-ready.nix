{ pkgs }:
pkgs.writeShellApplication {
  name = "git-ready";
  runtimeInputs = with pkgs; [ gh git coreutils jq wl-clipboard ];
  text = ''
    set -euo pipefail

    fail() { echo "$1" >&2; exit 1; }
    ensure_repo_root() { git rev-parse --show-toplevel >/dev/null 2>&1 || fail "Not inside a git repository"; }
    ensure_branch() { git symbolic-ref --quiet --short HEAD >/dev/null 2>&1 || fail "Detached HEAD state"; }

    pr_json() {
      gh pr view --json number,url,isDraft 2>/dev/null >/tmp/git-ready-pr.json || fail "No pull request associated with branch";
      cat /tmp/git-ready-pr.json
    }

    mark_ready_if_draft() {
      if gh pr view --json isDraft | jq -e '.isDraft' >/dev/null 2>&1; then
        gh pr ready >/dev/null 2>&1 || fail "Failed to mark PR ready";
      fi
    }

    pr_number() { jq -r '.number'; }
    pr_url() { jq -r '.url'; }

    repo_key() {
      url=$1
      repo=$(printf '%s' "''${url}" | awk -F'/pull/' '{print $1}' | awk -F'/energy/' '{print $2}')
      num=$(printf '%s' "''${url}" | awk -F'/pull/' '{print $2}')
      [ -z "''${repo}" ] || [ -z "''${num}" ] && fail "Failed to parse URL: ''${url}"
      printf '%s#%s' "''${repo}" "''${num}"
    }

    send_clipboard() {
      link_key=$1; url=$2
      msg="Please (catch me for a :pair-review: pair) review of [''${link_key}](''${url}) :super-please: :super-please: :super-please:"
      printf '%s' "''${msg}" | wl-copy || fail "Failed to write to clipboard"
    }

    ensure_repo_root
    ensure_branch
    json=$(pr_json)
    mark_ready_if_draft
    number=$(printf '%s' "''${json}" | pr_number)
    url=$(printf '%s' "''${json}" | pr_url)
    key=$(repo_key "''${url}")
    send_clipboard "''${key}" "''${url}"
    echo "Copied review request for PR #''${number} (''${key}) to clipboard"
  '';
}
