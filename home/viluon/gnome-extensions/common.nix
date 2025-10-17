{ pkgs, ... }:

{
  gnome.extensions = {
    extraExtensions = with pkgs.gnomeExtensions; [
      auto-move-windows
      brightness-control-using-ddcutil
      kimpanel
      middle-click-to-close-in-overview
      vitals
    ];
  };
}
