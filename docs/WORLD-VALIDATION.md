# v2.0.0 驗收

日期：2026-10-17。Windows PowerShell 5.1 / WPF，全部採用隔離存檔，不寫入使用者生活進度。

| 項目 | 結果 |
| --- | --- |
| 完整 WPF 回歸 | [1,439 項通過](world-integration.json)，含原有 1,362 項與小世界 77 項 |
| 最後修正後的小世界 WPF | [77 項通過](world-focused-integration.json) |
| 小世界模型與遷移 | [632 項通過](world-model.json) |
| 舊設定與番茄鐘 | [139 項通過](world-state-tests.json) |
| 電子雞模型 | [44 項通過](world-care-model.json) |
| 既有遊戲模型 | [81 項通過](world-play-model.json) |
| 五角色設定 | [19 項通過](world-monster-state.json) |
| 離線預覽 | [16 組通過](world-preview-check.json)：八場景 × 1,240 / 390 px；40 秒影片可播放，無 JS 錯誤、資產失敗或水平溢出 |

五位單人與所有不同角色配對的六段故事都有完成／還原檢查；實際 WPF 驗證 20 組雙人載入與咖凌三套服裝。測試涵蓋家具拖放、紙箱分支、球移動、故事介入、到達後才表演、選擇對象不轉移未完成互動、正確角色才獲得點心及習慣、三次探險選擇、單次獎勵與中斷不給獎。

舊 schema 3 檔案實際讀寫升級，保留服裝、位置、計時與收藏；小世界便便與原子備份有存檔往返檢查。驗證專注、安靜、手動／全螢幕隱藏、最小化、拖曳中關閉、原生關閉、回到先前小屋及角色切換。照片加入原相簿，顯示時維持寬高比。

人工查看實際 WPF 圖片與動畫影格：庭院、森林、溪畔、蓮擦劍、綠水靈追球與葉堆遮擋、肥肥及咖凌三套衣裝。新角色動作使用保留透明度的生成原圖，舊角色母圖不變。怪物使用既有姿態搭配連續位移／形變；蓮有八張、咖凌各套有六張新增姿態。

## 下載包驗收

發布流程在提交完成後，將所有受 Git 追蹤的檔案打包，檢查 ZIP CRC、逐檔內容及 SHA-256。完整解壓到含中文與空白的路徑，分別執行 `Start.exe --self-test` 和 `Start.bat --self-test`；每次重新跑完整 1,439 項 WPF 回歸。推送後再下載 GitHub Code ZIP，逐檔比對並執行 EXE。只有全部通過才發布正式版，最終提交、下載包雜湊與啟動器結果附在 v2.0.0 發布頁的 `VALIDATION.json`。

EXE 原始碼與建置腳本在 `launcher/`。它啟動系統 Windows PowerShell，`--version` 顯示版本、`--updates` 開啟本專案 Releases，沒有背景下載。自我檢查使用隔離目錄；缺少完整資料的 EXE 應回傳失敗。

## 可重跑

完整解壓後執行 `Start.exe --self-test`，或 `Start.bat --self-test`。EXE 也接受 `--test-data "C:\任意資料夾"` 指定隔離測試目錄。純模型：`powershell -NoProfile -ExecutionPolicy Bypass -File tests/World.Model.Tests.ps1 -OutputDirectory 任意測試目錄`。WPF 動畫記錄可用 `pet.ps1 -SelfTest -WorldTestsOnly -WorldPreview`。

## 尚未完成的實機驗證

Windows 未允許測試視窗可靠取得前景，因此跨程序真實滑鼠穿透及前景全螢幕自動偵測仍未端到端驗證。實體滑鼠拖曳、混合 DPI 多螢幕和強制休眠／喚醒未測；已測正式事件處理器、邊界與時間間隔邏輯。啟動器由實際子程序運行 WPF 自我檢查，未透過 Explorer 實體雙擊，也不能代替不同電腦上的 SmartScreen 行為驗收。

小世界採六個固定擺設區，並非自由任意擺放或路徑規劃系統；外出是本機三段互動小旅行。天氣手動選擇，不連網；相處習慣僅依程式內已完成互動計算。沒有商店、貨幣、線上同步或背景安裝。
