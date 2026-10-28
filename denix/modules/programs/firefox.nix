{ delib, host, pkgs, ... }:
delib.module {
  name = "programs.firefox";

  options = delib.singleEnableOption host.isLaptop;

  nixos.ifEnabled = {
    programs.firefox = {
      enable = true;
      package = pkgs.firefox-devedition;
      preferences = {
        "browser.tabs.allow_transparent_browser" = true;

        "media.eme.enabled" = true;

        "network.lna.blocking" = false;
      };
    };
  };
}
