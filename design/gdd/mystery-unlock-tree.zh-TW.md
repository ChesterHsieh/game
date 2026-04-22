# Mystery Unlock Tree（中文）

> **狀態**：設計中（審查後修訂）
> **作者**：Chester + Claude Code agents  
> **最後更新**：2026-04-18  
> **對應支柱**：Discovery Without Explanation（不解釋的探索感）

## 概述

Mystery Unlock Tree（MUT）是一個功能層級（Feature-layer）的執行期資料結構，用於追蹤玩家在整個遊戲歷程中發現過哪些卡牌組合。它會監聽 Interaction Template Framework 發出的 `combination_executed` 訊號（經由 EventBus，ADR-003），並把每個唯一配方記錄為一次發現。

在單一場景內，MUT 只負責「記錄已發生的發現」，不直接決定能否解鎖；樹狀展開由配方與生成卡的關係本身形成。跨場景時，MUT 累積可持久化的發現集合，用於支援場景間進展門檻（例如：至少需要 N 個發現，或特定關鍵配方）。在全遊戲層級，它也追蹤是否達成最終插畫記憶的條件。

玩家不會直接看到或操作這棵樹。她只是在拖曳卡牌、看到世界回應：新卡出現、場景推進、門被打開。MUT 是那本「看不見的帳本」。

## 玩家體驗幻想（Player Fantasy）

MUT 模擬的是聯想式記憶：不是被教導順序，而是「一件事自然帶出下一件事」。當玩家把兩張卡合在一起，若跳出的不是冷冰冰的「解鎖成功」，而是「喔天啊，我好多年沒想起這件事了」，就代表這個系統達標。

## 詳細設計

### 核心規則

1. **MUT 是 autoload singleton**（註冊名 `MysteryUnlockTree`）。它是觀察者：只監聽、記錄、回答查詢；不生成卡牌、不修改配方、不阻擋配方執行。
2. **發現追蹤主索引**
   - `_discovered_recipes: Dictionary`
   - key: `recipe_id`
   - value: `{ card_id_a, card_id_b, scene_id, discovery_order, template }`
3. **次索引**
   - `_scene_discoveries[scene_id] -> Array[recipe_id]`（依發現順序）
   - `_cards_in_discoveries[card_id] -> scene_id`（該卡首次出現於哪個場景）
4. **`combination_executed` 處理流程**
   - 僅在 `Active` 狀態處理，其他狀態直接忽略。
   - 已發現的 `recipe_id` 不重複記錄。
   - 遞增全域 `discovery_order`，寫入主索引與次索引。
   - 送出 `EventBus.recipe_discovered(...)`。
   - 評估里程碑閾值與 epilogue 條件。
5. **跨系統變更：ITF 訊號參數擴充**
   - `combination_executed` 由 4 參數擴成 6 參數，新增 `card_id_a`, `card_id_b`。
   - 既有消費端若不使用新參數，仍需同步更新 handler 簽名（Godot 4.3 typed signal 不相容舊簽名）。
6. **場景內定位**
   - MUT 不控制可用配方、也不控制卡牌出現；它只記錄「已發生」。
7. **跨場景 carry-forward**
   - 場景 JSON 可定義 `carry_forward`，每筆有 `card_id` 與 `requires_recipes`。
   - MUT 提供 `get_carry_forward_cards(carry_forward_spec)` 回傳符合條件的卡牌。
   - Scene Goal System 在 `load_scene()` 讀取並附加到 `seed_cards`。
8. **最終插畫記憶條件**
   - 必要配方清單由 `res://assets/data/epilogue-requirements.tres` 單一來源維護。
   - `epilogue_started()` 時依 `partial_threshold` 判斷是否送出 `final_memory_ready()`。
   - 若必要清單為空（`R_total == 0`），明確防呆：不送出 `epilogue_conditions_met()` 與 `final_memory_ready()`，並記錄錯誤。
9. **發現里程碑**
   - `_milestone_pct` 以百分比設定，`_ready()` 時轉成絕對數量閾值。
   - 命中後送出 `discovery_milestone_reached(milestone_id, discovery_count)`，每閾值每局只觸發一次。

### 可見性限制（Pillar 3，反慶祝）

- `epilogue_conditions_met` 與 `discovery_milestone_reached` 只允許「引擎內部、玩家不可見」用途（如靜默 preload、靜默敘事狀態切換）。
- 禁止：音效提示、UI 動畫、視覺慶祝、螢幕訊息。
- `recipe_discovered` 與 `final_memory_ready` 可對應到作者設計的玩家可見時刻。

## 狀態機與轉移

| 狀態 | 進入條件 | 離開條件 | 行為 |
|---|---|---|---|
| `Inactive` | `_ready()` 預設 | 收到 `scene_started` 或 `epilogue_started` | 忽略 `combination_executed` |
| `Active` | `scene_started(scene_id)` | `scene_completed(scene_id)` | 記錄發現、送出 discovery/里程碑/epilogue 訊號 |
| `Transitioning` | `scene_completed(scene_id)` | `scene_started(next)` 或 `epilogue_started()` | 忽略組合事件，允許 carry-forward 查詢 |
| `Epilogue` | `epilogue_started()` | 無（終止） | 判斷 final memory；不再接受新發現 |

主要轉移：
- `Inactive -> Active`：`scene_started`
- `Active -> Transitioning`：匹配當前場景的 `scene_completed`
- `Transitioning -> Active`：下一場 `scene_started`
- `* -> Epilogue`：`epilogue_started`（含退化路徑，需 log warning）

## 系統互動（摘要）

- **MUT 監聽**
  - `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)`
  - `scene_started(scene_id)`
  - `scene_completed(scene_id)`
  - `epilogue_started()`
- **MUT 發送**
  - `recipe_discovered(...)`
  - `discovery_milestone_reached(...)`
  - `epilogue_conditions_met()`
  - `final_memory_ready()`
- **MUT 讀取資料**
  - `epilogue-requirements.tres`
  - `recipes.tres`（`R_authored` 與 recipe id 驗證）
- **MUT 提供查詢給其他系統**
  - `get_carry_forward_cards(...)`
  - `get_epilogue_state()`
  - `get_save_state()` / `load_save_state(...)`

## Query API（唯讀）

| 方法 | 簽名 | 說明 |
|---|---|---|
| `is_recipe_discovered` | `(recipe_id: String) -> bool` | 此配方是否已發現 |
| `get_discovery_count` | `() -> int` | 全局發現總數 |
| `get_scene_discoveries` | `(scene_id: String) -> Array[String]` | 指定場景發現序列 |
| `get_scene_discovery_count` | `(scene_id: String) -> int` | 指定場景發現數 |
| `get_discovery_record` | `(recipe_id: String) -> Dictionary` | 單配方完整紀錄 |
| `is_card_in_discovery` | `(card_id: String) -> bool` | 卡牌是否出現在任何已發現配方 |
| `get_carry_forward_cards` | `(carry_forward_spec: Array) -> Array[String]` | 回傳符合 carry-forward 的卡牌 |
| `get_epilogue_state` | `() -> Dictionary` | `{ required_count, discovered_count, is_complete, missing_ids, discovery_pct }` |
| `is_final_memory_earned` | `() -> bool` | 是否已達最終記憶條件 |
| `get_save_state` | `() -> Dictionary` | 可序列化快照 |
| `load_save_state` | `(data: Dictionary) -> void` | 載入快照 |

## 公式

### 1) 里程碑命中

- 啟動時解析：`T_i = max(1, ceil(P_i * R_authored))`
- 執行期命中：`D == T_i`

變數：
- `D`: 已發現唯一配方數（1-indexed）
- `P_i`: `milestone_pct` 中某一個百分比
- `T_i`: 解析後閾值
- `R_authored`: 配方總數

### 2) Carry-forward 可用性

`eligible(E) = 所有 E.requires_recipes 都存在於 _discovered_recipes`  
`result = 所有 eligible(E) 為 true 的 E.card_id`

### 3) Epilogue 條件

`R_found = |_epilogue_required_ids ∩ keys(_discovered_recipes)|`  
`epilogue_complete = (R_found >= ceil(R_total * partial_threshold))`

### 4) 發現百分比（僅報表）

`P_discovery = D / R_authored`，若 `R_authored == 0` 則回傳 `0.0` 並記錯誤。

## 邊界案例（摘要）

- 非 `Active` 狀態收到 `combination_executed`：靜默丟棄。
- `scene_completed` 場景 id 不匹配：靜默忽略。
- `Active` 狀態又收到 `scene_started`：記 warning，當成隱式完成上一場再切換。
- `combination_executed` 的 `recipe_id` 不存在於 Recipe DB：不記錄、記 warning。
- `card_id_a` 或 `card_id_b` 為空：仍記錄配方，但跳過空 card_id 的 `_cards_in_discoveries` 更新並記 warning。
- `epilogue-requirements.tres` 空或缺失：記 error，阻止 epilogue 相關訊號誤觸發。
- `R_authored == 0`：停用里程碑解析、`discovery_pct` 防除零。
- Godot 4.3 訊號簽名不相容：ITF 擴參數是破壞性變更，所有 listener 必須同 commit 同步更新。

## 相依關係（摘要）

### 上游（MUT 依賴）
- Interaction Template Framework（組合事件）
- Scene Manager（場景生命週期）
- Recipe Database（配方總量與 id 驗證）
- Epilogue Requirements 檔案
- EventBus

### 下游（依賴 MUT）
- Scene Goal System（carry-forward 解算）
- Final Epilogue Screen（最終揭示判斷）
- Save/Progress System（存檔）

### 必要 autoload 順序

`EventBus -> RecipeDatabase -> MysteryUnlockTree`

另外：Scene Manager 首次 `scene_started` 需使用 deferred emit，避免 MUT 還沒完成 `_ready()` 就錯過訊號。

## 調參旋鈕（Tuning Knobs）

| 旋鈕 | 所在處 | 預設 | 安全範圍 | 影響 |
|---|---|---|---|---|
| `milestone_pct` | `mut-config.tres` | `[0.15, 0.50, 0.80]` | (0,1]、嚴格遞增且不重複 | 靜默敘事節點觸發 |
| `partial_threshold` | `mut-config.tres` | `1.0` | [0,1] | 最終記憶門檻鬆緊 |
| `epilogue-requirements.tres` | 資料檔 | 依內容 | 長度 >= 1，id 必須有效 | 最終記憶必要配方 |
| `carry_forward` | 場景檔 | 首場常為 `[]` | 每場通常 0~10 筆 | 跨場景種子卡延續 |
| `force_unlock_all`（僅開發） | `debug-config.tres` | `false` | 只允許 dev | 開發快速跳關 |

注意事項：
- `milestone_pct` 太密集會讓靜默狀態變更變成噪音。
- `partial_threshold < 0.5` 容易讓結局「得來太容易」。
- `epilogue-requirements` 包含不存在 id 會造成永遠無法完成，必須修檔，不可靜默移除。
- `debug-config.tres` 必須由 export 設定排除於 release。

## 視覺 / 音效 / UI

- **MUT 本身沒有視覺、音效、UI。**
- 所有玩家可見回饋由下游系統實作（Card Visual、UI、Audio、Final Epilogue Screen）。

## 驗收標準（Acceptance Criteria）

> 以下保留原 AC 編號，方便對照英文版。內容是中文摘要版，語意與原版一致。

### Discovery Recording
- **AC-001 ~ AC-006 [Logic]**：首次發現完整記錄；次索引同步更新；重複配方不重記；計數單調且與字典大小一致；跨場景索引總和一致。

### Signal Emission
- **AC-007 [Logic]**：`recipe_discovered` 僅首次觸發。
- **AC-008 ~ AC-010 [Logic]**：里程碑只在命中解析閾值觸發；不重複觸發；閾值最小為 1。
- **AC-011 ~ AC-014 [Logic]**：`epilogue_conditions_met` 在「完成必要集合的那一刻」觸發且只觸發一次；`final_memory_ready` 只在 `epilogue_started` 且條件達成時觸發；里程碑與 epilogue 訊號可同一事件中同時發送。

### State Machine
- **AC-015 ~ AC-022 [Logic]**：四大狀態與轉移正確；錯誤順序事件可容錯且不崩潰；重複完成事件應被忽略。

### Carry-Forward
- **AC-023 ~ AC-027 [Logic/Config]**：`requires_recipes` 採全稱量化（全部都要）；空需求視為真；可跨場景滿足；Inactive 下回傳空；啟動時驗證未知 recipe id。

### Query API
- **AC-028 ~ AC-031 [Logic]**：未知配方查詢回空字典；`get_epilogue_state` 欄位完整；`is_final_memory_earned` 可反映中途完成；所有 query 無副作用。

### Save / Load
- **AC-032 ~ AC-035 [Logic]**：存讀往返一致；非 Inactive 載入前要先 reset 狀態機；過期 recipe 需修剪並重算；load 後不重播歷史訊號。

### Cross-System Integration
- **AC-036 [Integration]**：啟動後 EventBus 連線完整。
- **AC-037a / AC-037b [Integration]**：ITF 6 參數訊號與所有消費端簽名同步更新（目前受 OQ-7 阻塞）。
- **AC-038 [Integration]**：carry-forward 回空時 SGS 仍可正常載入場景。

### Edge Cases & Validation
- **AC-039 ~ AC-051 [Logic/Config/Integration]**：未知 recipe 丟棄、空 card_id 防呆、前置訊號時序防呆、epilogue 空集合保護、autoload 順序檢查、不合法 milestone 配置回退策略、`force_unlock_all` dev-only 行為、`R_authored == 0` 防除零、Inactive 直入 Epilogue 退化路徑、epilogue required 可達性（OQ-2 工具）、partial threshold 範例驗證。

## Open Questions（保留編號）

| # | 問題 | Owner | 目標時間 |
|---|---|---|---|
| OQ-1 | `combination_executed` 處理的效能預算尚未量化（recipe 規模成長後需 ms 級目標） | systems-designer + performance-analyst | Vertical Slice 前 |
| OQ-2 | 缺少「epilogue 必要配方可達性」靜態檢查工具 | tools-programmer | Alpha |
| OQ-3 | 缺少依場景順序檢查 carry-forward 合法性的工具 | tools-programmer | Alpha |
| OQ-4 | New Game 的重置 API（`clear_state()` 或 `load_save_state` sentinel）待定 | game-designer + Save/Progress | Alpha |
| OQ-5 | 是否需要熱重載調參（目前 `_ready()` 一次載入） | systems-designer | 視測試需求 |
| OQ-6 | 是否加入發現分析遙測（`recipe_discovered` log） | analytics + creative-director | Alpha 前 |
| OQ-7 | ITF 訊號 4->6 參數擴充是破壞性變更，需消費端同 commit 同步更新 | itf + statusbar author | MUT 實作前 |
| OQ-8 | SGS GDD 尚未寫入 `get_carry_forward_cards()` 軟依賴 | sgs author | Vertical Slice 前 |
| OQ-9 | epilogue 顯示名稱來源（requirements 同檔欄位 / Recipe DB / 別檔）待定 | game + narrative | Alpha 前 |
| OQ-10 | 是否建立統一 autoload 順序清單文件 | technical-director | Vertical Slice 前 |

