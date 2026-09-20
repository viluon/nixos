{ delib, ... }:
delib.host {
  name = "nixluon";

  nixos.disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-WD_BLACK_SN850X_2000GB_250304804903";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          start = "1M";
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "/rootfs" = {
                mountOptions = [ "compress=zstd:8" ];
                mountpoint = "/";
              };
              "/home" = {
                mountpoint = "/home";
              };
              "/home/user" = { };
              "/nix" = {
                mountOptions = [ "noatime" ];
                mountpoint = "/nix";
              };
            };
            mountpoint = "/partition-root";
          };
        };
      };
    };
  };
}
