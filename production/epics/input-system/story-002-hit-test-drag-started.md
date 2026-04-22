# Story 002: Hit-test + drag_started + z-order resolution

> **Epic**: input-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-system-002` — per-frame hit-test to identify card
under cursor by `card_id`. `TR-input-system-003` — emit `drag_started` on
left-mouse press on a card. `TR-input-system-009` — resolve overlapping
cards by highest `z_index`.

**ADR Governing Implementation**: ADR-003 — `drag_started(card_id: String, world_pos: Vector2)` is declared in EventBus
**ADR Decision Summary**: InputSystem performs the hit-test, identifies the
topmost card by z_index, transitions FSM to Dragging, and emits
`EventBus.drag_started.emit(card_id, world_pos)`.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `get_viewport().get_world_2d().direct_space_state` for
point queries (physics-based hit-test) is stable in 4.3. Alternatively,
`get_children_at_point()` or manual Area2D overlap checking. Cards must have
CollisionShape2D or Area2D for detection.

**Control Manifest Rules (Foundation layer)**:
- Required: emit signals via EventBus, not direct method calls.
- Forbidden: InputSystem calling methods on Card Engine or any downstream
  system.
- Guardrail: hit-test must complete within the frame budget (~1 ms for
  ~20 cards on screen).

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`:*

- [ ] Left mouse press triggers a hit-test at the cursor position
- [ ] Hit-test identifies which card (by `card_id`) is under the cursor
- [ ] When a card is found, FSM transitions from Idle → Dragging
- [ ] `EventBus.drag_started.emit(card_id, world_pos)` fires with the
      correct card_id and world-space position
- [ ] When two cards overlap at the cursor position, the card with the
      highest `z_index` is selected (topmost wins)
- [ ] Pressing on empty table space (no card hit) stays in Idle — no
      signal emitted
- [ ] Left mouse press while already in Dragging state is ignored (single
      active drag — Story 003 enforces this, but the hit-test must also
      guard against re-entry)

---

## Implementation Notes

*Derived from GDD Core Rules and Edge Cases:*

1. Hit-test approach — use `PhysicsDirectSpaceState2D.intersect_point()`:
   ```gdscript
   func _hit_test(world_pos: Vector2) -> String:
       var space: PhysicsDirectSpaceState2D = get_viewport().get_world_2d().direct_space_state
       var query := PhysicsPointQueryParameters2D.new()
       query.position = world_pos
       query.collide_with_areas = true
       query.collide_with_bodies = false
       var results: Array[Dictionary] = space.intersect_point(query)
       if results.is_empty():
           return ""
       # Sort by z_index descending — topmost card wins
       results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
           return a.collider.z_index > b.collider.z_index)
       var top_node: Node2D = results[0].collider
       return top_node.get_meta("card_id", "")
   ```
2. Cards must have an Area2D with CollisionShape2D and a `card_id` metadata
   field (or property). The exact card scene structure is owned by Card
   Visual / Card Spawning System — this story only reads it.
3. On left-press hitting a card:
   ```gdscript
   func _unhandled_input(event: InputEvent) -> void:
       if event is InputEventMouseButton:
           if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
               if _state != State.IDLE:
                   return
               var world_pos: Vector2 = _screen_to_world(event.position)
               var card_id: String = _hit_test(world_pos)
               if card_id.is_empty():
                   return
               _state = State.DRAGGING
               _dragged_card_id = card_id
               _last_world_pos = world_pos
               EventBus.drag_started.emit(card_id, world_pos)
   ```
4. z_index tie-break: if multiple cards have the same z_index at the same
   position, the physics engine's internal ordering applies (last added to
   tree wins). This is acceptable for MVP.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload + FSM skeleton (prerequisite)
- Story 003: drag_moved + drag_released
- Story 004: proximity detection
- Story 005: cancel_drag()
- Card scene structure (Area2D, CollisionShape2D) — Card Visual / Card
  Spawning System's concern

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (left press on card emits drag_started)**:
  - Given: InputSystem in Idle state; a card with `card_id = "test-card"`
    at position (100, 100)
  - When: left mouse press at (100, 100)
  - Then: `EventBus.drag_started` emitted with `card_id == "test-card"`
    and correct world_pos; `_state == State.DRAGGING`

- **AC-2 (press on empty space — no signal)**:
  - Given: InputSystem in Idle state; no cards under cursor
  - When: left mouse press at (500, 500)
  - Then: no `drag_started` emitted; `_state == State.IDLE`

- **AC-3 (overlapping cards — z_index tie-break)**:
  - Given: card "bottom" at z_index=0 and card "top" at z_index=1, both
    overlapping at position (100, 100)
  - When: left mouse press at (100, 100)
  - Then: `drag_started` emitted with `card_id == "top"`

- **AC-4 (second press while dragging is ignored)**:
  - Given: InputSystem in Dragging state (already dragging "card-a")
  - When: left mouse press on "card-b"
  - Then: no new `drag_started` emitted; still dragging "card-a"

- **AC-5 (hit-test returns empty string for no card)**:
  - Given: no cards in the scene
  - When: `_hit_test(Vector2(100, 100))`
  - Then: returns `""`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input_system/hit_test_drag_started_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload + FSM + coordinate conversion)
- Unlocks: Story 003 (drag_moved/released need Dragging state), Story 004
  (proximity needs a dragged card)
