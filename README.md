# 咖凌 · Kaling Desktop Pet

紅髮異色瞳的 Windows 桌面夥伴。透明背景、拖曳移動、點擊揮手、跳躍、散步與滑鼠視線追蹤。

![咖凌動作預覽](animations/all-states.gif)

## 下載與啟動

1. 從 Releases 下載 `KalingPet-Windows.zip`，選擇「全部解壓縮」。也可以用 GitHub 的 Code → Download ZIP。
2. 雙擊 `Start.vbs`。若系統不支援 VBScript，請使用 `Start.bat`。
3. 咖凌會出現在桌面右下角；右鍵選單可設定動作、模式、大小或關閉。

Windows 10 / 11，使用系統內建 Windows PowerShell 5.1 與 WPF，不需 Python、Node.js 或安裝程式。啟動器只為當次程序指定 ExecutionPolicy Bypass，不修改永久執行原則。不連網、不讀取個人文件、不加入開機啟動。

## 操作

| 操作 | 功能 |
| --- | --- |
| 左鍵拖曳 | 移動位置 |
| 點一下 | 揮手 |
| 點兩下 | 跳躍 |
| 右鍵 | 動作、留在原地、自由散步、跟著滑鼠、視線追蹤、尺寸與關閉 |
| 開啟 `preview.html` | 離線查看九組動作和十六個視線方向 |

預設留在原地。重複啟動不會產生第二隻。出錯時可查看同資料夾的 `pet-error.log`。

## 素材與程式

- `pet.ps1`：可檢視與修改的 Windows / WPF 程式。
- `spritesheet.png`：透明 PNG，1536×2288，單格 192×208，共 73 格。
- `animations/`：各動作 GIF、整體 GIF / MP4 及十六方向展示。
- `docs/`：動作接觸表、視線圖與驗證摘要。

九組動作為待機、向右移動、向左移動、揮手、跳躍、失落、等待、思考、檢查。視線以十六個方向切換。

本專案是獨立 Windows 桌面程式；它不會讀取 Codex 聊天狀態。Codex 原生寵物使用另外的本機寵物套件。

## 驗證與限制

Windows PowerShell 5.1 / WPF 已執行自我測試，確認 73 格載入、九組動作、十六方向、尺寸、邊界限制與揮手／跳躍選單。圖集通過尺寸、透明度、空格與動作檢查。網頁預覽通過模擬 DOM 的按鈕與方向邏輯檢查，尚未完成實際瀏覽器的視覺驗收。

執行 `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\pet.ps1 -SelfTest` 可重新驗證；會產生測試紀錄和畫面。真實多螢幕與不同 DPI 的拖曳體驗仍可能因環境不同而異。

## 創作來源

角色造型依提供的「咖凌」參考圖製作，動畫素材由 AI 生成並整理。此為個人同人桌面寵物，非官方產品。程式碼採 MIT 授權；角色名稱、設定及圖像不包含在程式碼的 MIT 授權範圍中。
