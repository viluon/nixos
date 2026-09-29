{ delib, inputs, ... }:
delib.module {
  name = "system.secrets";

  nixos.always =
    { myconfig, ... }:
    let
      secretRoot = ../../.. + "/secrets";
      registryPath = secretRoot + "/recipients.json";
      registry =
        if builtins.pathExists registryPath
        then builtins.fromJSON (builtins.readFile registryPath)
        else { devices = { }; };
      device = registry.devices.${myconfig.host.name} or { scopes = [ ]; };
      scopeSecrets = scope:
        let
          directory = secretRoot + "/${scope}";
          files =
            if builtins.pathExists directory
            then
              builtins.attrNames
                (
                  inputs.nixpkgs.lib.filterAttrs
                    (file: type: type == "regular" && inputs.nixpkgs.lib.hasSuffix ".yaml" file)
                    (builtins.readDir directory)
                )
            else [ ];
        in
        map
          (file: {
            name = "${scope}/${inputs.nixpkgs.lib.removeSuffix ".yaml" file}";
            value = {
              sopsFile = directory + "/${file}";
              key = "value";
            };
          })
          files;
      secrets = builtins.listToAttrs (builtins.concatMap scopeSecrets device.scopes);
    in
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
        (
          { lib, ... }:
          {
            sops = {
              age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
              inherit secrets;
            };
            virtualisation.vmVariant.sops.secrets = lib.mkForce { };
          }
        )
      ];
    };
}
