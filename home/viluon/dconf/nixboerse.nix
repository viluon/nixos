{ lib
, ...
}:

with lib.hm.gvariant;

{
  "org/gnome/shell" = {
    enabled-extensions = [
      "display-brightness-ddcutil@themightydeity.github.com"
    ];
  };

  "org/gnome/desktop/input-sources" = {
    mru-sources = [ (mkTuple [ "xkb" "us" ]) ];
    sources = [ (mkTuple [ "xkb" "us" ]) ];
    xkb-options = [ "lv3:ralt_switch" "compose:rctrl" ];
  };

  "org/gnome/desktop/interface" = {
    scaling-factor = mkUint32 1;
    text-scaling-factor = 1.0;
  };
}
