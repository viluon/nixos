{ delib, inputs, ... }:
delib.host {
  name = "nixboerse";
  type = "laptop";

  homeManagerSystem = "x86_64-linux";

  nixos.imports = [
    inputs.niri.nixosModules.niri
    inputs.stylix.nixosModules.stylix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p1-gen3
    inputs.disko.nixosModules.disko
    ../../hosts/nixboerse
  ];
}
