{ pkgs, ... }:

{
  gnome.extensions.enabledExtensions = with pkgs.gnomeExtensions; [
    brightness-control-using-ddcutil
    kimpanel
    middle-click-to-close-in-overview
    vitals
  ];

  dconf.settings."org/gnome/shell/extensions/auto-move-windows" = {
    application-list = [
      "firefox.desktop:1"
      "idea-ultimate.desktop:2"
      "obsidian.desktop:3"
      "org.gnome.SystemMonitor.desktop:3"
      "virt-manager.desktop:4"
    ];
  };
}
