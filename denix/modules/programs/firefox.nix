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

            "network.lna.blocking" = false;
          };
        };
      }
    )
  ];
}
