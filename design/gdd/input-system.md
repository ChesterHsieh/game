# Input System

> **Status**: Designed
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-23
> **Implements Pillar**: Discovery without Explanation (input must be invisible)

## Overview

The Input System translates raw mouse input into semantic drag events the Card
Engine can act on. It detects when the player presses on a card, moves it, releases
it, and when a dragged card moves near another card. It emits typed signals with
position data attached. No gameplay logic lives here — it only observes and reports.

## Player Fantasy

The player should never think about input. Dragging a card should feel like picking
up a physical object — responsive, direct, zero latency between intention and result.
The Input System is successful when it disappears entirely from the player's awareness.

## Detailed Design

### Core Rules

1. The Input System is the **sole owner** of raw mouse input. No other system reads
   `InputEvent` directly for drag interactions.
2. The Input System performs a hit-test each frame (area query or raycast) to
   determine which card is under the cursor. It identifies cards by their `card_id`.
3. Only **one card can be dragged at a time**. If the player somehow triggers a
   second press while already dragging, the active drag takes precedence.
4. The Input System emits **signals only** — it does not call methods on other
   systems. The Card Engine connects to these signals and responds.
5. The Input System tracks proximity between the dragged card and all other cards
   each frame. When the dragged card enters or exits the `snap_radius` of another
   card, the corresponding proximity signal fires.
6. Platform: **mouse input only** for MVP. Touch input is out of scope.

### Events Emitted

All events are Godot signals on the `InputSystem` autoload (singleton):

| Signal | Parameters | Fired when |
|--------|------------|-----------|
| `drag_started` | `card_id: String, world_pos: Vector2` | Player presses left mouse button on a card |
| `drag_moved` | `card_id: String, world_pos: Vector2, delta: Vector2` | Player moves mouse while a drag is active |
| `drag_released` | `card_id: String, world_pos: Vector2` | Player releases left mouse button during a drag |
| `proximity_entered` | `dragged_id: String, target_id: String` | Dragged card's center enters `snap_radius` of a stationary card |
| `proximity_exited` | `dragged_id: String, target_id: String` | Dragged card's center exits `snap_radius` of a stationary card |

`world_pos` is in Godot world coordinates (not screen coordinates). The Input
System converts screen position using the camera transform.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| `Idle` | Default; no drag active | Left mouse pressed on a card | Checks hit-test each frame; no signals emitted |
| `Dragging` | `drag_started` signal fired | Mouse released OR drag cancelled | Emits `drag_moved` each frame; checks proximity each frame |

Only two states. No pending state — press either hits a card (→ Dragging) or misses (stays Idle).

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Card Engine** | Downstream consumer | Connects to all 5 signals. Receives drag and proximity events to drive card movement and magnetic snap logic. |
| **Card Engine** | Reads from (indirect) | Input System queries card node positions to detect proximity. Card positions at runtime are owned by Card Engine (it updates them each frame). Input System reads these positions during the drag phase to compute proximity distances. |

## Formulas

None. The Input System performs no mathematical calculations beyond coordinate
conversion (screen → world space, handled by Godot's Camera2D transform).

The only numeric threshold is `snap_radius` — see Tuning Knobs.

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **Click misses all cards** | Mouse press on empty table | Stay Idle. No signal emitted. |
| **Cards overlap — which is picked up?** | Two cards share the same screen position | Pick the card with the highest z-index (topmost). Input System breaks ties by z-order. |
| **Mouse leaves window during drag** | Player drags card off the application window | Continue tracking — Godot captures mouse during drag. On release outside window, emit `drag_released` at last known position. |
| **Right-click during drag** | Player right-clicks while left-drag is active | Ignore. Right mouse button has no defined action in MVP. |
| **dragged_id == target_id in proximity** | Card's proximity circle overlaps itself | Never fire proximity signals where `dragged_id == target_id`. Guard against this in the proximity check. |
| **Drag cancelled by game event** | A scene transition or pause fires mid-drag | Input System exposes a `cancel_drag()` method. Emits `drag_released` at current position, returns to Idle. |

## Dependencies

### Upstream (this system depends on)

None. The Input System is a Foundation-layer system. It relies only on Godot's
built-in `Input` singleton and `Camera2D` for coordinate conversion.

### Downstream (systems that depend on this)

| System | What They Need |
|--------|---------------|
| **Card Engine** | All 5 signals — drag lifecycle and proximity events |
| **Table Layout System** | Indirect read — Input System queries card world positions for proximity checks |

## Tuning Knobs

| Knob | Type | Default | Safe Range | Effect if too low | Effect if too high |
|------|------|---------|------------|------------------|--------------------|
| `snap_radius` | float (pixels) | 80 | 40–160 | Snap never triggers; player must be pixel-perfect | Snap triggers from across the table; feels uncontrolled |

`snap_radius` is the only designer-adjustable value. It determines how close a
dragged card must get to another card before `proximity_entered` fires. The Card
Engine uses this signal to begin the magnetic pull animation.

Default of 80px at 1080p feels like "almost touching." Tune this after the first
prototype — it is the single most important feel parameter in the entire input layer.

## Acceptance Criteria

- [ ] Pressing left mouse button on a card emits `drag_started` with the correct `card_id` and world position
- [ ] Moving the mouse while dragging emits `drag_moved` every frame with correct delta
- [ ] Releasing the mouse emits `drag_released` at the final world position
- [ ] Pressing on empty table space emits no signals and leaves state as Idle
- [ ] When two cards overlap, the topmost (highest z-index) card is picked up
- [ ] `proximity_entered` fires when dragged card center comes within `snap_radius` of another card
- [ ] `proximity_exited` fires when dragged card center moves back beyond `snap_radius`
- [ ] `proximity_entered` is never fired with `dragged_id == target_id`
- [ ] `cancel_drag()` transitions to Idle and emits `drag_released` at last known position
- [ ] World position values are in Godot world coordinates, not screen coordinates
- [ ] Only one drag can be active at a time

## Open Questions

- **Snap radius at different resolutions**: 80px at 1080p may feel different at 1440p or 4K. Should `snap_radius` scale with viewport resolution, or stay in world units? Resolve when Card Engine is prototyped.
- **Scroll/pan**: Does the player need to pan the table if too many cards accumulate? Not in MVP scope, but if yes, the Input System would need a pan gesture. Defer to Table Layout System design.
