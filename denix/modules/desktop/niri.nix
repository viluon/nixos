{ delib, niri, ... }:
delib.module {
  name = "desktop.niri";

  nixos.always.imports = [
    (
      { config, pkgs, ... }@moduleArgs:
      {
        nixpkgs.overlays = [ niri.overlays.niri ];

        programs.steam = {
          enable = true;
          remotePlay.openFirewall = true;
          localNetworkGameTransfers.openFirewall = true;
        };

        programs.gamescope.enable = true;

        programs.niri = import ./niri/tuned.nix (
          moduleArgs // { hostname = config.networking.hostName; inherit niri; }
        );

        environment.systemPackages = with pkgs; [
          (import ./niri/idea-terminals.nix moduleArgs)
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
      }
    )
  ];

  home.always.imports = [
    (
      { config, lib, pkgs, ... }@moduleArgs:
      {
        programs.niri.settings = import ./niri/niri-config.nix moduleArgs;

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
            extensionNames = builtins.attrNames (
              lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./niri/vicinae-extensions)
            );
            mkLocalExtension = name: config.lib.vicinae.mkExtension {
              inherit name;
              src = ./niri/vicinae-extensions/${name};
            };
          in
          {
            enable = true;
            systemd.enable = true;
            settings.keybinds.toggle-action-panel = "control+.";
            extensions = builtins.map mkLocalExtension extensionNames;
          };

        programs.hyprlock = {
          enable = true;
          settings = import ./niri/hyprlock-config.nix moduleArgs;
        };

        programs.waybar = {
          enable = true;
          systemd.enable = true;
          settings = import ./niri/waybar-config.nix moduleArgs;
          style = builtins.readFile ./niri/waybar.css;
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

          Install.WantedBy = [ "graphical-session.target" ];
        };
      }
    )
  ];
}
