{ delib, inputs, ... }:
delib.host {
  name = "nixluon";
  type = "laptop";

  homeManagerSystem = "x86_64-linux";

  nixos.imports = [
    inputs.niri.nixosModules.niri
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
    inputs.disko.nixosModules.disko
    (
      { config, lib, pkgs, ... }:
      {
        hardware.bluetooth.enable = true;
        services.blueman.enable = true;
        services.hardware.bolt.enable = true;
        services.joycond.enable = true;

        myconfig.system.btrfsDedupe = {
          enable = config.fileSystems ? "/partition-root";
          spec = config.fileSystems."/partition-root".device;
          loadavgTarget = "4.0";
        };

        hardware.xpadneo.enable = true;
        services.nixseparatedebuginfod2.enable = true;

        boot.extraModprobeConfig = ''
          options cfg80211 ieee80211_regdom="CZ"
        '';
        boot.loader.efi.efiSysMountPoint = "/boot";

        console = {
          earlySetup = true;
          font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
          keyMap = "us";
          packages = [ pkgs.terminus_font ];
          colors = [
            "1e1e2e"
            "181825"
            "313244"
            "45475a"
            "585b70"
            "cdd6f4"
            "f5e0dc"
            "b4befe"
            "f38ba8"
            "fab387"
            "f9e2af"
            "a6e3a1"
            "94e2d5"
            "89b4fa"
            "cba6f7"
            "f2cdcd"
          ];
        };

        boot.supportedFilesystems = [ "ntfs" ];

        services.displayManager.sddm.enable = false;
        services.desktopManager.plasma6.enable = true;
        programs.ssh.askPassword = lib.mkForce "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

        services.sysprof.enable = true;
        services.flatpak.enable = true;
        services.fprintd.enable = true;
        security.pam.services.login = {
          enableGnomeKeyring = true;
          fprintAuth = lib.mkForce true;
        };
        services.fstrim.enable = true;

        programs.java.package = pkgs.zulu25;

        environment.systemPackages = with pkgs; [
          lm_sensors
          wget
        ];

        environment.variables = { };

        virtualisation = {
          containerd.enable = true;
          podman = {
            enable = true;
            dockerCompat = true;
            defaultNetwork.settings.dns_enabled = true;
          };
          libvirtd = {
            enable = true;
            qemu.package = pkgs.qemu_kvm;
          };
          waydroid.enable = true;
        };

        networking.firewall =
          let
            warcraft3Range = { from = 6112; to = 6119; };
            steamLocalTransferPort = 27040;
            googleCastPort = 5000;
          in
          {
            allowedTCPPorts = [ 80 443 steamLocalTransferPort googleCastPort ];
            allowedTCPPortRanges = [ warcraft3Range ];
            allowedUDPPorts = [ 16000 ];
            allowedUDPPortRanges = [
              warcraft3Range
              { from = 27000; to = 27100; }
            ];
          };

        networking.nameservers = [ "100.100.100.100" "8.8.8.8" "1.1.1.1" ];
        networking.search = [ "werewolf-torino.ts.net" ];
        services.tailscale.enable = true;

        system.stateVersion = "24.11";
        programs.gnome-disks.enable = true;
      }
    )
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
          mpv
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
