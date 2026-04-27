# Scene: 十週年總結

> **Status**: Draft
> **Last updated**: 2026-04-27
> **Source of truth**: this file. All generated data files are reconstructable
> from this spec via `/create-scene tenth-anniversary`.
>
> **How to use this template**: fill every section top-to-bottom. Run `/scene-audit
> tenth-anniversary` after filling to catch missing references before committing
> the implementation pass.

---

## 1. Identity

| Field | Value |
|---|---|
| `scene_id` | `tenth-anniversary` |
| `display_name` | 十週年 |
| `narrative_beat` | 十年的碎片重新拼在一起——這就是我們的故事 |
| `manifest_order` | 8 |
| `phase` | Epilogue |

---

## 2. Seed State (cards on the table at scene start)

```
ju
chester
TODO: carry-forward cards from italy + all previous highlights
```

All carried-forward cards from previous scenes arrive at the table together.

---

## 3. New Cards (define in this scene — added to cards.tres)

### `TODO_card_id`
| Field | Value |
|---|---|
| type | moment / feeling |
| display_name | TODO |
| flavor_text | TODO |
| scene_id | `tenth-anniversary` |
| art_path | `res://assets/cards/TODO_card_id.png` |

> Cards referenced but already defined elsewhere — do NOT re-define:
> `ju`, `chester`, + all carry-forward cards from prior scenes

---

## 4. Puzzle Graph (recipes — added to recipes.tres, scene-scoped)

Readable summary:

```
TODO: recipe_id : card_a + card_b → result_card  [template, keeps: X | notes]
(這場景的 recipe 是把前面所有回憶配對，產生「十年的回憶」這張最終牌)
```

### `TODO-recipe-id`
| Field | Value |
|---|---|
| id | `TODO-recipe-id` |
| card_a | `TODO` |
| card_b | `TODO` |
| template | `merge` |
| result_card | `ten_years_of_us` |
| keeps | — |
| emote | `heart` |

---

## 5. Win Condition

| Field | Value |
|---|---|
| type | `reach_value` |
| bars | see §6 |
| max_value | 100 |
| threshold | 100 |
| duration_sec | 2.0 |

---

## 6. Left Panel Content (status bars)

| id | label | initial_value | decay_rate_per_sec |
|---|---|---|---|
| `love` | 十年的愛 | 0 | 0 |

---

## 7. Bar Effects

```json
"TODO-recipe-id": { "love": +20 }
```

---

## 8. Hint System

| Field | Value |
|---|---|
| stagnation_sec | 600 |
| level_1_cue | *(TBD)* |
| level_2_cue | *(TBD)* |

---

## 9. Audio Cues

| Event | SFX | Notes |
|---|---|---|
| Scene enter | ambient loop | *(TBD — 溫暖、懷舊、感動)* |
| Win condition met | special fanfare | 比其他場景更有重量感 |
| Scene completion | page-turn rustle → epilogue music | final scene |

---

## 10. Palette Override

- `table_tint`: `#F4EEDE` (default Paper Warm)
- `bar_accent`: default (or gold?)

### 10.2 Ambient Background Plate

| Field | Value |
|---|---|
| `ambient.path` | `res://assets/ambient/tenth-anniversary.png` |
| `ambient.anchor` | `"full_viewport"` |
| `ambient.alpha` | `0.9` |

---

## 11. Epilogue Handoff

| Field | Value |
|---|---|
| `next_scene` | `none` |
| On completion | `scene_completed` emits; `epilogue_started` fires → final epilogue sequence |

### Interstitial Slides

```
interstitial:
  slides:
    - illustration: res://assets/epilogue/tenth-anniversary-1.png
      caption: "十年，謝謝你。"
      hold_ms: 5000
    - illustration: res://assets/epilogue/tenth-anniversary-2.png
      caption: "TODO"
      hold_ms: 6000
```

---

## 12. MUT Contribution

- Is this the `final-memory` scene? YES
- Required-for-epilogue? YES
- Completing this scene unlocks the full epilogue

---

## 13. Carry-Forward

- No carry-forward — this is the final scene

---

## 14. STUI Transition Override

| Field | Value |
|---|---|
| fold_duration_scale | 1.5 |
| paper_tint | default |
| sfx_variant_id | `epilogue` |

---

## 15. Scene-Level Constants / Open Questions

- `KNOWN_SCENE_IDS` 需新增 `"tenth-anniversary"`
- [ ] 最終牌 `ten_years_of_us` 的圖像設計：匯集了所有場景的元素？
- [ ] 十週年的 epilogue 文字：這是整個遊戲的結語，要仔細寫
- [ ] bar `love` 不衰退、threshold 100 → 玩家完成所有配對才贏，象徵「圓滿」
- [ ] Interstitial slides：要放真實照片還是插圖風格？
- [ ] 這是 Ju 會最後看到的畫面 — 每一個字都值得花時間

---

## 16. Generated Files

| File | Change type |
|---|---|
| `assets/data/cards.tres` | append N SubResources |
| `assets/data/recipes.tres` | append N SubResources |
| `assets/data/bar-effects.json` | add N keys |
| `assets/data/scenes/tenth-anniversary.json` | create |
| `assets/data/scene-manifest.tres` | extend `scene_ids` |
| `src/core/card_database.gd` | extend `KNOWN_SCENE_IDS` |

---

## 17. Validation Checklist

- [ ] Every seed card resolves (including all carry-forward cards)
- [ ] Every recipe has valid card references
- [ ] All template values lowercase
- [ ] Bar effects keys match recipe ids
- [ ] Scene id in manifest and KNOWN_SCENE_IDS
- [ ] `next_scene: none` + `final-memory: YES` → epilogue content slot not empty
- [ ] Interstitial slides exist on disk if declared

---

## Feedback / Iteration Log

- 2026-04-27 — Template scaffolded, pending design details
