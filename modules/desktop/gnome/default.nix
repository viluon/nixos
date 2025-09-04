{ pkgs
, ...
}:

{
  # Enable the X11 windowing system
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
      options = "caps:swapescape";
    };
    excludePackages = [ pkgs.xterm ];
  };

  # Enable GNOME Desktop Environment
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.displayManager.defaultSession = "gnome";

  # Swap caps lock & escape on Wayland (user must be in uinput group)
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

  # GNOME-specific packages
  environment.systemPackages = with pkgs; [
    gnome-tweaks
    gnomeExtensions.kimpanel
  ];

  # Wayland session variables
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
