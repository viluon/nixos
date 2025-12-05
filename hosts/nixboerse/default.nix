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
  minikube-subnet = "192.168.49.0/24";
  kind-subnet = "172.19.0.0/16";
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

  # NVIDIA-specific configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    prime.offload.enable = true;
    powerManagement.finegrained = true;
  };

  # Intel-specific configuration
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];

  programs.virt-manager.enable = true;

  virtualisation.libvirtd = {
    enable = true;
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

  # fix routing from Docker interfaces to virbr0
  networking.firewall = {
    extraCommands = lib.mkAfter ''
      # Allow traffic from minikube & kind to virbr0
      iptables -I FORWARD -s ${minikube-subnet} ! -i wlp9s0 -o virbr0 -j ACCEPT
      iptables -I FORWARD -s ${kind-subnet} ! -i wlp9s0 -o virbr0 -j ACCEPT

      # More restricted established connection handling
      iptables -I FORWARD -i virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    '';

    extraStopCommands = ''
      iptables -D FORWARD -s ${minikube-subnet} ! -i wlp9s0 -o virbr0 -j ACCEPT || true
      iptables -D FORWARD -s ${kind-subnet} ! -i wlp9s0 -o virbr0 -j ACCEPT || true
      iptables -D FORWARD -i virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || true
    '';
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
  };

  services.ddccontrol.enable = true;

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
      memorySize = 4096;
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
