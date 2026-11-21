# Ink Studio × Godot 4.7 整合與技術評估筆記

- **工具來源**：[siliconjungle/shapeshift-labs-ink-studio](https://github.com/siliconjungle/shapeshift-labs-ink-studio)（套件名 `@shapeshift-labs/ink-studio`，MIT 授權，Node.js 18+，無外部執行期依賴）
- **本機安裝目標**：`_tools/ink-studio`（可雙擊專案根目錄的 `install_ink_studio.command` 一鍵下載與驗證）
- **專案定位結論**：**保留 Godot 4.7.2 為《補簽遠行》主力引擎**，將 Ink Studio 定位為側邊的 **「3D 程式化雕刻 × 像素光影／碎裂實驗室 × 素材產出管線」**，而非將整套遊戲重寫為 JS／WebGL。

---

## 1. Ink Studio 核心能力摘要

| 面向 | 主要能力與 API |
| --- | --- |
| **3D 程式化雕刻與建模** | 以有號距離場（Signed-Distance Solids）搭配布林運算（`union`、`cut`、`common`、`round`、`chamfer`、`engrave` 等）建構立體幾何，並透過自適應取樣（adaptive sampling）將邊緣、倒角與輪廓烘焙為「像素風高斯潑濺」（Pixel-art Gaussian Splats，儲存在 `Float32Array`，每點 16 floats）。 |
| **像素風材質與動態光影** | 支援色盤色階（palette ramps）、程式化紋理（noise、Voronoi、wave、bricks、checkers）、特殊質感（`wax`、`jelly`、`glass`、`fur`、`em` 發光），並支援即時重打光（live splat relighting）與藝術化步階陰影。 |
| **動畫、物理與持久環境狀態** | 透過 `K.stage(world)` 驅動 `world.anim` 生命週期：內建木偶／骨架動畫、粒子系統、布料／毛髮、流體漣漪、Voronoi 碎裂破壞，以及會被記住的持久表面狀態（燒焦痕跡、積雪累積、磨損）。 |
| **資產匯入與匯出** | `readMesh` / `readAsset` 可匯入 OBJ、glTF/GLB 與深度圖；`exportGlb` 可匯出自包含 `.glb` 網格模型；`render` 與 `spriteAtlas` 可透過 CPU / CLI 離線產出圖片、旋轉展示圖或方向性精靈圖集（RGBA atlas）。 |
| **零依賴 CLI 與 AI 友善結構** | 場景以純 JavaScript（`{ id, name, seed, build(seed) }`）或 JSON 定義，固定 seed 與固定時間步進即可 100% 重現，適合版本控制與搭配 LLM 快速生成參數化物件。 |

---

## 2. Ink Studio 與一般 AI 生成 3D 模型的關鍵差異

| 比較維度 | Ink Studio（白盒程式化系統） | 一般 AI 生 3D 模型（黑盒推論） |
| --- | --- | --- |
| **生成方式** | 以 JS / JSON 程式碼定義幾何、色階與物理規則（可由 AI 輔助撰寫腳本）。 | 輸入文字或圖片，由神經網路直接推論 Mesh / 貼圖。 |
| **可控性與微調** | 極高；可直接修改半徑、挖洞座標、色階或碎裂參數並穩定重算。 | 較低；局部比例或凹槽不合意時多需重抽（reroll）或進 Blender 修補。 |
| **動態與互動** | 原生具備動畫、粒子、碎裂與持久狀態記憶（燒焦／積雪）。 | 以靜態模型為主，動態與物理需另行綁骨與接引擎。 |
| **版控與批次流程** | 純文字腳本＋固定 seed，適合 Git 版控與 CLI 批次產圖。 | 二進位模型檔隨機性高，不易做細緻的參數化批次調整。 |

> **互補用法**：可用外部工具（或 Tripo）先產出基礎 `.glb`，匯入 Ink Studio 進行布林雕刻或視覺風格實驗，或請 AI 直接撰寫 Ink Studio 場景腳本，由 Ink Studio 穩定掌控結構與色階。

---

## 3. 與 Godot 4.7 的整合策略（為何不直接轉用 JS）

### 為何保留 Godot 為主力
- Ink Studio 是專注於「SDF 雕刻 → 像素高斯潑濺渲染與模擬」的工具包，**並非通用完整遊戲引擎**。
- 《補簽遠行》已建立完整的 6 區大世界、2.5D 斜俯視角、職業與昇華系統、造裝工坊、UI、音效／BGM 與跨平台打包需求；若全數改寫為 JS／WebGL，需自行補齊 UI、存檔、輸入／手掣、效能與 Steam／多平台發佈基建，長遠風險與成本過高。
- Ink Studio 的即時物理與持久狀態綁定於其內部的 `Float32Array` 潑濺管線與 `world.anim`，**無法一鍵原封不動搬入 Godot 執行**。

### 實戰可行的三種配合管線
1. **靜態與變體資產產出（`exportGlb`）**：用 JS / JSON 搭配不同 seed 批次雕刻場景道具（岩石、遺跡、木桶、武器胚子），匯出 `.glb` 直接匯入 Godot 場景。
2. **離線特效與精靈圖集（`render` / `spriteAtlas`）**：將特定爆裂、煙霧、水花或展示旋轉序列算成 PNG / Sprite Atlas，導入 Godot 作為 2D 粒子貼圖或視覺參考。
3. **視覺實驗室 → Godot 原生重現（最推薦於核心玩法）**：先在 Ink Studio 驗證色階、光影節奏與破壞手感，再以 Godot 原生系統落地：
   - **像素／手繪立體質感**：低解析度 `SubViewport`＋`Nearest` 放大（若走像素路線）或延續現有 `@amelicart` 水粉步階著色器（`amelicart_gouache.gdshader`）＋色階量化（Posterize／Palette Ramp）。
   - **物理碎裂與破壞**：以 `RigidBody3D` 預切碎片（或程式生成木塊／碎石）搭配 `GPUParticles3D` 與 60 FPS 整數幀 Hitstop。
   - **持久環境痕跡（燒焦／積雪／泥濘）**：以 2D 狀態格網或動態 `Image` / `ViewportTexture` 記錄地表數值（溫度、積雪厚度、焦黑度），交由地形與物件 Shader 即時混合覆蓋層。

---

## 4. 快速指令速查（安裝完成後）

```bash
# 進入本機工具目錄
cd _tools/ink-studio

# 查看說明與內建範例場景
node cli/ink-studio.js help
node cli/ink-studio.js scenes

# 算圖輸出範例場景（輸出至 studio/out/）
node cli/ink-studio.js render watcher --t 2.6 --colored

# 輸出旋轉多角度序列圖或查詢統計
node cli/ink-studio.js turn examples/sculpt.js --n 8
node cli/ink-studio.js stats examples/sculpt.js
```
