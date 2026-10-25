{ inputs }:
let
  denixConfigurations = settings: inputs.denix.lib.configurations ({
    moduleSystem = "nixos";
    homeManagerUser = "viluon";

    extensions = with inputs.denix.lib.extensions; [
      args
      (base.withConfig { args.enable = true; })
    ];
  } // settings);

  serverHosts = [ ../denix/hosts/never-talk-to-strangers ];
in
import ./desktop.nix { inherit inputs denixConfigurations serverHosts; }
  // import ./server.nix { inherit inputs denixConfigurations serverHosts; }
