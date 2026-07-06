{ delib, unstable-pkgs, ... }:
delib.module {
  name = "editors.vscode";

  home.always.imports = [
    (
      { pkgs, config, ... }:
      {
        home.file.".vscode/argv.json".source = ./argv.json;

        programs.vscode = {
          enable = true;
          package = unstable-pkgs.vscode;

          profiles.default = {
            userSettings = import ./vscode-settings.nix;

            extensions = pkgs.nix4vscode.forVscodeVersion config.programs.vscode.package.version [
              "dbaeumer.vscode-eslint"
              "esbenp.prettier-vscode"
              "github.codespaces"
              "GitHub.copilot"
              "github.vscode-github-actions"
              "github.vscode-pull-request-github"
              "iliazeus.vscode-ansi"
              "jackmacwindows.craftos-pc"
              "jnoortheen.nix-ide"
              "ms-azuretools.vscode-docker"
              "ms-python.python"
              "ms-vscode-remote.remote-ssh"
              "ms-vscode.hexeditor"
              "ms-vsliveshare.vsliveshare"
              "rust-lang.rust-analyzer"
              "sheaf.groovylambda"
              "stkb.rewrap"
              "streetsidesoftware.code-spell-checker-british-english"
              "streetsidesoftware.code-spell-checker-czech"
              "streetsidesoftware.code-spell-checker"
              "tamasfe.even-better-toml"
              "timonwong.shellcheck"
              "v4run.transpose"
              "vue.volar"
              "wakatime.vscode-wakatime"
              "wayou.vscode-todo-highlight"
            ];
          };
        };
      }
    )
  ];
}
