{ delib, ... }:
delib.module {
  name = "core.server-home-integration";

  nixos.always = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
  };
}
