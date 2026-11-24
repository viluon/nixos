{ osConfig }:
[
  {
    app-id = "^firefox-devedition$";
    workspace = "firefox";
    command = [ "firefox-devedition" ];
    maximized = true;
  }
  {
    app-id = "jetbrains-idea";
    workspace = "idea";
    command = [ "systemd-run" "--user" "--scope" "--collect" "--property=TimeoutStopSec=8s" "intellij-idea" ];
    enable = osConfig.myconfig.editors.idea.enable;
  }
  {
    app-id = "obsidian";
    workspace = "obsidian";
    command = [ "obsidian" ];
    maximized = true;
  }
  {
    app-id = "virt-manager";
    workspace = "virt-manager";
    command = [ "virt-manager" ];
    enable = osConfig.programs.virt-manager.enable;
  }
  {
    app-id = "^code$";
    workspace = "vs-code";
    command = [ "code" "/home/viluon/nixos" ];
    enable = osConfig.myconfig.editors.vscode.enable;
    maximized = true;
  }
  {
    app-id = "btop";
    workspace = "btop";
    command = [ "kitty" "--app-id=btop" "btop" ];
    maximized = true;
  }
  {
    app-id = "nixos";
    workspace = "vs-code";
    command = [ "kitty" "--app-id=nixos" "--override=font_size=14" "--working-directory=~/nixos" ];
  }
]
