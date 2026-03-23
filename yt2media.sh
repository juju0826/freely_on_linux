#!/usr/bin/env bash

# yt2media.sh
# 用途：
# - 互動式下載 YouTube 為 MP3 或 MP4
# - 固定使用目前這次驗證成功的方式：
#   youtube:player_client=android_vr,android
# - 不使用 cookie fallback
# - 輸出固定到 ~/Music
# - 適合長期保留與維護

set -Eeuo pipefail

# 顯示一般訊息。
msg()  { printf '%s\n' "$*"; }

# 顯示成功訊息。
ok()   { printf '✅ %s\n' "$*"; }

# 顯示警告訊息。
warn() { printf '⚠️  %s\n' "$*"; }

# 顯示錯誤訊息到 stderr。
err()  { printf '❌ %s\n' "$*" >&2; }

# 依序尋找可用的 yt-dlp 執行檔。
YTDLP=""
for c in \
  "$HOME/.local/bin/yt-dlp" \
  "$HOME/.local/pipx/venvs/yt-dlp/bin/yt-dlp" \
  "$(command -v yt-dlp 2>/dev/null || true)"; do
  [[ -n "${c:-}" && -x "$c" ]] && { YTDLP="$c"; break; }
done

# 若找不到 yt-dlp，直接停止。
if [[ -z "$YTDLP" ]]; then
  err "找不到 yt-dlp。"
  msg "可先安裝官方單檔版："
  msg 'mkdir -p ~/.local/bin'
  msg 'wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O ~/.local/bin/yt-dlp'
  msg 'chmod +x ~/.local/bin/yt-dlp'
  exit 1
fi

# 檢查 ffmpeg 是否存在，因為 MP3 抽音與 MP4 合併都需要它。
if ! command -v ffmpeg >/dev/null 2>&1; then
  err "找不到 ffmpeg。"
  msg "Debian / Ubuntu / Mint 可執行： sudo apt install ffmpeg"
  exit 1
fi

# 顯示版本資訊，方便日後除錯。
msg "yt-dlp: $("$YTDLP" --version 2>/dev/null || echo unknown)"
msg "ffmpeg: $(ffmpeg -version 2>/dev/null | head -n1 || echo unknown)"

# 自動偵測可用的 JavaScript runtime。
JS_RUNTIME=""
if command -v deno >/dev/null 2>&1; then
  JS_RUNTIME="deno"
elif command -v node >/dev/null 2>&1; then
  JS_RUNTIME="node"
elif command -v bun >/dev/null 2>&1; then
  JS_RUNTIME="bun"
fi

# 若有偵測到，就加入 yt-dlp 參數；沒有也可繼續執行。
JS_OPTS=()
if [[ -n "$JS_RUNTIME" ]]; then
  ok "偵測到 JS runtime：$JS_RUNTIME"
  JS_OPTS=( --js-runtimes "$JS_RUNTIME" )
else
  warn "未偵測到 deno / node / bun。某些影片成功率可能下降。"
fi

# 讀入使用者輸入的 YouTube 網址。
read -rp "請輸入 YouTube 影片連結: " RAW_URL

# 去除可能混入的換行字元。
RAW_URL="${RAW_URL//[$'\r\n']}"

# 若沒有輸入網址，直接停止。
if [[ -z "$RAW_URL" ]]; then
  err "你沒有輸入連結。"
  exit 1
fi

# 讓使用者選擇下載 MP3 或 MP4。
msg "請選擇下載格式："
select FORMAT in "MP3 (音訊)" "MP4 (影片)"; do
  case "$REPLY" in
    1) MEDIA_TYPE="mp3"; break ;;
    2) MEDIA_TYPE="mp4"; break ;;
    *) warn "請輸入 1 或 2" ;;
  esac
done

# 固定輸出目錄為 ~/Music。
OUTPUT_DIR="$HOME/Music"

# 若目錄不存在就建立。
mkdir -p "$OUTPUT_DIR"

# 設定輸出檔名樣板。
OUT_TMPL="${OUTPUT_DIR}/%(title).80s_%(id)s.%(ext)s"

# 將各種 YouTube 網址正規化成 watch?v=ID 格式。
normalize_url() {
  python3 - "$1" <<'PY'
import sys, re, urllib.parse as u

s = sys.argv[1].strip().strip('"').strip("'")

def to_watch(video_id):
    return f"https://www.youtube.com/watch?v={video_id}"

m = re.fullmatch(r'[A-Za-z0-9_-]{11}', s)
if m:
    print(to_watch(s))
    raise SystemExit

p = u.urlparse(s)
q = u.parse_qs(p.query)

if 'v' in q and q['v']:
    vid = q['v'][0]
    if re.fullmatch(r'[A-Za-z0-9_-]{11}', vid):
        print(to_watch(vid))
        raise SystemExit

m = re.search(r'([A-Za-z0-9_-]{11})', s)
if m:
    print(to_watch(m.group(1)))
else:
    print(s)
PY
}

# 取得正規化後的網址。
CLEAN_URL="$(normalize_url "$RAW_URL")"

# 顯示這次實際要抓的目標網址。
msg "目標網址：$CLEAN_URL"

# 建立暫存 log 檔，失敗時可供除錯。
LOGFILE="$(mktemp -t ytdlp_XXXX.log)"

# 設定共用 yt-dlp 參數。
COMMON_OPTIONS=(
  --ignore-config
  --no-playlist
  --no-update
  --restrict-filenames
  --continue
  --retries infinite
  --fragment-retries infinite
  --concurrent-fragments 1
  --http-chunk-size 1M
  --force-ipv4
  --user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36"
  --extractor-args "youtube:player_js_version=actual;player_client=android_vr,android"
  "${JS_OPTS[@]}"
)

# 顯示本次固定使用的下載模式。
msg
msg "=============================="
msg "開始下載：模式 = android_vr,android / nocookie"
msg "=============================="

# 依照使用者選擇，執行 MP3 或 MP4 下載。
if [[ "$MEDIA_TYPE" == "mp3" ]]; then

  # MP3：優先抓 m4a 音訊，再轉成 mp3。
  set +e
  "$YTDLP" \
    "${COMMON_OPTIONS[@]}" \
    -o "$OUT_TMPL" \
    -f "ba[ext=m4a]/ba/bestaudio/best" \
    -x --audio-format mp3 --audio-quality 0 \
    --embed-metadata \
    --embed-thumbnail \
    "$CLEAN_URL" 2>&1 | tee -a "$LOGFILE"
  STATUS=${PIPESTATUS[0]}
  set -e

else

  # MP4：優先抓 mp4 視訊 + m4a 音訊，再合併成 mp4。
  set +e
  "$YTDLP" \
    "${COMMON_OPTIONS[@]}" \
    -o "$OUT_TMPL" \
    -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b/best" \
    --merge-output-format mp4 \
    --embed-metadata \
    "$CLEAN_URL" 2>&1 | tee -a "$LOGFILE"
  STATUS=${PIPESTATUS[0]}
  set -e

fi

# 若下載失敗，就提示 log 位置。
if [[ "${STATUS:-1}" -ne 0 ]]; then
  err "下載失敗。"
  msg "日誌位置：$LOGFILE"
  exit 1
fi

# 若成功，就顯示完成訊息。
ok "下載完成！已儲存至 ~/Music"
