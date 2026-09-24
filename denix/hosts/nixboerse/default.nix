{ delib, inputs, ... }:
delib.host {
  name = "nixboerse";
  type = "laptop";

  homeManagerSystem = "x86_64-linux";

  myconfig.system.containerNetworking = {
    enable = true;
    uplinkInterface = "wlp9s0";
    vmName = "ubuntu";
    splitDnsServer = "100.64.0.2";
    splitDnsDomains = [
      "cedelgroup.com"
      "cloudconsole-pa.clients6.google.com"
      "cloudusersettings-pa.clients6.google.com"
      "dbgcloud.io"
      "deutsche-boerse.de"
      "gke.goog"
      "googleapis.com"
      "oa.pnrad.net"
    ];
  };

  nixos.imports = [
    inputs.niri.nixosModules.niri
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p1-gen3
    inputs.disko.nixosModules.disko
    (
      { config, pkgs, unstable-pkgs, ... }:
      {
        hardware.i2c.enable = true;

        fileSystems."/mnt/ubuntu-boot" = {
          device = "/dev/disk/by-uuid/a111f378-e9db-4d4c-8d45-70e7a74b0b3b";
          fsType = "ext4";
          options = [ "ro" ];
        };

        hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

        environment.systemPackages = with pkgs; [
          chromium
          ddcutil
          efibootmgr
          kind
          kubectl
          kubectx
          kubernetes-helm
          minikube
          openssl
          parallel
        ];

        myconfig.programs.entraSso.enable = true;
        programs.java.package = unstable-pkgs.zulu25;
        services.ddccontrol.enable = true;
        myconfig.hardware.thinkfan.enable = true;

        programs.wireshark = {
          enable = true;
          package = pkgs.wireshark;
        };

        programs.firefox.policies = {
          ExtensionSettings."firefox.container-shortcuts@strategery.io" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4068015/easy_container_shortcuts-1.6.0.xpi";
            installation_mode = "force_installed";
            updates_disabled = true;
          };
          Preferences."xpinstall.signatures.required" = false;
        };

        virtualisation.vmVariant.virtualisation = {
          diskSize = 4096;
          resolution = {
            x = 1920;
            y = 1080;
          };
        };

        myconfig.system.btrfsDedupe = {
          enable = true;
          spec = config.fileSystems."/".device;
          loadavgTarget = "2.0";
        };

        services.pipewire.wireplumber.extraConfig.stutter-fix."monitor.alsa.rules" = [
          {
            matches = [{ node.name = "~alsa_output.*"; }];
            actions.update-props = {
              "api.alsa.period-size" = 1024;
              "api.alsa.headroom" = 8192;
            };
          }
        ];

        system.stateVersion = "25.05";
      }
    )
  ];

  home.imports = [
    (
      { pkgs, lib, unstable-pkgs, ... }:
      {
        dconf.settings = with lib.hm.gvariant; {
          "org/gnome/desktop/input-sources" = {
            mru-sources = [ (mkTuple [ "xkb" "us" ]) ];
            sources = [ (mkTuple [ "xkb" "us" ]) ];
            xkb-options = [ "lv3:ralt_switch" "compose:rctrl" ];
          };
          "org/gnome/desktop/interface" = {
            scaling-factor = mkUint32 1;
            text-scaling-factor = 1.0;
          };
        };

        gnome.extensions.enabledExtensions = with pkgs.gnomeExtensions; [
          brightness-control-using-ddcutil
          kimpanel
          middle-click-to-close-in-overview
          vitals
        ];

        home.packages = [
          unstable-pkgs.mill
          pkgs.nodejs_24
          (pkgs.google-cloud-sdk.withExtraComponents [
            pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
          ])
        ];
      }
    )
  ];
}
