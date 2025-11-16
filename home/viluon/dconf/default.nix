{ lib
, ...
}:

let
  filenames = builtins.attrNames (lib.filterAttrs (name: _: name != "default.nix") (builtins.readDir ./.));
  hostnames = map (name: lib.removeSuffix ".nix" name) filenames;
  hosts = lib.genAttrs hostnames (hostname: import ./${hostname}.nix { inherit lib; });

  commonSettings = with lib.hm.gvariant; {
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
in
{
  getGnomeSettings = hostname: lib.recursiveUpdate commonSettings hosts.${hostname};
}
