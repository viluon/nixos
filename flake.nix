{
  inputs = {
    disko.url = "github:nix-community/disko/latest";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    disko.inputs.nixpkgs.follows = "nixpkgs-unstable";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, disko, nixpkgs, nixpkgs-unstable, nix-index-database, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.flake-root.flakeModule
      ];

      flake = {
        nixosConfigurations.nixluon = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            nix-index-database.nixosModules.nix-index
            {
              programs.nix-index-database.comma.enable = true;
            }
            disko.nixosModules.disko
            ./disko-config.nix
          ];
          specialArgs = {
            unstable-pkgs = nixpkgs-unstable.legacyPackages.${system};
          };
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
