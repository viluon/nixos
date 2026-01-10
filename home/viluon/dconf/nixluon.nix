# originally generated via dconf2nix: https://github.com/gvolpe/dconf2nix
{ lib
, ...
}:

with lib.hm.gvariant;

{
  "org/gnome/desktop/input-sources" = {
    mru-sources = [ (mkTuple [ "xkb" "us" ]) ];
    sources = [ (mkTuple [ "xkb" "us" ]) ];
    xkb-options = [ "lv3:ralt_switch" "compose:rctrl" ];
  };
}
