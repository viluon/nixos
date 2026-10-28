{ delib, inputs, ... }:
delib.host {
  name = "harold-the-third";
  type = "laptop";

  homeManagerSystem = "x86_64-linux";

  nixos.imports = [
    inputs.niri.nixosModules.niri
    inputs.disko.nixosModules.disko
  ] ++ delib.umport {
    path = ./.;
    exclude = [ ./default.nix ];
  };
}
