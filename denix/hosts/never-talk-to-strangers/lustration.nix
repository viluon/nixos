{ delib, ... }:
delib.host {
  name = "never-talk-to-strangers";

  nixos = {
    boot.initrd.systemd.enable = false;

    boot.loader.grub.extraEntries = ''
      menuentry "Ubuntu (only before the first NixOS boot)" {
        search --no-floppy --label --set=root UEFI
        chainloader /EFI/ubuntu/shimx64.efi
      }
    '';
  };
}
