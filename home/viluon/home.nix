{ config, pkgs, lib, inputs, hostname, unstable-pkgs, ... }:

let
  # Host-specific packages
  hostPackages = {
    nixluon = with pkgs; [
      # Development tools
      atuin
      cloc
      compsize
      coreutils
      kotlin
      (lib.hiPrio lua5_1)
      (lib.lowPrio luajit)
      mold
      nodejs
      rustup
      wasm-pack

      # Media and graphics
      ffmpeg
      galaxy-buds-client
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
      qbittorrent
      texlive.combined.scheme-full
    ] ++ [
      # Host-specific packages that need special args
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.amd-epp-tool
    ];

    nixboerse = with pkgs; [
      unstable-pkgs.mill
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
    ./eww
    ./git
    ../../modules/desktop/input-methods.nix
    "${inputs.xhmm}/desktop/gnome/extensions.nix"
    (getGnomeExtensions hostname)
  ];

  home.packages = (getHostPackages hostname) ++ scripts;

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
      cat = "bat";
      find = "fd";
      grep = "rg";
      glr = "git pull --rebase";
      gsh = "git show --ext-diff";
      lh = "eza --long --git --icons=auto --classify=always";
      ll = "eza --long --git --icons=auto --classify=always --all";
      lt = "eza --long --git --icons=auto --classify=always --git-ignore --tree";
      ls = "eza";
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
      # Vendored fzf key-bindings with syntax-highlighted history widget
      __FZF_ZSH_SH_DIR="${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting"
      source ${./fzf-key-bindings.zsh}
      source ${inputs.fzf-git-sh}/fzf-git.sh

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

      # Mill completion
      source ${./completions/mill.sh}

      # comma-rs completion
      source <(, --print-completions zsh 2>/dev/null)
      compdef _comma ,

      # completion for aliases
      unsetopt completealiases
      # Expose packaged git-* scripts as git subcommands for completion.
      # Automatically generated from ./scripts (git-*.nix) at build time.
      zstyle ':completion:*:*:git:*' user-commands ${gitUserCommandsZstyle}

      _git-ready() {
        _values 'git ready arguments' auto
      }

      _git-open() {
        if (( CURRENT == 2 )); then
          _values 'git open arguments' ready
        elif (( CURRENT == 3 )) && [[ "''${words[2]}" == "ready" ]]; then
          _values 'git open arguments' auto
        fi
      }

      # VS Code shell integration
      [[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"
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

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.bat.enable = true;

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
  };

  # Kitty terminal emulator
  programs.kitty = {
    enable = true;
    font = {
      # override stylix default
      size = lib.mkForce 12;
    };
    themeFile = "Catppuccin-Mocha";
    keybindings = {
      "ctrl+shift+t" = "new_tab_with_cwd";
    };
    settings = {
      confirm_os_window_close = 0;
      cursor_trail = 1;
      dynamic_background_opacity = true;
      enable_audio_bell = false;
      momentum_scroll = 0.96;
      mouse_hide_wait = "-1.0";
      notify_on_cmd_finish = "unfocused";
      pixel_scroll = true;
      scrollback_lines = 50000;
      scrollback_pager_history_size = 128;
      shell = "${pkgs.zsh}/bin/zsh";
      window_padding_width = 10;
    };
  };

  stylix.targets.gtk.extraCss = ''
    popover > contents {
      background-color: rgba(24, 24, 37, 0.5);
    }
  '';

  # configure Obsidian
  stylix.targets.obsidian.vaultNames = [ "kb" ];
  programs.obsidian.enable = true;
  programs.obsidian.vaults.kb = {
    enable = true;
    target = "projects/kb";
    settings = {
      app.livePreview = false;
      # override Stylix default
      appearance.baseFontSize = lib.mkForce 17;
      hotkeys = {
        "insert-current-time" = [{ modifiers = [ "Mod" ]; key = " "; }];
        "insert-current-date" = [{ modifiers = [ "Mod" "Shift" ]; key = " "; }];
      };
      corePlugins = [
        "backlink"
        "bookmarks"
        "canvas"
        "command-palette"
        "daily-notes"
        "editor-status"
        "file-explorer"
        "file-recovery"
        "global-search"
        "graph"
        "note-composer"
        "outgoing-link"
        "outline"
        "page-preview"
        "switcher"
        "tag-pane"
        {
          name = "templates";
          settings = {
            folder = "templates";
            timeFormat = "";
          };
        }
        "word-count"
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

  programs.claude-code.enable = true;

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
    DFT_PARSE_ERROR_LIMIT = "300";
    EDITOR = "nvim";
    NIXD_FLAGS = "-log=error";
    REPORTMEMORY = "1000000";
    TIMEFMT = "real: %E | user: %U | sys: %S | cpu: %P | %*E total | max rss: %M kB";
  };

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
