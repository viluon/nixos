{ pkgs, lib, hostname, ... }:
let
  projectTabsSession = pkgs.writeText "idea-terminal.session" (
    lib.concatStringsSep "\nnew_tab\n" (lib.replicate 4 "cd $IDEA_TERMINAL_CWD")
  );

  spawnTerminal = {
    nixboerse = ''
      niri msg action spawn -- env "IDEA_TERMINAL_CWD=$HOME/projects/m7g$terminal_number" \
        kitty --app-id=idea-terminal --session=${projectTabsSession}
    '';
  }.${hostname} or ''
    niri msg action spawn -- kitty --app-id=idea-terminal
  '';
in
pkgs.writeShellApplication {
  name = "idea-terminals";
  runtimeInputs = with pkgs; [ coreutils jq ];
  text = ''
    declare -A workspace_name
    declare -A spawned_for
    terminal_number=0

    classify='
      if .WorkspacesChanged then
        .WorkspacesChanged.workspaces[]
        | "workspace\t\(.id)\t\(.name // "")"
      elif .WindowOpenedOrChanged then
        .WindowOpenedOrChanged.window
        | "window\t\(.id)\t\(.app_id // "")\t\(.workspace_id)\t\(.is_floating)\t\(.title // "")"
      else empty end
    '

    timeout 60 niri msg -j event-stream \
      | jq --unbuffered -rc "$classify" \
      | while IFS=$'\t' read -r event id app workspace floating title; do
          case "$event" in
            workspace)
              workspace_name["$id"]="$app"
              ;;
            window)
              [[ "$app" == "jetbrains-idea" ]] || continue
              [[ "$floating" == "false" ]] || continue
              [[ -n "$title" ]] || continue
              [[ "''${workspace_name[$workspace]:-}" == "idea" ]] || continue
              [[ -z "''${spawned_for[$id]:-}" ]] || continue

              spawned_for["$id"]=1
              terminal_number=$((terminal_number + 1))
              ${spawnTerminal}
              ;;
          esac
        done
  '';
}
