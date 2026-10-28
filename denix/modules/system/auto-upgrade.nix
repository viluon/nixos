{ delib, host, ... }:
delib.module {
  name = "system.autoUpgrade";

  options = delib.singleEnableOption host.isServer;

  nixos.ifEnabled = { myconfig, ... }: {
    system.autoUpgrade = {
      enable = true;
      flake = "github:viluon/nixos#${myconfig.host.name}";
      upgrade = false;
      allowReboot = true;
      rebootWindow = {
        lower = "03:00";
        upper = "04:00";
      };
    };
  };
}
