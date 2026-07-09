final: prev: {
  linux-entra-sso = prev.callPackage ./linux-entra-sso.nix { };
  starship-pr-ci = prev.callPackage ./starship-pr-ci { };
}
