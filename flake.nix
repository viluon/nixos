{
  inputs = {
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    disko.url = "github:nix-community/disko/latest";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    niri.url = "github:sodiboo/niri-flake";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix4vscode.url = "github:nix-community/nix4vscode";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    xhmm.url = "github:schuelermine/xhmm";
    stylix.url = "github:nix-community/stylix/release-25.05";

    disko.inputs.nixpkgs.follows = "nixpkgs-unstable";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    niri.inputs = {
      nixpkgs-stable.follows = "nixpkgs";
      nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nix4vscode.inputs.nixpkgs.follows = "nixpkgs";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@
    { self
    , chaotic
    , disko
    , flake-parts
    , home-manager
    , niri
    , nix-index-database
    , nixos-hardware
    , nixpkgs
    , nixpkgs-unstable
    , stylix
    , ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;
        amd-epp-tool-module = importApply ./amd-epp-tool.nix { inherit withSystem; };
        idea-module = importApply ./modules/editors/idea.nix { inherit withSystem; };

        buildNixosSystem = hostname: config:
          let
            unstable-pkgs = import nixpkgs-unstable {
              system = config.system;
              config = { allowUnfree = true; };
            };
          in
          nixpkgs.lib.nixosSystem {
            system = config.system;
            modules = [
              ./hosts/${hostname}
              niri.nixosModules.niri
              stylix.nixosModules.stylix
              nixos-hardware.nixosModules.${config.hardware}
              disko.nixosModules.disko
              { networking.hostName = hostname; }
              nix-index-database.nixosModules.nix-index
              { programs.nix-index-database.comma.enable = true; }
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users = self.mkHomeUsers hostname;
                home-manager.extraSpecialArgs = {
                  inherit inputs hostname unstable-pkgs;
                };
              }
              {
                nixpkgs.overlays = [
                  (import ./packages)
                  inputs.nix4vscode.overlays.default
                ];
              }
              chaotic.nixosModules.nyx-cache
              chaotic.nixosModules.nyx-overlay
              chaotic.nixosModules.nyx-registry
            ];
            specialArgs = self.packages.${config.system} // {
              inherit unstable-pkgs;
              niri = inputs.niri;
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
          ./home
          amd-epp-tool-module
          idea-module
          inputs.flake-root.flakeModule
          inputs.treefmt-nix.flakeModule
        ];

        flake.nixosConfigurations = nixpkgs.lib.mapAttrs buildNixosSystem hostConfigs;

        flake.packages = nixpkgs.lib.genAttrs (nixpkgs.lib.unique (nixpkgs.lib.mapAttrsToList (_: config: config.system) hostConfigs)) (system:
          let pkgs = nixpkgs.legacyPackages.${system}.extend (import ./packages);
          in {
            linux-entra-sso = pkgs.linux-entra-sso;
          }
        );

        systems = nixpkgs.lib.unique (nixpkgs.lib.mapAttrsToList (_: config: config.system) hostConfigs);

        perSystem = { config, pkgs, ... }: {
          treefmt.config = {
            inherit (config.flake-root) projectRootFile;
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
