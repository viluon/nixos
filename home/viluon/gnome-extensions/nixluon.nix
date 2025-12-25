{ pkgs, ... }:

{
  gnome.extensions.enabledExtensions = with pkgs.gnomeExtensions; [
    brightness-control-using-ddcutil
    kimpanel
    middle-click-to-close-in-overview
    vitals
  ];
}
