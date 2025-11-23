[
  {
    app-id = "^firefox-devedition$";
    workspace = "firefox";
    command = [ "firefox-devedition" ];
  }
  {
    app-id = "jetbrains-idea";
    workspace = "idea";
    command = [ "idea-ultimate" ];
  }
  {
    app-id = "obsidian";
    workspace = "obsidian";
    command = [ "obsidian" ];
  }
  {
    app-id = "virt-manager";
    workspace = "virt-manager";
    command = [ "virt-manager" ];
  }
  {
    app-id = "^code$";
    workspace = "vs-code";
    command = [ "code" "~/nixos" ];
  }
  {
    app-id = "nvitop";
    workspace = "nvitop";
    command = [ "kitty" "--app-id=nvitop" "nvitop" ];
  }
  {
    app-id = "nixos";
    workspace = "vs-code";
    command = [ "kitty" "--app-id=nixos" "--working-directory=~/nixos" ];
  }
]
