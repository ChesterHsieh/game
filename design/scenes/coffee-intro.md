# Scene: Coffee Intro

> **Status**: Live (first playable — served as Vertical Slice)
> **Last updated**: 2026-04-23
> **Source of truth**: this file. All generated data files (cards.tres,
> recipes.tres, bar-effects.json, coffee-intro.json, scene-manifest.tres)
> are reconstructable from this spec via `/create-scene coffee-intro`.

---

## 1. Identity

| Field | Value |
|---|---|
| `scene_id` | `coffee-intro` |
| `display_name` | Coffee Intro |
| `narrative_beat` | The quiet ritual that starts everything — making coffee for Ju |
| `manifest_order` | 0 (first scene the player sees) |
| `phase` | Tutorial / emotional on-ramp |

---

## 2. Seed State (cards on the table at scene start)

```
chester, ju, coffee_machine, coffee_beans
```

Order = declaration order; TableLayoutSystem randomises positions within the
play area, deterministically if `rng_seed` is pinned.

---

## 3. New Cards (define in this scene — added to cards.tres)

### `coffee_machine`
| Field | Value |
|---|---|
| type | object (enum 3) |
| display_name | Coffee Machine |
| flavor_text | Hums before sunrise. |
| art_style | Template B (ink-line object card) |
| art_path | `res://assets/cards/coffee_machine.png` |

### `coffee_beans`
| Field | Value |
|---|---|
| type | object (enum 3) |
| display_name | Coffee Beans |
| flavor_text | Dark roast, fair trade. |
| art_style | Template B |
| art_path | `res://assets/cards/coffee_beans.png` |

### `coffee`
| Field | Value |
|---|---|
| type | object (enum 3) |
| display_name | Coffee |
| flavor_text | Still steaming. |
| art_style | Template B |
| art_path | `res://assets/cards/coffee.png` |

> Existing cards referenced but not defined here (must already exist):
> `chester`, `ju`, `seed-together`

---

## 4. Puzzle Graph (recipes — added to recipes.tres, scene-scoped)

```
brew-coffee      : coffee_machine + coffee_beans → coffee        [keeps: coffee_machine]
deliver-coffee   : coffee + ju                  → seed-together  [WIN — fires affection +100]
```

### `brew-coffee`
| Field | Value |
|---|---|
| id | `brew-coffee` |
| card_a | `coffee_machine` |
| card_b | `coffee_beans` |
| template | `merge` |
| result_card | `coffee` |
| keeps | `coffee_machine` *(catalyst — stays on the table, no merge animation)* |
| emote | `spark` *(success / aha — coffee is ready)* |

### `deliver-coffee`
| Field | Value |
|---|---|
| id | `deliver-coffee` |
| card_a | `coffee` |
| card_b | `ju` |
| template | `merge` |
| result_card | `seed-together` |
| keeps | *(none — both consumed)* |
| emote | `heart` *(affection delivered — Ju receives the coffee)* |

---

## 5. Win Condition (goal config in `assets/data/scenes/coffee-intro.json`)

| Field | Value |
|---|---|
| type | `reach_value` |
| bars | `[{ id: "affection", initial_value: 0, decay_rate_per_sec: 0.0 }]` |
| max_value | 100 |
| threshold | 100 |
| duration_sec | 0.1 (near-instant fire once threshold hit) |

Implicit: no sustain. The `deliver-coffee` recipe adds exactly threshold,
so the scene completes the moment Coffee merges with Ju.

---

## 6. Left Panel Content (status bars visible during the scene)

- **affection** bar — starts at 0, no decay, max 100

Panel size uses the reduced tuning (`panel_width_px=90`, `bar_height_px=60`,
`bar_width_px=12`) — see StatusBarUI exports. If a scene needs a different
panel treatment (e.g. multiple bars), override per-scene via exported
tuning knobs.

---

## 7. Bar Effects (`assets/data/bar-effects.json` — recipe_id → bar deltas)

```json
"deliver-coffee": { "affection": 100 }
```

`brew-coffee` has no bar effect — it only produces a card.

---

## 8. Hint System (per-scene timing)

Current: default (HintSystem uses `STAGNATION_SEC=300` fallback). The
tutorial is short enough that no hint should ever fire.

Future scenes may override via a per-scene `hint_stagnation_sec` field
in the scene JSON (SceneGoal already reads this).

---

## 9. Audio Cues (recipe-triggered SFX)

| Event | SFX | Notes |
|---|---|---|
| `brew-coffee` fires | *(none yet — deferred to Polish)* | candidate: soft kettle hum |
| `deliver-coffee` fires | *(none yet)* | candidate: ceramic clink |
| Scene completion | STUI page-turn rustle | handled by STUI's existing SFX |

---

## 10. Palette Override (Art Bible §4.2)

- `table_tint`: default Paper Warm `#F4EEDE` (no override — baseline scene)
- `bar_accent` for affection: warm amber (default `COLOR_BAR_FILL` in StatusBarUI)

### 10.2 Ambient Background Plate

| Field | Value |
|---|---|
| `ambient.path` | `res://assets/ambient/coffee-intro.png` ✅ committed 2026-04-23 (regen) |
| `ambient.anchor` | `full_viewport` |
| `ambient.alpha` | `0.9` |

**Subject**: ornate warm-cream parchment plate with filigree frame.
Four corner motifs (all integrated into the scrollwork, not placed as
objects): mortar-and-pestle (top-left), whisk (top-right), wheat stalk
(bottom-left), coffee cup with steam (bottom-right). Centre is empty
parchment where cards sit. Warm brown ink only — no text, no centre
illustration, no strong contrast.

Generated via nano-banana using the reusable prompt template
(`_TEMPLATE.md` §10.2). Filled with `{SCENE_CONCEPT}` =
"kitchen-morning" and the four motifs above. Downscaled via
`sips -Z 720` (~770 KB on disk).

**Supersedes**: the earlier corner-vignette concept (coffee cup + window
+ "morning" label in a 160×160 parchment frame at bottom-right). That
direction read as too on-the-nose — it showed the scene instead of
*suggesting* it. The new background plate keeps the hint subtle and
lets cards remain the focal point.

---

## 11. Epilogue Handoff

| Field | Value |
|---|---|
| `next_scene` | `drive` |
| On completion | SceneManager triggers `_enter_epilogue()` → emits `epilogue_started` |
| FES behaviour | arms `cover_ready_timeout` watchdog; after 5s fades in (no illustration yet → background-color fallback) |
| Epilogue content | **DEFERRED** — see backlog: "結局黑幕可以新增照片或是一些描述" |

---

## 12. MUT Contribution (unlock tree)

- `deliver-coffee` discovery counts toward `get_discovery_count()`
- This scene contributes: 2 discoveries (`brew-coffee`, `deliver-coffee`)
- No milestone explicitly requires completion of this scene in MVP
- Not marked as `final-memory` — so epilogue conditions are not met after
  this scene alone

---

## 13. Carry-Forward

None in MVP (single-scene game currently). When a second scene lands:
- Candidate to carry: `seed-together` (the memory left behind after delivery)
- `chester` stays (global character card)

---

## 14. STUI Transition Override

Default (no override in `assets/data/ui/transition-variants.tres`). The
scene uses the standard cream page-turn with baseline timings.

---

## 15. Scene-Level Constants / Open Questions

- `KNOWN_SCENE_IDS` in `src/core/card_database.gd` MUST include
  `"coffee-intro"` so the new cards' `scene_id` doesn't trigger orphan
  warnings. (One-time addition; future scenes add their own ids here.)

---

## 16. Generated Files (what `/create-scene coffee-intro` produces / updates)

| File | Change |
|---|---|
| `assets/data/cards.tres` | +3 SubResource blocks (coffee_machine, coffee_beans, coffee), +3 ExtResource textures, entries array appended |
| `assets/data/recipes.tres` | +2 SubResource blocks (brew-coffee, deliver-coffee), entries array appended |
| `assets/data/bar-effects.json` | +1 key: `"deliver-coffee"` |
| `assets/data/scenes/coffee-intro.json` | created |
| `assets/data/scene-manifest.tres` | `scene_ids` extended with `"coffee-intro"` at index 0 |
| `src/core/card_database.gd` | `KNOWN_SCENE_IDS` extended |
| `assets/cards/coffee_machine.png`, `coffee_beans.png`, `coffee.png` | user places (via `/asset-spec` + nano-banana) |
| `design/assets/specs/card-database-assets.md` | +3 asset specs for the new object cards |
| `design/assets/asset-manifest.md` | +3 asset rows |

---

## 17. Validation Checklist (what `/scene-audit coffee-intro` checks)

- [ ] Every `seed_cards[*].card_id` exists in cards.tres
- [ ] Every recipe's `card_a` / `card_b` / `result_card` / `keeps` exists in cards.tres
- [ ] Every bar-effects key matches a recipe id in recipes.tres
- [ ] Every bar_id referenced in bar-effects deltas is declared in the scene goal's `bars`
- [ ] Scene id is listed in `scene-manifest.tres`
- [ ] Scene id is in `KNOWN_SCENE_IDS`
- [ ] New card art files exist in `assets/cards/` OR are deferred placeholders
- [ ] Scene JSON passes `python3 -m json.tool`
- [ ] Recipe templates are lowercase (per `.claude/rules/data-files.md` enum-ish rule)

---

## Feedback / Iteration Log

- 2026-04-23 — First playtest (Chester, solo): 4/5 on core mechanic feel.
  Flagged needs: (a) stronger magnetic attract + push-away juice, (b)
  epilogue needs photo + descriptive text as the emotional "forced input"
  beat. Both items moved to Production backlog.
