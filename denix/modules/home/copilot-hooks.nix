{ delib, ... }:
delib.module {
  name = "home.copilotHooks";

  home.always.imports = [
    (
      { pkgs, ... }:
      let
        sentinel = "comments are a poor fix for illegible code";

        reviewReason = ''
          review any code changes you've made
          - comments are a poor fix for illegible code
          - `just build` should pass, if applicable
        '';

        reminder = pkgs.writeShellScript "copilot-review-reminder" ''
          set -euo pipefail
          payload="$(cat)"
          session="$(printf '%s' "$payload" | ${pkgs.jq}/bin/jq -er .sessionId)"
          marker="/tmp/copilot-review-reminder-''${session}"
          if [ -e "$marker" ]; then
            exit 0
          fi
          : > "$marker"
          cat ${blockDecision}
        '';

        blockDecision = pkgs.writeText "copilot-review-block.json" (
          builtins.toJSON {
            decision = "block";
            reason = reviewReason;
          }
        );

        clearMarker = pkgs.writeShellScript "copilot-review-reminder-clear" ''
          set -euo pipefail
          payload="$(cat)"
          session="$(printf '%s' "$payload" | ${pkgs.jq}/bin/jq -er .sessionId)"
          prompt="$(printf '%s' "$payload" | ${pkgs.jq}/bin/jq -er '.prompt // ""')"
          if printf '%s' "$prompt" | ${pkgs.gnugrep}/bin/grep -qF ${pkgs.lib.escapeShellArg sentinel}; then
            exit 0
          fi
          rm -f "/tmp/copilot-review-reminder-''${session}"
        '';

        config = {
          version = 1;
          hooks = {
            agentStop = [
              {
                type = "command";
                bash = "${reminder}";
                timeoutSec = 10;
              }
            ];
            userPromptSubmitted = [
              {
                type = "command";
                bash = "${clearMarker}";
                timeoutSec = 10;
              }
            ];
          };
        };
      in
      {
        home.file.".copilot/hooks/review-reminder.json".text = builtins.toJSON config;
      }
    )
  ];
}
