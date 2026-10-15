# v1.3.0-ren.1 驗收紀錄

2026-10-15，Windows PowerShell 5.1 / WPF。

## 已完成

- 37 項狀態檢查：v1 → v2 遷移、角色及各自衣裝、座標、番茄鐘、無效資料與備份。見 `ren-state-tests.json`。
- 190 項 WPF／原生整合檢查：保留咖凌三套衣裝、蓮 24 列動作與文案、衣櫃隔離、三招時間軸、自然結束、拖曳／摸頭／換角／換裝／縮放／隱藏／安靜／專注中斷、左右邊界、突進時存檔及出招中關閉。見 `ren-integration.json`。
- 特效視窗驗證 NOACTIVATE、TRANSPARENT、隱藏工作列與 WPF hit testing 停用；原生全螢幕幾何判斷及訊息派送通過。
- 蓮 104 格角色素材與 12 格效果；透明邊界、未使用格與不同動作內容檢查。逐格檢視後替換半身／裁切素材，保留生成提示詞。
- 直接渲染實際 WPF 角色與特效層並檢視 `ren-dragon-wpf.png`。這是 WPF RenderTargetBitmap，非整個桌面的螢幕錄影。
- Playwright / Chrome：兩角色、四衣裝、三招按鈕、暫停後 canvas 不變、背景切換與無 JavaScript page errors。瀏覽器工具禁止 file URL，因此透過僅綁定 127.0.0.1 的伺服器載入相同靜態檔案。
- ZIP 完整解壓後由 `Start.bat --self-test` 執行同一組整合驗收；發布前另記錄套件雜湊與啟動結果。

## 限制與未通過項目

- 曾嘗試實體滑鼠穿透驗收：原生穿透樣式可設定、快捷鍵可到達，但 `WindowFromPoint` 未回傳預期的另一個測試程序，因此「實體跨程序點擊穿透」未通過。未對非測試視窗發送點擊；沒有將該項算入成功檢查。
- 完整實體輸入測試改為明確使用 `-PhysicalInputTest` 才執行；預設自我測試不移動使用者滑鼠。原有穿透實作沒有因測試限制而改寫。
- Windows 前景啟用結果受環境影響，部分執行無法端到端驗證真正的前景全螢幕輪詢；模擬隱藏訊號、視窗幾何與效果取消已驗證。
- 混合 DPI 實體多螢幕切換與電腦實際睡眠／喚醒未強制測試；時間跳躍暫停邏輯有測試。
- 本次不含生活小屋；保留獨立的活動取消入口，供後續整合。

## 重跑

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\State.Tests.ps1
Start.bat --self-test
# 在可控桌面環境才啟用實體輸入測試：
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File pet.ps1 -SelfTest -PhysicalInputTest
```

設定升級至 v2。回退舊版前請先備份 `%LOCALAPPDATA%\KalingPet`；v1.2 不支援 v2 設定格式。
