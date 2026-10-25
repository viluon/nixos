{ delib, ... }:
delib.host {
  name = "never-talk-to-strangers";

  nixos =
    { name, ... }:
    {
      system.autoUpgrade = {
        enable = true;
        flake = "github:viluon/nixos#${name}";
        upgrade = false;
        dates = "03/4:00";
        allowReboot = true;
        rebootWindow = {
          lower = "03:00";
          upper = "04:00";
        };
      };
    };
}
