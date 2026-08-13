inputs@{ niri
, pkgs
, config
, ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  wayscriber = inputs.wayscriber.packages.${system}.default;

  wayscriber-toggle = pkgs.writeShellApplication {
    name = "wayscriber-toggle";
    runtimeInputs = [ wayscriber pkgs.systemd pkgs.coreutils pkgs.gnugrep ];
    text = ''
      toggle() { wayscriber --daemon-toggle 2>&1 || true; }
      broker-broken() { printf '%s' "$1" | grep -q "Unable to launch overlay process"; }

      if broker-broken "$(toggle)"; then
        systemctl --user restart wayscriber
        for ((attempt = 0; attempt < 50; attempt++)); do
          sleep 0.1
          broker-broken "$(toggle)" || exit 0
        done
      fi
    '';
  };
in
{
  nixpkgs.overlays = [ niri.overlays.niri ];

  programs.niri = import ./tuned.nix (inputs // { hostname = config.networking.hostName; });

  environment.systemPackages = with pkgs; [
    (import ./idea-terminals.nix inputs)
    grim
    libsecret
    networkmanagerapplet
    pavucontrol
    playerctl
    slurp
    swaybg
    wayscriber
    wayscriber-toggle
    inputs.wayscriber.packages.${system}.wayscriber-configurator
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
      { config, lib, ... }@inputs: {
        programs.niri.settings = import ./niri-config.nix inputs;

        programs.btop = {
          enable = true;
          package = pkgs.btop-cuda;
          settings = {
            freq_mode = "range";
            io_mode = true;
          };
        };

        programs.vicinae =
          let
            extension-names = builtins.attrNames (
              lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./vicinae-extensions)
            );
            mk-local-extension = name: config.lib.vicinae.mkExtension {
              inherit name;
              src = ./vicinae-extensions/${name};
            };
          in
          {
            enable = true;
            systemd.enable = true;
            settings.keybinds.toggle-action-panel = "control+.";
            extensions = builtins.map mk-local-extension extension-names;
          };

        programs.hyprlock = {
          enable = true;
          settings = import ./hyprlock-config.nix inputs;
        };

        programs.waybar = {
          enable = true;
          systemd.enable = true;
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
            history_length = 5000;
            mouse_left_click = "do_action,open_url,close_current";
            mouse_middle_click = "context";
            mouse_right_click = "close_current";
            timeout = 0;
          };
        };

        systemd.user.services.dunst.Service = {
          Restart = "on-failure";
          RestartSec = 1;
        };

        systemd.user.services.wayscriber = {
          Unit = {
            Description = "wayscriber screen annotation daemon";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };

          Service = {
            Type = "simple";
            ExecStart = "${wayscriber}/bin/wayscriber --daemon";
            Restart = "on-failure";
            RestartSec = 1;
          };

          Install.WantedBy = [ "graphical-session.target" ];
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
