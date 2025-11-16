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
        package = pkgs.iosevka;
        name = "Iosevka";
      };
    };
  };
}
