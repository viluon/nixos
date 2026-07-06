{ pkgs }:
pkgs.writeShellApplication {
  name = "git-update-staging";
  runtimeInputs = with pkgs; [ git ];
  text = ''
    set -euo pipefail

    fail() { echo "$1" >&2; exit 1; }
    current_branch() { git symbolic-ref --quiet --short HEAD || fail "detached HEAD state"; }

    branch=$(current_branch)
    staging_dir="$HOME/projects/m7g.monorepo-staging"

    if [ ! -d "$staging_dir" ]; then
      fail "staging directory not found: $staging_dir"
    fi

    echo "Updating staging repo for branch: $branch"
    cd "$staging_dir"
    git fetch --all
    git reset --hard "upstream/$branch"
    git push --force-with-lease --force-if-includes
  '';
}
