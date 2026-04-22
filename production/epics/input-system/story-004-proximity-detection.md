# Story 004: Proximity detection — proximity_entered / proximity_exited

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-system-006` — emit `proximity_entered` /
`proximity_exited` on snap_radius crossings. `TR-input-system-010` —
per-frame proximity check; guard against `dragged_id == target_id`.
`TR-input-system-013` — expose tunable `snap_radius` (default 80px,
range 40–160).

**ADR Governing Implementation**: ADR-003 — `proximity_entered(dragged_id: String, target_id: String)` and `proximity_exited(dragged_id: String, target_id: String)` declared in EventBus
**ADR Decision Summary**: During Dragging state, InputSystem checks every
frame whether the dragged card's center is within `snap_radius` of any
other card. Crossing in → `proximity_entered`; crossing out →
`proximity_exited`. Emitted on EventBus.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Distance calculation between Node2D positions via
`global_position.distance_to()` is trivial. For ~20 cards, per-frame
iteration is sub-millisecond. No spatial partitioning needed at this scale.

**Control Manifest Rules (Foundation layer)**:
- Required: emit signals via EventBus.
- Forbidden: mutating card state or positions from InputSystem.
- Guardrail: proximity check O(n) where n = cards on screen ≈ 20; < 0.5 ms.

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`:*

- [ ] While in Dragging state, each frame checks distance between dragged
      card center and all other card centers
- [ ] When a card enters `snap_radius` for the first time:
      `EventBus.proximity_entered.emit(dragged_id, target_id)` fires
- [ ] When a card exits `snap_radius` (was inside, now outside):
      `EventBus.proximity_exited.emit(dragged_id, target_id)` fires
- [ ] `proximity_entered` is NEVER fired with `dragged_id == target_id`
- [ ] `proximity_exited` is NEVER fired with `dragged_id == target_id`
- [ ] `snap_radius` defaults to 80.0 and is exposed as a tunable parameter
- [ ] `snap_radius` safe range is 40–160 (documented; enforcement is
      advisory, not clamped — designer knows the range from GDD Tuning Knobs)
- [ ] When drag ends (drag_released or cancel_drag), all active proximity
      targets receive `proximity_exited`
- [ ] Multiple targets can be in proximity simultaneously — each gets its
      own enter/exit signals

---

## Implementation Notes

*Derived from GDD Detailed Design and Tuning Knobs:*

1. Track which cards are currently in proximity:
   ```gdscript
   @export var snap_radius: float = 80.0
   var _proximity_targets: Dictionary = {}   # card_id → true

   func _process(_delta: float) -> void:
       if _state != State.DRAGGING:
           return
       _check_proximity()

   func _check_proximity() -> void:
       var current_near: Dictionary = {}
       for card_node: Node2D in _get_all_card_nodes():
           var target_id: String = card_node.get_meta("card_id", "")
           if target_id.is_empty() or target_id == _dragged_card_id:
               continue
           var dist: float = _last_world_pos.distance_to(card_node.global_position)
           if dist <= snap_radius:
               current_near[target_id] = true
               if not _proximity_targets.has(target_id):
                   EventBus.proximity_entered.emit(_dragged_card_id, target_id)
       # Check for exits
       for prev_id: String in _proximity_targets:
           if not current_near.has(prev_id):
               EventBus.proximity_exited.emit(_dragged_card_id, prev_id)
       _proximity_targets = current_near
   ```
2. `_get_all_card_nodes()` returns all card Node2D instances currently in the
   scene tree. The exact method depends on how Card Spawning System organises
   cards — likely a group ("cards") or a parent node. Use `get_tree().get_nodes_in_group("cards")`.
3. On drag end (in drag_released and cancel_drag), emit `proximity_exited`
   for all entries in `_proximity_targets`, then clear the dictionary.
4. `snap_radius` is `@export` so it can be tuned from the inspector. The GDD
   says 80px default, 40–160 safe range. No runtime clamping — the range is
   advisory for the designer.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload + FSM
- Story 002: hit-test + drag_started
- Story 003: drag_moved + drag_released
- Story 005: cancel_drag() (but cancel_drag must call proximity cleanup)
- Magnetic pull animation — Card Engine's concern; InputSystem only signals
- Snap resolution (what happens when cards combine) — Card Engine / ITF

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (proximity_entered fires on enter)**:
  - Given: InputSystem dragging "card-a"; card "card-b" at (200, 200);
    snap_radius = 80
  - When: dragged card center moves to (150, 200) (distance = 50, < 80)
  - Then: `EventBus.proximity_entered` emitted with
    `dragged_id == "card-a"`, `target_id == "card-b"`

- **AC-2 (proximity_exited fires on exit)**:
  - Given: "card-b" was in proximity (entered signal already fired)
  - When: dragged card moves to (400, 400) (distance > 80)
  - Then: `EventBus.proximity_exited` emitted with
    `dragged_id == "card-a"`, `target_id == "card-b"`

- **AC-3 (dragged_id == target_id guard)**:
  - Given: dragged card "card-a" exists in the card nodes list
  - When: proximity check runs
  - Then: "card-a" is skipped; no proximity signal with
    `dragged_id == target_id`

- **AC-4 (multiple targets can be near simultaneously)**:
  - Given: card-b at distance 50 and card-c at distance 60 (both < 80)
  - When: proximity check runs
  - Then: `proximity_entered` fires for both card-b and card-c

- **AC-5 (proximity cleanup on drag end)**:
  - Given: card-b and card-c in proximity
  - When: drag_released fires
  - Then: `proximity_exited` fires for both card-b and card-c;
    `_proximity_targets` is empty

- **AC-6 (snap_radius default is 80)**:
  - Given: fresh InputSystem
  - When: test reads `snap_radius`
  - Then: `snap_radius == 80.0`

- **AC-7 (no proximity signals when Idle)**:
  - Given: InputSystem in Idle state
  - When: `_process()` runs
  - Then: no proximity signals emitted

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input_system/proximity_detection_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload + FSM), Story 002 (hit-test to enter
  Dragging state), Story 003 (drag lifecycle — proximity runs during drag)
- Unlocks: Story 005 (cancel_drag calls proximity cleanup)
