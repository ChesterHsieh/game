# Story 003: remove_card() + Clearing state + clear_all_cards()

> **Epic**: Card Spawning System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-spawning-system.md`
**Requirements**: `TR-card-spawning-system-008`, `TR-card-spawning-system-009`, `TR-card-spawning-system-010`, `TR-card-spawning-system-012`, `TR-card-spawning-system-013`, `TR-card-spawning-system-014`

**ADR Governing Implementation**: ADR-002 (pool — hide + return to free list on remove; Ready/Clearing state machine) + ADR-003 (EventBus — `card_removing` fires before hide; `card_removed` fires after) + ADR-004 (SceneManager calls `clear_all_cards()` during scene transition)
**ADR Decision Summary**: `card_removing` must fire synchronously before any node state change so CardEngine can cancel in-flight Tweens on the node while it is still live. `card_removed` fires after the node is hidden and returned to the pool. During Clearing, incoming `spawn_card()` calls are queued and executed when Ready state returns.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Godot signal emission is synchronous — all `card_removing` listeners run before the next line of `remove_card`. `Array.append()` for queue is safe; process queue with a `while !_spawn_queue.is_empty()` loop.

**Control Manifest Rules (Core layer)**:
- Required: EventBus for all card lifecycle events — `card_removing` and `card_removed`
- Required: `card_removing` fires BEFORE `queue_free` / node hide — CardEngine must be able to cancel tweens on a live node
- Forbidden: Never `queue_free` card nodes — return to pool free list instead

---

## Acceptance Criteria

*From GDD `design/gdd/card-spawning-system.md`, scoped to this story:*

- [ ] `card_removing(instance_id)` fires on EventBus before the card node is hidden or reset
- [ ] `card_removed(instance_id)` fires after the card node is hidden and returned to the free list
- [ ] `remove_card` with an unknown `instance_id`: `push_warning`, no crash, no action, no signals emitted
- [ ] `clear_all_cards()`: enters Clearing state; emits `card_removing` then `card_removed` for every live card; registry is empty on completion; state returns to Ready
- [ ] During Clearing, incoming `spawn_card()` calls are queued; they execute (in order) after Clearing completes

---

## Implementation Notes

*Derived from ADR-002 + ADR-003 + GDD remove and Clearing sections:*

- **`remove_card(instance_id: String)`** (replace stub from story-001):
  ```gdscript
  func remove_card(instance_id: String) -> void:
      if not _registry.has(instance_id):
          push_warning("CardSpawningSystem: remove_card called with unknown instance_id '%s'" % instance_id)
          return

      var node: Node2D = _registry[instance_id]

      EventBus.card_removing.emit(instance_id)   # fires BEFORE any state change

      _registry.erase(instance_id)
      node.card_id = ""
      node.instance_id = ""
      node.visible = false
      _free_list.append(node)

      EventBus.card_removed.emit(instance_id)    # fires AFTER node is reset
  ```
- **Clearing state machine**:
  ```gdscript
  enum _State { READY, CLEARING }
  var _state: _State = _State.READY
  var _spawn_queue: Array = []   # Array of {card_id, position} Dictionaries

  func spawn_card(card_id: String, position: Vector2) -> String:
      if _state == _State.CLEARING:
          _spawn_queue.append({"card_id": card_id, "position": position})
          return ""   # queued; instance_id not yet known
      # ... existing logic ...

  func clear_all_cards() -> void:
      _state = _State.CLEARING
      for instance_id in _registry.keys():
          var node: Node2D = _registry[instance_id]
          EventBus.card_removing.emit(instance_id)
          node.card_id = ""
          node.instance_id = ""
          node.visible = false
          _free_list.append(node)
          EventBus.card_removed.emit(instance_id)
      _registry.clear()

      _state = _State.READY
      _process_spawn_queue()

  func _process_spawn_queue() -> void:
      while not _spawn_queue.is_empty():
          var req: Dictionary = _spawn_queue.pop_front()
          spawn_card(req["card_id"], req["position"])
  ```
- Note: queued `spawn_card` calls during Clearing return `""` to the original caller. If the caller needs the `instance_id`, it should listen for the subsequent `card_spawned` signal instead.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Pool initialization and counter logic
- [Story 002]: `card_spawned` signal; `spawn_seed_cards`

---

## QA Test Cases

- **AC-1**: card_removing fires before node is hidden
  - Given: "morning-light_0" is live and visible
  - When: `remove_card("morning-light_0")` called; listener on `EventBus.card_removing` checks node visibility
  - Then: inside `card_removing` handler, `node.visible == true`; after `remove_card` returns, `node.visible == false`

- **AC-2**: card_removed fires after node is hidden
  - Given: listener on `EventBus.card_removed` checks node visibility
  - When: `remove_card("morning-light_0")` called
  - Then: inside `card_removed` handler, `node.visible == false`; node is back in `_free_list`

- **AC-3**: Unknown instance_id is idempotent
  - Given: "ghost_99" is not in registry
  - When: `remove_card("ghost_99")` called
  - Then: `push_warning` called; no `card_removing` or `card_removed` emitted; registry unchanged; no crash

- **AC-4**: clear_all_cards empties registry
  - Given: 3 cards live: "a_0", "b_0", "c_0"
  - When: `clear_all_cards()` called
  - Then: `card_removing` fired for all 3 (while nodes still visible); `card_removed` fired for all 3; `get_live_cards()` returns []; all 3 nodes returned to pool (visible == false)

- **AC-5**: Spawn queued during Clearing executes after
  - Given: `clear_all_cards()` starts (Clearing state active); a listener captures `card_spawned`
  - When: `spawn_card("morning-light", Vector2(100,100))` called during Clearing
  - Then: immediate return is ""; after `clear_all_cards()` finishes, `card_spawned` fires for "morning-light_0"; `get_live_cards()` contains "morning-light_0"

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/card_spawning_system/remove_clearing_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: story-002-spawn-lifecycle must be DONE
- Unlocks: None (final CardSpawningSystem story; unlocks Feature layer epics — InteractionTemplateFramework depends on CardEngine + CardSpawningSystem)
