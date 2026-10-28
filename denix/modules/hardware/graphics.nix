{ delib, host, ... }:
delib.module {
  name = "hardware.graphics";

  options = delib.singleEnableOption host.isLaptop;

  nixos.ifEnabled.hardware.graphics.enable = true;
}
