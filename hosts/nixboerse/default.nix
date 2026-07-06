# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config
, lib
, pkgs
, unstable-pkgs
, ...
}:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware.nix
      ./kernel.nix
      ./nvidia.nix
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

  boot.kernel.sysctl = {
    # enable sysrq
    "kernel.sysrq" = 502;
    "kernel.perf_event_paranoid" = 1;
    "kernel.kptr_restrict" = 0;
    "fs.inotify.max_user_watches" = 1048576;
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
    package = pkgs.wireshark;
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
