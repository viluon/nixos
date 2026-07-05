{ delib, inputs, ... }:
delib.host {
  name = "nixluon";
  type = "laptop";

  homeManagerSystem = "x86_64-linux";

  nixos.imports = [
    inputs.niri.nixosModules.niri
    inputs.stylix.nixosModules.stylix
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
    inputs.disko.nixosModules.disko
    ../../hosts/nixluon
  ];
}
