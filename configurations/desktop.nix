{ inputs, denixConfigurations, serverHosts }:
denixConfigurations {
  paths = [ ../denix ];
  exclude = [
    ../denix/modules/editors/vscode-settings.nix
    ../denix/modules/desktop/niri
    ../denix/modules/home/scripts
    ../denix/modules/home/slack-review.nix
  ] ++ serverHosts;

  specialArgs = {
    inherit inputs;
    inherit (inputs) niri;
    unstable-pkgs = import inputs.nixpkgs-unstable {
      system = "x86_64-linux";
      config = { allowUnfree = true; };
    };
  };
}
