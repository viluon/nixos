{ delib, ... }:
delib.module {
  name = "programs.firefox";

  nixos.always.imports = [
    (
      { pkgs, ... }:
      {
        programs.firefox = {
          enable = true;
          package = pkgs.firefox-devedition;
          preferences = {
            "browser.tabs.allow_transparent_browser" = true;
          };
        };
      }
    )
  ];
}
