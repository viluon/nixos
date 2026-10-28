{ delib, host, ... }:
delib.module {
  name = "system.legacyCompat";

  options = delib.singleEnableOption host.isLaptop;

  nixos.ifEnabled = {
    services.envfs.enable = true;
    programs.nix-ld.enable = true;
  };
}
