{ pkgs }:

let
  zshSyntaxHighlighting = pkgs.zsh-syntax-highlighting;
  fzfKeyBindings = ../home/viluon/fzf-key-bindings.zsh;

  testScript = pkgs.writeText "fzf-highlight-test.zsh" ''
    emulate zsh
    setopt extendedglob

    failures=0
    tests=0

    assert_eq() {
      local label="$1" expected="$2" actual="$3"
      (( tests++ ))
      if [[ "$expected" != "$actual" ]]; then
        (( failures++ ))
        print -r -- "FAIL: $label"
        print -r -- "  expected: $(printf '%q' "$expected")"
        print -r -- "  actual:   $(printf '%q' "$actual")"
      else
        print -r -- "ok: $label"
      fi
    }

    assert_contains() {
      local label="$1" needle="$2" haystack="$3"
      (( tests++ ))
      if [[ "$haystack" != *"$needle"* ]]; then
        (( failures++ ))
        print -r -- "FAIL: $label"
        print -r -- "  expected to contain: $(printf '%q' "$needle")"
        print -r -- "  actual:              $(printf '%q' "$haystack")"
      else
        print -r -- "ok: $label"
      fi
    }

    assert_not_contains() {
      local label="$1" needle="$2" haystack="$3"
      (( tests++ ))
      if [[ "$haystack" == *"$needle"* ]]; then
        (( failures++ ))
        print -r -- "FAIL: $label"
        print -r -- "  should NOT contain: $(printf '%q' "$needle")"
        print -r -- "  actual:             $(printf '%q' "$haystack")"
      else
        print -r -- "ok: $label"
      fi
    }

    assert_not_eq() {
      local label="$1" unexpected="$2" actual="$3"
      (( tests++ ))
      if [[ "$unexpected" == "$actual" ]]; then
        (( failures++ ))
        print -r -- "FAIL: $label"
        print -r -- "  should differ from: $(printf '%q' "$unexpected")"
      else
        print -r -- "ok: $label"
      fi
    }

    # Load zsh-syntax-highlighting; widget-binding aborts in non-interactive
    # mode, so load the main highlighter explicitly afterwards.
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)
    typeset -gA ZSH_HIGHLIGHT_STYLES
    source "${zshSyntaxHighlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" 2>/dev/null || true
    source "${zshSyntaxHighlighting}/share/zsh-syntax-highlighting/highlighters/main/main-highlighter.zsh"

    assert_eq "paint fn exists" 0 "$(type _zsh_highlight_highlighter_main_paint >/dev/null 2>&1; echo $?)"
    assert_eq "add_highlight fn exists" 0 "$(type _zsh_highlight_add_highlight >/dev/null 2>&1; echo $?)"

    # Extract functions under test from the [[ -o interactive ]] guard
    eval "$(sed -n '/^__fzf_style_to_ansi/,/^}/p; /^__fzf_highlight_cmd/,/^}/p' "${fzfKeyBindings}")"

    assert_eq "style_to_ansi fn exists" 0 "$(type __fzf_style_to_ansi >/dev/null 2>&1; echo $?)"
    assert_eq "highlight_cmd fn exists" 0 "$(type __fzf_highlight_cmd >/dev/null 2>&1; echo $?)"

    # --- style → ANSI conversion ---
    print -- "--- __fzf_style_to_ansi ---"

    assert_eq "fg named"    $'\e[32m'              "$(__fzf_style_to_ansi 'fg=green')"
    assert_eq "compound"    $'\e[31;1m'            "$(__fzf_style_to_ansi 'fg=red,bold')"
    assert_eq "bold"        $'\e[1m'               "$(__fzf_style_to_ansi 'bold')"
    assert_eq "underline"   $'\e[4m'               "$(__fzf_style_to_ansi 'underline')"
    assert_eq "none"        $'\e[0m'               "$(__fzf_style_to_ansi 'none')"
    assert_eq "memo only"   ""                     "$(__fzf_style_to_ansi 'memo=zsh-syntax-highlighting')"
    assert_eq "with memo"   $'\e[31m'              "$(__fzf_style_to_ansi 'fg=red, memo=zsh-syntax-highlighting')"
    assert_eq "256-color"   $'\e[38;5;42m'         "$(__fzf_style_to_ansi 'fg=42')"
    assert_eq "truecolor"   $'\e[38;2;255;0;128m'  "$(__fzf_style_to_ansi 'fg=#ff0080')"

    # --- command highlighting ---
    print -- "--- __fzf_highlight_cmd ---"

    check_highlighted() {
      local label="$1" cmd="$2"
      shift 2
      local result="$(__fzf_highlight_cmd "$cmd")"
      assert_contains "$label produces ANSI" $'\e[' "$result"
      assert_not_eq   "$label differs from plain" "$cmd" "$result"
      local word
      for word in "$@"; do
        assert_contains "$label contains '$word'" "$word" "$result"
      done
    }

    check_highlighted "builtin"     "echo hello"                      echo hello
    check_highlighted "command"     "ls -la"                          ls
    check_highlighted "unknown cmd" "nonexistent_cmd_12345 --foo"     nonexistent_cmd_12345
    check_highlighted "quoted str"  "echo 'hello world'"              echo hello world
    check_highlighted "pipeline"    "cat foo | grep bar"              cat grep "|"
    check_highlighted "multiline"   $'if true; then\necho hi\nfi'    if echo fi

    assert_eq "empty input" "" "$(__fzf_highlight_cmd "")"

    # --- alias recognition ---
    print -- "--- alias recognition ---"
    alias myalias='echo test'
    myalias_result="$(__fzf_highlight_cmd "myalias foo")"
    assert_contains "alias produces ANSI" $'\e[' "$myalias_result"
    # Should NOT be highlighted as unknown-token (red)
    unknown_result="$(__fzf_highlight_cmd "nonexistent_cmd_12345")"
    # Both should have ANSI, but the alias shouldn't use the unknown-token style
    assert_not_eq "alias differs from unknown" "$unknown_result" \
      "$(__fzf_highlight_cmd "myalias")"

    # --- full pipeline (simulates widget data flow) ---
    print -- "--- pipeline ---"

    run_pipeline() {
      local limit=''${1:--1}
      shift
      local i=0
      printf '%s\0%s\0' "$@" |
      while IFS= read -r -d $'\0' num; do
        IFS= read -r -d $'\0' cmd || break
        if (( limit < 0 || i++ < limit )); then
          local highlighted="$(__fzf_highlight_cmd "$cmd")"
        else
          local highlighted="$cmd"
        fi
        local nl=$'\n' nltab=$'\n\t'
        highlighted="''${highlighted//$nl/$nltab}"
        printf '%s\t%s\000' "$num" "$highlighted"
      done
    }

    pipeline_out="$(run_pipeline -1 42 'echo hello' 117 'ls -la')"
    assert_contains "has entry 42"  "42"    "$pipeline_out"
    assert_contains "has entry 117" "117"   "$pipeline_out"
    assert_contains "has ANSI"      $'\e['  "$pipeline_out"
    assert_contains "has echo"      "echo"  "$pipeline_out"
    assert_contains "has ls"        "ls"    "$pipeline_out"

    pipeline_ml="$(run_pipeline -1 99 $'if true; then\necho hi\nfi')"
    assert_contains     "multiline has tab-indented newline" $'\n\t' "$pipeline_ml"
    assert_not_contains "no literal dollar-quote"            "\$'"   "$pipeline_ml"

    # Hybrid: only first N entries highlighted, rest plain
    hybrid_out="$(run_pipeline 1 1 'echo hello' 2 'ls -la' 3 'cat foo')"
    # Split by null to get individual records
    local -a records=( "''${(@0)hybrid_out}" )
    # First record (index 1) should have ANSI
    assert_contains "hybrid: first entry highlighted" $'\e[' "$records[1]"
    # Later records should be plain text (no ANSI)
    assert_not_contains "hybrid: second entry plain" $'\e[' "$records[2]"
    assert_not_contains "hybrid: third entry plain"  $'\e[' "$records[3]"

    # --- ANSI stripping (regex used in selection handler) ---
    print -- "--- ANSI stripping ---"
    colored=$'\e[32mecho\e[0m \e[33mhello\e[0m'
    stripped="''${colored//$'\e'\[[0-9;]#m/}"
    assert_eq "strip ANSI" "echo hello" "$stripped"

    print -- "--- Results: $((tests - failures))/$tests passed ---"
    (( failures == 0 )) || exit 1
  '';
in
pkgs.runCommand "fzf-history-highlight-check"
{
  nativeBuildInputs = [ pkgs.zsh zshSyntaxHighlighting ];
} ''
  ${pkgs.zsh}/bin/zsh ${testScript}
  touch $out
''
