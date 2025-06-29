# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs
, ...
}:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware.nix
      ../../modules/system/networking
      ../../modules/system/nix
      ../../modules/desktop/gnome
      ../../modules/desktop/input-methods.nix
      ../../modules/hardware/audio.nix
      ../../modules/hardware/graphics.nix
      ../../modules/users/common.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # NVIDIA-specific configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = true;

  # Intel-specific configuration
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];

  # Host-specific packages
  environment.systemPackages = with pkgs; [
    efibootmgr
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
