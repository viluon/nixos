{ pkgs
, config
, ...
}:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default.extensions = pkgs.nix4vscode.forVscode [
      # "jackmacwindows.craftos-pc"
      "dbaeumer.vscode-eslint"
      "esbenp.prettier-vscode"
      "github.codespaces"
      "github.copilot-chat"
      "github.copilot"
      "github.vscode-github-actions"
      "github.vscode-pull-request-github"
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
      "sumneko.lua"
      "tamasfe.even-better-toml"
      "timonwong.shellcheck"
      "v4run.transpose"
      "vue.volar"
      "wakatime.vscode-wakatime"
      "wayou.vscode-todo-highlight"
    ];
  };
}
