{ inputs, denixConfigurations, hosts }:
denixConfigurations {
  paths = hosts ++ [
    ../denix/modules/core/constants.nix
    ../denix/modules/core/home-manager.nix
    ../denix/modules/core/locale.nix
    ../denix/modules/core/nixpkgs.nix
    ../denix/modules/core/user.nix
    ../denix/modules/home/basic-shell.nix
    ../denix/modules/home/core.nix
    ../denix/modules/home/git.nix
    ../denix/modules/system/auto-upgrade.nix
    ../denix/modules/system/gc.nix
    ../denix/modules/system/nix.nix
  ];

  specialArgs = { inherit inputs; };
}
