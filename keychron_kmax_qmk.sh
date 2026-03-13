#!/usr/bin/env bash
set -Eeuo pipefail

QMK_HOME="${HOME}/qmk_firmware"
KEYMAP="bengju_a"
BRANCH="wireless_playground"

echo
echo "=== Keychron K Max 燈光工具 (最終版) ==="
echo

DEVICE="$(lsusb | grep -i keychron || true)"

if [[ -z "$DEVICE" ]]; then
  echo "找不到 Keychron 鍵盤"
  exit 1
fi

echo "偵測到："
echo "$DEVICE"
echo

MODEL="k2_max"

if echo "$DEVICE" | grep -qi "k3"; then MODEL="k3_max"; fi
if echo "$DEVICE" | grep -qi "k5"; then MODEL="k5_max"; fi
if echo "$DEVICE" | grep -qi "k7"; then MODEL="k7_max"; fi
if echo "$DEVICE" | grep -qi "k8"; then MODEL="k8_max"; fi
if echo "$DEVICE" | grep -qi "k10"; then MODEL="k10_max"; fi

echo "鍵盤型號: $MODEL"
echo

echo "選擇燈光類型"
echo "1 RGB"
echo "2 白光"

read -p "選擇 [1]: " TYPE
TYPE=${TYPE:-1}

if [[ "$TYPE" == "1" ]]; then
  MATRIX="rgb"
  KEYBOARD="keychron/${MODEL}/ansi/rgb"
else
  MATRIX="white"
  KEYBOARD="keychron/${MODEL}/ansi/white"
fi

KEYMAP_DIR="${QMK_HOME}/keyboards/${KEYBOARD}/keymaps/${KEYMAP}"
VIA_DIR="${QMK_HOME}/keyboards/${KEYBOARD}/keymaps/via"

echo
echo "KEYBOARD = $KEYBOARD"
echo

rm -rf "$KEYMAP_DIR"
mkdir -p "$KEYMAP_DIR"

cp -r "$VIA_DIR"/* "$KEYMAP_DIR"

EFFECTS="${KEYMAP_DIR}/bengju_effects.c"

echo "生成燈效程式..."

if [[ "$TYPE" == "1" ]]; then

cat > "$EFFECTS" << 'EOF'
#include QMK_KEYBOARD_H

bool enter_wave_active=false;
bool esc_wave_active=false;

uint16_t enter_wave_timer=0;
uint16_t esc_wave_timer=0;

uint8_t enter_led_index=NO_LED;
uint8_t esc_led_index=NO_LED;

#define CAPS_BRIGHT 160
#define WAVE_DURATION 450

bool rgb_matrix_indicators_user(void){

    if(host_keyboard_led_state().caps_lock){
        rgb_matrix_set_color_all(CAPS_BRIGHT,CAPS_BRIGHT,CAPS_BRIGHT);
    }

    if(enter_wave_active){

        uint16_t t=timer_elapsed(enter_wave_timer);

        if(t>WAVE_DURATION){
            enter_wave_active=false;
        }else{

            uint8_t r=t/2;

            int cx=g_led_config.point[enter_led_index].x;
            int cy=g_led_config.point[enter_led_index].y;

            for(uint8_t i=0;i<RGB_MATRIX_LED_COUNT;i++){

                int dx=g_led_config.point[i].x-cx;
                int dy=g_led_config.point[i].y-cy;

                uint16_t d=abs(dx)+abs(dy);

                if(d<r && d>(r>12?r-12:0)){
                    rgb_matrix_set_color(i,120,255,120);
                }
            }
        }
    }

    if(esc_wave_active){

        uint16_t t=timer_elapsed(esc_wave_timer);

        if(t>WAVE_DURATION){
            esc_wave_active=false;
        }else{

            uint8_t r=t/2;

            int cx=g_led_config.point[esc_led_index].x;
            int cy=g_led_config.point[esc_led_index].y;

            for(uint8_t i=0;i<RGB_MATRIX_LED_COUNT;i++){

                int dx=g_led_config.point[i].x-cx;
                int dy=g_led_config.point[i].y-cy;

                uint16_t d=abs(dx)+abs(dy);

                if(d<r && d>(r>12?r-12:0)){
                    rgb_matrix_set_color(i,255,0,0);
                }
            }
        }
    }

    return true;
}
EOF

else

cat > "$EFFECTS" << 'EOF'
#include QMK_KEYBOARD_H

bool enter_wave_active=false;
bool esc_wave_active=false;

uint16_t enter_wave_timer=0;
uint16_t esc_wave_timer=0;

uint8_t enter_led_index=NO_LED;
uint8_t esc_led_index=NO_LED;

#define CAPS_BRIGHT 160
#define WAVE_DURATION 450

bool led_matrix_indicators_user(void){

    if(host_keyboard_led_state().caps_lock){
        led_matrix_set_value_all(CAPS_BRIGHT);
    }

    if(enter_wave_active){

        uint16_t t=timer_elapsed(enter_wave_timer);

        if(t>WAVE_DURATION){
            enter_wave_active=false;
        }else{

            uint8_t r=t/2;

            int cx=g_led_config.point[enter_led_index].x;
            int cy=g_led_config.point[enter_led_index].y;

            for(uint8_t i=0;i<LED_MATRIX_LED_COUNT;i++){

                int dx=g_led_config.point[i].x-cx;
                int dy=g_led_config.point[i].y-cy;

                uint16_t d=abs(dx)+abs(dy);

                if(d<r && d>(r>12?r-12:0)){
                    led_matrix_set_value(i,255);
                }
            }
        }
    }

    if(esc_wave_active){

        uint16_t t=timer_elapsed(esc_wave_timer);

        if(t>WAVE_DURATION){
            esc_wave_active=false;
        }else{

            uint8_t r=t/2;

            int cx=g_led_config.point[esc_led_index].x;
            int cy=g_led_config.point[esc_led_index].y;

            for(uint8_t i=0;i<LED_MATRIX_LED_COUNT;i++){

                int dx=g_led_config.point[i].x-cx;
                int dy=g_led_config.point[i].y-cy;

                uint16_t d=abs(dx)+abs(dy);

                if(d<r && d>(r>12?r-12:0)){
                    led_matrix_set_value(i,255);
                }
            }
        }
    }

    return true;
}
EOF

fi

KEYMAP_FILE="${KEYMAP_DIR}/keymap.c"

sed -i '/process_record_user/,$d' "$KEYMAP_FILE"

cat >> "$KEYMAP_FILE" << 'EOF'

#include "bengju_effects.c"

bool process_record_user(uint16_t keycode,keyrecord_t *record){

    if(record->event.pressed){

        if(keycode==KC_ENT){
            enter_wave_active=true;
            enter_wave_timer=timer_read();
            enter_led_index=g_led_config.matrix_co[record->event.key.row][record->event.key.col];
        }

        if(keycode==KC_ESC){
            esc_wave_active=true;
            esc_wave_timer=timer_read();
            esc_led_index=g_led_config.matrix_co[record->event.key.row][record->event.key.col];
        }

    }

    return true;
}
EOF

cd "$QMK_HOME"

qmk clean

qmk compile -kb "$KEYBOARD" -km "$KEYMAP"

echo
echo "編譯完成"
echo

echo "進入 DFU"
echo "ESC + 插USB"

read -p "按 Enter 繼續"

BIN=$(ls ${QMK_HOME}/*.bin | tail -1)

sudo dfu-util -a 0 -d 0483:df11 -s 0x08000000:leave -D "$BIN"

echo
echo "完成"
