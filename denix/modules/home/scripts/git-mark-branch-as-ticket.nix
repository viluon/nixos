{ pkgs }:
pkgs.writeShellApplication {
  name = "git-mark-branch-as-ticket";
  runtimeInputs = with pkgs; [ git gnused ];
  text = ''
    set -eo pipefail

    if [ -z "''${1:-}" ]; then
      echo "Please provide a ticket number, e.g. M7G-123"
      exit 1
    fi

    git prefix-messages "$1: " "$(git remote show origin | grep "HEAD branch" | sed 's/.*: //')"
  '';
}
