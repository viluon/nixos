{ niri
, pkgs
, ...
}: {
  nixpkgs.overlays = [ niri.overlays.niri ];

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };

  environment.systemPackages = with pkgs; [
    btop
    grim
    networkmanagerapplet
    pavucontrol
    playerctl
    slurp
    swaylock
    wireplumber
    wl-clipboard
    wlogout
  ];

  fonts.packages = [ pkgs.maple-mono.NF-CN ];

  # FIXME: shouldn't hardcode username
  home-manager.users.viluon.imports = [
    (
      { config
      , ...
      }: {
        programs.niri.settings = with config.lib.niri.actions; {
          input.keyboard = {
            xkb = { };
            numlock = true;
          };

          binds = {
            "Mod+Shift+Slash".action = show-hotkey-overlay;

            "Mod+T".action = spawn "kitty";
            "Mod+D".action = spawn "fuzzel";
            "Super+Alt+L".action = spawn "swaylock";

            "XF86AudioRaiseVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+";
            "XF86AudioLowerVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-";

            "Mod+Q".action = close-window;
            "Mod+W".action = toggle-column-tabbed-display;

            "Mod+Left".action = focus-column-left;
            "Mod+Down".action = focus-window-down;
            "Mod+Up".action = focus-window-up;
            "Mod+Right".action = focus-column-right;
            "Mod+H".action = focus-column-left;
            "Mod+J".action = focus-window-down;
            "Mod+K".action = focus-window-up;
            "Mod+L".action = focus-column-right;

            "Mod+Ctrl+Left".action = move-column-left;
            "Mod+Ctrl+Down".action = move-window-down;
            "Mod+Ctrl+Up".action = move-window-up;
            "Mod+Ctrl+Right".action = move-column-right;
            "Mod+Ctrl+H".action = move-column-left;
            "Mod+Ctrl+J".action = move-window-down;
            "Mod+Ctrl+K".action = move-window-up;
            "Mod+Ctrl+L".action = move-column-right;

            "Mod+Home".action = focus-column-first;
            "Mod+End".action = focus-column-last;
            "Mod+Ctrl+Home".action = move-column-to-first;
            "Mod+Ctrl+End".action = move-column-to-last;

            "Mod+Shift+Left".action = focus-monitor-left;
            "Mod+Shift+Down".action = focus-monitor-down;
            "Mod+Shift+Up".action = focus-monitor-up;
            "Mod+Shift+Right".action = focus-monitor-right;
            "Mod+Shift+H".action = focus-monitor-left;
            "Mod+Shift+J".action = focus-monitor-down;
            "Mod+Shift+K".action = focus-monitor-up;
            "Mod+Shift+L".action = focus-monitor-right;

            "Mod+Shift+Ctrl+Left".action = move-column-to-monitor-left;
            "Mod+Shift+Ctrl+Down".action = move-column-to-monitor-down;
            "Mod+Shift+Ctrl+Up".action = move-column-to-monitor-up;
            "Mod+Shift+Ctrl+Right".action = move-column-to-monitor-right;
            "Mod+Shift+Ctrl+H".action = move-column-to-monitor-left;
            "Mod+Shift+Ctrl+J".action = move-column-to-monitor-down;
            "Mod+Shift+Ctrl+K".action = move-column-to-monitor-up;
            "Mod+Shift+Ctrl+L".action = move-column-to-monitor-right;

            "Mod+V".action = toggle-window-floating;
            "Mod+Shift+V".action = switch-focus-between-floating-and-tiling;
            "Mod+BracketLeft".action = consume-or-expel-window-left;
            "Mod+BracketRight".action = consume-or-expel-window-right;

            "Mod+Page_Down".action = focus-workspace-down;
            "Mod+Page_Up".action = focus-workspace-up;
            "Mod+U".action = focus-workspace-down;
            "Mod+I".action = focus-workspace-up;
            "Mod+Ctrl+Page_Down".action = move-column-to-workspace-down;
            "Mod+Ctrl+Page_Up".action = move-column-to-workspace-up;
            "Mod+Ctrl+U".action = move-column-to-workspace-down;
            "Mod+Ctrl+I".action = move-column-to-workspace-up;

            "Mod+Shift+Page_Down".action = move-workspace-down;
            "Mod+Shift+Page_Up".action = move-workspace-up;
            "Mod+Shift+U".action = move-workspace-down;
            "Mod+Shift+I".action = move-workspace-up;

            "Mod+1".action = focus-workspace 1;
            "Mod+2".action = focus-workspace 2;
            "Mod+3".action = focus-workspace 3;
            "Mod+4".action = focus-workspace 4;
            "Mod+5".action = focus-workspace 5;
            "Mod+6".action = focus-workspace 6;
            "Mod+7".action = focus-workspace 7;
            "Mod+8".action = focus-workspace 8;
            "Mod+9".action = focus-workspace 9;
            "Mod+Ctrl+1".action.move-column-to-workspace = [ 1 ];
            "Mod+Ctrl+2".action.move-column-to-workspace = [ 2 ];
            "Mod+Ctrl+3".action.move-column-to-workspace = [ 3 ];
            "Mod+Ctrl+4".action.move-column-to-workspace = [ 4 ];
            "Mod+Ctrl+5".action.move-column-to-workspace = [ 5 ];
            "Mod+Ctrl+6".action.move-column-to-workspace = [ 6 ];
            "Mod+Ctrl+7".action.move-column-to-workspace = [ 7 ];
            "Mod+Ctrl+8".action.move-column-to-workspace = [ 8 ];
            "Mod+Ctrl+9".action.move-column-to-workspace = [ 9 ];

            "Mod+Comma".action = consume-window-into-column;
            "Mod+Period".action = expel-window-from-column;

            "Mod+R".action = switch-preset-column-width;
            "Mod+F".action = maximize-column;
            "Mod+Shift+F".action = fullscreen-window;
            "Mod+C".action = center-column;

            "Mod+Minus".action = set-column-width "-10%";
            "Mod+Equal".action = set-column-width "+10%";

            "Mod+Shift+Minus".action = set-window-height "-10%";
            "Mod+Shift+Equal".action = set-window-height "+10%";

            "Print".action.screenshot = [ ];
            "Ctrl+Print".action.screenshot-screen = [ ];
            "Alt+Print".action.screenshot-window = [ ];

            "Mod+Shift+E".action = quit;

            "Mod+Shift+P".action = power-off-monitors;
            "Mod+O".action = toggle-overview;
          };
        };

        programs.fuzzel.enable = true;

        programs.waybar = {
          enable = true;

          # inspired by https://github.com/ryan4yin/nix-config
          # Copyright (c) 2023 Ryan Yin under the MIT license
          settings = {
            mainBar =
              let
                unicode = code: builtins.fromJSON "\"\\u${code}\"";
              in
              {
                position = "top";
                layer = "top";

                modules-left = [ "custom/launcher" "temperature" "backlight" "niri/workspaces" ];
                modules-center = [ "custom/playerctl" ];
                modules-right = [
                  "pulseaudio"
                  "memory"
                  "cpu"
                  "network"
                  "battery"
                  "clock"
                  "idle_inhibitor"
                  "custom/powermenu"
                  "tray"
                ];

                "niri/workspaces" = {
                  format = "{icon}";
                  on-click = "activate";
                  format-icons = {
                    "1" = "";
                    "2" = "";
                    "3" = "";
                    "4" = "";
                    "5" = "";
                    "6" = "";
                    "7" = "";
                    "8" = "";
                    "9" = "";
                    "10" = "〇";
                    focused = "";
                    default = "";
                  };
                };

                clock = {
                  interval = 60;
                  align = 0;
                  rotate = 0;
                  tooltip-format = "<big>{:%B %Y}</big>\n<tt><small>{calendar}</small></tt>";
                  format = " {:%H:%M}";
                  format-alt = " {:%a %b %d, %G}";
                };

                cpu = {
                  format = "CPU {usage}%";
                  interval = 1;
                  on-click-middle = "kitty btop";
                  on-click-right = "kitty btop";
                };

                memory = {
                  format = "MEM {percentage}%";
                  interval = 1;
                  states = {
                    warning = 85;
                  };
                };

                "custom/launcher" = {
                  format = "${unicode "f313"} ";
                  on-click = "fuzzel";
                  on-click-middle = "exec default_wall";
                  on-click-right = "exec wallpaper_random";
                  tooltip = false;
                };

                "custom/powermenu" = {
                  format = "${unicode "f011"}";
                  on-click = "wlogout";
                  tooltip = false;
                };

                "custom/playerctl" = {
                  format = "{icon}  <span>{}</span>";
                  return-type = "json";
                  max-length = 55;
                  exec = "playerctl -a metadata --format '{\"text\": \" {{markup_escape(title)}}\", \"tooltip\": \"{{playerName}} : {{markup_escape(title)}}\", \"alt\": \"{{status}}\", \"class\": \"{{status}}\"}' -F";
                  on-click-middle = "playerctl previous";
                  on-click = "playerctl play-pause";
                  on-click-right = "playerctl next";
                  format-icons = {
                    Paused = "<span foreground='#6dd9d9'></span>";
                    Playing = "<span foreground='#82db97'></span>";
                  };
                };

                network = {
                  interval = 5;
                  format = "{ifname}";
                  format-wifi = "  {signalStrength}% Down: {bandwidthDownBytes} Up: {bandwidthUpBytes} {essid}";
                  format-ethernet = "  {ifname} Down: {bandwidthDownBytes} Up: {bandwidthUpBytes}";
                  format-disconnected = "Disconnected ⚠";
                  tooltip-format = " {ifname} via {gwaddri}";
                  tooltip-format-wifi = "  {ifname} @ {essid}\nIP: {ipaddr}\nStrength: {signalStrength}%\nFreq: {frequency}MHz\nDown: {bandwidthDownBytes} Up: {bandwidthUpBytes}";
                  tooltip-format-ethernet = " {ifname}\nIP: {ipaddr}\n Down: {bandwidthDownBytes} Up: {bandwidthUpBytes}";
                  tooltip-format-disconnected = "Disconnected";
                  max-length = 50;
                  on-click-middle = "nm-connection-editor";
                  on-click-right = "kitty nmtui";
                };

                pulseaudio = {
                  format = "{icon} {volume}%";
                  format-muted = " Mute";
                  format-bluetooth = " {volume}% {format_source}";
                  format-bluetooth-muted = " Mute";
                  format-source = " {volume}%";
                  format-source-muted = "";
                  format-icons = {
                    headphone = "";
                    hands-free = "";
                    headset = "";
                    phone = "";
                    portable = "";
                    car = "";
                    default = [ "" "" "" ];
                  };
                  scroll-step = 5.0;
                  on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
                  on-click-right = "pavucontrol";
                  smooth-scrolling-threshold = 1;
                };

                temperature = {
                  format = "${unicode "f2c9"} {temperatureC}${unicode "00b0"}C";
                  tooltip = false;
                };

                backlight = {
                  format = "{icon} {percent}%";
                  format-icons = [ "" "" "" "" "" "" "" "" "" ];
                };

                tray = {
                  icon-size = 15;
                  spacing = 5;
                };

                battery = {
                  interval = 60;
                  states = {
                    warning = 30;
                    critical = 15;
                  };
                  max-length = 20;
                  format = "{icon} {capacity}%";
                  format-warning = "{icon} {capacity}%";
                  format-critical = "{icon} {capacity}%";
                  format-charging = "<span font-family='Font Awesome 6 Free'></span> {capacity}%";
                  format-plugged = " {capacity}%";
                  format-alt = "{icon} {time}";
                  format-full = " {capacity}%";
                  format-icons = [ " " " " " " " " " " ];
                };

                idle_inhibitor = {
                  format = "{icon}";
                  format-icons = {
                    activated = "${unicode "f06e"}";
                    deactivated = "${unicode "f070"}";
                  };
                  tooltip = false;
                };
              };
          };

          style = builtins.readFile ./waybar.css;
        };
      }
    )
  ];
}
