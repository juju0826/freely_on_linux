#!/usr/bin/env bash
set -euo pipefail

# postinstall.sh
# 用法：
#   ./postinstall.sh            # 直接套用（APPLY）
#   ./postinstall.sh --dry-run  # 乾跑（只顯示不執行）

# ---------- Config ----------
BASE_PKGS=(vim curl gnupg gawk make git im-config)

# Fcitx4 + Cangjie 3 (traditional)
FCITX_PKGS=(fcitx fcitx-table fcitx-table-cangjie fcitx-config-gtk)

# Brave (official apt repo) - amd64 only
BRAVE_KEY_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
BRAVE_KEYRING="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
BRAVE_LIST="/etc/apt/sources.list.d/brave-browser-release.list"
BRAVE_APT_LINE="deb [signed-by=${BRAVE_KEYRING} arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main"

# ble.sh
BLE_REPO="https://github.com/akinomyoga/ble.sh.git"
BLE_SRC_DIR_NAME="ble.sh"
BLE_INSTALLED_PATH="/usr/local/share/blesh/ble.sh"

# bashrc managed block markers
BEGIN_MARKER="# >>> postinstall.sh managed block (BEGIN) >>>"
END_MARKER="# <<< postinstall.sh managed block (END) <<<"

# ---------- Runtime ----------
DRY_RUN=0  # 0=apply (default), 1=dry-run

# ---------- Helpers ----------
die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "NOTE: $*" >&2; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] $*"
  else
    "$@"
  fi
}

as_root() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] sudo $*"
  else
    sudo "$@"
  fi
}

detect_user() {
  local u
  u="${SUDO_USER:-${USER:-}}"
  [ -n "$u" ] || u="$(id -un)"
  echo "$u"
}

user_home() {
  local u="$1"
  getent passwd "$u" | awk -F: '{print $6}'
}

arch_is_amd64() {
  local a
  a="$(dpkg --print-architecture 2>/dev/null || true)"
  [ "$a" = "amd64" ]
}

prompt_cangjie() {
  # 你指定的風格：Enter=YES, n=NO
  local ans
  while true; do
    read -r -p "Install Cangjie input (Fcitx4)? Enter=YES, n=NO: " ans || true
    case "${ans:-}" in
      "" ) return 0 ;;
      n|N ) return 1 ;;
      * ) echo "（直接按 Enter = 裝；輸入 n = 不裝）" ;;
    esac
  done
}

ensure_block_in_file() {
  # Args: file, begin_marker, end_marker, block_content (stdin)
  local file="$1"
  local begin="$2"
  local end="$3"
  local content
  content="$(cat)"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] write block into ${file}"
    return 0
  fi

  mkdir -p "$(dirname "$file")"
  touch "$file"

  local tmp
  tmp="$(mktemp)"

  if grep -qF "$begin" "$file" 2>/dev/null; then
    awk -v begin="$begin" -v end="$end" -v repl="$content" '
      BEGIN {inblk=0}
      {
        if ($0==begin) {print begin; print repl; inblk=1; next}
        if (inblk==1 && $0==end) {print end; inblk=0; next}
        if (inblk==0) print
      }
    ' "$file" >"$tmp"
  else
    cat "$file" >"$tmp"
    {
      echo ""
      echo "$begin"
      echo "$content"
      echo "$end"
    } >>"$tmp"
  fi

  cp -a "$tmp" "$file"
  rm -f "$tmp"
}

backup_file() {
  local f="$1"
  local ts="$2"
  if [ -f "$f" ]; then
    run cp -a "$f" "${f}.bak.${ts}"
  fi
}

# ---------- Args ----------
for arg in "${@:-}"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --apply)   DRY_RUN=0 ;;   # 允許 --apply（等同預設）
    --help|-h)
      cat <<'EOF'
Usage:
  ./postinstall.sh            # APPLY (default)
  ./postinstall.sh --apply    # APPLY
  ./postinstall.sh --dry-run  # DRY-RUN
EOF
      exit 0
      ;;
    "") : ;;
    *) die "Unknown argument: $arg" ;;
  esac
done

need_cmd id
need_cmd awk
need_cmd getent
need_cmd mktemp

TARGET_USER="$(detect_user)"
TARGET_HOME="$(user_home "$TARGET_USER")"
[ -n "$TARGET_HOME" ] || die "Cannot detect home directory for user: $TARGET_USER"

TS="$(date +%Y%m%d-%H%M%S)"
MODE_STR="APPLY"; [ "$DRY_RUN" -eq 1 ] && MODE_STR="DRY-RUN"

echo "== Post-install (user=${TARGET_USER}, mode=${MODE_STR}) =="
echo ""

# =========================
# 1) sudo group
# =========================
echo "[1/7] sudo group"
as_root usermod -aG sudo "$TARGET_USER"
note "要重新登入才會生效（sudo 群組）"
echo ""

# =========================
# 2) base packages
# =========================
echo "[2/7] base packages"
as_root apt update
as_root apt install -y "${BASE_PKGS[@]}"
echo ""

# =========================
# 3) Brave (amd64 only)
# =========================
echo "[3/7] brave"
if arch_is_amd64; then
  as_root curl -fsSLo "$BRAVE_KEYRING" "$BRAVE_KEY_URL"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] echo \"${BRAVE_APT_LINE}\" | sudo tee \"${BRAVE_LIST}\" >/dev/null"
  else
    echo "${BRAVE_APT_LINE}" | sudo tee "${BRAVE_LIST}" >/dev/null
  fi
  as_root apt update
  as_root apt install -y brave-browser
else
  note "非 amd64，自動跳過 Brave（arch=$(dpkg --print-architecture 2>/dev/null || echo unknown)）"
fi
echo ""

# =========================
# 4) Cangjie (optional)
# =========================
echo "[4/7] cangjie (optional)"
DO_CANGJIE=0
if prompt_cangjie; then
  DO_CANGJIE=1
fi

if [ "$DO_CANGJIE" -eq 1 ]; then
  as_root apt install -y "${FCITX_PKGS[@]}"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] sudo -u \"${TARGET_USER}\" -H bash -lc 'im-config -n fcitx || true'"
  else
    sudo -u "$TARGET_USER" -H bash -lc 'im-config -n fcitx || true'
  fi
  note "輸入法通常需要登出/登入；必要時重開機"
else
  echo "skip"
fi
echo ""

# =========================
# 5) ble.sh
# =========================
echo "[5/7] ble.sh"
BLE_SRC="${TARGET_HOME}/${BLE_SRC_DIR_NAME}"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] test -d \"${BLE_SRC}/.git\" && (cd \"${BLE_SRC}\" && git pull --ff-only) || git clone \"${BLE_REPO}\" \"${BLE_SRC}\""
  echo "[DRY] cd \"${BLE_SRC}\" && sudo make install"
else
  if [ -d "$BLE_SRC/.git" ]; then
    sudo -u "$TARGET_USER" -H bash -lc "cd \"${BLE_SRC}\" && git pull --ff-only"
  else
    sudo -u "$TARGET_USER" -H git clone "$BLE_REPO" "$BLE_SRC"
  fi
  sudo -u "$TARGET_USER" -H bash -lc "cd \"${BLE_SRC}\" && sudo make install"
fi
echo ""

# =========================
# 6) ~/.bashrc block
# =========================
echo "[6/7] ~/.bashrc"
USER_BASHRC="${TARGET_HOME}/.bashrc"
backup_file "$USER_BASHRC" "$TS"

USER_BLOCK_CONTENT="$(cat <<'EOF'
# ---- Input method env (Fcitx) ----
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS='@im=fcitx'

# ---- ble.sh (Bash Line Editor) ----
if [[ $- == *i* ]]; then
  if [ -f /usr/local/share/blesh/ble.sh ]; then
    source /usr/local/share/blesh/ble.sh

    # Enter = execute, Ctrl+J = newline (no MULTILINE)
    bleopt edit_line_multiline=0 2>/dev/null || true
    ble-bind -f C-j 'insert-newline' 2>/dev/null || true

    # 建議/提示：淡一點，不刺眼（不同版本可能不支援，忽略錯誤）
    bleopt highlight_syntax=1 2>/dev/null || true
    bleopt prompt_rps1_transient=1 2>/dev/null || true
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
    echo -e "\033[91m[WARNING] ${where} ${who} dangerous command:\033[0m" >&2
    echo -e "\033[91m  ${cmd}\033[0m" >&2
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
EOF
)"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] cp -a \"${USER_BASHRC}\" \"${USER_BASHRC}.bak.${TS}\""
  echo "[DRY] write block into ${USER_BASHRC}"
else
  ensure_block_in_file "$USER_BASHRC" "$BEGIN_MARKER" "$END_MARKER" <<<"$USER_BLOCK_CONTENT"
fi
echo ""

# =========================
# 7) /root/.bashrc block
# =========================
echo "[7/7] /root/.bashrc"
ROOT_BASHRC="/root/.bashrc"

ROOT_BLOCK_CONTENT="$(cat <<'EOF'
# ---- Root prompt: make it obvious ----
if [[ $- == *i* ]]; then
  PS1="\[\033[91m\][ROOT]\[\033[0m\] ${PS1}"
fi
EOF
)"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] sudo test -f /root/.bashrc || sudo touch /root/.bashrc"
  echo "[DRY] sudo remove old managed block (if exists) from /root/.bashrc"
  echo "[DRY] sudo append new managed block to /root/.bashrc"
else
  # Ensure file exists
  sudo test -f /root/.bashrc || sudo touch /root/.bashrc

  # Remove old managed block (safe if not present)
  sudo sed -i \
    -e "\|^${BEGIN_MARKER}$|,\|^${END_MARKER}$|d" \
    /root/.bashrc

  # Append new managed block (write as root)
  sudo bash -lc "cat >> /root/.bashrc" <<__POSTINSTALL_ROOT_EOF__
${BEGIN_MARKER}
${ROOT_BLOCK_CONTENT}
${END_MARKER}
__POSTINSTALL_ROOT_EOF__
fi

echo ""
