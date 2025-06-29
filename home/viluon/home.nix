{ config, pkgs, lib, inputs, hostname ? "unknown", ... }:

let
  commonPackages = with pkgs; [
    grimblast
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
      jetbrains.idea-ultimate
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
    ];
  };

  # Function to get packages for current host
  getHostPackages = hostname:
    if builtins.hasAttr hostname hostPackages
    then hostPackages.${hostname}
    else [ ];

in
{
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
  home.packages = commonPackages ++ (getHostPackages hostname);

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      lh = "ls -lhF";
      ll = "ls -lhFA";
    };
  };

  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    bind =
      [
        "$mod, F, exec, firefox"
        ", Print, exec, grimblast copy area"
      ]
      ++ (
        # workspaces
        # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
        builtins.concatLists (builtins.genList
          (i:
            let ws = i + 1;
            in [
              "$mod, code:1${toString i}, workspace, ${toString ws}"
              "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
            ]
          )
          9)
      );
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
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
