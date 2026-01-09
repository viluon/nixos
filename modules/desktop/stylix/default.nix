{ pkgs
, ...
}:
{
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    polarity = "dark";
    image = "${pkgs.runCommand "wallpaper.png" { } "${pkgs.imagemagick}/bin/convert ${./wallpaper.webp} png:$out"}";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.iosevka;
        name = "Iosevka Nerd Font";
      };

      sansSerif = {
        package = pkgs.inter-nerdfont;
        name = "Inter Nerd Font";
      };
    };

    icons = {
      enable = true;
      dark = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    opacity = {
      popups = 0.85;
      terminal = 0.75;
    };
  };
}
