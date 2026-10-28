{ delib, host, pkgs, ... }:
delib.module {
  name = "fonts";

  options = delib.singleEnableOption host.isLaptop;

  nixos.ifEnabled = {
    fonts.packages = with pkgs; [
      corefonts
      libertine
    ];
  };
}
