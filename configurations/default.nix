{ inputs }:
let
  hostNames = builtins.attrNames (builtins.readDir ../denix/hosts);
in
inputs.denix.lib.configurations {
  moduleSystem = "nixos";
  homeManagerUser = "viluon";

  paths = [ ../denix/modules ] ++ map (name: ../denix/hosts + "/${name}/default.nix") hostNames;
  exclude = [
    ../denix/modules/editors/vscode-settings.nix
    ../denix/modules/desktop/niri
    ../denix/modules/home/scripts
    ../denix/modules/home/slack-review.nix
  ];

  extensions = with inputs.denix.lib.extensions; [
    args
    (base.withConfig {
      args.enable = true;
      hosts.type.types = [ "laptop" "server" ];
      hosts.features.features = [ "coding" "gaming" "monitoring" ];
    })
  ];

  specialArgs = {
    inherit inputs;
    inherit (inputs) niri;
    unstable-pkgs = import inputs.nixpkgs-unstable {
      system = "x86_64-linux";
      config = { allowUnfree = true; };
    };
  };
}
