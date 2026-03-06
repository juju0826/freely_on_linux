# freely_on_linux 
在Linux裡自由自在

Running free software on Linux in a way that is stable, predictable, and sustainable.

在 Linux 上，將自由軟體組裝成一個可以長期、安心運作的系統。

---
## 這個 repository 在做什麼？
記錄一條實際走過、並已在作業系統中長期運作的路線。
## 核心觀念：把事情放在對的層級處理
這個 repo 實踐各司其職。系統的穩定性，通常來自於角色分工是否清楚，不只是單一元件的效能或參數調整。

# .sh 腳本
## postinstall.sh
灌好Linux後要先做的幾件事：
✅ 把使用者名稱加入sudoers群組 ✅ 安裝fcitx4架構的倉頡輸入法, 安裝文字編輯器vim, 安裝瀏覽器 brave
## .vimrc.sh
✅ 優化文字處理器vim。腳本名稱前要加個點.變成隱藏檔，放在家目錄底下
## .bashrc.sh
✅ 優化終端機的bash視覺效果。腳本名稱前要加個點.變成隱藏檔，放在家目錄底下
## nextcloud_diag.sh
✅ 檢查Nextcloud系統健康狀態之簡易診斷腳本 ✅ 檢查 Nextcloud 狀態, Background jobs, Redis, php-fpm, CPU, Memory, Disk, IO, nginx
## collabora_watch.sh
✅ Collabora 壓力監控腳本 ✅ 腳本會每 2 秒更新一次，顯示以下資訊： CPU 使用率, Load Average, 記憶體使用, 磁碟 IO, 網路流量, Collabora CPU / RAM, php-fpm, worker 數, Redis clients, Collabora websocket session 數
## update_k3max_qmk.sh
🛠️ 先更新 Keychron K3 MAx 鍵盤韌體到最新再跑此 QMK 腳本，最後再跑 Keymap-K3 Max White-6-18-12.json 檔 ✅ 修改 K3 MAX 鍵盤的燈光邏輯，不論燈光模式如何，Enter鍵永遠是擴散波紋。當按下FN+CAPSLOCK=大寫字母時，燈光全開，亮度中亮。
## Keymap-K3 Max White-6-18-12.json
✅ 修改 Caps鍵 為 Esc鍵；將 Fn鍵 + Caps鍵 設為 Caps Lock 大寫字母
