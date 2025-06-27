{
  inputs = {
    disko.url = "github:nix-community/disko/latest";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    disko.inputs.nixpkgs.follows = "nixpkgs-unstable";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.inputs.flake-utils.follows = "flake-utils";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@
    { self
    , disko
    , flake-parts
    , home-manager
    , nix-index-database
    , nixos-hardware
    , nixpkgs
    , nixpkgs-unstable
    , ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;
        vscode-module = importApply ./vscode.nix { inherit withSystem; };
        amd-epp-tool-module = importApply ./amd-epp-tool.nix { inherit withSystem; };
      in
      {
        imports = [
          ./home/flake-module.nix
          amd-epp-tool-module
          vscode-module
          inputs.flake-root.flakeModule
          inputs.home-manager.flakeModules.home-manager
          inputs.treefmt-nix.flakeModule
        ];

        flake = {
          nixosConfigurations.nixluon = nixpkgs.lib.nixosSystem rec {
            system = "x86_64-linux";
            modules = [
              ./configuration.nix
              nixos-hardware.nixosModules.framework-amd-ai-300-series
              nix-index-database.nixosModules.nix-index
              {
                programs.nix-index-database.comma.enable = true;
              }
              disko.nixosModules.disko
              ./disko-config.nix
            ];
            specialArgs = {
              inherit (self.packages.${system}) vscode-customised amd-epp-tool;
              unstable-pkgs = nixpkgs-unstable.legacyPackages.${system};
            };
          };
          nixosConfigurations.nixboerse = nixpkgs.lib.nixosSystem rec {
            system = "x86_64-linux";
            modules = [
              ./hosts/nixboerse/configuration.nix
              nixos-hardware.nixosModules.lenovo-thinkpad-p1-gen3
              nix-index-database.nixosModules.nix-index
              {
                programs.nix-index-database.comma.enable = true;
              }
            ];
            specialArgs = {
              inherit (self.packages.${system}) vscode-customised;
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
      }
    );
}
