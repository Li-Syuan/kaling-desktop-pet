# v1.1.0 驗證紀錄

執行環境：Windows PowerShell 5.1、WPF、Windows 原生視窗 API。測試資料存於獨立資料夾，未讀寫正式個人設定。

## 通過

- 29 項狀態測試：小數秒倒數、暫停、睡眠時間落差、四輪專注與長休息、手動開始下一階段、重開時暫停、偏好保存、安全替換與備份、損壞復原、輸入驗證、點擊分類、螢幕範圍限制與時段台詞。
- 57 項介面與原生整合檢查：73 格素材、九組動作及十六方向、摸頭與三種食物選單、互動冷卻、雙擊取消單擊、拖曳、番茄鐘選單及完成提示、時間設定驗證、縮放、原生快捷鍵註冊及 WM_HOTKEY 派送、滑鼠穿透視窗旗標、系統匣恢復、全螢幕視窗幾何判斷及隱藏恢復、實際 Dispatcher 倒數與小劇場抑制。
- 檢視 WPF 渲染的餵食、專注與完成提示畫面。
- 程式碼通過語法檢查；角色圖集維持 v1.0 已驗證的相同 SHA-256。

機器可讀的結果：`state-tests.json`、`integration-tests.json`。

## 未驗證與環境限制

- Windows 拒絕測試視窗取得前景，因此未端到端驗證「使用者真的切入／離開全螢幕」；已驗證真實視窗的全螢幕判斷及顯示控制。
- OS 命中測試無法確認游標位置為測試視窗，為避免對其他程式送出點擊，跳過實體按鍵輸入與跨程式點擊傳遞；已驗證快捷鍵註冊、訊息派送、穿透旗標和系統匣恢復。
- 未實際拔插不同 DPI 的螢幕或強制電腦睡眠；已測試負座標螢幕、越界位置、睡眠時間落差和重開恢復邏輯。
- 既有離線 HTML 圖鑑僅有模擬 DOM 檢查，未新增真實瀏覽器視覺測試。

## Windows API 依據

透明分層視窗使用 `WS_EX_TRANSPARENT` 傳遞滑鼠事件，見 [Microsoft 視窗功能](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features)。全域快捷鍵使用 [RegisterHotKey](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey)，並透過 `WM_HOTKEY` 處理；衝突時保留系統匣操作。
