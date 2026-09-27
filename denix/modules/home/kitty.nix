{ delib, ... }:
delib.module {
  name = "home.kitty";

  home.always.imports = [
    (
      { lib, pkgs, ... }:
      {
        programs.kitty = {
          enable = true;
          font.size = lib.mkForce 12;
          themeFile = "Catppuccin-Mocha";
          keybindings."ctrl+shift+t" = "new_tab_with_cwd";
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
      }
    )
  ];
}
