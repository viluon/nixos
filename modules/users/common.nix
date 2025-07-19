{ config
, pkgs
, ...
}:

{
  # Define common user account
  users.users.viluon = {
    isNormalUser = true;
    description = "Andrew Kvapil";
    extraGroups = [
      "cdrom"
      "docker"
      "networkmanager"
      "uinput"
      "wheel"
      "wireshark"
      config.hardware.i2c.group
    ];
    packages = [
    ];
    openssh.authorizedKeys.keys =
      let
        githubKeysJson = builtins.fetchurl {
          url = "https://api.github.com/users/viluon/keys";
          sha256 = "0iyqnwnsmx51y7yl7czsmz3aclr9ynxkphyjgr5v76dyz3x8islf";
        };
      in
      map (key: key.key) (builtins.fromJSON (builtins.readFile githubKeysJson));
    shell = pkgs.zsh;
  };

  security.pam.loginLimits = [
    {
      domain = "viluon";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
  ];

  # Common programs
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-devedition;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  programs.zsh.enable = true;

  # Common system packages
  environment.systemPackages = with pkgs; [
    iosevka
    ryujinx
    vim
  ];

  # Font configuration
  fonts.packages = with pkgs; [
    iosevka
    libertine
  ];

  # Internationalization
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

  # Timezone
  time.timeZone = "Europe/Prague";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
