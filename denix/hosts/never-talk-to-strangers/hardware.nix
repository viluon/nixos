{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/oci-options.nix")
    (modulesPath + "/virtualisation/oci-common.nix")
  ];

  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/cloudimg-rootfs";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-label/UEFI";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  boot.growPartition = lib.mkForce false;

  # The 106 MB ESP holds kernels and initrds of every listed generation.
  boot.loader.grub.configurationLimit = 2;
}
