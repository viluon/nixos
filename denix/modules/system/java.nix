{ delib, ... }:
delib.module {
  name = "system.java";

  nixos.always.programs.java.enable = true;
}
