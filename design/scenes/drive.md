# Scene: drive the car

> **Status**: Ready
> **Last updated**: 2026-04-23
> **Source of truth**: this file. All generated data files are reconstructable
> from this spec via `/create-scene [scene-id]`.
>
> **How to use this template**: fill every section top-to-bottom. Sections
> marked [optional] can be deleted if not applicable. Run `/scene-audit
> [scene-id]` after filling to catch missing references before committing
> the implementation pass.

---

## 1. Identity

| Field | Value |
|---|---|
| `scene_id` | `drive` |
| `display_name` | drive the car |
| `narrative_beat` | 表達日常拌嘴的駕駛經驗 |
| `manifest_order` | 1 |
| `phase` |  Mid-game  |

---

## 2. Seed State (cards on the table at scene start)

```
ju
chester
drive_seat_9
shotgun_10
kingdom_far_away
```

Every `card_id` must either already exist in `cards.tres` or be defined
in Section 3 below.

---

## 3. New Cards (define in this scene — added to cards.tres)

### `drive_seat_9`
| Field | Value |
|---|---|
| type | OBJECT |
| display_name | 駕駛座 |
| flavor_text | 方向盤在你手上。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/drive_seat_9.png` |

### `shotgun_10`
| Field | Value |
|---|---|
| type | OBJECT |
| display_name | 副駕駛座 |
| flavor_text | 最佳觀測位置。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/shotgun_10.png` |

### `kingdom_far_away`
| Field | Value |
|---|---|
| type | PLACE |
| display_name | 遠的要命王國 |
| flavor_text | 導航說還有一個小時。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/kingdom_far_away.png` |

### `ju_driving`
| Field | Value |
|---|---|
| type | PERSON |
| display_name | 駕駛 Ju |
| flavor_text | 我來開。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/ju_driving.png` |

### `chester_backseat`
| Field | Value |
|---|---|
| type | PERSON |
| display_name | 路怒症導師 |
| flavor_text | 我只是說說而已。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/chester_backseat.png` |

### `nav_info`
| Field | Value |
|---|---|
| type | OBJECT |
| display_name | 導航資訊 |
| flavor_text | 前方 500 公尺右轉。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/nav_info.png` |

### `better_nav_info`
| Field | Value |
|---|---|
| type | OBJECT |
| display_name | 更合理的導航資訊 |
| flavor_text | 這條路根本不用繞。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/better_nav_info.png` |

### `restaurant_bbq`
| Field | Value |
|---|---|
| type | PLACE |
| display_name | 控窯雞 |
| flavor_text | 聽起來不錯。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/restaurant_bbq.png` |

### `restaurant_japanese`
| Field | Value |
|---|---|
| type | PLACE |
| display_name | 日式料理 |
| flavor_text | 也可以。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/restaurant_japanese.png` |

### `sure_either`
| Field | Value |
|---|---|
| type | FEELING |
| display_name | 都行 |
| flavor_text | 都行。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/sure_either.png` |

### `mcdonalds`
| Field | Value |
|---|---|
| type | PLACE |
| display_name | 麥當勞 |
| flavor_text | 最後還是麥當勞。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/mcdonalds.png` |

### `five_more_min`
| Field | Value |
|---|---|
| type | FEELING |
| display_name | 再開五分鐘 |
| flavor_text | 再撐一下就到了。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/five_more_min.png` (placeholder — uses `home.png` until art generated) |

### `scenic_view`
| Field | Value |
|---|---|
| type | PLACE |
| display_name | 好山好水 |
| flavor_text | 天地山水 與妳。 |
| scene_id | `drive` |
| art_path | `res://assets/cards/scenic_view.png` (placeholder — uses `home.png` until art generated) |

> Cards referenced but already defined elsewhere — do NOT re-define:
> `ju`, `chester`

---

## 4. Puzzle Graph (recipes — added to recipes.tres, scene-scoped)

```
seat-ju                  : ju + drive_seat_9 → ju_driving                            [merge, consumes both]
seat-chester             : chester + shotgun_10 → chester_backseat                    [merge, consumes both]
kingdom-nav              : kingdom_far_away + chester_backseat → nav_info             [merge, keeps BOTH — dual-catalyst]
nav-upgrade              : nav_info + chester_backseat → better_nav_info              [merge, keeps: chester_backseat]
nav-advance              : better_nav_info + ju_driving → progress +1                 [additive, keeps: ju_driving (consumes better_nav_info); spawns: restaurant_bbq, restaurant_japanese]
nav-reject               : nav_info + ju_driving → (排斥×2 + emote: anger)           [reject template, 兩張都不消費]
bbq-sure                 : restaurant_bbq + ju_driving → sure_either                  [merge, keeps: ju_driving]
japanese-sure            : restaurant_japanese + ju_driving → sure_either             [merge, keeps: ju_driving]
sure-merge               : sure_either + sure_either → mcdonalds                      [merge, consumes both]
mcd-advance              : mcdonalds + ju_driving → progress +1                       [additive, keeps: ju_driving (consumes mcdonalds); spawns: five_more_min]
five-more-scenic         : five_more_min + kingdom_far_away → scenic_view             [merge, 消費兩張 — 到此王國退場]
scenic-advance-ju        : scenic_view + ju_driving → progress +1                     [merge, keeps: ju_driving; consumes scenic_view]
scenic-advance-chester   : scenic_view + chester_backseat → progress +1               [merge, keeps: chester_backseat; consumes scenic_view]
```

主路徑（+1 推進第 1 次）：
```
kingdom_far_away + chester_backseat → nav_info             (dual-catalyst; 兩張都留)
nav_info + chester_backseat → better_nav_info              (keeps chester_backseat)
better_nav_info + ju_driving → +1 progress                 (spawn: restaurant_bbq, restaurant_japanese)
```

餐廳支線（+1 推進第 2 次，spawn 下一個卡）：
```
restaurant_bbq + ju_driving → sure_either
restaurant_japanese + ju_driving → sure_either
sure_either + sure_either → mcdonalds
mcdonalds + ju_driving → +1 progress                       (spawn: five_more_min)
```

好山好水支線（+1 推進第 3 次 — 結局感）：
```
five_more_min + kingdom_far_away → scenic_view             (keeps kingdom_far_away)
scenic_view + ju_driving         → +1 progress             (或)
scenic_view + chester_backseat   → +1 progress
```

排斥互動（非 recipe）：
```
nav_info + ju_driving → emote: angry + 排斥力 ×2  [兩張卡都不消費]
```

### `seat-ju`
| Field | Value |
|---|---|
| id | `seat-ju` |
| card_a | `ju` |
| card_b | `drive_seat_9` |
| template | `merge` |
| result_card | `ju_driving` |

### `seat-chester`
| Field | Value |
|---|---|
| id | `seat-chester` |
| card_a | `chester` |
| card_b | `shotgun_10` |
| template | `merge` |
| result_card | `chester_backseat` |

### `kingdom-nav`
| Field | Value |
|---|---|
| id | `kingdom-nav` |
| card_a | `kingdom_far_away` |
| card_b | `chester_backseat` |
| template | `merge` |
| result_card | `nav_info` |
| keeps | `[kingdom_far_away, chester_backseat]` (dual-catalyst) |

> **2026-04-24 design change**: Originally specced as `merge` keeping both
> inputs, then switched to `generator` because the framework only supported
> single-card `keeps`. The framework was extended to accept an Array of
> card_ids, and this recipe is now the intended one-shot dual-catalyst merge.
> 30s cooldown prevents spam; nav_info can be re-produced each cycle.

### `nav-upgrade`
| Field | Value |
|---|---|
| id | `nav-upgrade` |
| card_a | `nav_info` |
| card_b | `chester_backseat` |
| template | `merge` |
| result_card | `better_nav_info` |
| keeps | `chester_backseat` |

### `nav-advance`
| Field | Value |
|---|---|
| id | `nav-advance` |
| card_a | `better_nav_info` |
| card_b | `ju_driving` |
| template | `additive` |
| keeps | `ju_driving` |
| bar_delta | `journey_progress` +1 |
| spawns | `restaurant_bbq`, `restaurant_japanese` |

### `nav-reject`
| Field | Value |
|---|---|
| id | `nav-reject` |
| card_a | `nav_info` |
| card_b | `ju_driving` |
| template | `reject` |
| repulsion_multiplier | `2.0` |
| emote | `anger` |
| result | 無；兩張卡都不消費（reject template 自動處理）|

### `bbq-sure`
| Field | Value |
|---|---|
| id | `bbq-sure` |
| card_a | `restaurant_bbq` |
| card_b | `ju_driving` |
| template | `merge` |
| result_card | `sure_either` |
| keeps | `ju_driving` |

### `japanese-sure`
| Field | Value |
|---|---|
| id | `japanese-sure` |
| card_a | `restaurant_japanese` |
| card_b | `ju_driving` |
| template | `merge` |
| result_card | `sure_either` |
| keeps | `ju_driving` |

### `sure-merge`
| Field | Value |
|---|---|
| id | `sure-merge` |
| card_a | `sure_either` |
| card_b | `sure_either` |
| template | `merge` |
| result_card | `mcdonalds` |

### `mcd-advance`
| Field | Value |
|---|---|
| id | `mcd-advance` |
| card_a | `mcdonalds` |
| card_b | `ju_driving` |
| template | `additive` |
| keeps | `ju_driving` |
| spawns | `five_more_min` |
| bar_delta | `journey_progress` +1 |

### `five-more-scenic`
| Field | Value |
|---|---|
| id | `five-more-scenic` |
| card_a | `five_more_min` |
| card_b | `kingdom_far_away` |
| template | `merge` |
| result_card | `scenic_view` |
| keeps | —（兩張都消費）|

### `scenic-advance-ju`
| Field | Value |
|---|---|
| id | `scenic-advance-ju` |
| card_a | `scenic_view` |
| card_b | `ju_driving` |
| template | `merge` |
| keeps | `ju_driving` |
| emote | `heart` |
| bar_delta | `journey_progress` +1 |

### `scenic-advance-chester`
| Field | Value |
|---|---|
| id | `scenic-advance-chester` |
| card_a | `scenic_view` |
| card_b | `chester_backseat` |
| template | `merge` |
| keeps | `chester_backseat` |
| emote | `heart` |
| bar_delta | `journey_progress` +1 |

---

## 5. Win Condition (goal config in `assets/data/scenes/[scene-id].json`)

| Field | Value |
|---|---|
| type | `reach_value` |
| bars | `[{ id: "journey_progress", initial_value: 0, decay_rate_per_sec: 0 }]` |
| max_value | 3 |
| threshold | 3 |
| duration_sec | 1 |

Trigger `nav-advance` three times to fill the bar and complete the scene.

> Goal types currently supported: `sustain_above`, `reach_value`.
> `find_key` and `sequence` are defined in GDD but not wired in SceneGoal code.

---

## 6. Left Panel Content (status bars visible during the scene)

- **`journey_progress`** — 旅程進度，starts 0，max 3，no decay。每次 `nav-advance` +1。三格滿即抵達目的地。

---

## 7. Bar Effects (`assets/data/bar-effects.json` — recipe_id → bar deltas)

```json
"nav-advance":             { "journey_progress": 1 },
"mcd-advance":             { "journey_progress": 1 },
"scenic-advance-ju":       { "journey_progress": 1 },
"scenic-advance-chester":  { "journey_progress": 1 }
```

Every key MUST match a recipe in Section 4.
Every value key MUST match a `bar_id` in Section 6.

---

## 8. Hint System (per-scene timing)

| Field | Value |
|---|---|
| stagnation_sec | 180 |
| level_1_cue | 弧線指向 `ju` 或 `chester` 和對應座位卡之間 |
| level_2_cue | 弧線指向 `kingdom_far_away` + `chester_backseat` |

---

## 9. Audio Cues (recipe-triggered SFX + ambient)

| Event | SFX | Notes |
|---|---|---|
| `seat-ju` fires | `sfx_card_snap` | Ju 坐進駕駛座 |
| `seat-chester` fires | `sfx_card_snap` | Chester 坐進副駕駛座 |
| `nav-advance` fires | `sfx_progress_tick` | 旅程推進一格 |
| Scene enter | `sfx_ambient_car_hum` | 車內低頻環境音（optional，待音頻設計確認）|
| Scene completion | page-turn rustle | default handled by STUI |

---

## 10. Palette Override (Art Bible §4.2)

- `table_tint`: default Paper Warm `#F4EEDE`
- `bar_accent`: default

### 10.2 Ambient Background Plate (optional) — full-viewport parchment

A **full-viewport parchment background** whose ornamental filigree border
subtly weaves in motifs that *hint* at the scene's theme (e.g. kitchen
scene → mortar-and-pestle, whisk, wheat, coffee cup embedded in the
corner scrollwork). The centre 70% stays blank parchment so cards
dominate the main visual. Follows Art Bible §6 (scenes are composed
from cards, not from backgrounds — but a decorative plate is the one
exception that signals *place*).

| Field | Value |
|---|---|
| `ambient.path` | `res://assets/ambient/drive.png` |
| `ambient.anchor` | `"full_viewport"` (default — covers the whole logical viewport) |
| `ambient.alpha` | `0.9` |

Legacy corner mode (`"bottom_right"` etc.) is still supported by the
runtime for cases where a scene prefers a smaller vignette instead of a
full background, but new scenes should default to `"full_viewport"`.

**Art direction constraints**:
- Base: aged warm-cream parchment texture (`#F4EEDE`), no gradients,
  no strong colour blocks
- Frame: thin warm-brown-ink filigree (scrollwork, vines, leaves) along
  all four edges — never pure black
- Corner motifs: abstract scene hints woven *into* the ornamental line
  work, never placed as standalone objects
- Centre: empty parchment with subtle paper texture only
- **Forbidden**: text, letters, numbers, watermarks, centre focal
  subjects, literal scene depictions in the middle, perspective,
  shadows, gradient fills in the centre
- **Forbidden**: motifs that steal attention from cards (heavy ink,
  high contrast, saturated colour, animation)

To generate this background, run:
```
/img-background drive "car-road-trip" "steering wheel curl (top-left), map fold line (top-right), road sign silhouette (bottom-left), destination flag (bottom-right)"
```
Prompt template and all scene examples: see `img_generate.md` § 概念產生背景圖.

**Code wiring** (live in `src/ui/ambient_indicator.gd` — see
`production/epics/scene-composition/story-006`):
- `AmbientLayer` CanvasLayer at `layer = -1` so the plate sits behind
  `CardTable` (default layer 0)
- `ambient_indicator.gd` listens on `EventBus.scene_started`, reads
  this block from the scene JSON, sets `TextureRect.texture`, applies
  `modulate.a`, stretches to viewport (`STRETCH_SCALE`)
- `mouse_filter = MOUSE_FILTER_IGNORE` on all nodes so card drags pass
  through to the cards above

---

## 11. Epilogue Handoff

| Field | Value |
|---|---|
| `next_scene` | TBD — 待其他場景確定後填入 |
| On completion | `scene_completed` emitted by SceneManager（標準行為） |
| Epilogue content | 過場插圖 + 旁白文案（見下） |

### Transition Illustration

| Field | Value |
|---|---|
| Source photo | `https://photos.app.goo.gl/w3Q2efsVV4JRzCVL6` |
| Asset path | `res://assets/epilogue/drive-epilogue.png` |
| Display mode | 全螢幕淡入，停留，淡出 |

### Narration Text

```
予天地山水 與妳
```

> 設計意圖：場景描述的是一段開車去遠方的日常拌嘴。
> 結尾這句話把那趟旅程升華——不是目的地，是「跟妳一起」這件事本身。
> 照片配上山水風景，讓文案自然落地。

---

## 12. MUT Contribution (unlock tree)

- Recipes in this scene count toward `get_discovery_count()`: 5 discoveries（seat-ju, seat-chester, kingdom-nav, nav-upgrade, nav-advance）
- Milestone(s) this scene contributes to: none（mid-game scene）
- Is this the `final-memory` scene? NO
- Required-for-epilogue? NO

---

## 13. Carry-Forward

- Cards from this scene that persist into the next: 無（所有卡片留在此場景）
- Cards that are consumed and gone: `drive_seat_9`, `shotgun_10`（merge 時消費）、`nav_info`（每輪 nav-upgrade 後消費）、`better_nav_info`（每輪 nav-advance 後消費）
- Cards that stay on table throughout: `kingdom_far_away`（catalyst，keeps）、`chester_backseat`（catalyst，keeps）、`ju_driving`（catalyst，keeps）

---

## 14. STUI Transition Override [optional]

Entry in `assets/data/ui/transition-variants.tres` under this scene's key:

| Field | Value |
|---|---|
| fold_duration_scale | 1.0 (default) |
| paper_tint | hex or default |
| sfx_variant_id | name or default |

---

## 15. Scene-Level Constants / Open Questions

- `KNOWN_SCENE_IDS` 需新增 `"drive"` 條目

### Resolved Questions

**OQ-1: 場景過場插圖系統 — RESOLVED 2026-04-24**

Feature implemented by Story 007 (`production/epics/scene-transition-ui/story-007-interstitial-illustration.md`):
STUI now supports an `interstitial` dict per scene in `transition-variants.tres`
with keys `illustration` (Texture2D), `caption` (String), `hold_ms` (float).
The panel fades in above the overlay during HOLDING, holds for `hold_ms`, then
fades out before FADING_IN begins. Reduced-motion path skips the fade tweens.

Wire-up for this scene: add an entry to `assets/data/ui/transition-variants.tres`
under key `"drive"` with the interstitial dict pointing at
`res://assets/epilogue/drive-epilogue.png` and the narration from Section 11.
This is **content authoring**, not covered by `/create-scene` — do it after
the scene's data layer is scaffolded.

---

## 16. Generated Files (what `/create-scene [id]` produces / updates)

Auto-populated by the skill. Lists every file touched so code review can
eyeball the blast radius.

| File | Change type (create / append / replace) |
|---|---|
| `assets/data/cards.tres` | append N SubResources |
| `assets/data/recipes.tres` | append N SubResources |
| `assets/data/bar-effects.json` | add N keys |
| `assets/data/scenes/[scene-id].json` | create |
| `assets/data/scene-manifest.tres` | extend `scene_ids` |
| `src/core/card_database.gd` | extend `KNOWN_SCENE_IDS` |
| `design/assets/specs/[target]-assets.md` | add N asset specs |

---

## 17. Validation Checklist (what `/scene-audit [id]` checks)

- [ ] Every `seed_cards[*].card_id` exists in cards.tres
- [ ] Every recipe's `card_a` / `card_b` / `result_card` / `keeps` exists
- [ ] Every bar-effects key matches a recipe id
- [ ] Every bar_id in bar-effects is declared in the scene goal's `bars`
- [ ] Scene id is listed in `scene-manifest.tres`
- [ ] Scene id is in `KNOWN_SCENE_IDS`
- [ ] New card art files exist in `assets/cards/` OR deferred with placeholder
- [ ] Scene JSON passes `python3 -m json.tool`
- [ ] Recipe templates are lowercase (`.claude/rules/data-files.md`)
- [ ] Section 11 epilogue handoff is consistent with Section 12 MUT flags

---

## Feedback / Iteration Log

- YYYY-MM-DD — Playtest N (tester): score, flagged items, backlog links
