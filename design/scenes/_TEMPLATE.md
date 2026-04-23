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
| art_style | Template A (person) / Template B (object) / custom |
| art_path | `res://assets/cards/[card_id].png` |

(repeat per new card)

> Cards referenced but already defined elsewhere — list here for reviewer
> awareness, do NOT re-define:
> `existing_card_a`, `existing_card_b`

---

## 4. Puzzle Graph (recipes — added to recipes.tres, scene-scoped)

Readable summary first:

```
recipe_id  : card_a + card_b → result_card  [keeps: X | notes]
```

Then per-recipe detail:

### `recipe_id_1`
| Field | Value |
|---|---|
| id | `recipe-id-kebab-case` |
| card_a | `card_id` |
| card_b | `card_id` |
| template | `merge` / `additive` / `animate` / `generator` (lowercase!) |
| result_card | `card_id` (for merge / additive) |
| keeps | `card_id` if one side stays (catalyst); omit for classic merge |
| other config | spawns / motion / interval / max_count — template-specific |

(repeat per recipe)

---

## 5. Win Condition (goal config in `assets/data/scenes/[scene-id].json`)

| Field | Value |
|---|---|
| type | `reach_value` / `sustain_above` |
| bars | `[{ id: "bar_id", initial_value: N, decay_rate_per_sec: N }]` |
| max_value | N |
| threshold | N |
| duration_sec | N (for sustain_above); small for reach_value |

> Goal types currently supported: `sustain_above`, `reach_value`.
> `find_key` and `sequence` are defined in GDD but not wired in SceneGoal code.

---

## 6. Left Panel Content (status bars visible during the scene)

- **`bar_id`** — starts at N, decays at N/sec, max N, narrative meaning

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
subtly weaves in motifs that *hint* at the scene's theme (e.g. kitchen
scene → mortar-and-pestle, whisk, wheat, coffee cup embedded in the
corner scrollwork). The centre 70% stays blank parchment so cards
dominate the main visual. Follows Art Bible §6 (scenes are composed
from cards, not from backgrounds — but a decorative plate is the one
exception that signals *place*).

| Field | Value |
|---|---|
| `ambient.path` | `res://assets/ambient/[scene-id].png` (or `"none"` to skip) |
| `ambient.anchor` | `"full_viewport"` (default — covers the whole logical viewport) |
| `ambient.alpha` | `0.9` default |

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

**Reusable nano-banana prompt template** (fill in `{SCENE_CONCEPT}` +
`{CORNER_MOTIFS}` and run):

```
Ornamental parchment background plate for a card game — wide landscape
aspect ratio. Aged warm cream parchment paper texture as the base
(#F4EEDE with very subtle tonal variation, no gradients, no strong
color blocks). Fine-line ornamental filigree border frames the full
rectangle in thin warm brown ink — scrollwork, vine curls, leaves.
Decorative corner flourishes SUBTLY weave in abstracted {SCENE_CONCEPT}
concepts as stylized line-art hints only: {CORNER_MOTIFS}, all rendered
as if they are PART of the ornamental filigree itself, NOT placed as
separate objects. The center 70% of the image is completely empty cream
parchment with very subtle paper texture only — this is the gameplay
surface where cards will sit. Overall feeling: vintage recipe book title
plate, ornate but understated, like a tarot card back or medieval herbal
manuscript frontispiece. Ink is soft warm brown, never black, never
harsh.

NEGATIVE: text, letters, numbers, words, names, signatures, watermarks,
any center focal subject, literal objects placed in the middle, strong
color blocks, photographic realism, 3D render, perspective, deep shadows,
human figures, modern UI elements, busy loud patterns, gradient fills
in the center, heavy dark ink, anime, cyberpunk, neon, pixel art. The
center MUST remain empty parchment — if it is not empty the image fails.
```

Example fill — coffee-intro:
- `{SCENE_CONCEPT}`: *kitchen-morning*
- `{CORNER_MOTIFS}`: *a tiny mortar-and-pestle silhouette in one corner,
  a small whisk curl in another, a sheaf of coffee beans / wheat stalk
  as a curving line in a third corner, a minimalist steam curl or coffee
  cup edge suggestion in the fourth*

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
| On completion | what SceneManager emits (`scene_completed` always; `epilogue_started` if last) |
| Epilogue content | illustration slot + descriptive text (only if `next_scene == none` AND this is final memory) |

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
