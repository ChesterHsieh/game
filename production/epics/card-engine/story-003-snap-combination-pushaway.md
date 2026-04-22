# Story 003: Snap, combination handshake, and push-away

> **Epic**: Card Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-engine.md`
**Requirements**: `TR-card-engine-007`, `TR-card-engine-008`, `TR-card-engine-009`, `TR-card-engine-010`, `TR-card-engine-011`, `TR-card-engine-012`, `TR-card-engine-015`, `TR-card-engine-019`

**ADR Governing Implementation**: ADR-002 (card pool + Tween motion) + ADR-003 (EventBus — combination signals cross the CardEngine ↔ ITF boundary)
**ADR Decision Summary**: All card motion uses cancellable Godot Tween nodes (ADR-002). Combination signals (`combination_attempted`, `combination_succeeded`, `combination_failed`) are the contract between CardEngine and ITF — they travel via EventBus (ADR-003).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `create_tween().tween_property(node, "position", target, duration)` is stable in 4.3. Tweens are cancellable via `tween.kill()`. `tween.tween_callback()` fires after all tween steps complete.

**Control Manifest Rules (Core layer)**:
- Required: All motion uses Godot Tween nodes; must be cancellable mid-flight
- Required: EventBus for combination signals — no direct ITF reference
- Forbidden: Never create card instances outside CardSpawningSystem

---

## Acceptance Criteria

*From GDD `design/gdd/card-engine.md`, scoped to this story:*

- [ ] Releasing inside snap radius: card tweens to snap position (`target.position + snap_offset`) in `snap_duration_sec` (default 0.12s)
- [ ] After snap tween completes: `combination_attempted(instance_id_a, instance_id_b)` emits on EventBus
- [ ] On `combination_failed(a, b)`: card tweens away from target by `push_distance` (default 60px) in push direction, clamped to table bounds, over `push_duration_sec` (default 0.18s); ends at new position (not origin)
- [ ] Only one combination can be in-flight at a time: if `_combination_in_flight` is true, further `combination_attempted` emissions are blocked
- [ ] New `drag_started` on the snapping card during SNAPPING cancels the snap tween and transitions card to DRAGGED
- [ ] Snap tween cancelled correctly if target card fires `card_removing` mid-animation: dragged card → IDLE at current position; `combination_attempted` does NOT fire

---

## Implementation Notes

*Derived from ADR-002 + ADR-003 + GDD Snap and Push-Away sections:*

- On `drag_released(instance_id, world_pos)` while ATTRACTING: transition to SNAPPING; create and store a Tween that moves the card to `target_card.position + snap_offset`.
- After snap tween: if `_combination_in_flight == false`, emit `EventBus.combination_attempted(instance_id_a, instance_id_b)` and set `_combination_in_flight = true`; transition card to EXECUTING.
- Listen for `EventBus.combination_failed.connect(_on_combination_failed)` and `EventBus.combination_succeeded.connect(_on_combination_succeeded)` in `_ready()`.
- On `combination_failed(a, b)`: compute push direction `dir = (card_a.position - card_b.position).normalized()`; push target `= card_a.position + dir * push_distance`; clamp to `table_bounds` Rect2; tween to push target with `ease_out`; on tween complete: transition to IDLE; `_combination_in_flight = false`.
- **Table bounds**: stored as an exported `Rect2` constant, e.g. `@export var table_bounds: Rect2`. Clamp: `push_target.x = clamp(push_target.x, table_bounds.position.x, table_bounds.end.x - card_size.x)` (same for y).
- **Snap interrupt**: if `drag_started` fires for a card currently in SNAPPING: `active_tween.kill()`; transition to DRAGGED; do not emit `combination_attempted`.
- **card_removing during snap**: in `card_removing` handler, if target_id == `_attract_target_id` and card is SNAPPING: kill snap tween; transition snapping card to IDLE.
- Constants (ADR-001 SCREAMING_SNAKE_CASE): `SNAP_DURATION_SEC := 0.12`, `PUSH_DISTANCE := 60.0`, `PUSH_DURATION_SEC := 0.18`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: DRAGGED / ATTRACTING state motion
- [Story 004]: `combination_succeeded` with Merge or Animate template animations

---

## QA Test Cases

- **AC-1**: combination_attempted fires after snap tween
  - Given: "card-a_0" is ATTRACTING toward "card-b_0"; both registered in CardEngine
  - When: `EventBus.drag_released.emit("card-a_0", <pos>)`
  - Then: after `SNAP_DURATION_SEC` elapses, `EventBus.combination_attempted` fires with ("card-a_0", "card-b_0")
  - Edge cases: snap_duration_sec set to minimum 0.05s — signal still fires after tween

- **AC-2**: Push-away ends at new position, not origin
  - Given: "card-a_0" is in EXECUTING at position (300, 300); "card-b_0" at (300, 300)
  - When: `EventBus.combination_failed.emit("card-a_0", "card-b_0")`
  - Then: after `PUSH_DURATION_SEC`, card-a ends at position ≈ (300±60, 300) (push direction dependent); position != original drag origin
  - Edge cases: push target outside table_bounds → clamped; no card ends up off-screen

- **AC-3**: Single in-flight combination enforced
  - Given: `_combination_in_flight == true` (previous combination not yet resolved)
  - When: another card pair snaps together and snap tween completes
  - Then: `combination_attempted` does NOT emit; second pair is blocked

- **AC-4**: Snap tween cancelled on card_removing for target
  - Given: "card-a_0" is SNAPPING toward "card-b_0"
  - When: `EventBus.card_removing.emit("card-b_0")`
  - Then: snap tween is killed; "card-a_0" transitions to IDLE at its current tween position; `combination_attempted` does NOT fire

- **AC-5**: drag_started during SNAPPING cancels snap
  - Given: "card-a_0" is in SNAPPING state
  - When: `EventBus.drag_started.emit("card-a_0", <cursor_pos>)`
  - Then: snap tween killed; "card-a_0" transitions to DRAGGED; `combination_attempted` does NOT fire

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/card_engine/snap_combination_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: story-002-drag-attract-motion must be DONE
- Unlocks: story-004-merge-animate-tween
