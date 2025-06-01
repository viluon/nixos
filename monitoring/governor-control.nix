{ config, lib, pkgs, ... }:

let
  governorServer = pkgs.replaceVars ./governor-server.py {
    cpupowerPath = "${pkgs.linuxPackages.cpupower}/bin/cpupower";
  };
in
{
  # Enable cpupower tools
  environment.systemPackages = with pkgs; [
    linuxPackages.cpupower
  ];

  # Create a dedicated user for the governor control service
  users.users.cpugovernor = {
    isSystemUser = true;
    group = "cpugovernor";
    description = "CPU Governor Control User";
  };

  users.groups.cpugovernor = { };

  # Create a simple HTTP service to handle governor changes
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

      # Security settings
      NoNewPrivileges = false;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/sys/devices/system/cpu" ];

      # Allow access to CPU frequency control
      SupplementaryGroups = [ "wheel" ];
    };

    environment = {
      PYTHONUNBUFFERED = "1";
    };
  };

  # Configure sudo access for cpugovernor user
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

  # Ensure cpufreq modules are loaded
  boot.kernelModules = [ "cpufreq_ondemand" "cpufreq_conservative" "cpufreq_powersave" "cpufreq_performance" ];
}
