# Card Visual

> **Status**: In Design
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-25
> **Implements Pillar**: Personal Over Polished; Recognition Over Reward

## Overview

Card Visual is the rendering layer for every card on the table. It reads card data
from the Card Database (label, art reference, optional badge) and card state from
the Card Engine (position, current state) to produce what the player sees and feels.
A card at rest shows its label, circular illustration, and optional bottom badge
inside a Stacklands-style bordered frame. A card being dragged lifts slightly —
scaling up and gaining a drop shadow — to communicate that it's in hand. When cards
enter magnetic attraction range, they drift visually toward each other. When they
snap and merge, Card Visual executes the scale-and-fade animation. Card Visual owns
no logic — it is a pure rendering system that reflects the state owned by Card Engine
and the content owned by Card Database.

## Player Fantasy

Each card is a physical object — something you can pick up. When she drags a card
across the table, it should feel like it has weight: it lifts slightly when grabbed,
it leans toward another card when they belong together, it settles back when released.
The art in the circular frame is the memory itself — not decorative, not generic.
It's the actual thing. The label is the name only Chester would write for it. The
card is not a game piece. It's an artifact. Card Visual is successful when she picks
up a card and something in the art or label makes her stop — not because the design
is beautiful, but because she recognizes it.

## Detailed Design

### Core Rules

1. Card Visual is a **per-card rendering component**, not a singleton system. Each card instance carries its own Card Visual node. Card Visual has no shared state between cards.
2. Card Visual is a **pure renderer** — it owns no game state. Content comes from Card Database; position and state come from Card Engine.
3. On card spawn (`_ready()`): Card Visual reads Card Database for this card's `card_id` to fetch `display_name`, `art_path`, and `badge` (if present). This data is cached on the instance — not re-read each frame.
4. Each frame: Card Visual reads the card's current state from Card Engine and applies the matching visual configuration.
5. Each card face contains three regions:
   - **Label** — `display_name` at the top of the card, inside the frame
   - **Circular illustration** — `art_path` image, cropped to a circle in the center of the card
   - **Badge (optional)** — a small authored element at the bottom center; shown only if the card's Card Database entry includes a `badge` field. Per-card — not all cards have one.
6. Art images are cropped to a circle using a circular mask. Source image aspect ratio does not affect card layout — the circle clips to center.
7. Drag visual: when in `Dragged` or `Attracting` state, the card scales to **~105%** and renders a **drop shadow** beneath the frame. This communicates "lifted."
8. Z-order: the dragged card renders above all other cards. Z-order **restores** to its authored table position after the card transitions to `Idle`, `Pushed`, or `Executing`.
9. Attraction state adds no visual effect beyond position — Card Engine's lerp toward the target is the visual. Card Visual does not add a separate attraction indicator.
10. Merge animation (Executing, Merge template): Card Visual tweens the card's **scale to 0** and **opacity to 0** as Card Engine drives the card to the midpoint. Duration matches Card Engine's `merge_duration_sec`.

### States and Transitions

| Card Engine State | Scale | Shadow | Opacity | Z-order |
|-------------------|-------|--------|---------|---------|
| `Idle` | 100% | Off | 100% | Restored |
| `Dragged` | 105% | On | 100% | Top |
| `Attracting` | 105% | On | 100% | Top |
| `Snapping` | 105% | On | 100% | Top |
| `Pushed` | 100% | Off | 100% | Restored |
| `Executing` (Additive/Generator) | 100% | Off | 100% | Restored |
| `Executing` (Merge) | 100% → 0% tween | Off | 100% → 0% tween | Top until removed |
| `Executing` (Animate) | Per ITF config | Off | 100% | Restored |

State transitions use instant value changes (no cross-fade between states), except the Merge tween which is explicitly animated.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Card Database** | Reads from | On spawn: reads `display_name`, `art_path`, `badge` (optional) by `card_id`. Cached on instance. |
| **Card Engine** | Reads state from | Each frame: reads card state enum (`Idle`, `Dragged`, etc.) to apply visual config. Card Engine updates the card node's position — Card Visual inherits position through the Godot scene tree automatically. |

> **Cross-reference note**: Card Database schema does not currently include a `badge` field. Card Visual requires it as an **optional** field. Card Database GDD open questions should be updated to include: "Add optional `badge` field to card schema — path to badge image or a badge type enum. Confirm with Card Visual design."

## Formulas

Card Visual has two explicit calculations:

**Drag scale:**
```
drag_scale = Vector2(1.05, 1.05)   // applied to card node in Dragged, Attracting, Snapping states
idle_scale = Vector2(1.0,  1.0)    // applied in all other states
```

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `drag_scale` | Vector2 | (1.05, 1.05) | Uniform scale applied while card is held. Tunable. |
| `idle_scale` | Vector2 | (1.0, 1.0) | Uniform scale at rest. |

**Merge fade (Executing, Merge template):**
```
tween.scale    = lerp(Vector2(1.0, 1.0), Vector2(0.0, 0.0), t)
tween.modulate.a = lerp(1.0, 0.0, t)
// t: 0.0 → 1.0 over merge_duration_sec (from Card Engine tuning knob)
```

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `merge_duration_sec` | float | Card Engine tuning knob (default 0.25s) | Duration of the scale+fade tween. Card Visual does not own this value — it matches Card Engine. |
| `t` | float | Tween progress 0.0–1.0 | Driven by Godot `Tween`. Easing: linear (or `ease_in` for a slight "popping" feel — resolve in prototype). |

All other visual properties (position, z-order) are set or restored discretely — no interpolation.

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **Missing art asset** | `art_path` points to a nonexistent file | Render a fallback circular placeholder (solid color or question mark). Log a warning naming the card ID. Match Card Database edge case behavior. |
| **No badge field** | Card Database entry has no `badge` field | Badge region is hidden. Card renders with label + art only. No error. This is the normal case for most cards. |
| **State change mid-tween (Merge interrupted)** | Card Engine cancels the merge tween (e.g., scene transition during animation) | Cancel tween immediately. Card transitions to Idle or is removed per Card Engine direction. No visual artifact left behind (ghost opacity or partial scale). |
| **drag_scale = 1.0 (tuning knob)** | Drag scale set to 1.0 | Card does not visually lift when dragged. Drop shadow still applies. This is a valid tuning choice for a flatter feel. |
| **display_name very long** | A card's `display_name` exceeds the label area | Clip or truncate to fit the label region. Do not overflow into the art area. Log a content warning naming the card ID if label is truncated. |
| **Card Engine state not recognized** | Card Visual receives an unknown state enum value | Apply idle visual config as fallback. Log a warning. Do not crash. |
| **Card spawned with invalid card_id** | Card Database returns null for this card's ID | Card Visual renders a full placeholder (label = "?", art = fallback circle, no badge). Log a clear error. Match Card Database error handling. |
| **Multiple cards dragged simultaneously** | Not possible — Input System enforces single drag | Not a case Card Visual needs to handle. Documented here to confirm: only ever one card in Dragged state at a time. |

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Card Database** | `display_name`, `art_path`, `badge` (optional) by `card_id` — read at spawn | Hard — cannot render a card without its content |
| **Card Engine** | Card state enum each frame; card position via scene tree | Hard — Card Visual is entirely state-driven by Card Engine |

### Downstream (systems that depend on this)

None. Card Visual is a leaf node in the dependency graph — nothing reads from it.

### Signals Emitted

None. Card Visual emits no signals. It is a pure consumer.

### Systems Index Update Required

Card Database GDD needs an optional `badge` field added to its card schema. This does not change the Card Database's dependencies — it's an additive schema change. Flag for correction when Card Database is reviewed.

## Tuning Knobs

| Knob | Type | Default | Safe Range | Too Low | Too High |
|------|------|---------|------------|---------|----------|
| `drag_scale` | float | 1.05 | 1.0–1.15 | No lift feel; card doesn't communicate "held" | Card feels too large; distorts table layout |
| `shadow_offset` | Vector2 (px) | (4, 6) | (2, 4)–(8, 12) | Shadow invisible; no lift depth | Shadow looks detached from card |
| `shadow_opacity` | float | 0.35 | 0.15–0.6 | Shadow invisible | Shadow too dark; distracting |
| `art_circle_radius` | float (% of card width) | 38% | 30–45% | Art too small to recognize | Art bleeds into label and badge regions |
| `label_font_size` | int (px) | 14 | 10–18 | Text too small to read | Text overflows label region |

**Note**: `merge_duration_sec` is **not** a Card Visual knob — it is owned by Card Engine. Card Visual reads it to match the tween duration. Change it there, not here.

## Acceptance Criteria

- [ ] A card at rest displays: `display_name` in the label region, circular cropped art in the center, and badge at bottom (if card has one in Card Database)
- [ ] A card with no `badge` field renders correctly with no badge region visible
- [ ] Dragging a card: scale increases to `drag_scale` and drop shadow appears instantly on state change to `Dragged`
- [ ] Releasing a card outside snap zone: scale returns to 100% and shadow disappears instantly on transition to `Idle`
- [ ] A card in `Attracting` state: same visual as `Dragged` (105% scale, shadow on)
- [ ] A card in `Pushed` state: renders at 100% scale, no shadow, at the position Card Engine provides
- [ ] Merge animation: card scale tweens from 100% to 0% and opacity from 100% to 0% over `merge_duration_sec`, then card is removed from scene
- [ ] If merge tween is interrupted (scene transition): tween cancels cleanly, no partial-scale or partial-opacity artifact remains
- [ ] A card with a missing art asset renders a fallback placeholder without crashing
- [ ] A card with an invalid `card_id` renders a full placeholder (label = "?", fallback circle) and logs an error
- [ ] Art image is visually circular regardless of source image aspect ratio
- [ ] Long `display_name` is clipped within the label region and does not overflow into the art area
- [ ] `drag_scale`, `shadow_offset`, `shadow_opacity`, `art_circle_radius`, and `label_font_size` can all be changed in code without modifying any other system
- [ ] The dragged card renders above all other cards (highest z-order)
- [ ] Z-order restores after the card transitions to `Idle` or `Pushed`

## Open Questions

- **Badge field in Card Database**: Card Database schema does not yet include a `badge` field. Card Visual requires it as an optional field (path to badge image, or a badge type enum). Resolve when Card Database is implemented — confirm format with Card Visual at that time.
- **Merge tween easing**: Linear vs. `ease_in` for the scale+fade. Linear is simpler; `ease_in` gives a slight "pop" as the card accelerates into disappearing. Resolve in prototype — one frame of each is enough to decide.
- **Art asset resolution and size constraints**: Card Database open question notes "PNG assumed — confirm resolution and size constraints with Card Visual." Card Visual defers this to implementation. Recommendation: 256×256px source images, circular region ~200px diameter. Confirm when implementing Card Visual node.
- **Flavor text**: Card Database schema includes `flavor_text` (optional small text below `display_name`). Card Visual does not currently render it. Decide during implementation: render `flavor_text` as a small secondary label below the main label, or omit from the card face entirely.
