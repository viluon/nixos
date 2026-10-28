{ inputs }:
let
  inherit (inputs.nixpkgs) lib;

  denixConfigurations = settings: inputs.denix.lib.configurations ({
    moduleSystem = "nixos";
    homeManagerUser = "viluon";

    extensions = with inputs.denix.lib.extensions; [
      args
      (base.withConfig { args.enable = true; })
    ];
  } // settings);

  hostEntryPoints = map (name: ../denix/hosts + "/${name}/default.nix");
  hostNames = builtins.attrNames (builtins.readDir ../denix/hosts);
  serverHostNames = [ "never-talk-to-strangers" ];

  desktop = import ./desktop.nix {
    inherit inputs denixConfigurations;
    hosts = hostEntryPoints (lib.subtractLists serverHostNames hostNames);
  };
  server = import ./server.nix {
    inherit inputs denixConfigurations;
    hosts = hostEntryPoints serverHostNames;
  };
in
desktop // server
