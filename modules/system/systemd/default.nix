{
  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "8s";
    DefaultCPUAccounting = true;
    DefaultIOAccounting = true;
    DefaultMemoryAccounting = true;
    DefaultTasksAccounting = true;
  };

  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
    settings.OOM = {
      SwapUsedLimitPercent = "90%";
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
}
