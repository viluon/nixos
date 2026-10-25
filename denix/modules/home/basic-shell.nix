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
            jc = "just compile";
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
          settings = {
            character = {
              success_symbol = "[➜](bold green) ";
              error_symbol = "[➜](bold red) ";
            };
            directory = {
              truncation_length = 3;
              truncation_symbol = "…/";
            };
            git_branch = {
              symbol = "[](bold blue) ";
            };
            git_status = {
              style = "dimmed white";
              stashed = "";
              ahead = "⇡\${count}";
              diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
              behind = "⇣\${count}";
            };
            gradle.symbol = " ";
            kotlin.symbol = " ";
          };
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
