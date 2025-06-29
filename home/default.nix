{ self
, inputs
, lib
, ...
}:

let
  userDirs = builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.));
  homeModules = lib.genAttrs userDirs (user: import ./${user}/home.nix);

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

  homeConfigurations = lib.genAttrs userDirs (user:
    mkHomeConfiguration {
      inherit user;
      system = "x86_64-linux";
      modules = [ homeModules.${user} ];
    }
  );

  # Provide users attrset for NixOS integration
  users = lib.genAttrs userDirs (user: homeModules.${user});
in
{
  imports = [ inputs.home-manager.flakeModules.home-manager ];

  flake = {
    inherit homeModules homeConfigurations;
    homeUsers = users;
  };
}
