{ delib, host, inputs, lib, pkgs, ... }:
delib.module {
  name = "desktop.stylix";

  options = delib.singleEnableOption host.isLaptop;

  nixos.always.imports = [ inputs.stylix.nixosModules.stylix ];

  nixos.ifEnabled = {
    stylix = {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      polarity = "dark";
      image = "${pkgs.runCommand "wallpaper.png" { } "${pkgs.imagemagick}/bin/convert ${./stylix/wallpaper.webp} png:$out"}";

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
        applications = 0.75;
        popups = 0.65;
        terminal = 0.75;
      };

      cursor = {
        name = "breeze_cursors";
        size = 24;
        package = pkgs.kdePackages.breeze;
      };

      targets.qt.platform = lib.mkForce "qtct";
    };
  };
}
