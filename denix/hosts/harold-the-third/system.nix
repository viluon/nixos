{ lib, ... }:
{
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.fprintd.enable = true;
  services.hardware.bolt.enable = true;

  programs.steam.enable = lib.mkForce false;
  hardware.graphics.enable32Bit = lib.mkForce false;
  programs.java.enable = lib.mkForce false;
  services.orca.enable = lib.mkForce false;
  services.speechd.enable = lib.mkForce false;

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "viluon";
    };
    defaultSession = lib.mkForce "niri";
  };

  system.stateVersion = "26.05";
}
