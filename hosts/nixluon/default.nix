# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config
, pkgs
, lib
, ...
}:

{
  imports =
    [
      ./disko.nix
      # Include the results of the hardware scan.
      ./hardware.nix
      ./kernel.nix
      ../../modules/desktop/gnome
      ../../modules/desktop/niri
      ../../modules/desktop/stylix
      ../../modules/hardware/audio.nix
      ../../modules/hardware/graphics.nix
      ../../modules/system/monitoring/governor-control.nix
      ../../modules/system/monitoring/grafana-config.nix
      ../../modules/system/networking
      ../../modules/system/nix
      ../../modules/system/systemd
      ../../modules/users/common.nix
    ];

  # firmware upgrades
  services.fwupd.enable = true;

  # bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # thunderbolt
  services.hardware.bolt.enable = true;

  # nintendo joycon controllers
  services.joycond.enable = true;

  # btrfs dedupe
  services.beesd.filesystems.root = lib.mkIf (config.fileSystems ? "/partition-root") {
    spec = config.fileSystems."/partition-root".device;
    hashTableSizeMB = 4 * 1024;
    extraOptions = [
      "--thread-min"
      "1"
      "--loadavg-target"
      "4.0"
    ];
  };

  # new xbox controller support
  hardware.xpadneo.enable = true;

  # on-demand debug info
  services.nixseparatedebuginfod2.enable = true;

  # fix for "network activation failed"
  # source: https://gist.github.com/Pitometsu/6db6ec921e19a7b37472
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="CZ"
  '';

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  # boot a rescue shell on kernel panic
  # boot.crashDump.enable = true; # TODO: enable once we find a good cache

  boot.kernel.sysctl = {
    # enable sysrq
    "kernel.sysrq" = 502;
    "kernel.perf_event_paranoid" = 1;
    "kernel.kptr_restrict" = 0;
  };

  # boot animation
  boot.plymouth.enable = true;

  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    keyMap = "us";
    packages = with pkgs; [ terminus_font ];

    # see https://github.com/catppuccin/base16/blob/99aa911b29c9c7972f7e1d868b6242507efd508c/base16/mocha.yaml
    colors = [
      "1e1e2e" # base
      "181825" # mantle
      "313244" # surface0
      "45475a" # surface1
      "585b70" # surface2
      "cdd6f4" # text
      "f5e0dc" # rosewater
      "b4befe" # lavender
      "f38ba8" # red
      "fab387" # peach
      "f9e2af" # yellow
      "a6e3a1" # green
      "94e2d5" # teal
      "89b4fa" # blue
      "cba6f7" # mauve
      "f2cdcd" # flamingo
    ];
  };

  # filesystems
  boot.supportedFilesystems = [ "ntfs" ];

  # Enable additional desktop environments
  services.displayManager.sddm.enable = false;
  services.desktopManager.plasma6.enable = true;
  # Use this for the kssshaskpass
  programs.ssh.askPassword = lib.mkForce "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

  # enable the profiling daemon
  services.sysprof.enable = true;

  services.flatpak.enable = true;

  services.fprintd.enable = true;
  security.pam.services.login = {
    enableGnomeKeyring = true;
    fprintAuth = lib.mkForce true;
  };

  services.fstrim.enable = true;

  # better legacy OS compatibility
  services.envfs.enable = true;
  programs.nix-ld.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    lm_sensors
    wget
  ];

  environment.variables = {
    # crashes Gnome on Wayland presently
    #MUTTER_DEBUG_FORCE_EGL_STREAM = "1";
  };

  # List services that you want to enable:
  virtualisation = {
    containerd.enable = true;

    podman = {
      enable = true;
      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    libvirtd = {
      enable = true;
      qemu.package = pkgs.qemu_kvm;
    };

    vmVariant = {
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
  };

  # Open ports in the firewall.
  networking.firewall =
    let
      warcraft3Range = { from = 6112; to = 6119; };
      steamLocalTransferPort = 27040;
    in
    {
      allowedTCPPorts = [ 80 443 steamLocalTransferPort ];
      allowedTCPPortRanges = [ warcraft3Range ];
      allowedUDPPorts = [ 16000 ];
      allowedUDPPortRanges = [ warcraft3Range { from = 27000; to = 27100; } ];
    };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  programs.gnome-disks.enable = true;
  programs.cdemu.enable = true;
}
