# 蓮素材與來源

目前角色 atlas、頭像與照顧反應已在 v1.6 依確認後的官方比例母圖更新；新的 16 姿勢、提示詞與渲染方式見 [蓮的日常](REN-LIFE.md)。下方保留初版與技能特效的來源紀錄。

角色外觀經使用者確認，以白髮、紅眼、兔耳、白金衣裝、綠色腰帶及原版劍裝為依據。

- 官方宣傳圖：https://g.nexonstatic.com/media/m2sndzne/1366x768-ren-the-red-eyed-wanderer-wallpaper-maplestory.jpg
- 日服角色／技能：https://maplestory.nexon.co.jp/job/anima/len/
- 插畫整理：https://peak.nexon.com/post/850
- 官方職業影片：https://www.youtube.com/watch?v=rhfnWXZ84ds

所有新增 runtime 圖像由內建 imagegen 依參考生成，是同人改編動畫，不是擷取的遊戲技能素材。原圖僅作製作參考，不打包原始宣傳桌布。沒有使用官方音效。

`assets/characters/ren/atlas.png`：1536×4992，192×208 單格，24 列，104 格。
`effects.png`：2048×1536，512×512 單格，三列各四格，12 格。
`portrait.png`：衣櫃縮圖。`prompts.json`：完整提示詞、修復步驟與生成模式。

動作是逐格動畫，劍光、殘影的位移與淡出由 WPF 時間軸控制。透明圖集經 alpha 區塊擷取、等比縮放及基線對齊；重做半身圖，移除誤生成的背景後才打包。保留每次來源雜湊與檢查報告。

角色與遊戲名稱屬原權利人；專案程式碼授權不代表取得角色商標或原美術授權。
