{ delib, ... }:
delib.module {
  name = "home.misc";

  home.always.imports = [
    (
      { pkgs, lib, ... }:
      {
        home.file = {
          ".mozilla/native-messaging-hosts/linux_entra_sso.json".source =
            "${pkgs.linux-entra-sso}/firefox/linux_entra_sso.json";
          ".config/chromium/NativeMessagingHosts/linux_entra_sso.json".source =
            "${pkgs.linux-entra-sso}/chrome/linux_entra_sso.json";
          ".config/wireshark/plugins/websocket-protobuf.lua".source =
            ./wireshark/plugins/websocket-protobuf.lua;
        };

        stylix.targets.gtk.extraCss = ''
          popover > contents {
            background-color: rgba(24, 24, 37, 0.5);
          }
        '';

        stylix.targets.obsidian.vaultNames = [ "kb" ];
        programs.obsidian.enable = true;
        programs.obsidian.vaults.kb = {
          enable = true;
          target = "projects/kb";
          settings = {
            app.livePreview = false;
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

        programs.k9s.enable = true;
        programs.claude-code.enable = true;

        home.sessionVariables = {
          DFT_PARSE_ERROR_LIMIT = "300";
          EDITOR = "nvim";
          NIXD_FLAGS = "-log=error";
          REPORTMEMORY = "1000000";
          TIMEFMT = "real: %E | user: %U | sys: %S | cpu: %P | %*E total | max rss: %M kB";
        };
      }
    )
  ];
}
