# freely_on_linux 
在Linux裡自由自在
Running free software on Linux in a way that is stable, predictable, and sustainable.
在 Linux 上，將自由軟體組裝成一個可以長期、安心運作的系統。
---
## 這個 repository 在做什麼？
這個 repository 記錄的是一條實際走過、並已在作業系統中長期運作的路線。
## 核心觀念：把事情放在對的層級處理
這個 repo 反覆驗證的一個原則是：各司其職。
系統的穩定性，通常來自於角色分工是否清楚，而不是單一元件的效能或參數調整。
## 記錄方式
這個 repo 採取漸進式的記錄方式，腳本的每個指令都有說明。
每一個被整理出來的經驗，都來自經過一段時間的驗證與實際運作。
# .sh 腳本
## postinstall.sh
灌好Linux後要先做的幾件事：
✅ 把使用者名稱加入sudoers群組
✅ 安裝fcitx4架構的倉頡輸入法
✅ 安裝文字編輯器vim並優化vim和終端機的功能及視覺效果
✅ 安裝瀏覽器 brave
