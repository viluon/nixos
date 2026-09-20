{ pkgs
, hostname
, niri
, ...
}:
let
  rust-overlay = niri.inputs."xwayland-satellite-unstable".inputs."rust-overlay".overlays.default;
  rust-nightly-pkgs = pkgs.extend rust-overlay;
  rust-nightly = rust-nightly-pkgs."rust-bin".selectLatestNightlyWith (toolchain: toolchain.minimal);
  rust-nightly-platform = pkgs.makeRustPlatform {
    cargo = rust-nightly;
    rustc = rust-nightly;
  };

  optimised-niri =
    (pkgs.niri-unstable.override {
      rustPlatform = rust-nightly-platform;
    }).overrideAttrs (_: old: {
      env.RUSTFLAGS = old.env.RUSTFLAGS + " -Ctarget-cpu=${target-cpu} -Z tune-cpu=${tune-cpu} ";
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
