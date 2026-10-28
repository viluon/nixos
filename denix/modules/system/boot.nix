{ delib, host, lib, ... }:
delib.module {
  name = "system.boot";

  options = delib.singleEnableOption host.isLaptop;

  nixos.ifEnabled = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
    boot.plymouth.enable = true;
    services.fwupd.enable = true;
  };
}
