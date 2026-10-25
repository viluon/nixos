{ delib
, inputs
, unstable-pkgs
, ...
}:
delib.module {
  name = "core.home-integration";

  nixos.always = {
    nixpkgs.hostPlatform = "x86_64-linux";
    nixpkgs.overlays = [ inputs.nix4vscode.overlays.default ];

    home-manager.extraSpecialArgs = {
      inherit inputs unstable-pkgs;
    };
  };
}
