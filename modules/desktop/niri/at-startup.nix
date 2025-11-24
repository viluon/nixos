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
    command = [ "idea-ultimate" ];
    maximized = true;
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
  }
  {
    app-id = "^code$";
    workspace = "vs-code";
    command = [ "code" "/home/viluon/nixos" ];
    maximized = true;
  }
  {
    app-id = "nvitop";
    workspace = "nvitop";
    command = [ "kitty" "--app-id=nvitop" "nvitop" ];
    maximized = true;
  }
  {
    app-id = "nixos";
    workspace = "vs-code";
    command = [ "kitty" "--app-id=nixos" "--override=font_size=14" "--working-directory=~/nixos" ];
  }
]
