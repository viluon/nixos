final: prev: {
  linux-entra-sso = prev.callPackage ./linux-entra-sso.nix { };
  kitty-cpu-tabs = prev.callPackage ./kitty-cpu-tabs { };
  starship-pr-ci = prev.callPackage ./starship-pr-ci { };
}
