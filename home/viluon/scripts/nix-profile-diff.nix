{ pkgs }:
pkgs.writeShellApplication {
  name = "nix-profile-diff";
  runtimeInputs = with pkgs; [ nix perl git coreutils ];
  text = ''
    set -euo pipefail

    fail() { echo "$1" >&2; exit 1; }
    ensure_git_repo() { git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"; }
    ensure_flake() { [ -f "flake.nix" ] || fail "no flake.nix found in repository root"; }

    ensure_git_repo
    ensure_flake

    current_system="/nix/var/nix/profiles/system"
    hostname=''${1:-$(hostname)}
    profile_dir=$(mktemp -d)

    cleanup() { rm -rf "$profile_dir"; }
    trap cleanup EXIT

    nix build "$current_system" --profile "$profile_dir/profile"

    nix build ".#nixosConfigurations.$hostname.config.system.build.toplevel" \
      --profile "$profile_dir/profile"

    nix profile diff-closures --profile "$profile_dir/profile" \
      | perl -pe 's/\e\[[0-9;]*m(?:\e\[K)?//g'
  '';
}
