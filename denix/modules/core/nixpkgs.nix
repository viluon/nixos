{ delib, inputs, ... }:
delib.module {
  name = "core.nixpkgs";

  nixos.always = { myconfig, ... }: {
    networking.hostName = myconfig.host.name;

    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = [ (import ../../../packages) ];

    imports = [
      inputs.nix-index-database.nixosModules.nix-index
      { programs.nix-index-database.comma.enable = true; }
    ];
  };
}
