{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "idea-terminals";
  runtimeInputs = with pkgs; [ jq ];
  text = ''
    declare -A workspace_name
    declare -A spawned_for

    classify='
      if .WorkspacesChanged then
        .WorkspacesChanged.workspaces[]
        | "workspace\t\(.id)\t\(.name // "")"
      elif .WindowOpenedOrChanged then
        .WindowOpenedOrChanged.window
        | "window\t\(.id)\t\(.app_id // "")\t\(.workspace_id)\t\(.is_floating)\t\(.title // "")"
      else empty end
    '

    niri msg -j event-stream \
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
              niri msg action focus-window --id "$id"
              niri msg action spawn -- kitty --app-id=idea-terminal
              sleep 1
              ;;
          esac
        done
  '';
}
