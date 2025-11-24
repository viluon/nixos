{ config
, lib
, ...
}: with config.lib.niri.actions; {
  input.keyboard = {
    xkb = { };
    numlock = true;
  };

  spawn-at-startup = [
    { argv = [ "waybar" ]; }
    { argv = [ "swaybg" "--image" config.stylix.image "--mode" "fill" ]; }
  ] ++ lib.map (app: { argv = app.command; }) (import ./at-startup.nix);

  workspaces =
    lib.listToAttrs
      (lib.imap
        (index: { name, output, ... }: {
          name = lib.concatStrings [ (toString index) "-" name ];
          value = {
            inherit name;
            open-on-output = output;
          };
        })
        (import ./workspaces.nix)
      );

  window-rules =
    let
      fully-rounded = radius: { top-left = radius; top-right = radius; bottom-left = radius; bottom-right = radius; };
      rounded-top = radius: { top-left = radius; top-right = radius; bottom-left = 0.0; bottom-right = 0.0; };
    in
    [
      {
        matches = [{ app-id = "kitty"; }];
        draw-border-with-background = false;
      }
      {
        matches = [{ app-id = "nvitop"; }];
        draw-border-with-background = false;
      }
      {
        matches = [{ app-id = "nixos"; }];
        draw-border-with-background = false;
      }
      {
        matches = [{ app-id = "^firefox"; }];
        geometry-corner-radius = rounded-top 12.0;
      }
      {
        matches = [{ app-id = "virt-manager"; }];
        geometry-corner-radius = rounded-top 12.0;
      }
      {
        matches = [{ app-id = "gcr-prompter"; }];
        geometry-corner-radius = rounded-top 12.0;
      }
      {
        matches = [{ app-id = "polkit-gnome-authentication-agent-1"; }];
        geometry-corner-radius = rounded-top 12.0;
      }
      {
        matches = [{ app-id = "^org.gnome."; }];
        geometry-corner-radius = fully-rounded 14.0;
      }
      {
        matches = [{ app-id = "^code$"; is-floating = true; }];
        geometry-corner-radius = fully-rounded 14.0;
      }
      {
        matches = [{ app-id = "^jetbrains-idea$"; is-floating = true; }];
        excludes = [{ title = ".*"; }];
        geometry-corner-radius = rounded-top 14.0;
      }
    ] ++ lib.map
      (app: {
        matches = [{ app-id = app.app-id; at-startup = true; }];
        open-on-workspace = app.workspace;
        open-maximized = app.maximized or null;
      })
      (import ./at-startup.nix);

  layer-rules = [
    {
      matches = [{ namespace = "^waybar$"; }];
      shadow.enable = false;
    }
  ];

  layout = {
    border.enable = false;

    focus-ring = {
      enable = true;
      width = 3;

      active.gradient = {
        from = config.lib.stylix.colors.base0D-hex;
        to = config.lib.stylix.colors.base09-hex;
        angle = 135;
        relative-to = "window";
      };
    };
  };

  outputs = {
    "DP-1" = {
      focus-at-startup = true;
      position = { x = 1707; y = 0; };
    };
    "eDP-1" = {
      position = { x = 0; y = 700; };
    };
  };

  binds = {
    "Mod+Shift+Slash".action = show-hotkey-overlay;

    "Mod+Return".action = spawn "kitty";
    "Mod+D".action = spawn "fuzzel";
    "Super+Alt+L".action = spawn "lock";

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

    "Mod+WheelScrollDown".action = focus-workspace-down;
    "Mod+WheelScrollUp".action = focus-workspace-up;
    "Mod+WheelScrollLeft".action = focus-column-left;
    "Mod+WheelScrollRight".action = focus-column-right;

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
    "Mod+Escape".action = toggle-overview;
  };
}
