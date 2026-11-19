# 《補簽遠行》（暫名） · Game Lab 4

一款偏向 MMORPG／ARPG 結構（採《Path of Exile 2》式獨立分區地圖）的童話奇幻動作 RPG。故事設定於「百年大戰早已結束、魔物全部退休轉行做生意」的和平世界——唯獨荒野深處的舊時代 Boss 仍未收到停戰通知。玩家扮演極少說話、以動作與表情互動的小旅人，騎乘冷靜可靠的巨型動物夥伴、帶著路癡胖黃羽信使鳥，透過體型差開路、合擊破防與雙軌刷裝，幫老古董 Boss 辦理「強制退休」。

## 專案目錄結構

- **`docs/design/`（遊戲設計與劇情規格）：**
  - [故事與世界觀企劃-補簽遠行](docs/design/故事與世界觀企劃-補簽遠行.md)
  - [核心玩法與雙軌配裝企劃](docs/design/核心玩法與雙軌配裝企劃.md)
  - [序章黃金五分鐘分鏡與實作規格](docs/design/序章黃金五分鐘分鏡與實作規格.md)
- **`docs/art/`（全專案美術與資產製作規範）：**
  - [全專案3D美術與資產規格](docs/art/全專案3D美術與資產規格.md)
  - [畫風分析與資產製作手冊](docs/art/畫風分析與資產製作手冊.md) · [style-spec.json](docs/art/style-spec.json)
  - [手繪風格重新分析](docs/art/手繪風格重新分析.md) · [遊戲風格參考圖索引](docs/art/遊戲風格參考圖索引.md)
- **`docs/archive/`：** 早期已退役之歷史企劃與舊版港城美術規格（僅供歷史參考）。
- **`game/`：** Godot 4.6.3 遊戲專案本體。
- **`美術參考/`：** 原始參考圖片與既有 3D／Tripo 資產庫（[資產交接清單](美術參考/西岸港城/README.md)）。

## 本機試玩（現行頭五分鐘灰盒原型）

用 **Godot 4.6.3** 開啟 [game/project.godot](game/project.godot)，按 **F5** 即可啟動頭五分鐘序章灰盒 [game/prologue/PrologueCloudhill.tscn](game/prologue/PrologueCloudhill.tscn)（舊港城技術灰盒 [game/harbor/Harbor.tscn](game/harbor/Harbor.tscn) 仍保留，可按 F6 單獨執行）。

| 按鍵 | 頭五分鐘灰盒操作 |
| --- | --- |
| WASD 或方向鍵 | 移動（標題畫面按任意鍵／點擊開始） |
| E | 互動（哥布林購劍／開閘拉桿／蓋退休章／開寶箱／懸賞板） |
| F | 上下騎（裝備《彈簧試驗鞍座》後下騎可彈飛高空暴擊下劈） |
| Q | 騎乘撞碎枯木路障／首領紅光蓄力時指揮巨狼破防（Stagger） |
| 滑鼠左鍵 / J / R | 揮劍攻擊 / 重新開始 |

## AI 代理與協作者

1. 每次接手先讀 [AGENTS.md](AGENTS.md) 與 [專案記憶](docs/project-memory.md)（Claude 亦可由 [CLAUDE.md](CLAUDE.md) 進入）。
2. 所有新開發、美術與劇情實作均以 `docs/design/` 與 `docs/art/` 為唯一基準。
