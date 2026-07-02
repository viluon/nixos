{ pkgs }:
pkgs.writeShellApplication {
  name = "phone-battery";
  runtimeInputs = with pkgs; [
    bluez
    glib
    gnugrep
    gawk
    coreutils
  ];
  text = ''
    empty='{"text": "", "tooltip": "No phone connected"}'

    get_prop() {
      gdbus call --system --dest org.bluez --object-path "$1" \
        --method org.freedesktop.DBus.Properties.Get "$2" "$3" 2>/dev/null
    }

    unquote() { grep -oE "'[^']*'" | head -n1 | tr -d "'"; }

    icon=$'\uf10b'
    texts=()
    tips=()
    min=101

    for mac in $(bluetoothctl devices Connected | awk '{print $2}'); do
      path="/org/bluez/hci0/dev_''${mac//:/_}"

      [ "$(get_prop "$path" org.bluez.Device1 Icon | unquote)" = "phone" ] || continue

      hex=$(get_prop "$path" org.bluez.Battery1 Percentage | grep -oE '0x[0-9a-fA-F]+' | head -n1)
      [ -z "$hex" ] && continue
      charge=$((hex))

      name=$(get_prop "$path" org.bluez.Device1 Name | unquote)
      texts+=("$icon $charge%")
      tips+=("$name: $charge%")
      [ "$charge" -lt "$min" ] && min=$charge
    done

    [ "''${#texts[@]}" -eq 0 ] && { echo "$empty"; exit 0; }

    if [ "$min" -le 15 ]; then
      state="critical"
    elif [ "$min" -le 30 ]; then
      state="warning"
    else
      state="normal"
    fi

    text=$(IFS=" "; echo "''${texts[*]}")

    tooltip=""
    for tip in "''${tips[@]}"; do
      [ -n "$tooltip" ] && tooltip="$tooltip\n"
      tooltip="$tooltip$tip"
    done

    printf '{"text": "%s", "tooltip": "%s", "class": "%s", "percentage": %s}\n' \
      "$text" "$tooltip" "$state" "$min"
  '';
}
