# Scene: 遠戀 2016–2020

> **Status**: Draft
> **Last updated**: 2026-04-27
> **Source of truth**: this file. All generated data files are reconstructable
> from this spec via `/create-scene long-distance`.
>
> **How to use this template**: fill every section top-to-bottom. Sections
> marked [optional] can be deleted if not applicable. Run `/scene-audit
> long-distance` after filling to catch missing references before committing
> the implementation pass.

---

## 1. Identity

| Field | Value |
|---|---|
| `scene_id` | `long-distance` |
| `display_name` | 遠戀 2016–2020 |
| `narrative_beat` | 跨越太平洋的思念——用小小的儀式對抗遠距離的孤獨 |
| `manifest_order` | 3 |
| `phase` | Mid-game |

---

## 2. Seed State (cards on the table at scene start)

```
ju
chester
TODO: add seed card ids
```

Every `card_id` must either already exist in `cards.tres` or be defined
in Section 3 below.

---

## 3. New Cards (define in this scene — added to cards.tres)

### `TODO_card_id`
| Field | Value |
|---|---|
| type | person / place / feeling / object / moment / inside_joke / seed |
| display_name | TODO |
| flavor_text | TODO |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/TODO_card_id.png` |

> Cards referenced but already defined elsewhere — list here for reviewer
> awareness, do NOT re-define:
> `ju`, `chester`

---

## 4. Puzzle Graph (recipes — added to recipes.tres, scene-scoped)

Readable summary:

```
TODO: recipe_id : card_a + card_b → result_card  [template, keeps: X | notes]
```

Then per-recipe detail:

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

## 5. Win Condition (goal config in `assets/data/scenes/long-distance.json`)

| Field | Value |
|---|---|
| type | `reach_value` |
| bars | see §6 |
| max_value | 100 |
| threshold | 80 |
| duration_sec | 1.0 |

---

## 6. Left Panel Content (status bars visible during the scene)

| id | label | initial_value | decay_rate_per_sec |
|---|---|---|---|
| `connection` | 連結感 | 20 | 0.5 |

---

## 7. Bar Effects (`assets/data/bar-effects.json` — recipe_id → bar deltas)

```json
"TODO-recipe-id": { "connection": +20 }
```

---

## 8. Hint System (per-scene timing)

| Field | Value |
|---|---|
| stagnation_sec | 300 |
| level_1_cue | *(TBD)* |
| level_2_cue | *(TBD)* |

---

## 9. Audio Cues (recipe-triggered SFX + ambient)

| Event | SFX | Notes |
|---|---|---|
| Scene enter | ambient loop | *(TBD — 安靜、帶點思念的背景音)* |
| Scene completion | page-turn rustle | default handled by STUI |

---

## 10. Palette Override (Art Bible §4.2)

- `table_tint`: `#F4EEDE` (default Paper Warm)
- `bar_accent`: default

### 10.2 Ambient Background Plate (optional) — full-viewport parchment

| Field | Value |
|---|---|
| `ambient.path` | `res://assets/ambient/long-distance.png` |
| `ambient.anchor` | `"full_viewport"` |
| `ambient.alpha` | `0.9` |

---

## 11. Epilogue Handoff

| Field | Value |
|---|---|
| `next_scene` | `board-games` |
| On completion | `scene_completed` emits; advance to next scene |

### Interstitial Slides [optional]

```
interstitial:
  slides:
    - illustration: res://assets/epilogue/long-distance-1.png
      caption: "TODO 中文句子"
      hold_ms: 4000
```

---

## 12. MUT Contribution (unlock tree)

- Recipes in this scene count toward `get_discovery_count()`: TODO discoveries
- Milestone(s) this scene contributes to: TODO (or none)
- Is this the `final-memory` scene? NO
- Required-for-epilogue? NO

---

## 13. Carry-Forward

- Cards from this scene that persist into the next: TODO
- Cards that are consumed and gone: TODO

---

## 14. STUI Transition Override [optional]

| Field | Value |
|---|---|
| fold_duration_scale | 1.0 |
| paper_tint | default |
| sfx_variant_id | default |

---

## 15. Scene-Level Constants / Open Questions

- `KNOWN_SCENE_IDS` 需新增 `"long-distance"`
- [ ] 遠戀的核心物件牌：電話、訊息、時差、倒數？
- [ ] 具體的儀式片段（每天固定通話、互寄包裹、一起看電影？）
- [ ] 地理背景：2016–2020 Chester 在哪？Ju 在哪？
- [ ] bar 設計：「連結感」衰退 → 玩家透過配對重建連結

---

## 16. Generated Files (what `/create-scene long-distance` produces / updates)

| File | Change type (create / append / replace) |
|---|---|
| `assets/data/cards.tres` | append N SubResources |
| `assets/data/recipes.tres` | append N SubResources |
| `assets/data/bar-effects.json` | add N keys |
| `assets/data/scenes/long-distance.json` | create |
| `assets/data/scene-manifest.tres` | extend `scene_ids` |
| `src/core/card_database.gd` | extend `KNOWN_SCENE_IDS` |
| `design/assets/specs/card-database-assets.md` | add N asset specs |

---

## 17. Validation Checklist (what `/scene-audit long-distance` checks)

**Referential integrity**
- [ ] Every `seed_cards[*].card_id` exists in cards.tres
- [ ] Every recipe's `card_a` / `card_b` / `result_card` (if present) / `spawns` exists
- [ ] Every entry in a recipe's `keeps` array refers to `card_a` or `card_b` of that recipe
- [ ] Every bar-effects key matches a recipe id
- [ ] Every bar_id in bar-effects is declared in the scene goal's `bars`

**Template well-formedness**
- [ ] All `template` values are lowercase
- [ ] `reject` recipes have `repulsion_multiplier`; no `result_card`, no `spawns`
- [ ] `additive` recipes have `spawns`

**Manifest + constants**
- [ ] Scene id is listed in `scene-manifest.tres`
- [ ] Scene id is in `KNOWN_SCENE_IDS`
- [ ] Scene JSON passes `python3 -m json.tool`

---

## Feedback / Iteration Log

- 2026-04-27 — Template scaffolded, pending design details
