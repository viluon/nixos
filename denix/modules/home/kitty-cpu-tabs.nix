{ delib, ... }:
delib.module {
  name = "home.kittyCpuTabs";

  home.always.imports = [
    (
      { config, lib, pkgs, ... }:
      let
        rgb = slot: map (channel: lib.toInt config.lib.stylix.colors."${slot}-rgb-${channel}") [ "r" "g" "b" ];
        tabColors = background: foreground: {
          background = rgb background;
          foreground = rgb foreground;
        };
        palette = pkgs.writeText "kitty-cpu-tabs-palette.json" (builtins.toJSON {
          active = tabColors "base00" "base05";
          inactive = tabColors "base01" "base04";
          heat = map rgb [ "base0A" "base09" "base08" ];
          hot_text = rgb "base00";
        });
      in
      {
        programs.kitty.settings = {
          allow_remote_control = "socket-only";
          listen_on = "unix:$XDG_RUNTIME_DIR/kitty-cpu";
        };

        systemd.user.services.kitty-cpu-tabs = {
          Unit = {
            Description = "Colour Kitty tabs by foreground CPU usage";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${pkgs.kitty-cpu-tabs}/bin/kitty-cpu-tabs ${palette}";
            Environment = "PATH=${lib.makeBinPath [ config.programs.kitty.package pkgs.coreutils ]}";
            Nice = 19;
            IOSchedulingClass = "idle";
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      }
    )
  ];
}
