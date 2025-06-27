# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config
, pkgs
, unstable-pkgs
, lib
, vscode-customised
, amd-epp-tool
, ...
}:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./disko.nix
      ./hardware.nix
      ../../modules/system/monitoring/governor-control.nix
      ../../modules/system/monitoring/grafana-config.nix
      ../../modules/system/nix
    ];

  nix.gc = {
    automatic = true;
    randomizedDelaySec = "15min";
    options = "--delete-older-than 60d";
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

  # btrfs dedupe
  services.beesd.filesystems.root = {
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
    options cfg80211 ieee80211_regdom="CZ"
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

  networking.hostName = "nixluon"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # MagicDNS
  networking.nameservers = [ "100.100.100.100" "8.8.8.8" "1.1.1.1" ];
  networking.search = [ "werewolf-torino.ts.net" ];

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
  services.displayManager.sddm.enable = false;
  services.displayManager.defaultSession = "gnome";
  services.xserver.displayManager.gdm.enable = true;
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

  # Swap caps lock & escape on Wayland too (user must be in the uinput group)
  hardware.uinput.enable = true;
  services.kanata = {
    enable = true;
    keyboards.framework.config = ''
      (defsrc
        esc
        grv  1    2    3    4    5    6    7    8    9    0    -    =    bspc
        tab  q    w    e    r    t    y    u    i    o    p    [    ]    \
        caps a    s    d    f    g    h    j    k    l    ;    '    ret
        lsft z    x    c    v    b    n    m    ,    .    /    rsft
        lctl lmet lalt           spc            ralt rctl
      )

      (deflayer swapped
        caps
        grv  1    2    3    4    5    6    7    8    9    0    -    =    bspc
        tab  q    w    e    r    t    y    u    i    o    p    [    ]    \
        esc  a    s    d    f    g    h    j    k    l    ;    '    ret
        lsft z    x    c    v    b    n    m    ,    .    /    rsft
        lctl lmet lalt           spc            ralt rctl
      )
    '';
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # enable the profiling daemon
  services.sysprof.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
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
  security.pam.services.login = {
    enableGnomeKeyring = true;
    fprintAuth = lib.mkForce true;
  };

  services.fstrim.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.viluon = {
    isNormalUser = true;
    description = "Andrew Kvapil";
    extraGroups = [ "cdrom" "networkmanager" "wheel" "docker" "uinput" ];
    packages = with pkgs; [
      amd-epp-tool
      atuin
      bottles
      btrfs-assistant
      cachix
      calibre
      cdemu-client
      cloc
      coreutils
      craftos-pc
      ddcui
      eza
      ffmpeg
      gamemode
      gifski
      gimp
      gnome-tweaks
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
      vscode-customised
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

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  programs.hyprlock.enable = true;
  programs.iio-hyprland.enable = true;
  # services.hypridle.enable = true;

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
  virtualisation.containerd.enable = true;
  virtualisation.podman = {
    enable = true;
    # Create a `docker` alias for podman, to use it as a drop-in replacement
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

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
