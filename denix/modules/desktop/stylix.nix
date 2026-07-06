{ delib, inputs, ... }:
delib.module {
  name = "desktop.stylix";
  nixos.always.imports = [
    inputs.stylix.nixosModules.stylix
    ../../../modules/desktop/stylix
  ];
}
