{ delib, ... }:
delib.module {
  name = "hardware.graphics";

  nixos.always = {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
