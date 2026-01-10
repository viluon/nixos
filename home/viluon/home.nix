{ config, pkgs, lib, inputs, hostname, ... }:

let
  commonPackages = with pkgs; [
    bat
    eza
    fd
    fzf
    gh
    grimblast
    nixd
    obsidian
    ripgrep
    shellcheck
    starship
    steam
    vivid
    waybar

    # System utilities
    blueman
    brightnessctl
    btrfs-assistant
    cachix
    cliphist
    compsize
    ddcui
    file
    gamescope
    just
    networkmanager
    nvitop
    pavucontrol
    playerctl
    polkit_gnome
    wl-clipboard
    xwayland-run
    xwayland-satellite

    # Fonts
    noto-fonts
    noto-fonts-color-emoji
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
      ryubing

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
      pandoc
      xournalpp

      # Tools and libraries
      gnumake
      openssl
      pkg-config
      texlive.combined.scheme-full

      # Unstable packages
      inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.galaxy-buds-client
      inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.qbittorrent
    ] ++ [
      # Host-specific packages that need special args
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.amd-epp-tool
    ];

    nixboerse = with pkgs; [
      nodejs_24
    ];
  };

  getHostPackages = hostname: hostPackages.${hostname};

  inherit (import ./dconf { inherit lib; }) getGnomeSettings;
  inherit (import ./gnome-extensions { inherit lib; }) getGnomeExtensions;

  scripts = lib.mapAttrsToList
    (name: _type: import ./scripts/${name} { inherit pkgs; })
    (builtins.readDir ./scripts);

  scriptFileNames = builtins.attrNames (builtins.readDir ./scripts);
  gitScriptVerbs = map (n: lib.removePrefix "git-" (lib.removeSuffix ".nix" n))
    (builtins.filter (n: lib.hasPrefix "git-" n) scriptFileNames);
  gitUserCommandsZstyle = lib.concatStringsSep " " (map (v: "${v}:'Custom git command'") gitScriptVerbs);
in
{
  imports = [
    ../../modules/desktop/input-methods.nix
    ../../modules/editors/neovim.nix
    ../../modules/editors/vscode
    inputs.self.homeModules.idea
    "${inputs.xhmm}/desktop/gnome/extensions.nix"
    (getGnomeExtensions hostname)
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

      # Niri completion
      if command -v niri >/dev/null 2>&1; then
        source <(niri completions zsh)
      fi

      # Just completion
      if command -v just >/dev/null 2>&1; then
        source <(just --completions zsh)
      fi

      # completion for aliases
      unsetopt completealiases
      # Expose packaged git-* scripts as git subcommands for completion.
      # Automatically generated from ./scripts (git-*.nix) at build time.
      zstyle ':completion:*:*:git:*' user-commands ${gitUserCommandsZstyle}

      _git-ready() {
        _values 'git ready arguments' auto
      }
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
      gradle.symbol = " ";
      kotlin.symbol = " ";
    };
  };

  # Kitty terminal emulator
  programs.kitty = {
    enable = true;
    font = {
      # override stylix default
      size = lib.mkForce 12;
    };
    themeFile = "Catppuccin-Mocha";
    settings = {
      confirm_os_window_close = 0;
      cursor_trail = 1;
      dynamic_background_opacity = true;
      enable_audio_bell = false;
      mouse_hide_wait = "-1.0";
      shell = "${pkgs.zsh}/bin/zsh";
      window_padding_width = 10;
    };
  };

  # configure Obsidian
  stylix.targets.obsidian.vaultNames = [ "kb" ];
  programs.obsidian.enable = true;
  programs.obsidian.vaults.kb = {
    enable = true;
    target = "projects/kb";
    settings = {
      # override Stylix default
      appearance.baseFontSize = lib.mkForce 17;
      hotkeys = config.programs.obsidian.defaultSettings.hotkeys // {
        "insert-current-time" = [{ modifiers = [ "Mod" ]; key = " "; }];
        "insert-current-date" = [{ modifiers = [ "Mod" "Shift" ]; key = " "; }];
      };
      corePlugins = config.programs.obsidian.defaultSettings.corePlugins ++ [
        {
          name = "templates";
          settings = {
            folder = "templates";
            timeFormat = "";
          };
        }
      ];
    };
  };

  # Enable direnv for automatic dev shell activation
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.k9s.enable = true;

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
    EDITOR = "nvim";
    NIXD_FLAGS = "-log=error";
    REPORTMEMORY = "1000";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # GNOME dconf settings
  dconf.settings = lib.mkMerge [
    {
      # Common GNOME settings
      "org/gnome/desktop/interface" = {
        enable-animations = true;
        show-battery-percentage = true;
      };
    }
    (getGnomeSettings hostname)
  ];
}
