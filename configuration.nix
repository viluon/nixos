# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, unstable-pkgs, lib, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./monitoring/grafana-config.nix
    ];

  nix = {
    # nix version
    package = pkgs.nixStable;

    # set nix build scheduling policies to idle to preserve interactivity
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";

    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # trust viluon to configure binary caches
      trusted-users = [ "root" "viluon" ];

      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://viluon.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "viluon.cachix.org-1:lYmQCd3Bb0GYrHCxPCshn2oCRDMqMmN/i5kgkBlxmNk="
      ];
    };

    gc = {
      automatic = true;
      randomizedDelaySec = "15min";
      options = "--delete-older-than 60d";
    };

    optimise = {
      automatic = true;
      dates = [ "20:00" ];
    };
  };

  # kernel version
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # firmware upgrades
  services.fwupd.enable = true;

  # bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # thunderbolt
  services.hardware.bolt.enable = true;

  # nintendo joycon controllers
  services.joycond.enable = true;

  # new xbox controller support
  hardware.xpadneo.enable = true;

  hardware.graphics = {
    enable = true;

    # fix for steam crashing
    enable32Bit = true;

    # va-api
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  # on-demand debug info
  services.nixseparatedebuginfod.enable = true;

  # extra modules
  boot.extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
  # fix for "network activation failed"
  # source: https://gist.github.com/Pitometsu/6db6ec921e19a7b37472
  boot.extraModprobeConfig = ''
    options iwlwifi 11n_disable=8
  '';

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  # boot a rescue shell on kernel panic
  # boot.crashDump.enable = true; # TODO: enable once we find a good cache

  # enable sysrq
  boot.kernel.sysctl."kernel.sysrq" = 502;

  # boot animation
  boot.plymouth.enable = true;

  # filesystems
  boot.supportedFilesystems = [ "ntfs" ];
  fileSystems = {
    "/".options = [ "compress=zstd" ];
  };

  networking.hostName = "nixluon"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # MagicDNS
  networking.nameservers = [ "100.100.100.100" "8.8.8.8" "1.1.1.1" ];
  networking.search = [ "example.ts.net" ];

  # systemd-resolved
  services.resolved = {
    enable = true;
    dnsovertls = "true";
  };

  # Set your time zone.
  time.timeZone = "Europe/Prague";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the GNOME and Plasma Desktop Environments.
  services.displayManager.sddm.enable = true;
  services.xserver.displayManager.gdm.enable = false;
  services.xserver.desktopManager.gnome.enable = true;
  services.desktopManager.plasma6.enable = true;
  # Use this for the kssshaskpass
  programs.ssh.askPassword = lib.mkForce "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

  # Enable the X11 windowing system
  # configure keymap in X11
  # and disable xterm
  services.xserver = {
    enable = true;
    xkb = {
      variant = "";
      options = "caps:swapescape";
      layout = "us";
    };
    excludePackages = [ pkgs.xterm ];
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # enable the profiling daemon
  services.sysprof.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  services.tailscale.enable = true;

  services.flatpak.enable = true;

  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = true;

  services.fstrim.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.viluon = {
    isNormalUser = true;
    description = "Andrew Kvapil";
    extraGroups = [ "cdrom" "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [
      (vscode-with-extensions.override {
        vscodeExtensions = with vscode-extensions; [
          bbenoist.nix
          dbaeumer.vscode-eslint
          esbenp.prettier-vscode
          github.codespaces
          github.copilot
          github.copilot-chat
          github.vscode-github-actions
          github.vscode-pull-request-github
          ms-azuretools.vscode-docker
          ms-python.python
          ms-vscode-remote.remote-ssh
          ms-vscode.hexeditor
          ms-vsliveshare.vsliveshare
          rust-lang.rust-analyzer
          stkb.rewrap
          streetsidesoftware.code-spell-checker
          sumneko.lua
          tamasfe.even-better-toml
          timonwong.shellcheck
          wakatime.vscode-wakatime
        ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "craftos-pc";
            publisher = "jackmacwindows";
            version = "1.2.2";
            sha256 = "sha256-A+MNroXv0t9Mw/gr0Fyov3cXyF/GGzwRLKrIxQ2tKCE=";
          }
          {
            name = "groovylambda";
            publisher = "sheaf";
            version = "0.1.0";
            sha256 = "sha256-bv1TgtFUYliKCorSvlyHABAZXVrbvBdUjepzDJI3XMg=";
          }
          {
            name = "code-spell-checker-czech";
            publisher = "streetsidesoftware";
            version = "1.0.4";
            sha256 = "sha256-WxmOfF8s4biiJ7TLKMkhmoCQmFrSeGcP4aIz0KRygdA=";
          }
          {
            name = "code-spell-checker-british-english";
            publisher = "streetsidesoftware";
            version = "1.3.0";
            sha256 = "sha256-w6RNWJH8Orc3dM0iH0sFh+WdvYTThn74HJ89KTPNAUA=";
          }
          {
            name = "transpose";
            publisher = "v4run";
            version = "0.0.6";
            sha256 = "sha256-oz0pg3n7jJ+JNCcSnEaRioqewCS8Jg+2ifC3F1feZ14=";
          }
          {
            name = "vscode-typescript-vue-plugin";
            publisher = "vue";
            version = "1.8.22";
            sha256 = "sha256-nPYsneBIXEotGYf1CQWwfjHO6nPrCxU26fKi993vJIE=";
          }
          {
            name = "vscode-todo-highlight";
            publisher = "wayou";
            version = "1.0.5";
            sha256 = "sha256-CQVtMdt/fZcNIbH/KybJixnLqCsz5iF1U0k+GfL65Ok=";
          }
        ];
      })
      alass
      atuin
      bottles
      btrfs-assistant
      cachix
      calibre
      cdemu-client
      cloc
      craftos-pc
      ddcui
      eza
      ffmpeg
      gamemode
      gifski
      gimp
      gnumake
      gthumb
      hieroglyphic
      jetbrains.idea-ultimate
      kotlin
      lua5_1
      luajit
      mold
      mozjpeg
      nodejs
      nvitop
      obsidian
      openssl
      pandoc
      pkg-config
      rpcs3
      rustup
      steam
      texlive.combined.scheme-full
      toybox
      unstable-pkgs.galaxy-buds-client
      unstable-pkgs.qbittorrent
      vlc
      wasm-pack
      xournalpp
    ];
  };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox-devedition;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    iosevka
    lm_sensors
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  # fix for vscode on wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.variables = {
    # crashes Gnome on Wayland presently
    #MUTTER_DEBUG_FORCE_EGL_STREAM = "1";
  };

  # tlp properly
  services.power-profiles-daemon.enable = false;
  powerManagement.powertop.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 91;
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      #
      #
    };
  };

  fonts.packages = with pkgs; [
    iosevka
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:
  virtualisation.docker.enable = true;
  #virtualisation.podman = {
  #enable = true;

  # Create a `docker` alias for podman, to use it as a drop-in replacement
  #dockerCompat = true;

  # Required for containers under podman-compose to be able to talk to each other.
  #defaultNetwork.dnsname.enable = true;
  #};

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall =
    let
      warcraft3Range = { from = 6112; to = 6119; };
      steamLocalTransferPort = 27040;
    in
    {
      enable = true;

      allowedTCPPorts = [ 80 443 steamLocalTransferPort ];
      allowedTCPPortRanges = [ warcraft3Range ];
      allowedUDPPorts = [ 16000 ];
      allowedUDPPortRanges = [ warcraft3Range { from = 27000; to = 27100; } ];
    };
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

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
