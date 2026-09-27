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

        systems = [
          "aarch64-linux"
          "x86_64-linux"
        ];

        unstable-pkgs = import nixpkgs-unstable {
          system = "x86_64-linux";
          config = { allowUnfree = true; };
        };

        denixExtensions = with inputs.denix.lib.extensions; [
          args
          (base.withConfig { args.enable = true; })
        ];

        desktopConfigurations = inputs.denix.lib.configurations {
          moduleSystem = "nixos";
          homeManagerUser = "viluon";

          paths = [ ./denix ];
          exclude = [
            ./denix/hosts/the-precise-nature-of-the-catastrophe
            ./denix/modules/desktop/niri
            ./denix/modules/editors/vscode-settings.nix
            ./denix/modules/home/scripts
            ./denix/modules/home/server-core.nix
            ./denix/modules/home/server-git.nix
            ./denix/modules/home/slack-review.nix
            ./denix/modules/core/nixpkgs.nix
            ./denix/modules/core/server-home-integration.nix
          ];

          extensions = denixExtensions;

          specialArgs = {
            inherit inputs unstable-pkgs;
            inherit (inputs) niri;
          };
        };

        raspberryPiConfigurations = inputs.denix.lib.configurations {
          moduleSystem = "nixos";
          homeManagerUser = "viluon";

          paths = [
            ./denix/hosts/the-precise-nature-of-the-catastrophe
            ./denix/modules/core/constants.nix
            ./denix/modules/core/locale.nix
            ./denix/modules/core/nixpkgs.nix
            ./denix/modules/core/server-home-integration.nix
            ./denix/modules/core/user.nix
            ./denix/modules/home/basic-shell.nix
            ./denix/modules/home/server-core.nix
            ./denix/modules/home/server-git.nix
            ./denix/modules/programs/gnupg.nix
            ./denix/modules/system/legacy-compat.nix
            ./denix/modules/system/networking.nix
            ./denix/modules/system/nix.nix
            ./denix/modules/system/sysctl.nix
          ];

          extensions = denixExtensions;

          specialArgs = {
            inherit inputs;
          };
        };

        the-precise-nature-of-the-catastrophe =
          raspberryPiConfigurations.the-precise-nature-of-the-catastrophe;

        crossThePreciseNatureOfTheCatastrophe =
          the-precise-nature-of-the-catastrophe.extendModules {
            modules = [{ nixpkgs.buildPlatform = "x86_64-linux"; }];
          };

        raspberryPiConfigurationsByBuildSystem = {
          aarch64-linux = the-precise-nature-of-the-catastrophe;
          x86_64-linux = crossThePreciseNatureOfTheCatastrophe;
        };

        standaloneRaspberryPiImage = configuration:
          configuration.config.system.build.sdImage.overrideAttrs {
            __structuredAttrs = true;
            unsafeDiscardReferences.out = true;
          };
      in
      {
        imports = [
          amd-epp-tool-module
          inputs.flake-root.flakeModule
          inputs.treefmt-nix.flakeModule
        ];

        flake.nixosConfigurations =
          desktopConfigurations // raspberryPiConfigurations;

        flake.packages.x86_64-linux =
          let pkgs = nixpkgs.legacyPackages.x86_64-linux.extend (import ./packages);
          in {
            linux-entra-sso = pkgs.linux-entra-sso;
            the-precise-nature-of-the-catastrophe =
              standaloneRaspberryPiImage raspberryPiConfigurationsByBuildSystem.x86_64-linux;
          };

        flake.packages.aarch64-linux.the-precise-nature-of-the-catastrophe =
          standaloneRaspberryPiImage raspberryPiConfigurationsByBuildSystem.aarch64-linux;

        inherit systems;

        perSystem = { config, pkgs, system, ... }: {
          checks = {
            fzf-history-highlight = import ./checks/fzf-history-highlight.nix { inherit pkgs; };
            the-precise-nature-of-the-catastrophe =
              raspberryPiConfigurationsByBuildSystem.${system}.config.system.build.toplevel;
          };

          treefmt.config = {
            inherit (config.flake-root) projectRootFile;
            programs.nixpkgs-fmt.enable = true;
            programs.rustfmt = {
              enable = true;
              edition = "2024";
            };
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
              pkgs.bmaptool
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
