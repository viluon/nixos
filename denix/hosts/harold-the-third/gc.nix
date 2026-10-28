{ lib, ... }:
{
  nix.gc.automatic = lib.mkForce false;
  programs.nh.clean = {
    enable = true;
    dates = "daily";
    extraArgs = "--keep 3 --keep-since 14d";
  };
}
