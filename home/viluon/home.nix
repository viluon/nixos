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

  rj-notifier = import ./scripts/rj-notifier.nix { inherit pkgs; };

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
  home.packages = commonPackages ++ (getHostPackages hostname) ++ [ rj-notifier ];

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

  wayland.windowManager.hyprland = {
    enable = false;
    settings = {
      # Monitor configuration
      monitor = [
        ",preferred,auto,auto"
      ];

      # Environment variables
      env = [
        "CLUTTER_BACKEND,wayland"
        "GDK_BACKEND,wayland,x11,*"
        "HYPRCURSOR_SIZE,24"
        "QT_AUTO_SCREEN_SCALE_FACTOR,1"
        "QT_QPA_PLATFORM,wayland;xcb"
        "QT_QPA_PLATFORMTHEME,qt5ct"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "SDL_VIDEODRIVER,wayland"
        "XCURSOR_SIZE,24"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
      ];

      # Input configuration
      input = {
        kb_layout = "us";

        follow_mouse = 1;
        sensitivity = 0;

        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          tap-to-click = true;
        };
      };

      # General configuration
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      # Decoration settings
      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 1.0;

        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";

        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };

      # Animations
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      # Dwindle layout
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      # Master layout
      master = {
        new_status = "master";
      };

      # Misc settings
      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = false;
      };

      # Variables
      "$terminal" = "kitty";
      "$fileManager" = "nautilus";
      "$menu" = "rofi -show drun";
      "$mod" = "SUPER";

      # Key bindings
      bind = [
        # Applications
        "$mod, Q, exec, $terminal"
        "$mod, C, killactive,"
        "$mod, M, exit,"
        "$mod, E, exec, $fileManager"
        "$mod, V, togglefloating,"
        "$mod, R, exec, $menu"
        "$mod, P, pseudo," # dwindle
        "$mod, J, togglesplit," # dwindle
        "$mod, F, exec, firefox-devedition"

        # Move focus with mainMod + arrow keys
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Move focus with mainMod + hjkl
        "$mod, h, movefocus, l"
        "$mod, l, movefocus, r"
        "$mod, k, movefocus, u"
        "$mod, j, movefocus, d"

        # Switch workspaces with mainMod + [0-9]
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Special workspace (scratchpad)
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through existing workspaces with mainMod + scroll
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"

        # Screenshot - ML4W specific bindings
        ", Print, exec, grimblast copy area"
        "$mod, Print, exec, grimblast copy screen"
        "$mod SHIFT, W, exec, ~/.config/hypr/scripts/wallpaper.sh"
        "$mod SHIFT, B, exec, waybar"
        "$mod CTRL, Q, exec, wlogout"

        # Window management
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
        "$mod SHIFT, h, movewindow, l"
        "$mod SHIFT, l, movewindow, r"
        "$mod SHIFT, k, movewindow, u"
        "$mod SHIFT, j, movewindow, d"

        # Resize windows
        "$mod CTRL, left, resizeactive, -20 0"
        "$mod CTRL, right, resizeactive, 20 0"
        "$mod CTRL, up, resizeactive, 0 -20"
        "$mod CTRL, down, resizeactive, 0 20"
        "$mod CTRL, h, resizeactive, -20 0"
        "$mod CTRL, l, resizeactive, 20 0"
        "$mod CTRL, k, resizeactive, 0 -20"
        "$mod CTRL, j, resizeactive, 0 20"

        # ML4W specific bindings
        "$mod SHIFT, S, exec, ~/.config/hypr/scripts/hyprshade.sh"
        "$mod CTRL, S, exec, ml4w-hyprland"
        "$mod, G, exec, ~/.config/hypr/scripts/gamemode.sh"
        "$mod ALT, G, exec, ~/.config/hypr/scripts/gtk.sh"
        "$mod SHIFT, A, exec, ~/.config/hypr/scripts/toggleallfloat.sh"
        "$mod, T, exec, ~/.config/hypr/scripts/toggleallfloat.sh"
        "$mod ALT, F, exec, ~/.config/hypr/scripts/filemanager.sh"
        "$mod CTRL, F, exec, ~/.config/hypr/scripts/filemanager.sh"

        # Media keys
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"

        # Brightness
        ", XF86MonBrightnessUp, exec, brightnessctl set 10%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Window rules
      windowrulev2 = [
        "suppressevent maximize, class:.*"
        "float, class:^(pavucontrol)$"
        "float, class:^(blueman-manager)$"
        "float, class:^(nm-connection-editor)$"
        "float, class:^(gnome-calculator)$"
        "float, title:^(Picture-in-Picture)$"
        "pin, title:^(Picture-in-Picture)$"
        "size 800 600, title:^(Picture-in-Picture)$"
        "move 100%-820 100%-620, title:^(Picture-in-Picture)$"
        "minsize 300 400, class:^(jetbrains-)(.*)$, title:^(\s*)$"
      ];

      # Layer rules
      layerrule = [
        "blur, gtk-layer-shell"
        "blur, rofi"
        "ignorezero, rofi"
      ];

      # Autostart
      exec-once = [
        "waybar"
        "hyprpaper"
        "hypridle"
        "dunst"
        "nm-applet"
        "blueman-applet"
        "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];
    };
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
