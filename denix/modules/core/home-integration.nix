{ delib
, inputs
, unstable-pkgs
, ...
}:
delib.module {
  name = "core.home-integration";

  nixos.always = { myconfig, ... }: {
    networking.hostName = myconfig.host.name;

    nixpkgs.hostPlatform = "x86_64-linux";

    nixpkgs.overlays = [
      (import ../../../packages)
      inputs.nix4vscode.overlays.default
    ];

    imports = [
      inputs.nix-index-database.nixosModules.nix-index
      { programs.nix-index-database.comma.enable = true; }
    ];

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.viluon = import ../../../home/viluon/home.nix;
    home-manager.extraSpecialArgs = {
      inherit inputs unstable-pkgs;
      hostname = myconfig.host.name;
    };
  };
}
