# Scene: [Scene Name]

> **Status**: Draft / Live / Deprecated
> **Last updated**: YYYY-MM-DD
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
| `scene_id` | `kebab-case-id` |
| `display_name` | Human-readable title (narrative-facing) |
| `narrative_beat` | One sentence: what this scene is about emotionally |
| `manifest_order` | Integer (0 = first scene in game) |
| `phase` | Tutorial / Mid-game / Climax / Epilogue |

---

## 2. Seed State (cards on the table at scene start)

```
card_id_1, card_id_2, card_id_3, ...
```

Every `card_id` must either already exist in `cards.tres` or be defined
in Section 3 below.

---

## 3. New Cards (define in this scene — added to cards.tres)

### `new_card_id_1`
| Field | Value |
|---|---|
| type | person / place / feeling / object / moment / inside_joke / seed |
| display_name | Title shown on the card |
| flavor_text | (optional) short diary-style line |
| art_path | `res://assets/cards/[card_id].png` |

Art is generated via `/img-card <concept>` after the spec lands — do
not embed prompts here. Placeholder art is acceptable at spec time.

(repeat per new card)

> Cards referenced but already defined elsewhere — list here for reviewer
> awareness, do NOT re-define:
> `existing_card_a`, `existing_card_b`

---

## 4. Puzzle Graph (recipes — added to recipes.tres, scene-scoped)

Readable summary first:

```
recipe_id  : card_a + card_b → result_card  [template, keeps: X | notes]
```

Then per-recipe detail:

### `recipe_id_1`
| Field | Value |
|---|---|
| id | `recipe-id-kebab-case` |
| card_a | `card_id` |
| card_b | `card_id` |
| template | `merge` / `additive` / `reject` / `animate` / `generator` (lowercase!) |
| result_card | `card_id` (for merge / additive) — **optional for merge** (see below) |
| keeps | `card_id` (single catalyst) OR `[card_id, card_id]` (dual catalyst) — see template-specific semantics below |
| emote | `spark` / `heart` / `ok` / `sweat` / `anger` / `question` / `exclaim` / `zzz` — bubble to pop when the recipe fires; omit or `"none"` = no emote |
| other config | spawns / motion / interval / max_count / repulsion_multiplier — template-specific |

Emote values are the filename stem (without `.png`) of any file in
`assets/emotes/`. See `.claude/rules/data-files.md` — emote is an
enum-ish field, use lowercase.

### Template-specific semantics

**`merge`** — two cards combine into `result_card`.
- No `keeps` → both inputs consumed, product spawns at midpoint.
- `keeps: "card_id"` → that card stays, the other is consumed.
- `keeps: ["id_a", "id_b"]` → **dual catalyst** (both stay), product still spawns.
- `result_card` is OPTIONAL. Omitting it → pure "consume + fire bar-delta" pattern
  (e.g. `scenic-advance-ju`: consumes scenic_view, keeps ju_driving, no new card —
  bar effect alone from `bar-effects.json`).

**`additive`** — spawns new cards next to the pair.
- No `keeps` → both inputs stay on the table (classic spawn-and-keep).
- `keeps: "card_id"` → that card stays, the other is **consumed**. Other non-`keeps` sides consumed.
- `spawns: [card_id, ...]` — required. Can be empty `[]` if the recipe's purpose is
  only firing a bar-delta.

**`reject`** — two cards refuse to combine, bounce apart.
- `repulsion_multiplier: float` — e.g. `2.0` (required, default 1.0 if absent).
- `emote: "anger"` / etc (optional). Bubble pops on one card mid-bounce.
- **No** `result_card`, **no** `spawns`, **no** `keeps` — both cards always stay.
- **Never enters cooldown** — reject fires every time the player retries the pair.
- Also **never emits `combination_executed`** — bar-effects will NOT run. HintSystem
  / MUT / StatusBarSystem stay blind to reject fires by design.

**`generator`** — one card periodically emits another while the pair sits together.
- `generates: card_id` — what to spawn per tick (required).
- `interval_sec: float` — seconds between spawns (required).
- `max_count: int | null` — cap before auto-stop; `null` = unlimited.
- `generator_card: "card_a" | "card_b"` — which slot is the "producer" (stays put;
  both cards stay on table).

**`animate`** — visual flourish only, no state change (motion/speed/target/duration).
Currently a no-op success path per ITF implementation notes.

(repeat per recipe)

---

## 5. Win Condition (goal config in `assets/data/scenes/[scene-id].json`)

| Field | Value |
|---|---|
| type | `reach_value` / `sustain_above` |
| bars | `[{ id, label, initial_value, decay_rate_per_sec }]` (see §6) |
| max_value | N |
| threshold | N |
| duration_sec | N — see clarification below |

**`duration_sec` semantics**:
- For `sustain_above`: every bar must sit ≥ threshold continuously for this long.
- For `reach_value`: bar must stay **at or above** threshold for this many seconds
  after first reaching it before `win_condition_met` fires. Values 0.5–1.0s feel
  instant to the player; values >2.0 only make sense if decay can pull you back down.

> Goal types currently supported: `sustain_above`, `reach_value`.
> `find_key` and `sequence` are defined in GDD but not wired in SceneGoal code.

---

## 6. Left Panel Content (status bars visible during the scene)

Each bar entry (lives in scene JSON `goal.bars[]` AND drives StatusBarUI):

| Field | Value | Purpose |
|---|---|---|
| id | `snake_case_id` | Internal key — must match all `bar-effects.json` value keys |
| label | `"中文 or English"` | String shown under the bar in StatusBarUI (CJK-safe) |
| initial_value | `N` | Bar starting value |
| decay_rate_per_sec | `N` | Per-second drain; `0` = no decay |

Example:
```json
{ "id": "journey_progress", "label": "旅程進度", "initial_value": 0, "decay_rate_per_sec": 0 }
```

List every bar shown during this scene. If the StatusBarUI panel layout
needs overriding (e.g. >2 bars), note the required tuning-knob overrides here.

---

## 7. Bar Effects (`assets/data/bar-effects.json` — recipe_id → bar deltas)

```json
"recipe-id-1": { "bar_id": +N },
"recipe-id-2": { "bar_id_a": +N, "bar_id_b": -N }
```

Every key MUST match a recipe in Section 4.
Every value key MUST match a `bar_id` in Section 6.

---

## 8. Hint System (per-scene timing)

| Field | Value |
|---|---|
| stagnation_sec | N (default 300 if omitted — use lower for tutorial) |
| level_1_cue | *(future)* what the faint hint arc suggests |
| level_2_cue | *(future)* the more explicit hint |

---

## 9. Audio Cues (recipe-triggered SFX + ambient)

| Event | SFX | Notes |
|---|---|---|
| `recipe_id_1` fires | `sfx_name` | description |
| Scene enter | ambient loop | (optional) |
| Scene completion | page-turn rustle | default handled by STUI |

---

## 10. Palette Override (Art Bible §4.2)

- `table_tint`: default Paper Warm `#F4EEDE` or override hex
- `bar_accent`: default or scene-specific hex

### 10.2 Ambient Background Plate (optional) — full-viewport parchment

A **full-viewport parchment background** whose ornamental filigree border
subtly weaves in motifs that *hint* at the scene's theme. The centre
70% stays blank parchment so cards dominate the main visual. Follows
Art Bible §6.

| Field | Value |
|---|---|
| `ambient.path` | `res://assets/ambient/[scene-id].png` (or `"none"` to skip) |
| `ambient.anchor` | `"full_viewport"` (default — covers the whole logical viewport) |
| `ambient.alpha` | `0.9` default |

Legacy corner mode (`"bottom_right"` etc.) is still supported by the
runtime for cases where a scene prefers a smaller vignette instead of a
full background, but new scenes should default to `"full_viewport"`.

Generate the background via `/img-background <scene-id> "<theme>"
"<corner-motifs>"` — the skill owns the prompt. Do not duplicate prompt
text here.

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
| `next_scene` | `[scene-id]` or `none` (epilogue triggers after) |
| On completion | `scene_completed` always emits; `epilogue_started` fires if `next_scene == none` |

### Interstitial Slides [optional — lives in `transition-variants.tres`]

Between `scene_completed` and `FADING_IN`, STUI plays any slides declared
here. Each slide fades in, holds, fades out, then the next one starts.
When the queue empties, STUI returns to IDLE (and if deferred, enters
EPILOGUE state). Caption supports CJK — STUI preloads a CJK SystemFont.

```
interstitial:
  slides:
    - illustration: res://assets/epilogue/<scene-id>-1.png
      caption: "中文句子 OK"
      hold_ms: 3000
    - illustration: res://assets/epilogue/<scene-id>-photo.jpg
      caption: ""
      hold_ms: 8000
```

Single-slide legacy form (still accepted):
```
interstitial: { illustration, caption, hold_ms }
```

---

## 12. MUT Contribution (unlock tree)

- Recipes in this scene count toward `get_discovery_count()`: N discoveries
- Milestone(s) this scene contributes to: `milestone_id` (or none)
- Is this the `final-memory` scene? YES / NO
- Required-for-epilogue? YES / NO

---

## 13. Carry-Forward

- Cards from this scene that persist into the next: `card_id_1`, `card_id_2`
- Cards that are consumed and gone: `card_id_3`

---

## 14. STUI Transition Override [optional]

Entry in `assets/data/ui/transition-variants.tres` under this scene's key:

| Field | Value |
|---|---|
| fold_duration_scale | 1.0 (default) |
| paper_tint | hex or default |
| sfx_variant_id | name or default |
| interstitial | see §11 Interstitial Slides (sub-key of the same variants entry) |

---

## 15. Scene-Level Constants / Open Questions

- Any one-time code additions (e.g. `KNOWN_SCENE_IDS` entry)
- Open design questions for this scene
- Risky interactions flagged for review

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

**Referential integrity**
- [ ] Every `seed_cards[*].card_id` exists in cards.tres
- [ ] Every recipe's `card_a` / `card_b` / `result_card` (if present) / `spawns` exists
- [ ] Every entry in a recipe's `keeps` array refers to `card_a` or `card_b` of that recipe
- [ ] Every bar-effects key matches a recipe id
- [ ] Every bar_id in bar-effects is declared in the scene goal's `bars`

**Template well-formedness**
- [ ] `reject` recipes have `repulsion_multiplier` (float); no `result_card`, no `spawns`
- [ ] `merge` recipes without `result_card` must have a non-empty `keeps` (consume-via-catalyst mode)
- [ ] `additive` recipes have `spawns` (may be empty array)
- [ ] `generator` recipes have `generates`, `interval_sec`, `generator_card`
- [ ] All `template` values are lowercase (`.claude/rules/data-files.md`)

**UI + presentation**
- [ ] Every bar in `goal.bars` has a `label` string (CJK OK)
- [ ] Interstitial slide illustrations (`res://assets/epilogue/...`) exist on disk if declared
- [ ] Ambient path exists on disk if declared

**Manifest + constants**
- [ ] Scene id is listed in `scene-manifest.tres`
- [ ] Scene id is in `KNOWN_SCENE_IDS`
- [ ] New card art files exist in `assets/cards/` OR deferred with placeholder
- [ ] Scene JSON passes `python3 -m json.tool`
- [ ] Section 11 epilogue handoff is consistent with Section 12 MUT flags

---

## Feedback / Iteration Log

- YYYY-MM-DD — Playtest N (tester): score, flagged items, backlog links
