{ delib, inputs, ... }:
delib.module {
  name = "desktop.gnome";

  nixos.always.imports = [ ../../../modules/desktop/gnome ];

  home.always.imports = [
    "${inputs.xhmm}/desktop/gnome/extensions.nix"
    (
      { lib, ... }:
      {
        dconf.settings = with lib.hm.gvariant; {
          "org/gnome/desktop/interface" = {
            enable-animations = true;
            font-antialiasing = "rgba";
            font-hinting = "full";
            show-battery-percentage = true;
          };
          "org/gnome/gnome-system-monitor" = {
            show-whose-processes = "all";
          };
          "org/gtk/gtk4/settings/file-chooser" = {
            show-hidden = true;
          };
        };
      }
    )
  ];
}
