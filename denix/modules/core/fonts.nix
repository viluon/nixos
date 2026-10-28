{ delib, pkgs, ... }:
delib.module {
  name = "fonts";

  nixos.always = {
    fonts.packages = with pkgs; [
      corefonts
      libertine
    ];
  };
}
