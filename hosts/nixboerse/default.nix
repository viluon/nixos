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
      ./nvidia.nix
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
  hardware.nvidia = {
    open = true;
    prime.offload.enable = true;
    powerManagement.finegrained = true;
  };

  # Intel-specific configuration
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];

  programs.virt-manager.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    qemu.package = pkgs.qemu_kvm;
    hooks.qemu = {
      libvirtd-network-hook = pkgs.writeShellScript "libvirtd-network-hook" ''
        set -euo pipefail

        case $1:$2 in
          ubuntu:start)
            ${pkgs.systemd}/bin/resolvectl dns virbr0 100.64.0.2
            ${pkgs.systemd}/bin/resolvectl domain virbr0 deutsche-boerse.de oa.pnrad.net dbgcloud.io
            ${pkgs.systemd}/bin/resolvectl default-route virbr0 no
            ;;
        esac
      '';
    };
  };

  # better legacy OS compatibility
  services.envfs.enable = true;
  programs.nix-ld.enable = true;

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
