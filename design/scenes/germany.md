# Scene: 德國旅行

> **Status**: Draft
> **Last updated**: 2026-04-27
> **Source of truth**: this file. All generated data files are reconstructable
> from this spec via `/create-scene germany`.
>
> **How to use this template**: fill every section top-to-bottom. Run `/scene-audit
> germany` after filling to catch missing references before committing
> the implementation pass.

---

## 1. Identity

| Field | Value |
|---|---|
| `scene_id` | `germany` |
| `display_name` | 德國旅行 |
| `narrative_beat` | 期待已久的旅程——異國的街道，只屬於兩個人的回憶 |
| `manifest_order` | 5 |
| `phase` | Mid-game |

---

## 2. Seed State (cards on the table at scene start)

```
ju
chester
TODO: add seed card ids  (帶入 save-for-italy carry-forward 的牌)
```

---

## 3. New Cards (define in this scene — added to cards.tres)

### `TODO_card_id`
| Field | Value |
|---|---|
| type | person / place / feeling / object / moment / inside_joke / seed |
| display_name | TODO |
| flavor_text | TODO |
| scene_id | `germany` |
| art_path | `res://assets/cards/TODO_card_id.png` |

> Cards referenced but already defined elsewhere — do NOT re-define:
> `ju`, `chester`

---

## 4. Puzzle Graph (recipes — added to recipes.tres, scene-scoped)

Readable summary:

```
TODO: recipe_id : card_a + card_b → result_card  [template, keeps: X | notes]
```

### `TODO-recipe-id`
| Field | Value |
|---|---|
| id | `TODO-recipe-id` |
| card_a | `TODO` |
| card_b | `TODO` |
| template | `merge` |
| result_card | `TODO` |
| keeps | — |
| emote | `heart` |

---

## 5. Win Condition

| Field | Value |
|---|---|
| type | `reach_value` |
| bars | see §6 |
| max_value | 100 |
| threshold | 80 |
| duration_sec | 1.0 |

---

## 6. Left Panel Content (status bars)

| id | label | initial_value | decay_rate_per_sec |
|---|---|---|---|
| `wonder` | 驚喜感 | 40 | 0.4 |

---

## 7. Bar Effects

```json
"TODO-recipe-id": { "wonder": +20 }
```

---

## 8. Hint System

| Field | Value |
|---|---|
| stagnation_sec | 300 |
| level_1_cue | *(TBD)* |
| level_2_cue | *(TBD)* |

---

## 9. Audio Cues

| Event | SFX | Notes |
|---|---|---|
| Scene enter | ambient loop | *(TBD — 歐洲廣場感、街頭音樂)* |
| Scene completion | page-turn rustle | default handled by STUI |

---

## 10. Palette Override

- `table_tint`: `#F4EEDE` (default Paper Warm)
- `bar_accent`: default

### 10.2 Ambient Background Plate

| Field | Value |
|---|---|
| `ambient.path` | `res://assets/ambient/germany.png` |
| `ambient.anchor` | `"full_viewport"` |
| `ambient.alpha` | `0.9` |

---

## 11. Epilogue Handoff

| Field | Value |
|---|---|
| `next_scene` | `save-for-italy` |
| On completion | `scene_completed` emits; advance to next scene |

---

## 12. MUT Contribution

- Recipes in this scene count toward `get_discovery_count()`: TODO discoveries
- Is this the `final-memory` scene? NO
- Required-for-epilogue? NO

---

## 13. Carry-Forward

- Cards that persist into the next (義大利場景): TODO
- Cards consumed and gone: TODO

---

## 14. STUI Transition Override [optional]

| Field | Value |
|---|---|
| fold_duration_scale | 1.0 |
| paper_tint | default |
| sfx_variant_id | default |

---

## 15. Scene-Level Constants / Open Questions

- `KNOWN_SCENE_IDS` 需新增 `"germany"`
- [ ] 哪些城市或地標？（慕尼黑？柏林？）
- [ ] 食物牌：德國豬腳、啤酒、市集熱紅酒？
- [ ] 特別的旅行時刻：迷路、博物館、夜晚街道？
- [ ] 與 italy scene 的敘事銜接：德國 → 義大利是同一趟旅程嗎？

---

## 16. Generated Files

| File | Change type |
|---|---|
| `assets/data/cards.tres` | append N SubResources |
| `assets/data/recipes.tres` | append N SubResources |
| `assets/data/bar-effects.json` | add N keys |
| `assets/data/scenes/germany.json` | create |
| `assets/data/scene-manifest.tres` | extend `scene_ids` |
| `src/core/card_database.gd` | extend `KNOWN_SCENE_IDS` |

---

## 17. Validation Checklist

- [ ] Every seed card resolves
- [ ] Every recipe has valid card references
- [ ] All template values lowercase
- [ ] Bar effects keys match recipe ids
- [ ] Scene id in manifest and KNOWN_SCENE_IDS

---

## Feedback / Iteration Log

- 2026-04-27 — Template scaffolded, pending design details
