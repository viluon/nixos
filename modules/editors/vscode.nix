localFlake:
{ self
, inputs
, lib
, config
, ...
}:
{
  perSystem = { system, ... }:
    let
      packages.vscode-customised = localFlake.withSystem system ({ pkgs, ... }:
        let
          patched-pkgs = import inputs.nixpkgs {
            system = system;
            config.allowUnfree = true;
            overlays = [ inputs.nix4vscode.overlays.forVscode ];
          };
          extensions = [
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
        in
        patched-pkgs.vscode-with-extensions.override {
          vscodeExtensions = patched-pkgs.nix4vscode.forVscode extensions;
        }
      );

      devShells.vscode = localFlake.withSystem system ({ pkgs, ... }: pkgs.mkShell {
        buildInputs = [ packages.vscode-customised ];
        shellHook = ''
          printf "VS Code with extensions:\n"
          code --list-extensions
        '';
      });

      checks.vscode = localFlake.withSystem system ({ pkgs, ... }:
        pkgs.runCommand "vscode-check" { } ''
          ${packages.vscode-customised}/bin/code --version
          mkdir -p $out
        ''
      );
    in
    {
      inherit packages devShells checks;
    };
}
