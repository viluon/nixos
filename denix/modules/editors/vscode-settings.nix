{
  "editor.fontLigatures" = true;
  "[haskell]" = {
    "editor.fontLigatures" = "\"calt\" 0, \"HSKL\" 1, \"cv57\" 2";
    "editor.tabSize" = 2;
  };
  "[amulet]" = {
    "editor.fontLigatures" = "\"calt\" 0, \"COQX\" 1, \"cv57\" 2";
    "editor.tabSize" = 2;
  };
  "[markdown]" = {
    "editor.lineNumbers" = "off";
    "editor.tabSize" = 2;
  };
  "editor.find.autoFindInSelection" = "multiline";
  "editor.renderWhitespace" = "all";
  "files.insertFinalNewline" = true;
  "editor.showFoldingControls" = "always";
  "files.trimTrailingWhitespace" = true;
  "editor.formatOnPaste" = true;
  "editor.multiCursorModifier" = "ctrlCmd";
  "editor.snippetSuggestions" = "top";
  "search.quickOpen.includeSymbols" = true;
  "search.showLineNumbers" = true;
  "search.smartCase" = true;
  "search.useReplacePreview" = false;
  "editor.suggestSelection" = "first";
  "update.mode" = "none";
  "files.hotExit" = "onExitAndWindowClose";
  "editor.minimap.showSlider" = "always";
  "cSpell.language" = "en-GB,cs";
  "editor.codeLensFontFamily" = "Iosevka Regular";
  "liveshare.showReadOnlyUsersInEditor" = "always";
  "workbench.tree.indent" = 12;
  "explorer.openEditors.visible" = 0;
  "keyboard.dispatch" = "keyCode";
  "outline.showModules" = false;
  "editor.matchBrackets" = "never";
  "editor.bracketPairColorization.enabled" = true;
  "editor.cursorBlinking" = "smooth";
  "cSpell.diagnosticLevel" = "Hint";
  "editor.inlineSuggest.enabled" = true;
  "cSpell.userWords" = [
    "analyzer"
    "Plugins"
    "prng"
    "Pythonu"
    "quickcheck"
    "randomizované"
    "řešič"
    "řešiče"
    "řešiči"
    "serializací"
    "Upvalue"
    "viluon"
    "whitebox"
    "Xoshiro"
  ];
  "github.copilot.enable" = {
    "*" = true;
    "plaintext" = true;
    "markdown" = true;
    "scminput" = false;
    "yaml" = true;
    "cpp" = true;
    "python" = true;
    "javascript" = true;
    "rust" = true;
    "github-actions-workflow" = true;
  };
  "rust-analyzer.check.command" = "clippy";
  "rust-analyzer.cargo.buildScripts.enable" = true;
  "files.exclude" = {
    "**/.classpath" = true;
    "**/.project" = true;
    "**/.settings" = true;
    "**/.factorypath" = true;
  };
  "cSpell.maxNumberOfProblems" = 400;
  "remote.SSH.remotePlatform" = {
    "ghost-in-the-wires" = "linux";
    "master-yoda" = "linux";
  };
  "telemetry.telemetryLevel" = "crash";
  "settingsSync.ignoredExtensions" = [
    "vittorioromeo.expand-selection-to-scope"
  ];
  "editor.foldingMaximumRegions" = 65000;
  "workbench.list.smoothScrolling" = true;
  "editor.smoothScrolling" = true;
  "git.confirmSync" = false;
  "editor.accessibilitySupport" = "off";
  "typescript.updateImportsOnFileMove.enabled" = "always";
  "diffEditor.ignoreTrimWhitespace" = false;
  "window.titleBarStyle" = "custom";
  "typescript.inlayHints.parameterNames.enabled" = "all";
  "git.replaceTagsWhenPull" = true;
  "githubPullRequests.pullBranch" = "never";
  "git.allowForcePush" = true;
  "git.confirmForcePush" = false;
  "[json]" = {
    "editor.defaultFormatter" = "vscode.json-language-features";
  };
  "[nix]" = {
    "editor.tabSize" = 2;
  };
  "workbench.editor.empty.hint" = "hidden";
  "editor.indentSize" = "tabSize";
  "github.copilot.nextEditSuggestions.enabled" = true;
  "nix.enableLanguageServer" = true;
  "nix.serverPath" = "/etc/profiles/per-user/viluon/bin/nixd";
  "diffEditor.hideUnchangedRegions.enabled" = true;
  "[typescript]" = {
    "editor.defaultFormatter" = "esbenp.prettier-vscode";
  };
  "workbench.editor.editorActionsLocation" = "titleBar";
  "chat.tools.terminal.autoApprove" = {
    "cd" = true;
    "echo" = true;
    "ls" = true;
    "pwd" = true;
    "cat" = true;
    "head" = true;
    "tail" = true;
    "findstr" = true;
    "wc" = true;
    "tr" = true;
    "cut" = true;
    "cmp" = true;
    "which" = true;
    "basename" = true;
    "dirname" = true;
    "realpath" = true;
    "readlink" = true;
    "stat" = true;
    "file" = true;
    "du" = true;
    "df" = true;
    "sleep" = true;
    "git status" = true;
    "git log" = true;
    "git show" = true;
    "git diff" = true;
    "Get-ChildItem" = true;
    "Get-Content" = true;
    "Get-Date" = true;
    "Get-Random" = true;
    "Get-Location" = true;
    "Write-Host" = true;
    "Write-Output" = true;
    "Split-Path" = true;
    "Join-Path" = true;
    "Start-Sleep" = true;
    "Where-Object" = true;
    "/^Select-[a-z0-9]/i" = true;
    "/^Measure-[a-z0-9]/i" = true;
    "/^Compare-[a-z0-9]/i" = true;
    "/^Format-[a-z0-9]/i" = true;
    "/^Sort-[a-z0-9]/i" = true;
    "column" = true;
    "/^column\\b.*-c\\s+[0-9]{4,}/" = false;
    "date" = true;
    "/^date\\b.*(-s|--set)\\b/" = false;
    "find" = true;
    "/^find\\b.*-(delete|exec|execdir|fprint|fprintf|fls|ok|okdir)\\b/" = false;
    "grep" = true;
    "/^grep\\b.*-(f|P)\\b/" = false;
    "sort" = true;
    "/^sort\\b.*-(o|S)\\b/" = false;
    "tree" = true;
    "/^tree\\b.*-o\\b/" = false;
    "/\\(.+\\)/" = {
      "approve" = false;
      "matchCommandLine" = true;
    };
    "/\\{.+\\}/" = {
      "approve" = false;
      "matchCommandLine" = true;
    };
    "/`.+`/" = {
      "approve" = false;
      "matchCommandLine" = true;
    };
    "rm" = false;
    "rmdir" = false;
    "del" = false;
    "Remove-Item" = false;
    "ri" = false;
    "rd" = false;
    "erase" = false;
    "dd" = false;
    "kill" = false;
    "ps" = false;
    "top" = false;
    "Stop-Process" = false;
    "spps" = false;
    "taskkill" = false;
    "taskkill.exe" = false;
    "curl" = false;
    "wget" = false;
    "Invoke-RestMethod" = false;
    "Invoke-WebRequest" = false;
    "irm" = false;
    "iwr" = false;
    "chmod" = false;
    "chown" = false;
    "Set-ItemProperty" = false;
    "sp" = false;
    "Set-Acl" = false;
    "jq" = false;
    "xargs" = false;
    "eval" = false;
    "Invoke-Expression" = false;
    "iex" = false;
    "kubectl describe" = true;
    "kubectl exec" = true;
    "kubectl get" = true;
    "kubectl logs" = true;
    "kubectl wait" = true;
    "kind get" = true;
    "nice -n 19 ionice -c 3 nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel" = {
      "approve" = true;
      "matchCommandLine" = true;
    };
    "systemd-analyze" = true;
    "systemctl show" = true;
    "systemctl status" = true;
    "systemctl list-dependencies" = true;
    "journalctl" = true;
  };
}
