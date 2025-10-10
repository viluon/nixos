{ niri
, pkgs
, ...
}: {
  programs.niri.enable = true;
  nixpkgs.overlays = [ niri.overlays.niri ];
  programs.niri.package = pkgs.niri-unstable;
}
