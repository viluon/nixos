{ lib
, ...
}:

with lib.hm.gvariant;

{
  "org/gnome/shell" = {
    enabled-extensions = [
      "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
      "display-brightness-ddcutil@themightydeity.github.com"
      "kimpanel@kde.org"
      "middleclickclose@paolo.tranquilli.gmail.com"
      "Vitals@CoreCoding.com"
    ];
  };

  "org/gnome/desktop/input-sources" = {
    mru-sources = [ (mkTuple [ "xkb" "us" ]) ];
    sources = [ (mkTuple [ "xkb" "us" ]) ];
    xkb-options = [ "lv3:ralt_switch" "compose:rctrl" ];
  };

  "org/gnome/shell/extensions/auto-move-windows" = {
    application-list = [
      "firefox.desktop:1"
      "idea-ultimate.desktop:2"
      "obsidian.desktop:3"
      "org.gnome.SystemMonitor.desktop:3"
      "virt-manager.desktop:4"
    ];
  };

  "org/gnome/desktop/interface" = {
    scaling-factor = mkUint32 1;
    text-scaling-factor = 1.0;
  };
}
