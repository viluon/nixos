{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    nix-vscode-extensions.inputs.flake-utils.follows = "flake-utils";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs@{ self, nixpkgs, nix-vscode-extensions, ... }:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        extensions = inputs.nix-vscode-extensions.extensions.${system};
        inherit (pkgs) vscode-with-extensions vscodium;

        packages.default = vscode-with-extensions.override {
          vscodeExtensions = [
            extensions.vscode-marketplace.golang.go
            extensions.open-vsx-release.rust-lang.rust-analyzer
          ];
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ packages.default ];
          shellHook = ''
            printf "VS Code with extensions:\n"
            code --list-extensions
          '';
        };
      in
      {
        inherit packages devShells;
      }
    );
}
