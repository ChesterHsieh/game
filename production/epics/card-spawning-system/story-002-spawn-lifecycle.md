# Story 002: spawn_card() + card lifecycle signals

> **Epic**: Card Spawning System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-spawning-system.md`
**Requirements**: `TR-card-spawning-system-005`, `TR-card-spawning-system-006`, `TR-card-spawning-system-007`, `TR-card-spawning-system-011`, `TR-card-spawning-system-015`, `TR-card-spawning-system-018`

**ADR Governing Implementation**: ADR-002 (pool — configure + show on spawn) + ADR-003 (EventBus — `card_spawned` signal) + ADR-004 (autoload order — CardEngine and CardVisual connect via EventBus after CardSpawningSystem is ready)
**ADR Decision Summary**: After a card is configured and made visible, `EventBus.card_spawned.emit(instance_id, card_id, position)` fires immediately. CardEngine (autoload #11) and CardVisual (not an autoload — connects in its own `_ready()`) are the declared downstream consumers. Unknown `card_id` returns `""` and logs an error — no node is shown.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Signal emit is synchronous — all connected listeners run before `spawn_card` returns. Autoload connection order follows ADR-004 §1.

**Control Manifest Rules (Core layer)**:
- Required: EventBus for all cross-system lifecycle events — emit via `EventBus.card_spawned.emit(...)`
- Required: Direct autoload call `CardDatabase.get_card(card_id)` for validation (read-only query, not a signal)
- Forbidden: Never emit signals not declared in EventBus

---

## Acceptance Criteria

*From GDD `design/gdd/card-spawning-system.md`, scoped to this story:*

- [ ] `card_spawned(instance_id, card_id, position)` fires on EventBus immediately after the card node is visible and positioned
- [ ] `spawn_card` with an unknown `card_id`: `push_error` naming the ID and caller, returns `""`, no node is shown, registry unchanged
- [ ] `spawn_seed_cards(scene_data: Array) -> Array[String]` calls `spawn_card` for each entry and returns `instance_id`s in the same order as the input; no entry is skipped (unknown IDs produce `""` in position)
- [ ] CardEngine and CardVisual receive `card_spawned` and can register the new node

---

## Implementation Notes

*Derived from ADR-003 + ADR-002 + GDD Spawn Lifecycle section:*

- Update `spawn_card` from story-001 to emit signal after pool configuration:
  ```gdscript
  func spawn_card(card_id: String, position: Vector2) -> String:
      if CardDatabase.get_card(card_id) == null:
          push_error("CardSpawningSystem: unknown card_id '%s'" % card_id)
          return ""

      var instance_id := card_id + "_" + str(_next_counter.get(card_id, 0))
      _next_counter[card_id] = _next_counter.get(card_id, 0) + 1

      var node: Node2D = _take_from_pool()
      node.card_id = card_id
      node.instance_id = instance_id
      node.position = position
      node.visible = true
      _registry[instance_id] = node

      EventBus.card_spawned.emit(instance_id, card_id, position)
      return instance_id
  ```
- `_take_from_pool()`: pop from `_free_list`; if empty, `push_warning` + dynamic instantiate fallback.
- **`spawn_seed_cards(scene_data: Array) -> Array[String]`**:
  ```gdscript
  func spawn_seed_cards(scene_data: Array) -> Array[String]:
      var result: Array[String] = []
      for entry in scene_data:
          result.append(spawn_card(entry["card_id"], entry["position"]))
      return result
  ```
  Scene Manager is responsible for calling `TableLayoutSystem.get_seed_card_positions()` first and passing positions in.
- The `card_spawned` signal is already declared in `EventBus` (ADR-003 expansion). No new signal declaration needed.
- CardEngine connects to `EventBus.card_spawned` in its own `_ready()` (story card-engine-001). CardVisual connects similarly. CardSpawningSystem does not reference either system directly.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Pool initialization and instance_id counter logic
- [Story 003]: `remove_card()` signal ordering; `card_removing`; `card_removed`; Clearing state

---

## QA Test Cases

- **AC-1**: card_spawned fires after spawn
  - Given: a test listener connected to `EventBus.card_spawned`
  - When: `CardSpawningSystem.spawn_card("morning-light", Vector2(200,200))` called
  - Then: listener received ("morning-light_0", "morning-light", Vector2(200,200)); card node is visible at (200,200)

- **AC-2**: Unknown card_id returns "" and logs error
  - Given: CardDatabase does not have "fake-card"
  - When: `spawn_card("fake-card", Vector2(0,0))` called
  - Then: returns ""; `push_error` called naming "fake-card"; no node shown; `get_live_cards()` unchanged; `card_spawned` NOT emitted

- **AC-3**: spawn_seed_cards returns ordered instance_ids
  - Given: scene_data = [{"card_id":"morning-light","position":Vector2(100,100)}, {"card_id":"chester","position":Vector2(200,200)}, {"card_id":"bridge","position":Vector2(300,300)}]
  - When: `spawn_seed_cards(scene_data)` called
  - Then: returns ["morning-light_0", "chester_0", "bridge_0"] in that order; all 3 nodes visible

- **AC-4**: spawn_seed_cards with one unknown card_id inserts "" in position
  - Given: scene_data second entry has card_id "unknown-card"
  - When: `spawn_seed_cards(scene_data)` called
  - Then: result[1] == ""; other entries spawned successfully; `push_error` for "unknown-card"

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/card_spawning_system/spawn_lifecycle_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: story-001-pool-registry must be DONE; card-database story-001-event-bus-autoload must be DONE (EventBus exists)
- Unlocks: story-003-remove-clearing
