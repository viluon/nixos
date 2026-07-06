{ delib, ... }:
delib.module {
  name = "desktop.niri";
  nixos.always.imports = [ ../../../modules/desktop/niri ];
}
