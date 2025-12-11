{ pkgs
, ...
}:

{
  nix = {
    # nix version
    package = pkgs.nixVersions.stable;

    # set nix build scheduling policies to idle to preserve interactivity
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";

    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # trust viluon to configure binary caches
      trusted-users = [ "root" "viluon" ];

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
  };
}
