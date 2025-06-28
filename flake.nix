{
  inputs = {
    disko.url = "github:nix-community/disko/latest";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    lix-module.url = "git+https://git@git.lix.systems/lix-project/nixos-module";
    lix.url = "git+https://git@git.lix.systems/lix-project/lix.git";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    disko.inputs.nixpkgs.follows = "nixpkgs-unstable";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    lix-module.inputs.lix.follows = "lix";
    lix-module.inputs.nixpkgs.follows = "nixpkgs";
    lix.inputs.nixpkgs.follows = "nixpkgs";
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
    , lix-module
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

        buildNixosSystem = hostname: config: nixpkgs.lib.nixosSystem {
          system = config.system;
          modules = [
            ./hosts/${hostname}
            { networking.hostName = hostname; }
            { programs.nix-index-database.comma.enable = true; }
            disko.nixosModules.disko
            lix-module.nixosModules.default
            nix-index-database.nixosModules.nix-index
            nixos-hardware.nixosModules.${config.hardware}
          ];
          specialArgs = self.packages.${config.system} // {
            unstable-pkgs = nixpkgs-unstable.legacyPackages.${config.system};
          };
        };

        hostConfigs = {
          nixluon = {
            system = "x86_64-linux";
            hardware = "framework-amd-ai-300-series";
          };
          nixboerse = {
            system = "x86_64-linux";
            hardware = "lenovo-thinkpad-p1-gen3";
          };
        };
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

        flake.nixosConfigurations = nixpkgs.lib.mapAttrs buildNixosSystem hostConfigs;

        systems = nixpkgs.lib.unique (nixpkgs.lib.mapAttrsToList (_: config: config.system) hostConfigs);

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
