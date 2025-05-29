{ self
, inputs
, lib
, ...
}:

let
  mkHomeConfiguration =
    { user
    , system
    , modules
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      extraSpecialArgs = { inherit inputs; };

      modules =
        [
          {
            home.username = user;
            home.homeDirectory = "/home/${user}";
          }
        ]
        ++ modules;
    };
in
{
  imports = [ inputs.home-manager.flakeModules.home-manager ];

  flake = {
    homeModules = {
      viluon = import ./viluon/home.nix;
    };
    homeConfigurations = {
      viluon = mkHomeConfiguration {
        user = "viluon";
        system = "x86_64-linux";
        modules = [
          self.homeModules.viluon
        ];
      };
    };
    homeManagerModules = lib.warn "`homeManagerModules` is deprecated. Use `homeModules` instead." self.homeModules;
  };
}

