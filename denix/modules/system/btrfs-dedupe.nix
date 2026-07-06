{ delib, ... }:
delib.module {
  name = "system.btrfsDedupe";

  options.system.btrfsDedupe = with delib; {
    enable = boolOption false;
    spec = strOption "";
    loadavgTarget = strOption "";
  };

  nixos.ifEnabled = { cfg, ... }: {
    services.beesd.filesystems.root = {
      inherit (cfg) spec;
      hashTableSizeMB = 4 * 1024;
      extraOptions = [
        "--thread-min"
        "1"
        "--loadavg-target"
        cfg.loadavgTarget
      ];
    };
  };
}
