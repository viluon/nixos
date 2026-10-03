{ delib, ... }:
delib.module {
  name = "home.basic-shell";

  home.always.imports = [
    (
      { config, ... }:
      {
        programs.bash = {
          enable = true;
          enableCompletion = true;

          shellAliases = {
            lh = "ls -lhF";
            ll = "ls -lhFA";
          };
        };

        programs.zsh = {
          enable = true;
          enableCompletion = true;
          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;

          shellAliases = {
            cat = "bat";
            find = "fd";
            glr = "git pull --rebase";
            grep = "rg";
            gsh = "git show --ext-diff";
            jb = "just build";
            lh = "eza --long --git --icons=auto --classify=always";
            ll = "eza --long --git --icons=auto --classify=always --all";
            ls = "eza";
            lt = "eza --long --git --icons=auto --classify=always --git-ignore --tree";
          };

          history = {
            size = 100 * 1000;
            path = "${config.xdg.dataHome}/zsh/history";
          };

          oh-my-zsh = {
            enable = true;
            plugins = [ "git" "sudo" ];
          };
        };

        programs.starship = {
          enable = true;
          enableZshIntegration = true;
        };

        programs.fzf = {
          enable = true;
          enableZshIntegration = true;
        };

        programs.bat.enable = true;

        programs.eza = {
          enable = true;
          enableZshIntegration = true;
          git = true;
          icons = "auto";
        };

        programs.direnv = {
          enable = true;
          enableBashIntegration = true;
          enableZshIntegration = true;
          nix-direnv.enable = true;
        };
      }
    )
  ];
}
