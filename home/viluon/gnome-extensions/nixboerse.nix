{ lib, ... }:

with lib.hm.gvariant;

{
  dconf.extensions = {
    auto-move-windows = {
      enable = true;
      settings."org/gnome/shell/extensions/auto-move-windows" = {
        application-list = [
          "firefox.desktop:1"
          "idea-ultimate.desktop:2"
          "obsidian.desktop:3"
          "org.gnome.SystemMonitor.desktop:3"
          "virt-manager.desktop:4"
        ];
      };
    };

    brightness-control-using-ddcutil.enable = true;
    kimpanel.enable = true;
    middle-click-to-close-in-overview.enable = true;
    vitals.enable = true;
  };
}
