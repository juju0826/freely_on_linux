#!/usr/bin/env bash
set -euo pipefail

# ===== 基本設定 =====
REMOTE_NAME="r2"                                # rclone 遠端名稱
BUCKET_NAME="media"                             # R2 bucket 名稱
CUSTOM_DOMAIN="https://XXXXXXX"                 # 填入自訂網域
CACHE_CONTROL_DEFAULT="public, max-age=31536000, immutable"
LAST_CATEGORY_FILE="$HOME/.upload_to_r2_last_category"

# ===== 顏色 =====
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){ echo -e "${RED}[ERR]${NC} $*"; }

# ===== 需求檢查 =====
command -v rclone >/dev/null || { err "請先安裝 rclone：sudo apt install -y rclone"; exit 1; }
command -v ffmpeg >/dev/null || warn "未安裝 ffmpeg，將無法壓縮音檔。"
command -v python3 >/dev/null || { err "缺少 python3（用於 URL 編碼）"; exit 1; }

# ===== 剪貼簿 =====
copy_to_clipboard() {
  local text="$1"
  if [[ "${XDG_SESSION_TYPE:-}" == "x11" || -n "${DISPLAY:-}" ]]; then
    command -v xclip >/dev/null 2>&1 && printf '%s' "$text" | xclip -selection clipboard && ok "已複製到剪貼簿（X11）" && return
  fi
  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    command -v wl-copy >/dev/null 2>&1 && printf '%s' "$text" | wl-copy && ok "已複製到剪貼簿（Wayland）" && return
  fi
  warn "無法自動複製到剪貼簿。"
}

# ===== URL 編碼 =====
urlencode() {
  local input="$1"
  python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$input"
}

# ===== 工具 =====
human_size() { awk -v b="$1" 'function p(x){s="B KB MB GB TB";split(s,a," ");i=1;while(x>=1024&&i<5){x/=1024;i++}printf("%.1f %s",x,a[i])}BEGIN{p(b)}'; }
filesize() { stat -c%s "$1"; }

normalize_path() {
  local p="$1"
  [[ "$p" == \"*\" ]] && p="${p#\"}" && p="${p%\"}"
  [[ "$p" == \'*\' ]] && p="${p#\'}" && p="${p%\'}"
  if [[ "$p" == ~* ]]; then eval "p=$p"; fi
  echo "$p"
}

guess_mime() {
  local ext="${1##*.}"; ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  case "$ext" in
    mp3) echo "audio/mpeg" ;;
    wav) echo "audio/wav" ;;
    m4a|aac) echo "audio/mp4" ;;
    flac) echo "audio/flac" ;;
    ogg|oga) echo "audio/ogg" ;;
    opus) echo "audio/opus" ;;
    mp4) echo "video/mp4" ;;
    webm) echo "video/webm" ;;
    jpg|jpeg) echo "image/jpeg" ;;
    png) echo "image/png" ;;
    webp) echo "image/webp" ;;
    pdf) echo "application/pdf" ;;
    *) echo "application/octet-stream" ;;
  esac
}

check_bucket() {
  if ! rclone lsd "${REMOTE_NAME}:${BUCKET_NAME}" >/dev/null 2>&1; then
    err "找不到 bucket '${BUCKET_NAME}'。請在 Cloudflare R2 建立並開啟 Public Access。"
    exit 1
  fi
}

transcode_to_mp3_160k() {
  local input_path="$1" tmpdir="$2"
  local base="$(basename "${input_path%.*}")"
  local out="${tmpdir}/${base}-160k.mp3"
  ffmpeg -y -i "$input_path" -vn -c:a libmp3lame -b:a 160k -ar 44100 -ac 2 "$out" </dev/null >/dev/null 2>&1
  echo "$out"
}

pick_category() {
  local default_cat=""
  [[ -f "$LAST_CATEGORY_FILE" ]] && default_cat=$(<"$LAST_CATEGORY_FILE")
  echo
  echo "請選擇分類（將成為 bucket 下的子目錄）"
  [[ -n "$default_cat" ]] && echo -e "上次使用分類：${GREEN}${default_cat}${NC}"
  echo "1) audio  2) podcast  3) video  4) images  5) docs  6) custom"
  read -rp "輸入數字或直接 Enter 使用上次分類: " choice
  case "$choice" in
    1) DEST_PREFIX="audio" ;;
    2) DEST_PREFIX="podcast" ;;
    3) DEST_PREFIX="video" ;;
    4) DEST_PREFIX="images" ;;
    5) DEST_PREFIX="docs" ;;
    6) read -rp "輸入自訂頂層目錄（例如 worship 或 assets/audio）: " custom_dir
       DEST_PREFIX="${custom_dir%/}" ;;
    "") DEST_PREFIX="${default_cat:-audio}" ;;
    *) DEST_PREFIX="audio" ;;
  esac
  echo "$DEST_PREFIX" > "$LAST_CATEGORY_FILE"
}

# ===== 主程式 =====
check_bucket
CACHE_CONTROL="$CACHE_CONTROL_DEFAULT"

read -rp "是否 dry-run (Y/n): " yn
[[ "${yn,,}" == "n" ]] && DRY_RUN=0 || DRY_RUN=1

read -rp "Cache-Control（預設: ${CACHE_CONTROL_DEFAULT}）: " cc
[[ -n "$cc" ]] && CACHE_CONTROL="$cc"

COMPRESS=0
if command -v ffmpeg >/dev/null 2>&1; then
  read -rp "將非 MP3 音檔轉為 MP3 160 kbps 再上傳？(Y/n): " ync
  [[ -z "${ync}" || "${ync,,}" == "y" ]] && COMPRESS=1
fi

pick_category

FILES=()
while :; do
  echo
  echo "貼上或拖曳檔案到此（可多個；以空白分隔）："
  read -er -a FILES
  [[ ${#FILES[@]} -gt 0 ]] && break
  echo "⚠️ 沒有輸入任何檔案，請再試一次。"
done

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

URLS=()

for RAW in "${FILES[@]}"; do
  FILE="$(normalize_path "$RAW")"
  [[ ! -f "$FILE" ]] && { err "找不到檔案：$RAW"; continue; }

  SRC="$FILE"
  SRC_EXT="${SRC##*.}"; SRC_EXT="${SRC_EXT,,}"
  ORIG_SIZE=$(filesize "$SRC"); ORIG_HS=$(human_size "$ORIG_SIZE")

  NEED_TRANSCODE=0
  [[ "$SRC_EXT" != "mp3" ]] && NEED_TRANSCODE=1

  if [[ $COMPRESS -eq 1 && $NEED_TRANSCODE -eq 1 ]]; then
    OUT="$(transcode_to_mp3_160k "$SRC" "$TMPDIR")"
    MIME="audio/mpeg"
    BASENAME="$(basename "$OUT")"
    NEW_SIZE=$(filesize "$OUT"); NEW_HS=$(human_size "$NEW_SIZE")
    echo -e "轉檔完成：${ORIG_HS} → ${NEW_HS}"
  else
    OUT="$SRC"; MIME="$(guess_mime "$OUT")"; BASENAME="$(basename "$OUT")"
  fi

  DEST_KEY="${DEST_PREFIX}/${BASENAME}"

  echo
  echo "== 上傳資訊 =="
  echo "來源：$SRC"
  echo "目的：${REMOTE_NAME}:${BUCKET_NAME}/${DEST_KEY}"
  echo "模式：$([[ $DRY_RUN -eq 1 ]] && echo 'dry-run' || echo '實際上傳')"

  if [[ $DRY_RUN -eq 1 ]]; then
    warn "[dry-run] 將上傳：$BASENAME"
  else
    rclone mkdir "${REMOTE_NAME}:${BUCKET_NAME}/${DEST_PREFIX}" >/dev/null 2>&1 || true

rclone copyto \
  --progress \
  --header-upload "Cache-Control: public, max-age=31536000, immutable" \
  --header-upload "Content-Type: audio/mpeg" \
  "$OUT" "${REMOTE_NAME}:${BUCKET_NAME}/${DEST_KEY}"

    # 嘗試設定 metadata（Content-Type + Cache-Control）
    if ! rclone rcat "${REMOTE_NAME}:${BUCKET_NAME}/${DEST_KEY}" < /dev/null \
      --header-upload "Content-Type:${MIME}" \
      --header-upload "Cache-Control:${CACHE_CONTROL}" >/dev/null 2>&1; then
        warn "⚠️ 無法設定 metadata（可能 rclone 版本不支援）。"
    else
        ok "已設定 metadata：${MIME}, ${CACHE_CONTROL}"
    fi
  fi

  ENCBASENAME="$(urlencode "$BASENAME")"
  URLS+=("${CUSTOM_DOMAIN}/${DEST_PREFIX}/${ENCBASENAME}")
done

# ===== 總結 =====
if [[ ${#URLS[@]} -gt 0 ]]; then
  echo
  echo "====== 公開網址 ======"
  printf '%s\n' "${URLS[@]}"
  echo "======================"

  echo
  echo "====== Hugo Shortcodes ======"
  SHORTCODES=""
  for url in "${URLS[@]}"; do
    filename="$(basename "${url%%\?*}")"
    title="${filename%.*}"
    title="${title%-160k}"
    shortcode="{{< audio_cdn src=\"${url}\" title=\"${title}\" >}}"
    echo "$shortcode"
    SHORTCODES+="$shortcode"$'\n'
  done
  echo "=============================="

  copy_to_clipboard "$SHORTCODES" || true
  ok "所有 shortcode 已複製到剪貼簿，可直接貼入 Hugo 文章。"
fi

ok "全部完成。"

