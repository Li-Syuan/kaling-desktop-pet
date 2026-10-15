# v1.2.0 驗證紀錄

執行環境：Windows PowerShell 5.1、WPF、Windows 原生視窗 API。測試資料存於獨立資料夾，未讀寫正式個人設定。

## 通過

- 32 項狀態測試：原本 29 項計時、保存、恢復與點擊測試，加上服裝保存、不存在服裝回退，以及 v1.1 設定遷移。
- 108 項介面與原生整合檢查：三套共 297 格載入、每套新增動作、衣櫃按鈕及保存、拖曳懸空、睡醒、探頭位置安全返回、Dispatcher 自動坐下／入睡、睡姿末格停留、衣櫃與安靜模式抑制自動睡覺，以及原本的餵食、計時、選單、快捷鍵註冊、訊息派送、系統匣恢復與全螢幕判斷。
- 檢視 WPF 渲染的衣櫃、餵食、專注與完成提示畫面；衣櫃截圖包含整個視窗，避免內容 Margin 造成截圖邊界裁切。
- 三張透明 PNG：每張 1536×4368，單格 192×208。逐格檢查非空、邊界留白、未使用格透明，以及動畫畫格差異。制服 113 格，睡衣與貓耳裝各 92 格。
- 檢視三套服裝動作接觸表；修正貓耳裝一格檢查動作與兩格側身的異色瞳方向。PNG 取完整連通角色而非硬切生成網格，避免裁掉超出生成格線的髮梢。
- 離線圖鑑模擬 DOM 檢查：三套各十九動作、睡姿末格、四個主要視線方向、暫停、背景與縮放。
- 程式碼通過 PowerShell 語法檢查；根目錄原始 73 格圖集保持既有 SHA-256，新增圖集摘要列於 `asset-validation.json`。

機器可讀的結果：`state-tests.json`、`integration-tests.json`、`asset-validation.json`、`preview-code-test.json`。整合測試從下載包解壓後透過 `Start.bat --self-test` 再次驗收；測試輸出不含正式個人設定。

## 未驗證與環境限制

- Windows 拒絕測試視窗取得前景，因此未端到端驗證「使用者真的切入／離開全螢幕」；已驗證真實視窗的全螢幕判斷及顯示控制。
- OS 命中測試無法確認游標位置為測試視窗，為避免對其他程式送出點擊，跳過實體按鍵輸入與跨程式點擊傳遞；已驗證快捷鍵註冊、訊息派送、穿透旗標和系統匣恢復。
- 未實際拔插不同 DPI 的螢幕或強制電腦睡眠；已測試負座標螢幕、越界位置、睡眠時間落差和重開恢復邏輯。
- 離線 HTML 圖鑑使用模擬 DOM 檢查，未新增真實瀏覽器視覺測試。

## Windows API 依據

透明分層視窗使用 `WS_EX_TRANSPARENT` 傳遞滑鼠事件，見 [Microsoft 視窗功能](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features)。全域快捷鍵使用 [RegisterHotKey](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey)，並透過 `WM_HOTKEY` 處理；衝突時保留系統匣操作。
