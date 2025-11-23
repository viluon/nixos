# inspired by https://github.com/ryan4yin/nix-config
# Copyright (c) 2023 Ryan Yin under the MIT license
{ lib }: {
  mainBar =
    let
      unicode = code: builtins.fromJSON "\"\\u${code}\"";
    in
    {
      position = "top";
      layer = "top";

      modules-left = [ "custom/launcher" "temperature" "backlight" "niri/workspaces" ];
      modules-center = [ "clock" "custom/playerctl" ];
      modules-right = [
        "pulseaudio"
        "memory"
        "cpu"
        "network"
        "battery"
        "idle_inhibitor"
        "custom/powermenu"
        "tray"
      ];

      "niri/workspaces" = {
        format = "{icon}";
        on-click = "activate";
        format-icons =
          let
            icons = [
              "" # firefox
              "" # intellij idea
              "" # source code
              "" # terminal
              "󰝇" # onenote (no obsidian in nerdfonts)
              "󰨞" # vs code
              "" # virtual machine
              "" # pulse

              "" # files
              "" # camera
              "" # chrome
              "" # chat
              "" # media
              "" # email
              "〇" # other
            ];
          in
          {
            focused = ""; # filled circle
            default = "";
          }
          // (builtins.listToAttrs
            (lib.zipListsWith
              (idx: value: { name = builtins.toString idx; inherit value; })
              (lib.range 1 (builtins.length icons))
              icons
            ));
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
        interface = "wlp*s*";
        format = "{ifname}";
        format-wifi = "  {signalStrength}% ↓{bandwidthDownBytes} ↑{bandwidthUpBytes} {essid}";
        format-ethernet = "  {ifname} ↓{bandwidthDownBytes} ↑{bandwidthUpBytes}";
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
        format = "{icon} {temperatureC}${unicode "00b0"}C";
        thermal-zone = 5; # TODO: split for nixluon
        warning-threshold = 95;
        critical-threshold = 100;
        format-icons = [ "${unicode "f2c9"}" "${unicode "f2c8"}" "${unicode "f2c7"}" ];
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
}
