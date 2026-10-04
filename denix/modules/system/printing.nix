{ delib, ... }:
delib.module {
  name = "system.printing";

  nixos.always.services.printing.enable = true;
}
