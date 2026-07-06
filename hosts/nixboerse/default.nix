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

  # Host-specific packages
  environment.systemPackages = with pkgs; [
    chromium
    ddcutil
    efibootmgr
    kind
    kubectl
    kubernetes-helm
    minikube
    openssl
    parallel
  ];

  myconfig.programs.entraSso.enable = true;

  programs.java.package = unstable-pkgs.zulu25;

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

  programs.firefox.policies = {
    ExtensionSettings = {
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

  virtualisation.vmVariant.virtualisation = {
    diskSize = 4096;
    resolution = {
      x = 1920;
      y = 1080;
    };
  };

  # btrfs dedupe
  myconfig.system.btrfsDedupe = {
    enable = true;
    spec = config.fileSystems."/".device;
    loadavgTarget = "2.0";
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
