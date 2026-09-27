{ delib, host, ... }:
delib.module {
  name = "system.printing";

  options = delib.singleEnableOption host.isLaptop;

  nixos.ifEnabled.services.printing.enable = true;
}
