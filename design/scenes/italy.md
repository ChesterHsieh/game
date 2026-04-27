# Scene: 義大利

> **Status**: Draft
> **Last updated**: 2026-04-27
> **Source of truth**: this file. All generated data files are reconstructable
> from this spec via `/create-scene italy`.
>
> **How to use this template**: fill every section top-to-bottom. Run `/scene-audit
> italy` after filling to catch missing references before committing
> the implementation pass.

---

## 1. Identity

| Field | Value |
|---|---|
| `scene_id` | `italy` |
| `display_name` | 義大利 |
| `narrative_beat` | 陽光、義大利麵、還有那個瞬間——旅行把兩人拉得更近 |
| `manifest_order` | 7 |
| `phase` | Climax |

---

## 2. Seed State (cards on the table at scene start)

```
ju
chester
TODO: add seed card ids  (帶入 germany carry-forward 的牌)
```

---

## 3. New Cards (define in this scene — added to cards.tres)

### `TODO_card_id`
| Field | Value |
|---|---|
| type | person / place / feeling / object / moment / inside_joke / seed |
| display_name | TODO |
| flavor_text | TODO |
| scene_id | `italy` |
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
| threshold | 90 |
| duration_sec | 1.5 |

---

## 6. Left Panel Content (status bars)

| id | label | initial_value | decay_rate_per_sec |
|---|---|---|---|
| `romance` | 浪漫感 | 30 | 0.3 |

---

## 7. Bar Effects

```json
"TODO-recipe-id": { "romance": +20 }
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
| Scene enter | ambient loop | *(TBD — 義大利廣場、噴泉聲、手風琴)* |
| Scene completion | page-turn rustle | default handled by STUI |

---

## 10. Palette Override

- `table_tint`: `#F4EEDE` (default Paper Warm)
- `bar_accent`: default

### 10.2 Ambient Background Plate

| Field | Value |
|---|---|
| `ambient.path` | `res://assets/ambient/italy.png` |
| `ambient.anchor` | `"full_viewport"` |
| `ambient.alpha` | `0.9` |

---

## 11. Epilogue Handoff

| Field | Value |
|---|---|
| `next_scene` | `tenth-anniversary` |
| On completion | `scene_completed` emits; advance to next scene |

---

## 12. MUT Contribution

- Recipes in this scene count toward `get_discovery_count()`: TODO discoveries
- Is this the `final-memory` scene? NO
- Required-for-epilogue? YES

---

## 13. Carry-Forward

- Cards that persist into the tenth-anniversary scene: TODO
- Cards consumed and gone: TODO

---

## 14. STUI Transition Override [optional]

| Field | Value |
|---|---|
| fold_duration_scale | 1.2 |
| paper_tint | default |
| sfx_variant_id | default |

---

## 15. Scene-Level Constants / Open Questions

- `KNOWN_SCENE_IDS` 需新增 `"italy"`
- [ ] 哪些城市？（羅馬、佛羅倫斯、威尼斯？）
- [ ] 特別的義大利時刻：吃什麼？看什麼？有沒有「那個瞬間」？
- [ ] 這是 Climax 場景 — 情感張力比前幾場更高，puzzle 設計要反映
- [ ] Required-for-epilogue: YES — 代表玩家必須完成這關才能觸發結局

---

## 16. Generated Files

| File | Change type |
|---|---|
| `assets/data/cards.tres` | append N SubResources |
| `assets/data/recipes.tres` | append N SubResources |
| `assets/data/bar-effects.json` | add N keys |
| `assets/data/scenes/italy.json` | create |
| `assets/data/scene-manifest.tres` | extend `scene_ids` |
| `src/core/card_database.gd` | extend `KNOWN_SCENE_IDS` |

---

## 17. Validation Checklist

- [ ] Every seed card resolves
- [ ] Every recipe has valid card references
- [ ] All template values lowercase
- [ ] Bar effects keys match recipe ids
- [ ] Scene id in manifest and KNOWN_SCENE_IDS
- [ ] Section 11 epilogue handoff consistent with Section 12 MUT flags

---

## Feedback / Iteration Log

- 2026-04-27 — Template scaffolded, pending design details
