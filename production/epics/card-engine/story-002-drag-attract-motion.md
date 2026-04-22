# Story 002: Drag and Attracting motion

> **Epic**: Card Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-engine.md`
**Requirements**: `TR-card-engine-004`, `TR-card-engine-005`, `TR-card-engine-006`, `TR-card-engine-017`, `TR-card-engine-020`

**ADR Governing Implementation**: ADR-002 (card object pooling — CardEngine owns runtime position)
**ADR Decision Summary**: CardEngine holds the authoritative runtime Vector2 position for every card. Table Layout System provides initial placement only. All card motion is Tween-based and code-driven — no physics.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `create_tween()` + chained `tween_property()` are stable in 4.3. `lerp()` is a built-in global function in GDScript. `z_index` property on Node2D is stable.

**Control Manifest Rules (Core layer)**:
- Required: All card motion uses `Tween` nodes — cancellable
- Required: Card positions are code-driven, not physics-simulated
- Forbidden: No direct node path references

---

## Acceptance Criteria

*From GDD `design/gdd/card-engine.md`, scoped to this story:*

- [ ] Dragging a card moves it to cursor world position each frame with zero perceptible lag
- [ ] Entering snap radius causes the card to visibly drift toward the target (`attraction_factor` effect visible)
- [ ] Exiting snap radius while still holding returns card to exact cursor tracking
- [ ] Releasing outside snap radius: card drops to cursor position and becomes Idle
- [ ] Dragged card renders on top via elevated `z_index`; previous `z_index` is restored on drop or combination

---

## Implementation Notes

*Derived from ADR-002 + GDD card-engine.md Drag Behavior section:*

- On `drag_started(instance_id, world_pos)`: look up card in `_cards`; assert state == IDLE; transition to DRAGGED; store `_dragged_id = instance_id`; elevate `card_node.z_index` (e.g. `+10` above default, or a fixed `DRAG_Z_INDEX` constant).
- On `drag_moved(instance_id, world_pos, delta)`: if card is in DRAGGED (not ATTRACTING), set `card_node.position = world_pos` directly — no lerp, no tween, frame-exact.
- On `proximity_entered(dragged_id, target_id)`: transition dragged card from DRAGGED → ATTRACTING; store `_attract_target_id = target_id`.
- During `_process(delta)` while ATTRACTING: `card_node.position = lerp(cursor_world_pos, target_node.position, attraction_factor)`. Re-read `target_node.position` every frame so moving targets are tracked (TR-006). Requires storing last known `cursor_world_pos` from the most recent `drag_moved`.
- On `proximity_exited(dragged_id, target_id)` while ATTRACTING: transition back to DRAGGED; clear `_attract_target_id`.
- On `drag_released(instance_id, world_pos)` while DRAGGED (not ATTRACTING): `card_node.position = world_pos`; restore `z_index`; transition to IDLE.
- **Tuning knob** `attraction_factor`: exported float, default `0.4`, range `0.0–0.5`. Constants in SCREAMING_SNAKE_CASE per ADR-001: `const DEFAULT_ATTRACTION_FACTOR := 0.4`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: EventBus wiring and card registration
- [Story 003]: `drag_released` while ATTRACTING (snap zone) — snap tween and combination handshake

---

## QA Test Cases

- **AC-1**: Dragged state — position follows cursor exactly
  - Given: "test-card_0" is registered in IDLE at position (50, 50)
  - When: `EventBus.drag_started.emit("test-card_0", Vector2(50,50))`; then `EventBus.drag_moved.emit("test-card_0", Vector2(300, 200), 0.016)`
  - Then: `card_node.position == Vector2(300, 200)`
  - Edge cases: multiple drag_moved calls in quick succession — final position == last world_pos

- **AC-2**: Attracting state — lerp formula applied
  - Given: "test-card_0" is DRAGGED; "target_0" is at position Vector2(400, 400); attraction_factor = 0.4
  - When: `EventBus.proximity_entered.emit("test-card_0", "target_0")`; then `_process` runs with last cursor = Vector2(200, 200)
  - Then: `card_node.position` ≈ `lerp(Vector2(200,200), Vector2(400,400), 0.4)` == Vector2(280, 280)
  - Edge cases: attraction_factor = 0.0 → position == cursor exactly; attraction_factor = 0.5 → position is midpoint

- **AC-3**: Exiting snap radius returns to cursor tracking
  - Given: card is ATTRACTING toward target
  - When: `EventBus.proximity_exited.emit("test-card_0", "target_0")`; then drag_moved with cursor Vector2(100, 100)
  - Then: card transitions to DRAGGED; `card_node.position == Vector2(100, 100)`

- **AC-4**: Release outside snap zone drops card at cursor
  - Given: card is DRAGGED at Vector2(250, 300)
  - When: `EventBus.drag_released.emit("test-card_0", Vector2(250, 300))`
  - Then: `card_node.position == Vector2(250, 300)`; card state == IDLE; z_index restored to original value

- **AC-5**: z_index elevated during drag
  - Given: card at default z_index (0)
  - When: drag_started fires
  - Then: `card_node.z_index > 0` (specifically: elevated above all non-dragged cards)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_engine/drag_attract_motion_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/card_engine/drag_attract_motion_test.gd` (14 tests)

> **FLAGGED DIVERGENCE**: `drag_moved` delta parameter is `Vector2` in implementation, `float` in story spec.
> Tests reflect actual implementation signature.

---

## Dependencies

- Depends on: story-001-fsm-scaffold must be DONE
- Unlocks: story-003-snap-combination-pushaway
