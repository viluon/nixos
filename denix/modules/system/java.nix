{ delib, host, ... }:
delib.module {
  name = "system.java";

  options = delib.singleEnableOption host.codingFeatured;

  nixos.ifEnabled.programs.java.enable = true;
}
