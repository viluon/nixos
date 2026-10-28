{ pkgs, ... }:
{
  boot.loader.efi.canTouchEfiVariables = false;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.fprintd.enable = true;
  services.hardware.bolt.enable = true;

  environment.gnome.excludePackages = [ pkgs.orca ];
  services.speechd.enable = false;

  services.displayManager.autoLogin = {
    enable = true;
    user = "viluon";
  };

  system.stateVersion = "26.05";
}
