# Mixamo 角色與動作放入指引（Godot 4.7 自動載入）

本專案已內建 `game/prologue/MixamoCharacterRig.gd`，只要將從 [Mixamo](https://www.mixamo.com/) 下載的 `.fbx`（或合併後的 `.glb`）放入本資料夾，啟動遊戲即會**自動替換主角為骨骼角色，並自動套用 `@amelicart` 手繪水粉 Shader**。

## 建議下載清單（從 Mixamo 下載，Format 選 `FBX Binary`）
1. **角色模型（Skin 選 `With Skin`）**：命名為 `character.fbx`（或 `character.glb`）
2. **核心動作（Skin 選 `Without Skin`，移動類勾選 `In Place`）**：
   - `idle.fbx` — 待機（例如 `Idle`）
   - `run.fbx` — 奔跑（例如 `Running`，勾選 `In Place`）
   - `slash.fbx` — 揮劍 1～2 段（例如 `Sword And Shield Slash`）
   - `spin.fbx` — 第 3 段旋風斬（例如 `Sword And Shield Spin`）
   - `dodge.fbx` — `[Space]` 翻滾閃避（例如 `Stand To Roll`，勾選 `In Place`）
   - `fall.fbx` — 彈簧鞍飛天重劈（例如 `Falling Idle`）
