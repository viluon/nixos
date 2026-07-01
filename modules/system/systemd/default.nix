{ pkgs, ... }:
{
  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "8s";
    DefaultCPUAccounting = true;
    DefaultIOAccounting = true;
    DefaultMemoryAccounting = true;
    DefaultTasksAccounting = true;
  };

  systemd.user.extraConfig = ''
    DefaultTimeoutStopSec=20s
  '';

  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
    settings.OOM = {
      SwapUsedLimit = "90%";
      DefaultMemoryPressureDurationSec = "20s";
    };
  };

  systemd.services."user@" = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "50%";
    };
  };

  systemd.slices.user.sliceConfig = {
    ManagedOOMSwap = "kill";
  };

  systemd.user.services.oomd-notify = {
    description = "Notify on OOM kills";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = pkgs.writeShellScript "oomd-notify" ''
        ${pkgs.systemd}/bin/journalctl -f -o cat -u systemd-oomd.service | while read -r line; do
          ${pkgs.libnotify}/bin/notify-send -u critical "OOM Kill" "$line"
        done
      '';
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
