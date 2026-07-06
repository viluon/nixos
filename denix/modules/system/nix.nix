{ delib, ... }:
delib.module {
  name = "system.nix";

  nixos.always =
    { myconfig, ... }:
    {
      imports = [
        (
          { pkgs, ... }:
          {
            nix = {
              package = pkgs.nixVersions.stable;

              daemonCPUSchedPolicy = "idle";
              daemonIOSchedClass = "idle";

              settings = {
                experimental-features = [ "nix-command" "flakes" ];

                trusted-users = [ "root" myconfig.constants.username ];

                substituters = [
                  "https://cache.nixos.org"
                  "https://nix-community.cachix.org"
                  "https://viluon.cachix.org"
                ];

                trusted-public-keys = [
                  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                  "viluon.cachix.org-1:lYmQCd3Bb0GYrHCxPCshn2oCRDMqMmN/i5kgkBlxmNk="
                ];
              };

              optimise = {
                automatic = true;
                dates = [ "20:00" ];
              };

              gc = {
                automatic = true;
                randomizedDelaySec = "15min";
                options = "--delete-older-than 60d";
              };
            };
          }
        )
      ];
    };
}
