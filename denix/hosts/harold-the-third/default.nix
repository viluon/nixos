{ delib, inputs, ... }:
delib.host {
  name = "harold-the-third";
  type = "laptop";

  homeManagerSystem = "x86_64-linux";

  myconfig.editors.idea.enable = false;
  myconfig.editors.vscode.enable = false;
  myconfig.system.monitoring.grafana-config.enable = false;

  nixos.imports = [
    inputs.niri.nixosModules.niri
    inputs.disko.nixosModules.disko
  ] ++ delib.umport {
    path = ./.;
    exclude = [ ./default.nix ];
  };
}
