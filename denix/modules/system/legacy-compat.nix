{ delib, ... }:
delib.module {
  name = "system.legacyCompat";

  nixos.always = {
    services.envfs.enable = true;
    programs.nix-ld.enable = true;
  };
}
