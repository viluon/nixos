{ delib, inputs, ... }:
delib.module {
  name = "home.shell";

  home.always.imports = [
    (
      { config, pkgs, lib, ... }:
      let
        scripts = lib.mapAttrsToList
          (name: _type: import ./scripts/${name} { inherit pkgs; })
          (builtins.readDir ./scripts);

        scriptFileNames = builtins.attrNames (builtins.readDir ./scripts);
        gitScriptVerbs = map (n: lib.removePrefix "git-" (lib.removeSuffix ".nix" n))
          (builtins.filter (n: lib.hasPrefix "git-" n) scriptFileNames);
        gitUserCommandsZstyle = lib.concatStringsSep " " (map (v: "${v}:'Custom git command'") gitScriptVerbs);
      in
      {
        home.packages = scripts;

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
            grep = "rg";
            glr = "git pull --rebase";
            gsh = "git show --ext-diff";
            lh = "eza --long --git --icons=auto --classify=always";
            ll = "eza --long --git --icons=auto --classify=always --all";
            lt = "eza --long --git --icons=auto --classify=always --git-ignore --tree";
            ls = "eza";
          };

          history = {
            size = 100 * 1000;
            path = "${config.xdg.dataHome}/zsh/history";
          };

          oh-my-zsh = {
            enable = true;
            plugins = [ "git" "sudo" ];
          };

          # 1050: after shell-integration snippets (order 1000), before shellAliases (1100).
          initContent = lib.mkOrder 1050 ''
            # Vendored fzf key-bindings with syntax-highlighted history widget
            __FZF_ZSH_SH_DIR="${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting"
            source ${./fzf-key-bindings.zsh}
            source ${inputs.fzf-git-sh}/fzf-git.sh

            # Case insensitive completion
            zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

            # Better ls colors
            export LS_COLORS="$(vivid generate catppuccin-mocha)"

            # Docker completion
            if command -v docker >/dev/null 2>&1; then
              source <(docker completion zsh)
            fi

            # Kubectl completion
            if command -v kubectl >/dev/null 2>&1; then
              source <(kubectl completion zsh)
            fi

            # Niri completion
            if command -v niri >/dev/null 2>&1; then
              source <(niri completions zsh)
            fi

            # Just completion
            if command -v just >/dev/null 2>&1; then
              source <(just --completions zsh)
            fi

            # Mill completion
            source ${./completions/mill.sh}

            # comma-rs completion
            source <(, --print-completions zsh 2>/dev/null)
            compdef _comma ,

            # completion for aliases
            unsetopt completealiases
            # Expose packaged git-* scripts as git subcommands for completion.
            # Automatically generated from ./scripts (git-*.nix) at build time.
            zstyle ':completion:*:*:git:*' user-commands ${gitUserCommandsZstyle}

            _git-ready() {
              _values 'git ready arguments' auto
            }

            _git-open() {
              if (( CURRENT == 2 )); then
                _values 'git open arguments' ready
              elif (( CURRENT == 3 )) && [[ "''${words[2]}" == "ready" ]]; then
                _values 'git open arguments' auto
              fi
            }

            # VS Code shell integration
            [[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"
          '';
        };

        programs.starship = {
          enable = true;
          enableZshIntegration = true;
          settings = {
            format = "$all$character";
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
              ahead = "⇡\${count}";
              diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
              behind = "⇣\${count}";
            };
            gradle.symbol = " ";
            kotlin.symbol = " ";
            custom.pr_ci_success = {
              when = "starship-pr-ci is success";
              symbol = "";
              style = "bold green";
              format = "[$symbol]($style) ";
            };
            custom.pr_ci_failure = {
              when = "starship-pr-ci is failure";
              symbol = "";
              style = "bold red";
              command = "starship-pr-ci detail";
              format = "[$output $symbol]($style) ";
            };
            custom.pr_ci_pending = {
              when = "starship-pr-ci is pending";
              symbol = "";
              style = "bold yellow";
              command = "starship-pr-ci detail";
              format = "[$output $symbol]($style) ";
            };
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

        programs.kitty = {
          enable = true;
          font = {
            size = lib.mkForce 12;
          };
          themeFile = "Catppuccin-Mocha";
          keybindings = {
            "ctrl+shift+t" = "new_tab_with_cwd";
          };
          settings = {
            confirm_os_window_close = 0;
            cursor_trail = 1;
            dynamic_background_opacity = true;
            enable_audio_bell = false;
            momentum_scroll = 0.96;
            mouse_hide_wait = "-1.0";
            notify_on_cmd_finish = "unfocused";
            pixel_scroll = true;
            scrollback_lines = 50000;
            scrollback_pager_history_size = 128;
            shell = "${pkgs.zsh}/bin/zsh";
            window_padding_width = 10;
          };
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
