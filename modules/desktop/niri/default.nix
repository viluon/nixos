inputs@{ niri
, pkgs
, ...
}: {
  nixpkgs.overlays = [ niri.overlays.niri ];

  programs.niri = import ./tuned.nix inputs;

  environment.systemPackages = with pkgs; [
    btop
    grim
    libsecret
    networkmanagerapplet
    pavucontrol
    playerctl
    slurp
    swaybg
    wireplumber
    wl-clipboard
    wlogout
    (pkgs.writeShellApplication {
      name = "lock";
      runtimeInputs = with pkgs; [
        procps
        hyprlock
      ];
      text = "pidof hyprlock || hyprlock";
    })
  ];

  fonts.packages = [ pkgs.maple-mono.NF-CN ];

  security.pam.services.hyprlock.enable = true;

  # FIXME: shouldn't hardcode username
  home-manager.users.viluon.imports = [
    (
      inputs: {
        programs.niri.settings = import ./niri-config.nix inputs;

        programs.btop.enable = true;
        programs.fuzzel.enable = true;

        programs.hyprlock = {
          enable = true;
          settings = import ./hyprlock-config.nix inputs;
        };

        programs.waybar = {
          enable = true;
          settings = import ./waybar-config.nix inputs;
          style = builtins.readFile ./waybar.css;
        };

        services.gnome-keyring.enable = true;

        services.dunst = {
          enable = true;

          settings.global = {
            corner_radius = 8;
            follow = "mouse";
            gap_size = 12;
            mouse_left_click = "do_action,open_url,close_current";
            mouse_middle_click = "context";
            mouse_right_click = "close_current";
          };
        };

        # niri-flake would enable the KDE agent by default
        systemd.user.services.niri-flake-polkit.Service.Enable = false;

        systemd.user.services.polkit-gnome-authentication-agent-1 = {
          Unit = {
            Description = "polkit-gnome-authentication-agent-1";
            After = [ "graphical-session.target" ];
            Wants = [ "graphical-session.target" ];
          };

          Service = {
            Type = "simple";
            ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
            Restart = "on-failure";
            RestartSec = 1;
            TimeoutStopSec = 10;
          };

          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
        };
      }
    )
  ];
}
