#!/usr/bin/env bash
set -euo pipefail

# ===============================
# postinstall.sh
# Debian post-install bootstrap
#
# Default: DRY-RUN (safe)
# Apply:   ./postinstall.sh --apply
# ===============================

TARGET_USER="${TARGET_USER:-bengju}"
DRY_RUN=1

# --------- args ----------
for a in "${@:-}"; do
  case "$a" in
    --apply)   DRY_RUN=0 ;;
    --dry-run) DRY_RUN=1 ;;
    --user=*)  TARGET_USER="${a#*=}" ;;
    -h|--help)
      cat <<'EOF'
Usage:
  ./postinstall.sh [--dry-run|--apply] [--user=bengju]

Notes:
  - Default is --dry-run (prints what would run).
  - Use --apply to actually change the system.
EOF
      exit 0
      ;;
    *)
      echo "Unknown arg: $a" >&2
      exit 2
      ;;
  esac
done

# --------- helpers ----------
step_i=0
step_n=10

say() { echo -e "\n== $* =="; }

run() {
  if [ "$DRY_RUN" = 1 ]; then
    echo "[DRY] $*"
  else
    eval "$@"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

as_root_guard() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "Please run this script as a normal user with sudo, not as root." >&2
    exit 1
  fi
  if ! need_cmd sudo; then
    echo "sudo not found. Install/configure sudo first." >&2
    exit 1
  fi
}

next_step() {
  step_i=$((step_i+1))
  echo -e "\n[${step_i}/${step_n}] $*"
}

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    run "cp -a \"$f\" \"$f.bak.$(date +%Y%m%d-%H%M%S)\""
  fi
}

ensure_block_in_file() {
  # ensure_block_in_file <file> <start_marker> <end_marker> <content_heredoc>
  local f="$1" start="$2" end="$3"
  local tmp
  tmp="$(mktemp)"

  # If exists, remove old block first (idempotent)
  if [ -f "$f" ]; then
    awk -v s="$start" -v e="$end" '
      BEGIN{inblk=0}
      $0==s {inblk=1; next}
      $0==e {inblk=0; next}
      inblk==0 {print}
    ' "$f" > "$tmp"
  else
    : > "$tmp"
  fi

  # Append new block
  {
    echo "$start"
    cat
    echo "$end"
  } >> "$tmp"

  # Write back
  backup_file "$f"
  if [ "$DRY_RUN" = 1 ]; then
    echo "[DRY] write block into $f"
    rm -f "$tmp"
  else
    install -m 0644 "$tmp" "$f"
    rm -f "$tmp"
  fi
}

# --------- start ----------
as_root_guard

say "Post-install bootstrap (user=$TARGET_USER, dry-run=$DRY_RUN)"
echo "Tip: run with --apply to actually make changes."

# ===============================
# [1] Add user to sudo group
# ===============================
next_step "Add $TARGET_USER to sudo group"
run "sudo usermod -aG sudo \"$TARGET_USER\""
echo "NOTE: group change requires log out / log in to take effect."

# ===============================
# [2] Base packages (vim/curl/gnupg/gawk/make/git + im-config)
# ===============================
next_step "Install base packages"
run "sudo apt update"
run "sudo apt install -y vim curl gnupg gawk make git im-config"

# ===============================
# [3] Install Brave (official repo)
# ===============================
next_step "Install Brave browser"
run "sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"

run "echo \"deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] \
https://brave-browser-apt-release.s3.brave.com/ stable main\" \
| sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null"

run "sudo apt update"
run "sudo apt install -y brave-browser"

# ===============================
# [4] Fcitx4 + Cangjie 3 (fcitx-table-cangjie)
# ===============================
next_step "Install Fcitx4 + Cangjie 3"
run "sudo apt install -y fcitx fcitx-table fcitx-table-cangjie fcitx-config-gtk"

# Set input method framework to fcitx (system-wide per user via im-config)
# (Works for X11; Wayland specifics omitted as you want X11.)
run "im-config -n fcitx || true"

# ===============================
# [5] Install ble.sh (if missing)
# ===============================
next_step "Install ble.sh (if missing)"
if [ -f /usr/local/share/blesh/ble.sh ]; then
  echo "ble.sh already installed: /usr/local/share/blesh/ble.sh"
else
  run "cd \"$HOME\""
  run "rm -rf \"$HOME/ble.sh\" || true"
  run "git clone https://github.com/akinomyoga/ble.sh.git \"$HOME/ble.sh\""
  run "cd \"$HOME/ble.sh\""
  run "sudo make install"
fi

# ===============================
# [6] Write user bashrc: fcitx env + ble.sh prefs + danger guard + ssh indicator
# ===============================
next_step "Write ~/.bashrc block (fcitx env + ble.sh + danger guard + ssh indicator)"
ensure_block_in_file "$HOME/.bashrc" \
"# >>> postinstall.sh BEGIN >>>" \
"# <<< postinstall.sh END <<<" \
<<'EOF'
# ---- Input Method (fcitx4) env ----
# Ensure apps pick fcitx (X11).
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

# ---- SSH session indicator ----
if [ -n "$SSH_CONNECTION" ]; then
  PS1='[SSH] '"$PS1"
fi

# ---- ble.sh ----
# Load ble.sh if installed.
if [ -f /usr/local/share/blesh/ble.sh ]; then
  source /usr/local/share/blesh/ble.sh

  # --- Your preferred behavior ---
  # Enter runs command immediately (no multiline default).
  # Ctrl+J inserts newline.
  ble-bind -f 'C-j' newline 2>/dev/null || true

  # Keep completion/menu readable (avoid harsh reverse).
  ble-face auto_complete=fg=242,bg=none 2>/dev/null || true
  ble-face menu_complete_selected=none 2>/dev/null || true
  ble-face menu_filter_input=fg=16,bg=none 2>/dev/null || true

  # History expansion highlight (keep stable; adjust if needed later).
  # (You already saw this face exists on your system.)
  ble-face syntax_history_expansion=fg=242,bg=none 2>/dev/null || true
fi

# ---- Danger command guard (NO trap; stable with ble.sh) ----
__danger_confirm_needed() {
  # Policy:
  # - SSH: always require YES
  # - root (local): require YES
  # - local user: warn only
  if [ -n "$SSH_CONNECTION" ]; then
    return 0
  fi
  [ "$(id -u)" -eq 0 ] && return 0
  return 1
}

__danger_where() { [ -n "$SSH_CONNECTION" ] && echo "[SSH]" || echo "[LOCAL]"; }
__danger_level() { [ "$(id -u)" -eq 0 ] && echo "ROOT" || echo "USER"; }

__danger_color_begin() {
  # SSH or ROOT => bright red, else yellow
  if [ -n "$SSH_CONNECTION" ] || [ "$(id -u)" -eq 0 ]; then
    printf '\e[91m'
  else
    printf '\e[33m'
  fi
}

__danger_warn() {
  local cmd="$1"
  local where="$(__danger_where)"
  local level="$(__danger_level)"
  local c; c="$(__danger_color_begin)"
  echo -e "${c}[WARNING] ${where} ${level} dangerous command:\e[0m" >&2
  echo -e "${c}  ${cmd}\e[0m" >&2
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

wipefs() {
  __danger_warn "wipefs $*"
  __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }
  command wipefs "$@"
}

mkfs()       { __danger_warn "mkfs $*";       __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs "$@"; }
mkfs.ext4()  { __danger_warn "mkfs.ext4 $*";  __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs.ext4 "$@"; }
mkfs.xfs()   { __danger_warn "mkfs.xfs $*";   __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs.xfs "$@"; }
mkfs.btrfs() { __danger_warn "mkfs.btrfs $*"; __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs.btrfs "$@"; }
mkfs.vfat()  { __danger_warn "mkfs.vfat $*";  __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs.vfat "$@"; }

sudo() {
  # Guard when sudo is used to run a command (not "sudo -i")
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
EOF

# ===============================
# [7] Write root bashrc: root prompt bright red + same guard (ssh indicator optional)
# ===============================
next_step "Write /root/.bashrc block (root prompt red + danger guard)"
run "sudo mkdir -p /root"
run "sudo bash -lc 'test -f /root/.bashrc || touch /root/.bashrc'"

# We reuse the same block content but add a root prompt override at top.
# (We do NOT touch your existing root PS1 logic outside our block.)
tmp_root_block="$(mktemp)"
cat >"$tmp_root_block" <<'EOF'
# ---- Root prompt: make "root@host# " bright red ----
if [ "$(id -u)" -eq 0 ]; then
  PS1="\[\e[91m\]\u@\h:\w#\[\e[0m\] "
fi

# ---- SSH session indicator ----
if [ -n "$SSH_CONNECTION" ]; then
  PS1='[SSH] '"$PS1"
fi

# ---- Danger command guard (same as user) ----
__danger_confirm_needed() {
  if [ -n "$SSH_CONNECTION" ]; then
    return 0
  fi
  [ "$(id -u)" -eq 0 ] && return 0
  return 1
}

__danger_where() { [ -n "$SSH_CONNECTION" ] && echo "[SSH]" || echo "[LOCAL]"; }
__danger_level() { [ "$(id -u)" -eq 0 ] && echo "ROOT" || echo "USER"; }

__danger_color_begin() {
  if [ -n "$SSH_CONNECTION" ] || [ "$(id -u)" -eq 0 ]; then
    printf '\e[91m'
  else
    printf '\e[33m'
  fi
}

__danger_warn() {
  local cmd="$1"
  local where="$(__danger_where)"
  local level="$(__danger_level)"
  local c; c="$(__danger_color_begin)"
  echo -e "${c}[WARNING] ${where} ${level} dangerous command:\e[0m" >&2
  echo -e "${c}  ${cmd}\e[0m" >&2
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

wipefs() {
  __danger_warn "wipefs $*"
  __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }
  command wipefs "$@"
}

mkfs()       { __danger_warn "mkfs $*";       __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs "$@"; }
mkfs.ext4()  { __danger_warn "mkfs.ext4 $*";  __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs.ext4 "$@"; }
mkfs.xfs()   { __danger_warn "mkfs.xfs $*";   __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs.xfs "$@"; }
mkfs.btrfs() { __danger_warn "mkfs.btrfs $*"; __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs.btrfs "$@"; }
mkfs.vfat()  { __danger_warn "mkfs.vfat $*";  __danger_confirm_or_cancel || { echo "Canceled." >&2; return 1; }; command mkfs.vfat "$@"; }

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
EOF

# Write root block with markers using sudo + bash heredoc
if [ "$DRY_RUN" = 1 ]; then
  echo "[DRY] write block into /root/.bashrc"
else
  sudo bash -lc "awk -v s='# >>> postinstall.sh BEGIN >>>' -v e='# <<< postinstall.sh END <<<' '
    BEGIN{inblk=0}
    \$0==s {inblk=1; next}
    \$0==e {inblk=0; next}
    inblk==0 {print}
  ' /root/.bashrc > /root/.bashrc.tmp"

  sudo cp -a /root/.bashrc "/root/.bashrc.bak.$(date +%Y%m%d-%H%M%S)"
  sudo bash -lc "cat /root/.bashrc.tmp > /root/.bashrc && rm -f /root/.bashrc.tmp"
  sudo bash -lc "echo '# >>> postinstall.sh BEGIN >>>' >> /root/.bashrc"
  sudo bash -lc "cat >> /root/.bashrc" < "$tmp_root_block"
  sudo bash -lc "echo '# <<< postinstall.sh END <<<' >> /root/.bashrc"
fi
rm -f "$tmp_root_block"

# ===============================
# [8] Reminder: apply takes effect after relog
# ===============================
next_step "Post checks / reminders"
echo "1) Re-login required for sudo group changes."
echo "2) For fcitx: log out/in, then run: im-config -m (to verify) and reboot if needed."
echo "3) New bashrc settings apply by: source ~/.bashrc"

# ===============================
# [9] Optional: quick verification commands
# ===============================
next_step "Quick verify (manual commands)"
cat <<EOF
Run these after --apply:

  groups $TARGET_USER | grep -q sudo && echo "sudo group OK"
  brave-browser --version
  im-config -m
  test -f /usr/local/share/blesh/ble.sh && echo "ble.sh OK"

EOF

# ===============================
# [10] Done
# ===============================
next_step "Done"
echo "Finished. (dry-run=$DRY_RUN)"

