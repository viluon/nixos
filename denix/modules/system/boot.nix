{ delib, ... }:
delib.module {
  name = "system.boot";

  nixos.always = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.plymouth.enable = true;
    services.fwupd.enable = true;
  };
}
