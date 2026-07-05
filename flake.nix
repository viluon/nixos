{
  inputs = {
    denix.url = "github:yunfachi/denix";
    disko.url = "github:nix-community/disko/latest";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    flake-utils.url = "github:numtide/flake-utils";
    fzf-git-sh = {
      url = "github:junegunn/fzf-git.sh";
      flake = false;
    };
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    niri-blur.url = "github:niri-wm/niri";
    niri.url = "github:sodiboo/niri-flake/very-refactor";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix4vscode.url = "github:nix-community/nix4vscode";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    stylix.url = "github:nix-community/stylix/release-26.05";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    wayscriber.url = "github:devmobasa/wayscriber";
    xhmm.url = "github:schuelermine/xhmm";
    xwayland-satellite-unstable.url = "github:Supreeeme/xwayland-satellite";

    denix.inputs.nixpkgs.follows = "nixpkgs";
    denix.inputs.home-manager.follows = "home-manager";
    disko.inputs.nixpkgs.follows = "nixpkgs-unstable";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    niri.inputs = {
      niri-unstable.follows = "niri-blur";
      nixpkgs-stable.follows = "nixpkgs";
      nixpkgs.follows = "nixpkgs-unstable";
      xwayland-satellite-unstable.follows = "xwayland-satellite-unstable";
    };
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix4vscode.inputs.nixpkgs.follows = "nixpkgs-unstable";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    wayscriber.inputs = {
      flake-utils.follows = "flake-utils";
      nixpkgs.follows = "nixpkgs-unstable";
    };
    xwayland-satellite-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs =
    inputs@
    { flake-parts
    , nixpkgs
    , nixpkgs-unstable
    , ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;
        amd-epp-tool-module = importApply ./packages/amd-epp-tool.nix { inherit withSystem; };
        idea-module = importApply ./modules/editors/idea.nix { inherit withSystem; };

        systems = [ "x86_64-linux" ];

        unstable-pkgs = import nixpkgs-unstable {
          system = "x86_64-linux";
          config = { allowUnfree = true; };
        };

        denixConfigurations = inputs.denix.lib.configurations {
          moduleSystem = "nixos";
          homeManagerUser = "viluon";

          paths = [ ./denix ];

          extensions = with inputs.denix.lib.extensions; [
            args
            (base.withConfig { args.enable = true; })
          ];

          specialArgs = {
            inherit inputs unstable-pkgs;
            inherit (inputs) niri wayscriber;
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

        flake.nixosConfigurations = denixConfigurations;

        flake.packages = nixpkgs.lib.genAttrs systems (system:
          let pkgs = nixpkgs.legacyPackages.${system}.extend (import ./packages);
          in {
            linux-entra-sso = pkgs.linux-entra-sso;
          }
        );

        inherit systems;

        perSystem = { config, pkgs, ... }: {
          checks.fzf-history-highlight = import ./checks/fzf-history-highlight.nix { inherit pkgs; };

          treefmt.config = {
            inherit (config.flake-root) projectRootFile;
            programs.nixpkgs-fmt.enable = true;
            programs.prettier = {
              enable = true;
              includes = [
                "*.ts"
                "*.tsx"
              ];
            };
            programs.clang-format = {
              enable = true;
              includes = [ "*.glsl" ];
            };
          };

          devShells.default = pkgs.mkShell {
            packages = [
              config.treefmt.build.wrapper
              pkgs.just
              pkgs.nvd
            ] ++ (builtins.attrValues config.treefmt.build.programs);

            shellHook = ''
              just --list
            '';
          };
        };
      }
    );
}
