{ delib, inputs, ... }:
delib.host {
  name = "nixboerse";
  type = "laptop";

  homeManagerSystem = "x86_64-linux";

  nixos.imports = [
    inputs.niri.nixosModules.niri
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p1-gen3
    inputs.disko.nixosModules.disko
    ../../hosts/nixboerse
  ];

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
