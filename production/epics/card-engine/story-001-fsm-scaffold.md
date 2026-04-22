# Story 001: CardEngine autoload + 6-state FSM scaffold

> **Epic**: Card Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-engine.md`
**Requirements**: `TR-card-engine-001`, `TR-card-engine-002`, `TR-card-engine-003`, `TR-card-engine-018`

**ADR Governing Implementation**: ADR-002 (card object pooling) + ADR-003 (EventBus signal bus)
**ADR Decision Summary**: CardEngine registers/deregisters card nodes via CardSpawningSystem lifecycle signals (ADR-002). All cross-system events travel through the EventBus autoload — no direct node references between systems (ADR-003).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `signal.connect(callable)` syntax required (string-based connect deprecated since 4.0). `@onready` stable in 4.3.

**Control Manifest Rules (Core layer)**:
- Required: Object pool — CardSpawningSystem owns card node lifecycle; CardEngine registers/deregisters via lifecycle signals
- Required: EventBus for all cross-system events; no direct node path references
- Forbidden: Never create or destroy card instances via `instantiate()` / `queue_free()` outside the Card Spawning System pool API

---

## Acceptance Criteria

*From GDD `design/gdd/card-engine.md`, scoped to this story:*

- [ ] CardEngine autoload initializes without errors; internal card state registry is empty on start
- [ ] Connects to all 5 InputSystem EventBus signals: `drag_started`, `drag_moved`, `drag_released`, `proximity_entered`, `proximity_exited`
- [ ] Connects to card lifecycle signals: `card_spawned`, `card_removing`, `card_removed`
- [ ] On `card_spawned(instance_id, card_id, position)`: registers the card node in the internal per-card state Dictionary with `state = Idle`
- [ ] On `card_removed(instance_id)`: deregisters the card from the registry; no null dereference errors
- [ ] On `card_removing(instance_id)`: marks that card's active tween (if any) as needing cancellation before the node is freed

---

## Implementation Notes

*Derived from ADR-002 + ADR-003 + GDD card-engine.md:*

- `CardEngine` is an autoload singleton (`class_name CardEngine extends Node`); registered in `project.godot` after `CardSpawningSystem` per ADR-004 §1 canonical order.
- Internal state: `_cards: Dictionary = {}` keyed by `instance_id: String`, value is a per-card struct or Dictionary containing `{ node: Node2D, state: CardState, active_tween: Tween }`.
- FSM states as an `enum CardState { IDLE, DRAGGED, ATTRACTING, SNAPPING, PUSHED, EXECUTING }`.
- Use `EventBus.drag_started.connect(_on_drag_started)` in `_ready()` — typed callable syntax, not string-based.
- On `card_removing`: call `active_tween.kill()` if a tween exists for that card. Do not deregister yet — `card_removed` fires after the free.
- On `card_removed`: erase the entry from `_cards`. Set any local variable references to that instance_id to `""` / `null` before erasing.
- CardEngine does **not** call `CardDatabase.get_card()` in this story — that is a story-002+ concern.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Drag follow, lerp, z_index motion
- [Story 003]: Snap tween, combination handshake, push-away
- [Story 004]: Merge/Animate template animations

---

## QA Test Cases

*Lean mode — test specs written at story creation.*

- **AC-1**: CardEngine initializes without errors
  - Given: All Foundation autoloads (EventBus, CardDatabase, CardSpawningSystem) are loaded
  - When: CardEngine._ready() runs
  - Then: No `push_error`, no failed assert; `_cards` is empty
  - Edge cases: EventBus not yet loaded (impossible by autoload order — guard with assert in tests)

- **AC-2**: Connects to 5 input signals
  - Given: EventBus autoload is ready
  - When: CardEngine._ready() completes
  - Then: `EventBus.drag_started.is_connected(CardEngine._on_drag_started)` == true; same for drag_moved, drag_released, proximity_entered, proximity_exited

- **AC-3**: card_spawned registers card in Idle state
  - Given: CardEngine is initialized; a card node exists (from CardSpawningSystem pool)
  - When: `EventBus.card_spawned.emit("morning-light_0", "morning-light", Vector2(100, 100))`
  - Then: `CardEngine._cards.has("morning-light_0")` == true; `_cards["morning-light_0"].state` == CardState.IDLE

- **AC-4**: card_removed deregisters card safely
  - Given: "morning-light_0" is in `_cards`
  - When: `EventBus.card_removed.emit("morning-light_0")`
  - Then: `CardEngine._cards.has("morning-light_0")` == false; no null dereference errors

- **AC-5**: card_removing cancels active tween
  - Given: "morning-light_0" has `active_tween` set to a running Tween mock
  - When: `EventBus.card_removing.emit("morning-light_0")`
  - Then: tween.kill() was called on the stored tween; card is still in `_cards` (not yet deregistered)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/card_engine/card_engine_wiring_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/card_engine/card_engine_wiring_test.gd` (16 tests)

> **BLOCKED ACs** (see test file header for full details):
> - AC-2 partial: EventBus connections absent — implementation uses InputSystem
> - AC-3: `card_spawned` listener not wired in `_ready()`
> - AC-4: `card_removed` listener not wired in `_ready()`
> - AC-5: `card_removing` tween-cancel listener not wired; no per-card tween storage

---

## Dependencies

- Depends on: card-database `story-001-event-bus-autoload` must be DONE (EventBus autoload must exist)
- Unlocks: story-002-drag-attract-motion
