#!/usr/bin/env bash
set -Eeuo pipefail

# 先更新鍵盤韌體到最新再跑QMK腳本，最後再跑.json 檔
# 修改 Keychron K3 MAx 鍵盤的燈光邏輯，不論燈光模式如何，Enter鍵永遠是擴散波紋。當按下FN+CAPSLOCK=大寫字母時，燈光全開，亮度中亮。
# 修改 Caps 為 Esc；將 Fn + Caps 設為 Caps Lock

# =========================================
# Keychron K3 Max ANSI White
# 官方 1.1.0 後重套 QMK 客製腳本
#
# 功能：
# 1. 更新 repo / branch
# 2. 同步 submodule
# 3. 從官方 via keymap 生成 bengju_a
# 4. 套用：
#    - Caps -> Esc
#    - Fn + Caps -> Caps Lock
#    - Caps Lock 開啟時全鍵盤中亮
#    - 按 Enter 時出現擴散波紋
# 5. 編譯
# 6. 提示你手動進 DFU
# 7. 用成功驗證過的 dfu-util 指令刷入
#
# 預設：--dry-run
# 實際執行：--apply
# =========================================

QMK_HOME="${QMK_HOME:-$HOME/qmk_firmware}"
BRANCH_NAME="wireless_playground"
KEYBOARD="keychron/k3_max/ansi/white"
KEYMAP="bengju_a"
KEYMAP_DIR="$QMK_HOME/keyboards/keychron/k3_max/ansi/white/keymaps/$KEYMAP"
VIA_DIR="$QMK_HOME/keyboards/keychron/k3_max/ansi/white/keymaps/via"
KEYMAP_FILE="$KEYMAP_DIR/keymap.c"
BIN_FILE="$QMK_HOME/keychron_k3_max_ansi_white_${KEYMAP}.bin"

DO_APPLY=0

msg()  { printf '\n== %s ==\n' "$*"; }
ok()   { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

run() {
  if [[ "$DO_APPLY" -eq 1 ]]; then
    printf '>>> %s\n' "$*"
    eval "$@"
  else
    printf '[dry-run] %s\n' "$*"
  fi
}

usage() {
  cat <<'EOF'
用法：
  ./update_k3max_qmk_after_official_110_wave.sh --dry-run
  ./update_k3max_qmk_after_official_110_wave.sh --apply

說明：
  這支腳本不會替你刷官方 1.1.0。
  正確流程是：

  1. 先到 Keychron Launcher / 官方頁面把 K3 Max ANSI White 更新到 1.1.0
  2. 再執行本腳本，重套你的 QMK 客製功能

本腳本會做：
  - 更新 wireless_playground
  - 同步 submodule
  - 從 via keymap 生成 bengju_a
  - 套用 Caps/Esc、Fn+Caps、Caps Lock 中亮、Enter 波紋
  - 編譯
  - 提示你進 DFU
  - 用 dfu-util 刷入
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

case "$1" in
  --apply)   DO_APPLY=1 ;;
  --dry-run) DO_APPLY=0 ;;
  *) usage; exit 1 ;;
esac

[[ -d "$QMK_HOME/.git" ]] || die "找不到 QMK repo：$QMK_HOME"

command -v git >/dev/null 2>&1 || die "缺少 git"
command -v qmk >/dev/null 2>&1 || die "缺少 qmk"
command -v dfu-util >/dev/null 2>&1 || die "缺少 dfu-util"
[[ -d "$VIA_DIR" ]] || die "找不到 via keymap 目錄：$VIA_DIR"

msg "重要提醒"
cat <<'EOF'
請先完成這件事：
  1. 到 Keychron Launcher / 官方頁面
  2. 把 K3 Max ANSI White 更新到 1.1.0
  3. 完成後再回來跑這支腳本

這支腳本之後會：
  - 重新生成 bengju_a
  - 重新編譯
  - 重新刷入你的客製功能
EOF

if [[ "$DO_APPLY" -eq 1 ]]; then
  read -r -p "如果你已經先刷完官方 1.1.0，按 Enter 繼續..."
else
  printf '[dry-run] 這裡會停住，等待你確認已刷官方 1.1.0\n'
fi

msg "目前設定"
printf 'QMK_HOME : %s\n' "$QMK_HOME"
printf 'BRANCH   : %s\n' "$BRANCH_NAME"
printf 'KEYBOARD : %s\n' "$KEYBOARD"
printf 'KEYMAP   : %s\n' "$KEYMAP"
printf 'BIN_FILE : %s\n' "$BIN_FILE"

msg "更新 repo 與 branch"
run "cd \"$QMK_HOME\" && git fetch origin"
run "cd \"$QMK_HOME\" && git switch \"$BRANCH_NAME\""
run "cd \"$QMK_HOME\" && git pull"

msg "同步 submodule"
run "cd \"$QMK_HOME\" && git submodule sync --recursive"
run "cd \"$QMK_HOME\" && git submodule update --init --recursive --checkout --force"
run "cd \"$QMK_HOME\" && make git-submodule"

msg "清理舊 build"
run "cd \"$QMK_HOME\" && qmk clean"
run "cd \"$QMK_HOME\" && rm -rf .build"

msg "建立自訂 keymap 目錄"
run "mkdir -p \"$KEYMAP_DIR\""
run "cp -r \"$VIA_DIR\"/* \"$KEYMAP_DIR\"/"

msg "寫入客製 keymap"
if [[ "$DO_APPLY" -eq 1 ]]; then
  cp "$KEYMAP_FILE" "$KEYMAP_FILE.bak.$(date +%F-%H%M%S)"

  python3 - "$KEYMAP_FILE" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()

# 1) Base layer: Caps -> Esc (MAC_BASE / WIN_BASE)
s = s.replace(
    "        KC_CAPS,  KC_A,",
    "        KC_ESC,   KC_A,",
    2
)

# 2) Fn layer same physical key: -> Caps Lock (MAC_FN / WIN_FN)
# 官方 via keymap 在對應位置通常是 BL_DOWN
s = s.replace(
    "        BL_DOWN,  _______,",
    "        KC_CAPS,  _______,",
    2
)

# 3) 移除舊的 process_record_user / matrix_scan_user / led_matrix_indicators_user
import re
s = re.sub(
    r"\nbool process_record_user\(uint16_t keycode, keyrecord_t \*record\)\s*\{.*?\n\}\n",
    "\n",
    s,
    flags=re.S
)
s = re.sub(
    r"\nvoid matrix_scan_user\(void\)\s*\{.*?\n\}\n",
    "\n",
    s,
    flags=re.S
)
s = re.sub(
    r"\nbool led_matrix_indicators_user\(void\)\s*\{.*?\n\}\n",
    "\n",
    s,
    flags=re.S
)

# 4) 追加新的 QMK 邏輯
append = r'''
static bool enter_wave_active = false;
static uint16_t enter_wave_timer = 0;

#define ENTER_WAVE_DURATION 350
#define ENTER_WAVE_WIDTH    18
#define ENTER_WAVE_CENTER_X 188
#define ENTER_WAVE_CENTER_Y 40
#define CAPS_LOCK_BASE_BRIGHTNESS 160

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    if (!process_record_keychron_common(keycode, record)) {
        return false;
    }

    if (keycode == KC_ENT && record->event.pressed) {
        enter_wave_active = true;
        enter_wave_timer = timer_read();
    }

    return true;
}

bool led_matrix_indicators_user(void) {
    if (host_keyboard_led_state().caps_lock) {
        led_matrix_set_value_all(CAPS_LOCK_BASE_BRIGHTNESS);
    }

    if (enter_wave_active) {
        uint16_t elapsed = timer_elapsed(enter_wave_timer);

        if (elapsed >= ENTER_WAVE_DURATION) {
            enter_wave_active = false;
            return true;
        }

        uint8_t radius = (elapsed * 224) / ENTER_WAVE_DURATION;

        for (uint8_t i = 0; i < LED_MATRIX_LED_COUNT; i++) {
            int16_t dx = (int16_t)g_led_config.point[i].x - ENTER_WAVE_CENTER_X;
            int16_t dy = (int16_t)g_led_config.point[i].y - ENTER_WAVE_CENTER_Y;

            uint16_t dist = (dx < 0 ? -dx : dx) + (dy < 0 ? -dy : dy);

            if (dist >= (radius > ENTER_WAVE_WIDTH ? radius - ENTER_WAVE_WIDTH : 0) &&
                dist <= (radius + ENTER_WAVE_WIDTH)) {
                led_matrix_set_value(i, 255);
            }
        }
    }

    return true;
}
'''
s = s.rstrip() + "\n\n" + append.lstrip()

p.write_text(s)
PY

  ok "已寫入 $KEYMAP_FILE"
else
  printf '[dry-run] 會修改 %s\n' "$KEYMAP_FILE"
fi

msg "檢查關鍵內容"
run "grep -n 'KC_ESC,   KC_A\\|KC_CAPS,  _______,\\|ENTER_WAVE_\\|CAPS_LOCK_BASE_BRIGHTNESS\\|process_record_user\\|led_matrix_indicators_user' \"$KEYMAP_FILE\""

msg "編譯自訂 keymap"
run "cd \"$QMK_HOME\" && qmk compile -kb \"$KEYBOARD\" -km \"$KEYMAP\""

msg "確認編譯產物"
if [[ "$DO_APPLY" -eq 1 ]]; then
  [[ -f "$BIN_FILE" ]] || die "找不到編譯完成的 .bin：$BIN_FILE"
  ls -lh "$BIN_FILE"
else
  printf '[dry-run] 會檢查檔案是否存在：%s\n' "$BIN_FILE"
fi

msg "接下來要手動進 DFU 模式"
cat <<'EOF'
請照這個成功流程操作：

1. 拔掉 USB
2. 按住 Esc
3. 插回 USB
4. 持續按住 3 秒
5. 放開

可先確認：
  lsusb | grep -i '0483:df11'

若有看到 0483:df11，再按 Enter 繼續刷入。
EOF

if [[ "$DO_APPLY" -eq 1 ]]; then
  read -r -p "確認已進入 DFU 後，按 Enter 繼續..."
else
  printf '[dry-run] 這裡會停下來等待你進 DFU\n'
fi

msg "刷入 firmware（成功驗證版指令）"
run "sudo dfu-util -a 0 -d 0483:df11 -s 0x08000000:leave -D \"$BIN_FILE\""

msg "完成"
cat <<'EOF'
若終端機看到：

  Download done.
  File downloaded successfully
  Transitioning to dfuMANIFEST state

就代表刷入成功。

刷完後建議：
1. 拔掉 USB
2. 等 3 秒
3. 再插回去

最後驗收：
- Caps -> Esc
- Fn + Caps -> Caps Lock
- Caps Lock 開啟時 -> 全鍵盤中亮
- 按 Enter -> 波紋向外擴散
EOF
