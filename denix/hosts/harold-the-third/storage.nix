{ config, lib, ... }:
let
  usbDiskLink = lib.removePrefix "/dev/" config.disko.devices.disk.usb.device;
  mebibytes = n: n * 1024 * 1024;
in
{
  boot.tmp.useTmpfs = true;

  fileSystems."/nix/var/nix/builds" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=0755" "size=50%" ];
  };

  zramSwap.enable = true;

  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="sd[a-z]", SYMLINK=="${usbDiskLink}", ATTR{queue/scheduler}="bfq"
  '';

  boot.kernel.sysctl = {
    "vm.dirty_background_bytes" = mebibytes 64;
    "vm.dirty_bytes" = mebibytes 256;
    "vm.vfs_cache_pressure" = 50;
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
  };
}
