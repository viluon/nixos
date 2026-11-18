{ pkgs }:
pkgs.writeShellApplication {
  name = "cleanup-before-shutdown";
  runtimeInputs = with pkgs; [ kitty jq coreutils ];
  text = ''
    shopt -s nullglob

    idle_zsh_windows='
      .[].tabs[].windows[]
      | select((.foreground_processes | map(.pid)) == [.pid])
      | select(.foreground_processes[0].cmdline[0] | test("(^|[/-])zsh$"))
      | .id'

    copilot_windows='
      .[].tabs[].windows[]
      | {id} + (.foreground_processes[] | {pid, cmdline})
      | select(.cmdline | any(test("(^|/)copilot$|github-copilot-cli/index\\.js$")))
      | "\(.id) \(.pid)"'

    has_uncompacted_messages='
      [inputs
        | select(.type == "user.message" or (.type == "session.compaction_complete" and .data.success))
        | .type]
      | last == "user.message"'

    session_events() {
      local locks=("$HOME"/.copilot/session-state/*/"inuse.$1.lock")
      [ "''${#locks[@]}" -eq 1 ] && printf '%s\n' "$(dirname "''${locks[0]}")/events.jsonl"
    }

    for socket in "$XDG_RUNTIME_DIR"/kitty-cpu-*; do
      kitty_at=(kitty @ --to "unix:$socket")
      windows=$("''${kitty_at[@]}" ls 2>/dev/null) || continue

      for window in $(jq -r "$idle_zsh_windows" <<<"$windows"); do
        "''${kitty_at[@]}" send-key --match "id:$window" ctrl+d
      done

      while read -r window pid; do
        events=$(session_events "$pid") || continue
        if jq -n -e "$has_uncompacted_messages" "$events" >/dev/null; then
          echo "compacting copilot $pid ($events)"
          "''${kitty_at[@]}" send-text --match "id:$window" /compact
          "''${kitty_at[@]}" send-key --match "id:$window" enter
        fi
      done < <(jq -r "$copilot_windows" <<<"$windows")
    done
  '';
}
