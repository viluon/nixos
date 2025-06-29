{ pkgs
, vscode-customised
, ...
}:

{
  # Define common user account
  users.users.viluon = {
    isNormalUser = true;
    description = "Andrew Kvapil";
    extraGroups = [ "cdrom" "networkmanager" "wheel" "docker" "uinput" ];
    packages = [
      vscode-customised
    ];
    openssh.authorizedKeys.keys =
      let
        githubKeysJson = builtins.fetchurl {
          url = "https://api.github.com/users/viluon/keys";
          sha256 = "1fj9ic79qsh3s2s8wc9kjzzli2xl46qs22jnj90hfzdzjp8fymnw";
        };
      in
      map (key: key.key) (builtins.fromJSON (builtins.readFile githubKeysJson));
  };

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

  # Common system packages
  environment.systemPackages = with pkgs; [
    iosevka
    vim
  ];

  # Font configuration
  fonts.packages = with pkgs; [
    iosevka
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
