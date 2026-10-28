{ delib, ... }:
delib.module {
  name = "system.gc";

  options = delib.singleEnableOption true;

  nixos.ifEnabled.nix.gc = {
    automatic = true;
    randomizedDelaySec = "15min";
    options = "--delete-older-than 60d";
  };
}
