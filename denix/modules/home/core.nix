{ delib, unstable-pkgs, ... }:
delib.module {
  name = "home.core";

  home.always.imports = [
    (
      { pkgs, ... }:
      {
        home.stateVersion = "25.05";

        home.packages = with pkgs; [
          fd
          fzf
          gh
          git-absorb
          grimblast
          manix
          nixd
          obsidian
          ripgrep
          shellcheck
          starship
          steam
          unstable-pkgs.github-copilot-cli
          vivid
          waybar

          blueman
          brightnessctl
          btrfs-assistant
          cachix
          cliphist
          compsize
          ddcui
          file
          gamescope
          just
          networkmanager
          pavucontrol
          playerctl
          polkit_gnome
          wl-clipboard
          xwayland-run
          xwayland-satellite

          noto-fonts
          noto-fonts-color-emoji
          noto-fonts-cjk-sans
          font-awesome

          figlet
          gum
          matugen
          wallust
          awww
          xdg-user-dirs
        ];

        programs.home-manager.enable = true;
      }
    )
  ];
}
