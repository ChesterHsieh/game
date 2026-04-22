# Story 001: CardSpawningSystem autoload + object pool + instance_id registry

> **Epic**: Card Spawning System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-spawning-system.md`
**Requirements**: `TR-card-spawning-system-001`, `TR-card-spawning-system-002`, `TR-card-spawning-system-003`, `TR-card-spawning-system-004`, `TR-card-spawning-system-016`, `TR-card-spawning-system-017`

**ADR Governing Implementation**: ADR-002 (object pool — pre-instantiate 30 card scenes at startup; visibility toggling, no runtime instantiate/free)
**ADR Decision Summary**: CardSpawningSystem pre-instantiates `pool_size = 30` card scenes at startup as children of a pool container. On spawn: take from free list, configure, show. On remove: hide, reset, return to free list. No `instantiate()` or `queue_free()` at runtime (pool exhaustion is the only exception, logging a warning).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `PackedScene.instantiate()` (not `.instance()`) is the 4.3 API. `Node.add_child()` at `_ready()` time is safe. `Dictionary.get(key, default)` available.

**Control Manifest Rules (Core layer)**:
- Required: Object pool — pre-instantiate 30 card scenes; visibility + position change at runtime only
- Required: Pool exhaustion falls back to dynamic instantiate + push_warning (not a crash)
- Forbidden: No `instantiate()` / `queue_free()` on card nodes outside this system

---

## Acceptance Criteria

*From GDD `design/gdd/card-spawning-system.md`, scoped to this story:*

- [ ] `spawn_card(card_id, position)` returns a unique `instance_id` in format `card_id + "_" + counter` (e.g. `"morning-light_0"`)
- [ ] Two calls to `spawn_card` with the same `card_id` return different `instance_id`s (e.g. `morning-light_0`, `morning-light_1`)
- [ ] Instance counters are never reused: after `morning-light_0` and `morning-light_1` are spawned and `morning-light_0` is removed, the next spawn of `morning-light` returns `morning-light_2`
- [ ] `get_live_cards() -> Array[String]` returns the authoritative list of all current `instance_id`s on the table; does not include removed cards

---

## Implementation Notes

*Derived from ADR-002 + GDD card-spawning-system.md Instance ID System:*

- `class_name CardSpawningSystem extends Node`. Autoload at position 8 per ADR-004 §1.
- **Pool setup in `_ready()`**:
  ```gdscript
  const POOL_SIZE := 30
  var _free_list: Array[Node] = []
  var _registry: Dictionary = {}        # instance_id -> Node
  var _next_counter: Dictionary = {}    # card_id -> int

  func _ready() -> void:
      var card_scene := preload("res://src/gameplay/card/card.tscn")
      for i in POOL_SIZE:
          var node := card_scene.instantiate()
          node.visible = false
          add_child(node)
          _free_list.append(node)
  ```
- **`spawn_card(card_id: String, position: Vector2) -> String`**:
  1. Validate `card_id` via `CardDatabase.get_card(card_id)` — if null, `push_error` + return `""`.
  2. Assign `instance_id = card_id + "_" + str(_next_counter.get(card_id, 0))`.
  3. Increment `_next_counter[card_id] = _next_counter.get(card_id, 0) + 1`.
  4. Take node from `_free_list` (pop_back); if empty: `push_warning("Pool exhausted")` + dynamic instantiate fallback.
  5. Set `node.card_id = card_id`, `node.instance_id = instance_id`, `node.position = position`, `node.visible = true`.
  6. Register: `_registry[instance_id] = node`.
  7. Return `instance_id`.
- **`remove_card(instance_id: String)`** (story-003 implements full signal flow; this story stubs as: hide node, erase from registry, return to free list):
  - Stub sufficient for pool counter tests.
- **`get_live_cards() -> Array[String]`**: return `_registry.keys()`.
- `card.tscn` for Core layer: a minimal `Node2D` with exported `@export var card_id: String` and `@export var instance_id: String`. CardVisual (Presentation layer) will add art and labels later.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: `card_spawned` / `card_removing` / `card_removed` EventBus signals; `spawn_seed_cards`
- [Story 003]: Full `remove_card` signal ordering; Clearing state; `clear_all_cards`

---

## QA Test Cases

- **AC-1**: instance_id format is correct
  - Given: CardDatabase has "morning-light" registered; pool initialized
  - When: `spawn_card("morning-light", Vector2(100,100))` called
  - Then: returns "morning-light_0"; node visible at (100, 100); `get_live_cards()` contains "morning-light_0"

- **AC-2**: Counter increments per card_id
  - Given: previous test left counter at 1 for "morning-light"
  - When: `spawn_card("morning-light", Vector2(200,200))` called
  - Then: returns "morning-light_1"; `get_live_cards()` contains both "morning-light_0" and "morning-light_1"

- **AC-3**: Counter not reused after removal
  - Given: "morning-light_0" spawned (counter=1), then `remove_card("morning-light_0")` called (stub)
  - When: `spawn_card("morning-light", Vector2(300,300))` called
  - Then: returns "morning-light_2" (not "morning-light_0")

- **AC-4**: get_live_cards reflects truth
  - Given: "morning-light_0" and "chester_0" are live; "morning-light_1" was spawned and removed
  - When: `get_live_cards()` called
  - Then: returned Array contains "morning-light_0" and "chester_0"; does NOT contain "morning-light_1"

- **AC-5**: Pool exhaustion warning (edge case)
  - Given: all 30 pool slots are in use
  - When: `spawn_card("extra-card", Vector2(0,0))` called
  - Then: `push_warning` called containing "exhausted"; a node is still returned (dynamic fallback); no crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_spawning_system/pool_registry_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/card_spawning_system/pool_registry_test.gd` (20 test functions)

---

## Dependencies

- Depends on: card-database `story-002-card-entry-manifest-resources` must be DONE (CardEntry Resource class needed for card_id validation; minimal `card.tscn` with card_id/instance_id exports must exist)
- Unlocks: story-002-spawn-lifecycle
