final: prev: {
  linux-entra-sso = prev.callPackage ./linux-entra-sso.nix { };
  secretctl = prev.callPackage ./secretctl { };
  starship-pr-ci = prev.callPackage ./starship-pr-ci { };
}
