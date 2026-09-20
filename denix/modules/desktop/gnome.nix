{ delib, inputs, ... }:
delib.module {
  name = "desktop.gnome";

  nixos.always.imports = [
    (
      { pkgs, ... }:
      {
        services.xserver = {
          enable = true;
          xkb.layout = "us";
          excludePackages = [ pkgs.xterm ];
        };

        services.displayManager = {
          gdm.enable = true;
          defaultSession = "niri";
        };
        services.desktopManager.gnome.enable = true;

        hardware.uinput.enable = true;
        services.kanata = {
          enable = true;
          keyboards.framework.config = ''
            (defsrc
              esc
              grv  1    2    3    4    5    6    7    8    9    0    -    =    bspc
              tab  q    w    e    r    t    y    u    i    o    p    [    ]    \
              caps a    s    d    f    g    h    j    k    l    ;    '    ret
              lsft z    x    c    v    b    n    m    ,    .    /    rsft
              lctl lmet lalt           spc            ralt rctl
            )

            (deflayer swapped
              caps
              grv  1    2    3    4    5    6    7    8    9    0    -    =    bspc
              tab  q    w    e    r    t    y    u    i    o    p    [    ]    \
              esc  a    s    d    f    g    h    j    k    l    ;    '    ret
              lsft z    x    c    v    b    n    m    ,    .    /    rsft
              lctl lmet lalt           spc            ralt rctl
            )
          '';
        };

        systemd.services.kanata-framework.serviceConfig = {
          Restart = "on-failure";
          RestartSec = 2;
        };

        environment.systemPackages = [ pkgs.gnome-tweaks ];
        environment.sessionVariables.NIXOS_OZONE_WL = "1";
      }
    )
  ];

  home.always.imports = [
    "${inputs.xhmm}/desktop/gnome/extensions.nix"
    (
      { lib, ... }:
      {
        dconf.settings = with lib.hm.gvariant; {
          "org/gnome/desktop/interface" = {
            enable-animations = true;
            font-antialiasing = "rgba";
            font-hinting = "full";
            show-battery-percentage = true;
          };
          "org/gnome/gnome-system-monitor" = {
            show-whose-processes = "all";
          };
          "org/gtk/gtk4/settings/file-chooser" = {
            show-hidden = true;
          };
        };
      }
    )
  ];
}
