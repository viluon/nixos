{ pkgs }:
pkgs.writeShellApplication {
  name = "git-prefix-messages";
  runtimeInputs = with pkgs; [ git gnused ];
  text = ''
    set -euxo pipefail

    if [ "$#" -ne 2 ]; then
      echo "usage: git-prefix-messages <prefix> <upstream-or-sha>" >&2
      exit 2
    fi

    GIT_MSG_PREFIX="$1"
    export GIT_MSG_SED_CMD="1 s/^(\\S+: ?)?/$GIT_MSG_PREFIX/1"

    git rebase --interactive "$2" --exec "git commit --amend --message=\"\$(git log --format=%B -n 1 | sed -E \"\$GIT_MSG_SED_CMD\")\""
  '';
}
