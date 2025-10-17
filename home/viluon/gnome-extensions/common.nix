{ pkgs, ... }:

{
  programs.gnome-shell.extensions = {
    auto-move-windows = {
      package = pkgs.gnomeExtensions.auto-move-windows;
    };

    brightness-control-using-ddcutil = {
      package = pkgs.gnomeExtensions.brightness-control-using-ddcutil;
    };

    middle-click-to-close-in-overview = {
      package = pkgs.gnomeExtensions.middle-click-to-close-in-overview;
    };

    vitals = {
      package = pkgs.gnomeExtensions.vitals;
    };

    kimpanel = {
      package = pkgs.gnomeExtensions.kimpanel;
    };
  };
}
