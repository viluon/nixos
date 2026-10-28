{ delib, host, inputs, unstable-pkgs, ... }:
delib.module {
  name = "core.home-integration";

  options = delib.singleEnableOption host.isLaptop;

  nixos.ifEnabled = {
    nixpkgs.hostPlatform = "x86_64-linux";
    nixpkgs.overlays = [ inputs.nix4vscode.overlays.default ];

    home-manager.extraSpecialArgs = {
      inherit inputs unstable-pkgs;
    };
  };
}
