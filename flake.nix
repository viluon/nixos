{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.flake-root.flakeModule
      ];

      flake = {
        nixosConfigurations.nixluon = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./configuration.nix ];
        };
      };

      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
      ];

      perSystem = { config, pkgs, ... }: {
        treefmt.config = {
          inherit (config.flake-root) projectRootFile;
          # formats .nix files
          programs.nixpkgs-fmt.enable = true;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            config.treefmt.build.wrapper
          ] ++ (builtins.attrValues config.treefmt.build.programs);
        };
      };
    };
}
