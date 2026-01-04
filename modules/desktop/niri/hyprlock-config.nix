{ lib
, config
, ...
}: {
  general = {
    disable_loading_bar = false;
    grace = 0;
    hide_cursor = true;
  };

  auth = {
    fingerprint.enabled = true;
  };

  background = {
    blur_passes = 3;
    path = lib.mkForce "screenshot";
  };

  input-field = {
    monitor = "";
    size = "300, 50";
    outline_thickness = 2;
    dots_size = 0.33;
    dots_spacing = 0.15;
    dots_center = true;
    fade_on_empty = false;
    placeholder_text = "";
    hide_input = false;
    position = "0, -20";
    halign = "center";
    valign = "center";
  };

  label = [
    {
      monitor = "";
      text = ''cmd[update:1000] echo "<b><big>$(date +"%H:%M")</big></b>"'';
      color = "rgb(${config.lib.stylix.colors.base05-hex})";
      font_size = 150;
      font_family = config.stylix.fonts.monospace.name;
      shadow_passes = 1;
      shadow_size = 4;
      position = "0, 190";
      halign = "center";
      valign = "center";
    }
    {
      monitor = "";
      text = ''cmd[update:1000] echo "<b><big>$(date +"%A, %B %-d")</big></b>"'';
      color = "rgb(${config.lib.stylix.colors.base05-hex})";
      font_size = 40;
      font_family = config.stylix.fonts.sansSerif.name;
      shadow_passes = 1;
      shadow_size = 2;
      position = "0, 60";
      halign = "center";
      valign = "center";
    }
  ];
}
