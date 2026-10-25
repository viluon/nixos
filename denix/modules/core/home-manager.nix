{ delib, ... }:
delib.module {
  name = "core.home-manager";

  nixos.always = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
  };
}
