{ pkgs
, hostname
, ...
}:
let
  optimised-niri =
    pkgs.niri-unstable.overrideAttrs (new: old: {
      RUSTFLAGS = old.RUSTFLAGS ++ [ "-Ctarget-cpu=${target-cpu}" ];
    });

  target-cpu = "x86-64-v3";

  # FIXME: should be defined consistently instead of pattern matching everywhere
  tune-cpu =
    if hostname == "nixboerse" then
      "tigerlake"
    else
      if hostname == "nixluon" then
        "znver5"
      else
        "x86-64-v4";
in
{
  enable = true;
  package = optimised-niri;
}
