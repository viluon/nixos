{ delib, host, pkgs, unstable-pkgs, ... }:
delib.module {
  name = "home.desktop-packages";

  options = delib.singleEnableOption host.isLaptop;

  home.ifEnabled = {
    home.packages = with pkgs; [
      gh
      grimblast
      obsidian
      unstable-pkgs.github-copilot-cli
      waybar

      blueman
      brightnessctl
      btrfs-assistant
      cliphist
      compsize
      ddcui
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

      matugen
      wallust
      awww
      xdg-user-dirs
    ];
  };
}
