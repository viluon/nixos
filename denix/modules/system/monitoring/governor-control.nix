{ delib, ... }:
delib.module {
  name = "system.monitoring.governor-control";

  nixos.always.imports = [
    (
      { config, lib, pkgs, ... }:

      let
        governorServer = pkgs.replaceVars ./governor-server.py {
          cpupowerPath = "${pkgs.linuxPackages.cpupower}/bin/cpupower";
        };
      in
      {
        environment.systemPackages = with pkgs; [
          linuxPackages.cpupower
        ];

        users.users.cpugovernor = {
          isSystemUser = true;
          group = "cpugovernor";
          description = "CPU Governor Control User";
        };

        users.groups.cpugovernor = { };

        systemd.services.cpu-governor-api = {
          description = "CPU Governor Control API";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];

          serviceConfig = {
            Type = "simple";
            User = "cpugovernor";
            Group = "cpugovernor";
            ExecStart = "${pkgs.python3}/bin/python3 ${governorServer}";
            Restart = "always";
            RestartSec = 5;

            NoNewPrivileges = false;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [ "/sys/devices/system/cpu" ];
          };

          environment = {
            PYTHONUNBUFFERED = "1";
          };
        };

        security.sudo.extraRules = [
          {
            users = [ "cpugovernor" ];
            commands = [
              {
                command = "${pkgs.linuxPackages.cpupower}/bin/cpupower";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      }
    )
  ];
}
