{ delib, ... }:
delib.module {
  name = "desktop.input-methods";
  home.always.imports = [ ../../../modules/desktop/input-methods.nix ];
}
