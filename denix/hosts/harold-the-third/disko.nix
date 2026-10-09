let
  btrfsMountOptions = [ "compress-force=zstd:15" "noatime" ];
in
{
  disko.devices.disk.usb = {
    type = "disk";
    device = "/dev/disk/by-id/usb-SanDisk_Ultra_Fit_4C531001370402104091-0:0";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          label = "harold-esp";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          label = "harold-root";
          content = {
            type = "btrfs";
            subvolumes = {
              "/rootfs" = {
                mountpoint = "/";
                mountOptions = btrfsMountOptions;
              };
              "/home" = {
                mountpoint = "/home";
                mountOptions = btrfsMountOptions;
              };
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = btrfsMountOptions;
              };
            };
          };
        };
      };
    };
  };
}
