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
            overlays = [ inputs.nix-vscode-extensions.overlays.default ];
          };
        in
        patched-pkgs.vscode-with-extensions.override {
          vscodeExtensions = with patched-pkgs; [
            # vscode-marketplace.jackmacwindows.craftos-pc
            open-vsx-release.rust-lang.rust-analyzer
            vscode-marketplace.bbenoist.nix
            vscode-marketplace.dbaeumer.vscode-eslint
            vscode-marketplace.esbenp.prettier-vscode
            vscode-marketplace.github.codespaces
            vscode-marketplace.github.copilot
            vscode-marketplace.github.copilot-chat
            vscode-marketplace.github.vscode-github-actions
            vscode-marketplace.github.vscode-pull-request-github
            vscode-marketplace.ms-azuretools.vscode-docker
            vscode-marketplace.ms-python.python
            vscode-marketplace.ms-vscode-remote.remote-ssh
            vscode-marketplace.ms-vscode.hexeditor
            vscode-marketplace.ms-vsliveshare.vsliveshare
            vscode-marketplace.sheaf.groovylambda
            vscode-marketplace.stkb.rewrap
            vscode-marketplace.streetsidesoftware.code-spell-checker
            vscode-marketplace.streetsidesoftware.code-spell-checker-british-english
            vscode-marketplace.streetsidesoftware.code-spell-checker-czech
            vscode-marketplace.sumneko.lua
            vscode-marketplace.tamasfe.even-better-toml
            vscode-marketplace.timonwong.shellcheck
            vscode-marketplace.v4run.transpose
            vscode-marketplace.vue.volar
            vscode-marketplace.wakatime.vscode-wakatime
            vscode-marketplace.wayou.vscode-todo-highlight
          ];
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
