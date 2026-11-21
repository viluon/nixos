{ delib, pkgs, unstable-pkgs, ... }:
delib.module {
  name = "home.core";

  home.always = {
    home.stateVersion = "25.05";

    home.packages = with pkgs; [
      cachix
      fd
      figlet
      file
      git-absorb
      gum
      just
      manix
      nixd
      ripgrep
      shellcheck
      unstable-pkgs.tailcat
      unzip
      vivid
    ];

    programs.home-manager.enable = true;
  };
}
