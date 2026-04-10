# Card Engine

> **Status**: Designed
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-23
> **Implements Pillar**: Discovery without Explanation; Interaction is Expression

## Overview

The Card Engine manages the physical lifecycle of every card on the table: drag
movement, magnetic snap attraction, push-away rejection, and combination detection.
It listens to Input System signals and translates them into card motion. When the
player releases a dragged card within snap range of another, the Card Engine fires
a combination event that the Interaction Template Framework resolves. The Card
Engine is the primary interface between player intent and game response — if it
doesn't feel right, nothing else does.

## Player Fantasy

Dragging a card should feel like picking up something that has weight — responsive
to the hand, reluctant to let go of things it's near. When two cards belong
together, there should be a moment of *pull* before release: a small resistance
that says "something wants to happen here." When they don't belong, the push-away
should be gentle but clear — not a rejection, just a redirection. The card engine's
fantasy is the fantasy of objects that know things.

## Detailed Design

### Core Rules

1. The Card Engine manages the physical position and state of every card on the table.
2. It does **not** read raw mouse input — it connects to Input System signals only.
3. It does **not** look up recipes — it fires `combination_attempted` and waits for ITF to respond.
4. One card can be in `Dragged` or `Attracting` state at a time (enforced by Input System's single-drag rule).
5. Card positions are authoritative in the Card Engine. Table Layout System provides initial placement; Card Engine owns runtime position.
6. All card motion (drag follow, attraction lerp, snap tween, push-away tween, merge fade) uses Godot `Tween` nodes for consistent, cancellable animation.

### Drag Behavior

- On `drag_started(card_id, world_pos)`: Card transitions to `Dragged`. Its position updates every frame to match `world_pos` from the Input System.
- On `drag_moved(card_id, world_pos, delta)`: If card is `Dragged` (not yet `Attracting`), set `card.position = world_pos`.
- On `proximity_entered(dragged_id, target_id)`: Card transitions to `Attracting`. Each frame, its rendered position is:
  ```
  card.position = lerp(cursor_world_pos, target_card.position, attraction_factor)
  ```
  The card visually drifts toward the target while still tracking the cursor. See Tuning Knobs for `attraction_factor`.
- On `proximity_exited(dragged_id, target_id)` while Attracting: Card returns to `Dragged`. Position reverts to exact cursor tracking.

### Snap and Push-Away Behavior

**On release in snap zone** (`drag_released` while state is `Attracting`):
1. Card transitions to `Snapping`.
2. Tween card position to `target_card.position + snap_offset` (slightly offset so both cards remain visible).
3. On tween complete: fire `combination_attempted(dragged_id, target_id)` signal. Card enters `Executing` state, waiting for ITF response.

**On `combination_failed` received from ITF:**
1. Card transitions to `Pushed`.
2. Compute push direction: `dir = (card.position - target_card.position).normalized()`
3. Tween card to `card.position + dir * push_distance` using `ease_out`.
4. On tween complete: card transitions to `Idle` at its new position (does not return to origin).

**On release outside snap zone** (`drag_released` while state is `Dragged`):
1. Card drops to its current world position.
2. Transitions to `Idle`.

### Combination Firing

When the snap tween completes, the Card Engine fires:
```
combination_attempted(instance_id_a: String, instance_id_b: String)
```
The ITF is the sole listener. It queries the Recipe Database (deriving base `card_id`
from each `instance_id`) and responds with either:
- `combination_succeeded(instance_id_a, instance_id_b, template, config)` — Card Engine executes template animation
- `combination_failed(instance_id_a, instance_id_b)` — Card Engine plays push-away

> **Updated**: Originally used `card_id` parameters. Corrected to `instance_id` when
> Interaction Template Framework was designed — ITF needs instance IDs to call
> `Card_Spawning.remove_card()` for Merge templates.

**Post-combination animations by template:**
- **Additive**: Both cards return to `Idle` in place. Card Spawning (via ITF) places result card(s) nearby.
- **Merge**: Both cards tween to their midpoint, scale to 0, fade to 0. On complete: both removed. Card Spawning places result card at midpoint.
- **Animate**: Card transitions to `Executing` with a looping motion pattern. ITF provides the animation parameters from `config`. Card Engine applies them each frame until ITF stops the animation.
- **Generator**: Card returns to `Idle`. ITF manages the generation timer and calls Card Spawning at each interval.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| `Idle` | Default; drag released outside snap zone; push-away complete; template complete | `drag_started` on this card | Stationary on table |
| `Dragged` | `drag_started` signal | `proximity_entered` OR `drag_released` outside snap zone | Follows cursor world position exactly each frame |
| `Attracting` | `proximity_entered` while Dragged | `proximity_exited` (→ Dragged) OR `drag_released` in snap zone (→ Snapping) | Lerps between cursor and target by `attraction_factor` |
| `Snapping` | `drag_released` in snap zone | Tween complete (→ Executing) | Tweens to snap position adjacent to target card |
| `Pushed` | `combination_failed` received | Tween complete (→ Idle) | Tweens away from target; stays at new position |
| `Executing` | `combination_succeeded` received OR snap tween complete | Template animation complete (→ Idle or removed) | Runs template-specific animation |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Input System** | Listens to signals | Connects to all 5 signals: `drag_started`, `drag_moved`, `drag_released`, `proximity_entered`, `proximity_exited` |
| **Card Database** | Reads | Uses `card_id` to look up card properties needed for rendering or logic (e.g., confirming a card exists before processing it) |
| **Interaction Template Framework** | Fires signal → receives response | Fires `combination_attempted(instance_id_a, instance_id_b)`. Listens for `combination_succeeded(a, b, template, config)` and `combination_failed(a, b)`. Also emits `merge_animation_complete(a, b, midpoint)` and `animate_complete(instance_id)` when template animations complete. |
| **Card Visual** | Drives | Card Engine updates card node positions; Card Visual reads those positions to render card faces |
| **Card Spawning System** | Indirect (via ITF) | Card Engine does not call Card Spawning directly. ITF handles spawning; Card Engine receives the spawned card as a new `Idle` node |

## Formulas

### Attraction Position (during Attracting state)

```
card_position = lerp(cursor_world_pos, target_card.position, attraction_factor)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `cursor_world_pos` | Vector2 | table bounds | Input System `drag_moved` | Current cursor position in world space |
| `target_card.position` | Vector2 | table bounds | Card Engine (target card's current position) | Center of the card being approached |
| `attraction_factor` | float | 0.0–0.5 | Tuning knob | How far the card drifts toward target (0 = no pull, 0.5 = halfway) |

**Expected output**: card renders between cursor and target. At `attraction_factor = 0.25`, card is 25% of the way from cursor to target.

---

### Push-Away Offset

```
push_target = card.position + normalize(card.position - target_card.position) * push_distance
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `card.position` | Vector2 | table bounds | Card Engine | Position of card at moment of failed combination |
| `target_card.position` | Vector2 | table bounds | Card Engine | Position of the card that rejected the combination |
| `push_distance` | float | 20–80px | Tuning knob | How far the card bounces away |

**Expected output**: card ends up 40px (default) away from target, in the direction it was approaching from.

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **Target card moves during attraction** | An Animate-template card drifts away while being approached | Attraction lerp target updates each frame to the target's current position. Pull follows the moving card. |
| **Target card is removed during snap tween** | Card Spawning removes target mid-snap (e.g., scene transition) | Snap tween is cancelled. Dragged card transitions to Idle at its current tween position. No `combination_attempted` fires. |
| **Two cards simultaneously released onto each other** | Extremely unlikely — Input System allows only one drag. | Not possible by design. Input System enforces single drag. Guard in Card Engine: if `combination_attempted` is already in-flight, ignore new combinations until resolved. |
| **Snap tween interrupted by drag** | Player manages to start a new drag during snap animation | Cancel snap tween. New `drag_started` takes priority. Card transitions from `Snapping` to `Dragged`. |
| **Push-away target is off-table** | `push_target` calculation places card outside table bounds | Clamp `push_target` to table bounds before tweening. |
| **Merge animation: one card already removed** | Mid-merge, a scene event removes one card | Cancel merge tween. Remaining card transitions to Idle. Log a warning. |
| **attraction_factor = 0.0** | Tuning knob set to zero | Card follows cursor exactly, no pull. `proximity_entered` / `proximity_exited` still fire normally — snap still works on release. |

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Input System** | 5 drag signals with world positions and card IDs | Hard — Card Engine cannot function without these |
| **Card Database** | Card ID validation (card exists before processing) | Soft — Card Engine works without it but may process invalid IDs |

### Downstream (systems that depend on this)

| System | What They Need |
|--------|---------------|
| **Interaction Template Framework** | `combination_attempted(a, b)` signal; receives `combination_succeeded/failed` responses back |
| **Card Visual** | Card node positions updated each frame — Card Visual reads these to render faces |

## Tuning Knobs

| Knob | Type | Default | Safe Range | Too Low | Too High |
|------|------|---------|------------|---------|----------|
| `attraction_factor` | float | 0.4 | 0.0–0.5 | No pull feel; snap surprise on release | Card yanked to target; player loses control |
| `snap_duration_sec` | float | 0.12 | 0.05–0.3 | Instant, no satisfying snap feel | Sluggish; player waits too long for combination to resolve |
| `push_distance` | float (px) | 60 | 20–80 | Cards barely separate; looks like a glitch | Cards fly apart; feels violent |
| `push_duration_sec` | float | 0.18 | 0.08–0.35 | Instant rejection; no gentle feel | Slow rejection; interrupts flow |
| `merge_duration_sec` | float | 0.25 | 0.15–0.5 | Disappear too fast; player misses it | Too slow; momentum breaks |

**Note**: `snap_radius` is owned by the Input System (default 80px) and controls when `proximity_entered` fires. It is the primary feel knob for the approach phase; these knobs control what happens after.

## Acceptance Criteria

- [ ] Dragging a card moves it to cursor world position each frame with zero perceptible lag
- [ ] Entering snap radius causes the card to visibly drift toward the target (`attraction_factor` effect visible)
- [ ] Exiting snap radius while still holding returns card to exact cursor tracking
- [ ] Releasing inside snap radius: card tweens to snap position in `snap_duration_sec`
- [ ] After snap tween: `combination_attempted` signal fires with both card IDs
- [ ] On `combination_failed`: card plays push-away animation, ends at new position (not origin)
- [ ] On `combination_succeeded` with Additive: both cards remain at snap position
- [ ] On `combination_succeeded` with Merge: both cards tween to midpoint, scale and fade to zero
- [ ] Releasing outside snap radius: card drops to cursor position and becomes Idle
- [ ] Only one combination can be in-flight at a time
- [ ] Push-away target is clamped to table bounds
- [ ] All animations run at target framerate with no hitching
- [ ] Snap tween cancelled correctly if target card is removed mid-animation

## Open Questions

- **Snap position offset**: When snapping onto a target, should the dragged card center perfectly on the target, or offset slightly (e.g., 20px right/down) so both card faces are still visible? Resolve in prototype — affects readability of combination state.
- **Animate template position ownership**: During an Animate-template motion, does the Card Engine apply the motion directly (each frame), or does the ITF own the card node's position entirely for that duration? Needs to be resolved when Interaction Template Framework is designed.
- **Z-order during drag**: Dragged card should render on top. Should z-order be restored after drop, or should it stay on top? Resolve with Card Visual design.
- **Can combinations re-fire?**: If an Additive combination fires and the two source cards remain on the table, can the same pair be combined again? Recipe Database flagged this as open. Card Engine will need to enforce or allow repeat firing once ITF decides.
