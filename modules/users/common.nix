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
      "libvirtd"
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
        stableGithubKeys = pkgs.stdenv.mkDerivation {
          name = "github-keys-viluon";

          dontUnpack = true;
          nativeBuildInputs = with pkgs; [ cacert curl jq ];

          outputHashMode = "flat";
          outputHashAlgo = "sha256";
          outputHash = "sha256-ZE8AAmneHgQsePxbCChIok0ODEKH9oSvz2d3JOPKuWU=";

          buildPhase = ''
            curl "https://api.github.com/users/viluon/keys" | \
              jq 'map(.key) | sort' > keys.json
          '';

          installPhase = ''
            cp keys.json $out
          '';
        };
      in
      builtins.fromJSON (builtins.readFile stableGithubKeys);

    shell = pkgs.zsh;
    initialHashedPassword = "$6$rounds=2000000$9V4QeLdb.yXDzOEM$37G75PGikc2/v2pogHnjnNp4By3aCwlPEWyVa1wD/myF1wo8Ur7WWFlsZ6atN.43wJdfi9pwebd.PqPDEw0WF1";
  };

  security.sudo.extraRules = [{
    users = [ "viluon" ];
    commands = [{
      # FIXME: hardcoded home path
      command = "/run/current-system/sw/bin/nixos-rebuild test -L --flake /home/viluon/nixos";
      options = [ "NOPASSWD" ];
    }];
  }];

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
    ryubing
  ];

  # Font configuration
  fonts.packages = with pkgs; [
    corefonts
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
