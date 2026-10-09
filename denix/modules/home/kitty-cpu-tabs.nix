{ delib, ... }:
delib.module {
  name = "home.kittyCpuTabs";

  home.always.imports = [
    (
      { config, lib, pkgs, ... }: {
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
            ExecStart = "${pkgs.kitty-cpu-tabs}/bin/kitty-cpu-tabs";
            Environment = "PATH=${lib.makeBinPath [ config.programs.kitty.package pkgs.coreutils pkgs.iproute2 ]}";
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      }
    )
  ];
}
