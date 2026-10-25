{ delib, ... }:
delib.module {
  name = "home.core";

  home.always.imports = [
    (
      { pkgs, ... }:
      {
        home.stateVersion = "25.05";

        home.packages = with pkgs; [
          cachix
          fd
          figlet
          file
          git-absorb
          gum
          just
          manix
          nixd
          ripgrep
          shellcheck
          unzip
          vivid
        ];

        programs.home-manager.enable = true;
      }
    )
  ];
}
