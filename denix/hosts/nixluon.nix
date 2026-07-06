{ delib, inputs, ... }:
delib.host {
  name = "nixluon";
  type = "laptop";

  homeManagerSystem = "x86_64-linux";

  nixos.imports = [
    inputs.niri.nixosModules.niri
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
    inputs.disko.nixosModules.disko
    ../../hosts/nixluon
  ];

  home.imports = [
    (
      { pkgs, lib, ... }:
      {
        dconf.settings = with lib.hm.gvariant; {
          "org/gnome/desktop/input-sources" = {
            mru-sources = [ (mkTuple [ "xkb" "us" ]) ];
            sources = [ (mkTuple [ "xkb" "us" ]) ];
            xkb-options = [ "lv3:ralt_switch" "compose:rctrl" ];
          };
        };

        gnome.extensions.enabledExtensions = with pkgs.gnomeExtensions; [
          brightness-control-using-ddcutil
          kimpanel
          middle-click-to-close-in-overview
          vitals
        ];

        home.packages = with pkgs; [
          atuin
          cloc
          compsize
          coreutils
          kotlin
          (lib.hiPrio lua5_1)
          (lib.lowPrio luajit)
          mold
          nodejs
          rustup
          wasm-pack

          ffmpeg
          galaxy-buds-client
          gifski
          gimp
          gthumb
          mozjpeg
          vlc

          bottles
          gamemode
          rpcs3
          ryubing

          calibre
          (pkgs.symlinkJoin {
            name = "craftos-pc-no-lua";
            paths = [ pkgs.craftos-pc ];
            postBuild = ''
              rm -f $out/lib/liblua.so*
            '';
          })
          hieroglyphic
          pandoc
          xournalpp

          gnumake
          openssl
          pkg-config
          qbittorrent
          texlive.combined.scheme-full

          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.amd-epp-tool
        ];
      }
    )
  ];
}
