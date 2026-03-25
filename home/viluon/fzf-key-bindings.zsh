#     ____      ____
#    / __/___  / __/
#   / /_/_  / / /_
#  / __/ / /_/ __/
# /_/   /___/_/ key-bindings.zsh
#
# Vendored from fzf with syntax-highlighted history widget.
#
# - $FZF_TMUX_OPTS
# - $FZF_CTRL_T_COMMAND
# - $FZF_CTRL_T_OPTS
# - $FZF_CTRL_R_COMMAND
# - $FZF_CTRL_R_OPTS
# - $FZF_ALT_C_COMMAND
# - $FZF_ALT_C_OPTS


# Key bindings
# ------------

# The code at the top and the bottom of this file is the same as in completion.zsh.
# Refer to that file for explanation.
if 'zmodload' 'zsh/parameter' 2>'/dev/null' && (( ${+options} )); then
  __fzf_key_bindings_options="options=(${(j: :)${(kv)options[@]}})"
else
  () {
    __fzf_key_bindings_options="setopt"
    'local' '__fzf_opt'
    for __fzf_opt in "${(@)${(@f)$(set -o)}%% *}"; do
      if [[ -o "$__fzf_opt" ]]; then
        __fzf_key_bindings_options+=" -o $__fzf_opt"
      else
        __fzf_key_bindings_options+=" +o $__fzf_opt"
      fi
    done
  }
fi

'builtin' 'emulate' 'zsh' && 'builtin' 'setopt' 'no_aliases'

{
if [[ -o interactive ]]; then

#----BEGIN INCLUDE common.sh
__fzf_defaults() {
  printf '%s\n' "--height ${FZF_TMUX_HEIGHT:-40%} --min-height 20+ --bind=ctrl-z:ignore $1"
  command cat "${FZF_DEFAULT_OPTS_FILE-}" 2> /dev/null
  printf '%s\n' "${FZF_DEFAULT_OPTS-} $2"
}

__fzf_exec_awk() {
  if [[ -z ${__fzf_awk-} ]]; then
    __fzf_awk=awk
    if [[ $OSTYPE == solaris* && -x /usr/xpg4/bin/awk ]]; then
      __fzf_awk=/usr/xpg4/bin/awk
    elif command -v mawk > /dev/null 2>&1; then
      local n x y z d
      IFS=' .' read -r n x y z d <<< $(command mawk -W version 2> /dev/null)
      [[ $n == mawk ]] &&
        (((x * 1000 + y) * 1000 + z >= 1003004)) 2> /dev/null &&
        ((d >= 20230302)) 2> /dev/null &&
        __fzf_awk=mawk
    fi
  fi
  LC_ALL=C exec "$__fzf_awk" "$@"
}
#----END INCLUDE

# CTRL-T - Paste the selected file path(s) into the command line
__fzf_select() {
  setopt localoptions pipefail no_aliases 2> /dev/null
  local item
  FZF_DEFAULT_COMMAND=${FZF_CTRL_T_COMMAND:-} \
  FZF_DEFAULT_OPTS=$(__fzf_defaults "--reverse --walker=file,dir,follow,hidden --scheme=path" "${FZF_CTRL_T_OPTS-} -m") \
  FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd) "$@" < /dev/tty | while read -r item; do
    echo -n -E "${(q)item} "
  done
  local ret=$?
  echo
  return $ret
}

__fzfcmd() {
  [ -n "${TMUX_PANE-}" ] && { [ "${FZF_TMUX:-0}" != 0 ] || [ -n "${FZF_TMUX_OPTS-}" ]; } &&
    echo "fzf-tmux ${FZF_TMUX_OPTS:--d${FZF_TMUX_HEIGHT:-40%}} -- " || echo "fzf"
}

fzf-file-widget() {
  LBUFFER="${LBUFFER}$(__fzf_select)"
  local ret=$?
  zle reset-prompt
  return $ret
}
if [[ "${FZF_CTRL_T_COMMAND-x}" != "" ]]; then
  zle     -N            fzf-file-widget
  bindkey -M emacs '^T' fzf-file-widget
  bindkey -M vicmd '^T' fzf-file-widget
  bindkey -M viins '^T' fzf-file-widget
fi

# ALT-C - cd into the selected directory
fzf-cd-widget() {
  setopt localoptions pipefail no_aliases 2> /dev/null
  local dir="$(
    FZF_DEFAULT_COMMAND=${FZF_ALT_C_COMMAND:-} \
    FZF_DEFAULT_OPTS=$(__fzf_defaults "--reverse --walker=dir,follow,hidden --scheme=path" "${FZF_ALT_C_OPTS-} +m") \
    FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd) < /dev/tty)"
  if [[ -z "$dir" ]]; then
    zle redisplay
    return 0
  fi
  zle push-line # Clear buffer. Auto-restored on next prompt.
  BUFFER="builtin cd -- ${(q)dir:a}"
  zle accept-line
  local ret=$?
  unset dir # ensure this doesn't end up appearing in prompt expansion
  zle reset-prompt
  return $ret
}
if [[ "${FZF_ALT_C_COMMAND-x}" != "" ]]; then
  zle     -N             fzf-cd-widget
  bindkey -M emacs '\ec' fzf-cd-widget
  bindkey -M vicmd '\ec' fzf-cd-widget
  bindkey -M viins '\ec' fzf-cd-widget
fi

# ---------------------------------------------------------------------------
# Syntax-highlighted CTRL-R history widget
# ---------------------------------------------------------------------------

# Convert a zsh highlight style spec (e.g. "fg=green,bold") to an ANSI SGR
# escape sequence. Handles named colours, 256-colour, true-colour (#RRGGBB),
# bold, underline, standout and "none".
__fzf_style_to_ansi() {
  setopt localoptions extendedglob
  local style="$1"
  local -a codes
  local part
  for part in ${(s:,:)style}; do
    part="${part## }" # strip leading spaces (memo field separator)
    case $part in
      fg=black)       codes+=(30) ;;
      fg=red)         codes+=(31) ;;
      fg=green)       codes+=(32) ;;
      fg=yellow)      codes+=(33) ;;
      fg=blue)        codes+=(34) ;;
      fg=magenta)     codes+=(35) ;;
      fg=cyan)        codes+=(36) ;;
      fg=white)       codes+=(37) ;;
      fg=default)     codes+=(39) ;;
      bg=black)       codes+=(40) ;;
      bg=red)         codes+=(41) ;;
      bg=green)       codes+=(42) ;;
      bg=yellow)      codes+=(43) ;;
      bg=blue)        codes+=(44) ;;
      bg=magenta)     codes+=(45) ;;
      bg=cyan)        codes+=(46) ;;
      bg=white)       codes+=(47) ;;
      bg=default)     codes+=(49) ;;
      fg=\#*)
        local hex=${part#fg=\#}
        codes+=(38 2 $((16#${hex[1,2]})) $((16#${hex[3,4]})) $((16#${hex[5,6]})))
        ;;
      bg=\#*)
        local hex=${part#bg=\#}
        codes+=(48 2 $((16#${hex[1,2]})) $((16#${hex[3,4]})) $((16#${hex[5,6]})))
        ;;
      fg=<->)
        codes+=(38 5 ${part#fg=})
        ;;
      bg=<->)
        codes+=(48 5 ${part#bg=})
        ;;
      bold)           codes+=(1) ;;
      underline)      codes+=(4) ;;
      standout)       codes+=(7) ;;
      none)           codes+=(0) ;;
      memo=*)         ;; # skip memo field
    esac
  done
  (( ${#codes} )) && printf '\e[%sm' "${(j:;:)codes}"
}

# Highlight a command string using zsh-syntax-highlighting internals and
# output an ANSI-coloured version on stdout.  Called from a pipeline
# subshell so direct writes to ZLE variables are safe (won't leak back).
__fzf_highlight_cmd() {
  setopt localoptions extendedglob
  local cmd="$1"
  (( ${#cmd} == 0 )) && { printf '%s' "$cmd"; return; }

  # BUFFER/CURSOR are writable ZLE specials — assign directly (no local,
  # which can misbehave with specials in subshells).  PREBUFFER is
  # read-only; leave it alone — it's empty at a normal prompt.
  BUFFER="$cmd"
  CURSOR=${#BUFFER}
  region_highlight=()

  # zsyh_user_options must be visible to the highlighter via dynamic scope
  local -A zsyh_user_options
  if zmodload -e zsh/parameter; then
    zsyh_user_options=("${(kv)options[@]}")
  fi

  local -a reply
  _zsh_highlight_highlighter_main_paint 2>/dev/null

  # Fallback to plain text if highlighting produced nothing
  if (( ${#region_highlight} == 0 )); then
    printf '%s' "$cmd"
    return
  fi

  # Per-character ANSI codes; later region_highlight entries take priority.
  local -a char_ansi
  local -i len=${#BUFFER} s e j
  local entry sty ansi
  for entry in "${region_highlight[@]}"; do
    local -a parts=( ${(s: :)entry} )
    s=${parts[1]}; e=${parts[2]}
    sty="${(j: :)parts[3,-1]}"
    (( s < 0 )) && s=0
    (( e > len )) && e=len
    (( s >= e )) && continue
    ansi="$(__fzf_style_to_ansi "$sty")"
    [[ -z "$ansi" ]] && continue
    for (( j = s; j < e; j++ )); do
      char_ansi[j+1]="$ansi"
    done
  done

  local output="" prev_ansi="" cur_ansi
  local reset=$'\e[0m'
  local -i i
  for (( i = 1; i <= len; i++ )); do
    cur_ansi="${char_ansi[$i]-}"
    if [[ "$cur_ansi" != "$prev_ansi" ]]; then
      [[ -n "$prev_ansi" ]] && output+="$reset"
      [[ -n "$cur_ansi" ]]  && output+="$cur_ansi"
      prev_ansi="$cur_ansi"
    fi
    output+="${BUFFER[$i]}"
  done
  [[ -n "$prev_ansi" ]] && output+="$reset"

  printf '%s' "$output"
}

# CTRL-R - Paste the selected command from history into the command line
fzf-history-widget() {
  local selected
  setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases noglob nobash_rematch 2> /dev/null

  zmodload -F zsh/parameter p:{commands,history}

  local -i highlight_limit=256

  local alias_defs="$(alias -L 2>/dev/null)"
  local func_names="${(j: :)${(k)functions[(I)[^_]*]}}"
  local parent_setopts="$(setopt)"

  selected="$(
    {
      local -A seen
      local num cmd
      for num cmd in "${(kv)history[@]}"; do
        [[ -n "${seen[$cmd]+x}" ]] && continue
        seen[$cmd]=1
        printf '%s\000%s\000' "$num" "$cmd"
      done
    } |
    zsh -c "
      for __opt in \${(f)5}; do setopt \$__opt 2>/dev/null; done
      $(functions __fzf_style_to_ansi __fzf_highlight_cmd)
      source \"\$1/zsh-syntax-highlighting.zsh\" 2>/dev/null || true
      source \"\$1/highlighters/main/main-highlighter.zsh\"
      eval \"\$2\"
      for fn in \${=3}; do
        eval \"\$fn() { :; }\" 2>/dev/null
      done
      local __cf=\"\${XDG_CACHE_HOME:-\$HOME/.cache}/fzf-history-highlights\"
      local -A __cache __used
      if [[ -f \"\$__cf\" ]]; then
        local __ck __cv
        while IFS= read -r -d \$'\\0' __ck && IFS= read -r -d \$'\\0' __cv; do
          __cache[\$__ck]=\"\$__cv\"
        done < \"\$__cf\"
      fi
      nl=\$'\\n'
      nltab=\$'\\n\\t'
      i=0
      while IFS= read -r -d \$'\\0' num; do
        IFS= read -r -d \$'\\0' cmd || break
        if [[ -n \"\${__cache[\$cmd]+x}\" ]]; then
          highlighted=\"\${__cache[\$cmd]}\"
          __used[\$cmd]=\"\$highlighted\"
        elif (( i++ < \$4 )); then
          highlighted=\"\$(__fzf_highlight_cmd \"\$cmd\")\"
          __used[\$cmd]=\"\$highlighted\"
        else
          highlighted=\"\$cmd\"
        fi
        highlighted=\"\${highlighted//\$nl/\$nltab}\"
        printf '%s\\t%s\\000' \"\$num\" \"\$highlighted\"
      done
      mkdir -p \"\${__cf:h}\" 2>/dev/null
      {
        local __k __v
        for __k __v in \"\${(kv)__used[@]}\"; do
          printf '%s\\0%s\\0' \"\$__k\" \"\$__v\"
        done
      } > \"\$__cf.tmp\" && mv \"\$__cf.tmp\" \"\$__cf\"
    " -- "$__FZF_ZSH_SH_DIR" "$alias_defs" "$func_names" "$highlight_limit" "$parent_setopts" |
    FZF_DEFAULT_OPTS=$(__fzf_defaults "" "-n2..,.. --scheme=history --bind=ctrl-r:toggle-sort,alt-r:toggle-raw --wrap-sign '\t↳ ' --highlight-line --ansi ${FZF_CTRL_R_OPTS-} --query=${(qqq)LBUFFER} +m --read0") \
    FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd))"
  local ret=$?
  if [ -n "$selected" ]; then
    # Strip ANSI escape codes before extracting the history number
    setopt localoptions extendedglob
    local clean="${selected//$'\e'\[[0-9;]#m/}"
    if [[ $(__fzf_exec_awk '{print $1; exit}' <<< "$clean") =~ ^[1-9][0-9]* ]]; then
      zle vi-fetch-history -n $MATCH
    else # selected is a custom query, not from history
      LBUFFER="$clean"
    fi
  fi
  zle reset-prompt
  return $ret
}
if [[ ${FZF_CTRL_R_COMMAND-x} != "" ]]; then
  if [[ -n ${FZF_CTRL_R_COMMAND-} ]]; then
    echo "warning: FZF_CTRL_R_COMMAND is set to a custom command, but custom commands are not yet supported for CTRL-R" >&2
  fi
  zle     -N            fzf-history-widget
  bindkey -M emacs '^R' fzf-history-widget
  bindkey -M vicmd '^R' fzf-history-widget
  bindkey -M viins '^R' fzf-history-widget
fi
fi

} always {
  eval $__fzf_key_bindings_options
  'unset' '__fzf_key_bindings_options'
}
