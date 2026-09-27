{ delib, ... }:
delib.module {
  name = "home.server-core";

  home.always.imports = [
    (
      { pkgs, ... }:
      {
        home = {
          stateVersion = "25.05";
          packages = with pkgs; [
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
        };

        programs.home-manager.enable = true;
      }
    )
  ];
}
