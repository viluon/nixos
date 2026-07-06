{ delib, ... }:
delib.module {
  name = "fonts";

  nixos.always.imports = [
    (
      { pkgs, ... }:
      {
        fonts.packages = with pkgs; [
          corefonts
          libertine
        ];
      }
    )
  ];
}
