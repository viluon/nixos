{ delib, ... }:
delib.module {
  name = "programs.firefox";

  nixos.always.imports = [
    (
      { pkgs, lib, ... }:
      {
        programs.firefox = {
          enable = true;
          package = pkgs.firefox-devedition;
          preferences = {
            "browser.tabs.allow_transparent_browser" = true;

            "network.lna.skip-domains" = lib.concatStringsSep "," [
              "googleapis.com"
              "*.googleapis.com"
              "*.gstatic.com"
              "*.clients6.google.com"
            ];
          };
        };
      }
    )
  ];
}
