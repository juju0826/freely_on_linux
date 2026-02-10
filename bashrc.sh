# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need this if you don't
# want to enable them, or if it's already enabled in /etc/bash.bashrc and
# /etc/profile sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# >>> postinstall.sh managed block (BEGIN) >>>
# ---- Input method env (Fcitx) ----
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS='@im=fcitx'

# ---- ble.sh (Bash Line Editor) ----
# 目標：
#  - 歷史建議：淡灰、不反白
#  - Enter：直接執行
#  - Ctrl+J：插入換行（穩）
#  - Ctrl+Enter：若終端支援就插入換行（不支援也不影響）
if [[ $- == *i* ]]; then
  if [ -f /usr/local/share/blesh/ble.sh ]; then
    source /usr/local/share/blesh/ble.sh

    # --- enable auto-complete suggestion (if supported by this ble.sh) ---
    if bleopt 2>/dev/null | grep -q '^complete_auto_complete='; then
      bleopt complete_auto_complete=1
    fi

    # --- suggestion style: soft gray, no reverse (use face auto_complete) ---
    # 0.4 系列常用 face 名稱：auto_complete
    # (舊版不支援 -s/-r 形式，所以用 assignment 形式最相容)
    ble-face auto_complete='fg=244'

    # --- define our own newline widget (works across versions) ---
    ble/widget/juju/insert-newline() {
      if declare -F ble-edit/insert-string >/dev/null 2>&1; then
        ble-edit/insert-string $'\n'
      elif declare -F ble-edit/insert >/dev/null 2>&1; then
        ble-edit/insert $'\n'
      else
        # fallback: emulate "C-v C-j" (documented way to insert newline)
        ble/util/put $'\x16\n' 2>/dev/null || true
      fi
    }

    # --- key bindings ---
    # Enter：直接執行（維持單行直覺）
    if ble-bind -L 2>/dev/null | grep -qx 'default/accept-line'; then
      ble-bind -f 'C-m' 'default/accept-line'
      ble-bind -f 'RET' 'default/accept-line' 2>/dev/null || true
    fi

    # Ctrl+J：插入換行（你指定的習慣）
    ble-bind -f 'C-j' 'juju/insert-newline'

    # Ctrl+Enter：終端若支援就能用（不支援也不噴錯）
    ble-bind -f 'C-Enter' 'juju/insert-newline' 2>/dev/null || true
    ble-bind -f 'C-RET'   'juju/insert-newline' 2>/dev/null || true

    # 想要更乾淨：不要自動跳出補全選單（若此選項存在）
    if bleopt 2>/dev/null | grep -q '^complete_auto_menu='; then
      bleopt complete_auto_menu=0
    fi
  fi
fi

# ---- Danger guard (interactive only) ----
if [[ $- == *i* ]]; then
  __danger_confirm_needed() {
    # SSH 或 root：需要 YES；本機一般使用者：只警告
    [ -n "$SSH_CONNECTION" ] && return 0
    [ "$(id -u)" -eq 0 ] && return 0
    return 1
  }

  __danger_warn() {
    local cmd="$1"
    local where="[LOCAL]"
    [ -n "$SSH_CONNECTION" ] && where="[SSH]"
    local who="USER"
    [ "$(id -u)" -eq 0 ] && who="ROOT"
    printf '\033[91m[WARNING] %s %s dangerous command:\033[0m\n' "$where" "$who" >&2
    printf '\033[91m  %s\033[0m\n' "$cmd" >&2
  }

  __danger_confirm_or_cancel() {
    __danger_confirm_needed || return 0
    local ans
    read -r -p "Type YES to run it: " ans
    [ "$ans" = "YES" ]
  }

  rm() {
    local cmd="rm $*"
    case " $* " in
      *" -rf / "*|*" -r / "*|*" -rf /"*|*" -r /"*|*" --no-preserve-root "*)
        __danger_warn "$cmd"
        __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }
        ;;
    esac
    command rm "$@"
  }

  dd() {
    local cmd="dd $*"
    case " $* " in
      *" if=/dev/"*|*" of=/dev/"*)
        __danger_warn "$cmd"
        __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }
        ;;
    esac
    command dd "$@"
  }

  wipefs() { __danger_warn "wipefs $*"; __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command wipefs "$@"; }
  mkfs()   { __danger_warn "mkfs $*";   __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs "$@"; }

  sudo() {
    if [ $# -ge 1 ] && [[ "$1" != "-"* ]]; then
      case "$1" in
        rm|dd|wipefs|mkfs|mkfs.ext4|mkfs.xfs|mkfs.btrfs|mkfs.vfat)
          __danger_warn "sudo $*"
          __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }
          ;;
      esac
    fi
    command sudo "$@"
  }
fi
# <<< postinstall.sh managed block (END) <<<

