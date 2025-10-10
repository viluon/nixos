{ config, pkgs, lib, inputs, hostname, ... }:

let
  commonPackages = with pkgs; [
    bat
    eza
    fd
    fzf
    grimblast
    nixd
    ripgrep
    shellcheck
    starship
    vivid

    # Hyprland ecosystem
    waybar
    hyprpaper
    hypridle
    hyprlock
    hyprpicker
    dunst
    rofi-wayland
    wlogout

    # System utilities
    wl-clipboard
    cliphist
    playerctl
    brightnessctl
    pavucontrol
    networkmanager
    blueman
    polkit_gnome

    # Fonts
    noto-fonts
    noto-fonts-emoji
    noto-fonts-cjk-sans
    font-awesome

    # ML4W specific tools
    figlet
    gum
    matugen
    wallust
    swww
    xdg-user-dirs
  ];

  # Host-specific packages
  hostPackages = {
    nixluon = with pkgs; [
      # Development tools
      atuin
      cloc
      compsize
      coreutils
      eza
      kotlin
      (lib.hiPrio lua5_1)
      (lib.lowPrio luajit)
      mold
      nodejs
      rustup
      wasm-pack

      # Media and graphics
      ffmpeg
      gifski
      gimp
      gthumb
      mozjpeg
      vlc

      # Gaming and emulation
      bottles
      gamemode
      rpcs3
      steam

      # System utilities
      btrfs-assistant
      cachix
      ddcui
      nvitop

      # Applications
      calibre
      cdemu-client
      (pkgs.symlinkJoin {
        name = "craftos-pc-no-lua";
        paths = [ pkgs.craftos-pc ];
        postBuild = ''
          rm -f $out/lib/liblua.so*
        '';
      })
      hieroglyphic
      obsidian
      pandoc
      xournalpp

      # Tools and libraries
      gnumake
      openssl
      pkg-config
      texlive.combined.scheme-full

      # Unstable packages
      inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.galaxy-buds-client
      inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.qbittorrent
    ] ++ [
      # Host-specific packages that need special args
      inputs.self.packages.${pkgs.system}.amd-epp-tool
    ];

    nixboerse = with pkgs; [
      gnomeExtensions.brightness-control-using-ddcutil
    ];
  };

  getHostPackages = hostname: hostPackages.${hostname};

  inherit (import ./dconf { inherit lib; }) getGnomeSettings;

  scripts = lib.mapAttrsToList
    (name: _type: import ./scripts/${name} { inherit pkgs; })
    (builtins.readDir ./scripts);

in
{
  imports = [
    ../../modules/editors/vscode.nix
    inputs.self.homeModules.idea
  ];

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = commonPackages ++ (getHostPackages hostname) ++ scripts;

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # Firefox native messaging host for linux-entra-sso
    ".mozilla/native-messaging-hosts/linux_entra_sso.json" = {
      source = "${pkgs.linux-entra-sso}/firefox/linux_entra_sso.json";
    };

    # Chromium native messaging host for linux-entra-sso
    ".config/chromium/NativeMessagingHosts/linux_entra_sso.json" = {
      source = "${pkgs.linux-entra-sso}/chrome/linux_entra_sso.json";
    };

    ".config/wireshark/plugins/websocket-protobuf.lua" = {
      source = ./wireshark/plugins/websocket-protobuf.lua;
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      lh = "ls -lhF";
      ll = "ls -lhFA";
    };
  };

  # Modern zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      lh = "eza --long --git --icons=auto --classify=always";
      ll = "eza --long --git --icons=auto --classify=always --all";
      ls = "eza";
      cat = "bat";
      grep = "rg";
      find = "fd";
    };

    history = {
      size = 100 * 1000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" ];
    };

    initContent = ''
      # Better history search with fzf
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh

      # Case insensitive completion
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

      # Better ls colors
      export LS_COLORS="$(vivid generate catppuccin-mocha)"

      # Docker completion
      if command -v docker >/dev/null 2>&1; then
        source <(docker completion zsh)
      fi

      # Kubectl completion
      if command -v kubectl >/dev/null 2>&1; then
        source <(kubectl completion zsh)
      fi

      # completion for aliases
      setopt completealiases
    '';
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = "$all$character";
      character = {
        success_symbol = "[➜](bold green) ";
        error_symbol = "[➜](bold red) ";
      };
      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
      };
      git_branch = {
        symbol = "[](bold blue) ";
      };
      git_status = {
        ahead = "⇡\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        behind = "⇣\${count}";
      };
    };
  };

  # Kitty terminal emulator
  programs.kitty = {
    enable = true;
    font = {
      name = "Iosevka";
      size = 10;
    };
    themeFile = "Catppuccin-Mocha";
    settings = {
      background_opacity = "0.75";
      confirm_os_window_close = 0;
      cursor_trail = 1;
      dynamic_background_opacity = true;
      enable_audio_bell = false;
      mouse_hide_wait = "-1.0";
      shell = "${pkgs.zsh}/bin/zsh";
      window_padding_width = 10;
    };
  };

  # Enable direnv for automatic dev shell activation
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/viluon/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "vim";
    NIXD_FLAGS = "-log=error";
    REPORTMEMORY = "1000";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # GNOME dconf settings
  dconf.settings = {
    # Common GNOME settings
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      enable-animations = true;
      show-battery-percentage = true;
    };
  } // (getGnomeSettings hostname); # Merge host-specific settings
}
