# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config
, lib
, pkgs
, unstable-pkgs
, ...
}:

let
  docker-bridge-dns = "172.17.0.1";
  docker-subnet = "172.17.0.0/16";
  minikube-subnet = "192.168.49.0/24";
  kind-subnet = "172.18.0.0/16";
in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware.nix
      ./kernel.nix
      ./nvidia.nix
      ../../modules/desktop/gnome
      ../../modules/desktop/niri
      ../../modules/desktop/stylix
      ../../modules/hardware/audio.nix
      ../../modules/hardware/graphics.nix
      ../../modules/system/networking
      ../../modules/system/nix
      ../../modules/system/systemd
      ../../modules/users/common.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # boot animation
  boot.plymouth.enable = true;

  # firmware upgrades
  services.fwupd.enable = true;

  # access to i2c for monitor control
  hardware.i2c.enable = true;

  # Ubuntu boot partition
  fileSystems."/mnt/ubuntu-boot" = {
    device = "/dev/disk/by-uuid/a111f378-e9db-4d4c-8d45-70e7a74b0b3b";
    fsType = "ext4";
    options = [ "ro" ];
  };

  # Intel-specific configuration
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];

  programs.virt-manager.enable = true;

  virtualisation.libvirtd = {
    enable = true;

    # work around the JSON parsing bug until the stable release lands
    # see https://gitlab.com/libvirt/libvirt/-/commit/b49d41b7e9eb983fdfbf70c91c2a27a995af3987
    package = pkgs.libvirt.overrideAttrs (old: {
      version = "12.0.0-rc1";
      src = old.src.override {
        tag = "v12.0.0-rc1";
        hash = "sha256-XQgGBuZ4fbEDeT/1OVF9GG4Q6JYZqPtxGkdLg1cG8Zc=";
      };
    });

    qemu.package = pkgs.qemu_kvm;
    hooks.qemu =
      let
        domains = builtins.concatStringsSep " " [
          "cedelgroup.com"
          "cloudconsole-pa.clients6.google.com"
          "cloudusersettings-pa.clients6.google.com"
          "dbgcloud.io"
          "deutsche-boerse.de"
          "gke.goog"
          "googleapis.com"
          "oa.pnrad.net"
        ];

        resolvectl = "${pkgs.systemd}/bin/resolvectl";
        VM = "ubuntu";
      in
      {
        libvirtd-network-hook = pkgs.writeShellScript "libvirtd-network-hook" ''
          set -euo pipefail

          case $1:$2 in
            ${VM}:start)
              ${resolvectl} dns virbr0 100.64.0.2
              ${resolvectl} domain virbr0 ${domains}
              ${resolvectl} default-route virbr0 no
              ${resolvectl} dnsovertls virbr0 no
              ;;
          esac
        '';
      };
  };

  systemd.services.libvirtd.restartTriggers = [
    config.virtualisation.libvirtd.hooks.qemu.libvirtd-network-hook
  ];

  services.resolved.extraConfig = ''
    DNSStubListenerExtra=${docker-bridge-dns}
  '';

  systemd.services.resume-ubuntu-vm = {
    description = "Resume Ubuntu VM snapshot";
    after = [ "libvirtd.service" ];
    requires = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "resume-ubuntu-vm" ''
        set -euo pipefail
        ${config.virtualisation.libvirtd.package}/bin/virsh snapshot-revert ubuntu --current
        ${config.virtualisation.libvirtd.package}/bin/virsh resume ubuntu
      ''}";
    };
  };

  # FORWARD ACCEPT rules for routing through libvirt are managed by
  # firewall-virbr0-bypass.service (see below) so they sit above libvirt's
  # REJECT and Docker's chain jumps regardless of unit start order.
  networking.firewall = {
    extraCommands = lib.mkAfter ''
      # Allow Docker/kind containers to reach host's resolved stub on docker0
      iptables -I nixos-fw -d ${docker-bridge-dns} -p udp --dport 53 -j nixos-fw-accept
      iptables -I nixos-fw -d ${docker-bridge-dns} -p tcp --dport 53 -j nixos-fw-accept
    '';

    extraStopCommands = ''
      iptables -D nixos-fw -d ${docker-bridge-dns} -p udp --dport 53 -j nixos-fw-accept || true
      iptables -D nixos-fw -d ${docker-bridge-dns} -p tcp --dport 53 -j nixos-fw-accept || true
    '';
  };

  # The NixOS firewall, libvirtd and dockerd race to install FORWARD-chain
  # jumps at boot. Whoever runs last wins (top of FORWARD). When dockerd or
  # libvirtd win, our ACCEPT rules end up below LIBVIRT_FWI's REJECT and kind
  # containers can no longer reach virbr0.
  # Re-insert the rules after both are up so they sit above LIBVIRT_FWI.
  systemd.services.firewall-virbr0-bypass = {
    description = "Re-insert FORWARD ACCEPT rules above libvirt/docker chains";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "libvirtd.service" "firewall.service" ];
    requires = [ "firewall.service" ];
    partOf = [ "firewall.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${lib.concatMapStringsSep "\n" (rule: ''
        ${pkgs.iptables}/bin/iptables -D FORWARD ${rule} 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -I FORWARD 1 ${rule}
      '') [
        "-s ${docker-subnet} ! -i wlp9s0 -o virbr0 -j ACCEPT"
        "-s ${minikube-subnet} ! -i wlp9s0 -o virbr0 -j ACCEPT"
        "-s ${kind-subnet} ! -i wlp9s0 -o virbr0 -j ACCEPT"
        "-i virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"
      ]}
    '';
    preStop = ''
      ${lib.concatMapStringsSep "\n" (rule: ''
        ${pkgs.iptables}/bin/iptables -D FORWARD ${rule} 2>/dev/null || true
      '') [
        "-s ${docker-subnet} ! -i wlp9s0 -o virbr0 -j ACCEPT"
        "-s ${minikube-subnet} ! -i wlp9s0 -o virbr0 -j ACCEPT"
        "-s ${kind-subnet} ! -i wlp9s0 -o virbr0 -j ACCEPT"
        "-i virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"
      ]}
    '';
  };

  # kind cross-node pod-to-pod traffic uses bridged frames between kind node
  # containers on the kind Docker network. With bridge-nf-call-iptables=1 (default),
  # those frames traverse the host iptables FORWARD chain, where the host has no
  # route for the pod CIDR and they get dropped. Disable bridge-nf so kindnet
  # bridged traffic forwards purely at L2.
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 0;
    "net.bridge.bridge-nf-call-ip6tables" = 0;
  };

  # better legacy OS compatibility
  services.envfs.enable = true;
  programs.nix-ld.enable = true;

  # Host-specific packages
  environment.systemPackages = with pkgs; [
    chromium
    ddcutil
    efibootmgr
    kind
    kubectl
    kubernetes-helm
    linux-entra-sso
    minikube
    openssl
    parallel
  ];

  # Enable native messaging hosts for Firefox and Chrome
  environment.etc = {
    "firefox/native-messaging-hosts/linux_entra_sso.json".source = "${pkgs.linux-entra-sso}/lib/mozilla/native-messaging-hosts/linux_entra_sso.json";
    "opt/chrome/native-messaging-hosts/linux_entra_sso.json".source = "${pkgs.linux-entra-sso}/etc/opt/chrome/native-messaging-hosts/linux_entra_sso.json";
    "chromium/native-messaging-hosts/linux_entra_sso.json".source = "${pkgs.linux-entra-sso}/etc/chromium/native-messaging-hosts/linux_entra_sso.json";
  };

  programs.java = {
    package = unstable-pkgs.zulu25;
    enable = true;
  };

  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      dns = [ docker-bridge-dns ];
    };
  };

  services.ddccontrol.enable = true;

  services.thinkfan =
    let
      low = 1;
      medium = 3;
      medium-high = 4;
      high = 7;
      max = "level full-speed";
    in
    {
      enable = true;
      levels = [
        [ 0 0 56 ]
        [ low 51 71 ]
        [ medium 70 81 ]
        [ medium-high 79 91 ]
        [ high 90 101 ]
        [ max 96 255 ]
      ];
    };

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark-qt;
  };

  programs.chromium = {
    enable = true;
    extensions =
      let
        id = builtins.readFile "${pkgs.linux-entra-sso}/chrome/extension-id.txt";
        expression = "${id};file://${pkgs.linux-entra-sso}/chrome/linux-entra-sso.zip";
      in
      [
        (builtins.replaceStrings [ "\n" ] [ "" ] expression)
      ];
  };

  programs.firefox.policies = {
    ExtensionSettings = {
      "linux-entra-sso@example.com" = {
        default_area = "menupanel";
        install_url = "file://${pkgs.linux-entra-sso}/firefox/linux-entra-sso.xpi";
        installation_mode = "force_installed";
        updates_disabled = true;
      };
      "firefox.container-shortcuts@strategery.io" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/file/4068015/easy_container_shortcuts-1.6.0.xpi";
        installation_mode = "force_installed";
        updates_disabled = true;
      };
    };

    Preferences = {
      "xpinstall.signatures.required" = false;
    };
  };

  virtualisation.vmVariant = {
    virtualisation = {
      cores = 2;
      diskSize = 4096;
      memorySize = 4096;
      resolution = { x = 1920; y = 1080; };
      forwardPorts = [
        { from = "host"; host.port = 2222; guest.port = 22; }
      ];
      qemu = {
        options = [
          "-enable-kvm"
          "-display gtk,grab-on-hover=on"
        ];
        package = pkgs.qemu_kvm;
      };
    };

    services.qemuGuest.enable = true;

    # Ensure virtio modules are loaded
    boot.kernelModules = [ "virtio_pci" "virtio_net" "virtio_blk" "virtio_scsi" "virtio_balloon" ];

    boot.kernel.sysctl = {
      # enable sysrq
      "kernel.sysrq" = 502;
      "kernel.perf_event_paranoid" = 1;
      "kernel.kptr_restrict" = 0;
    };

    # Enable passwordless login
    users.users.viluon = {
      initialHashedPassword = lib.mkForce null;
      password = "";
    };

    services.displayManager = {
      autoLogin = {
        enable = true;
        user = "viluon";
      };

      defaultSession = lib.mkForce "gnome";
    };
  };

  # btrfs dedupe
  services.beesd.filesystems.root = {
    spec = config.fileSystems."/".device;
    hashTableSizeMB = 4 * 1024;
    extraOptions = [
      "--thread-min"
      "1"
      "--loadavg-target"
      "2.0"
    ];
  };

  # give Alsa more headroom to fix audio stuttering
  # see https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Troubleshooting#stuttering-audio-in-virtual-machine
  services.pipewire.wireplumber.extraConfig.stutter-fix."monitor.alsa.rules" = [
    {
      matches = [{ node.name = "~alsa_output.*"; }];
      actions = {
        update-props = {
          "api.alsa.period-size" = 1024;
          "api.alsa.headroom" = 8192;
        };
      };
    }
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
