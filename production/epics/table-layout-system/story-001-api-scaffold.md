# Story 001: TableLayoutSystem autoload + stateless API scaffold

> **Epic**: Table Layout System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/table-layout-system.md`
**Requirements**: `TR-table-layout-system-001`, `TR-table-layout-system-002`, `TR-table-layout-system-003`, `TR-table-layout-system-015`

**ADR Governing Implementation**: ADR-001 (naming conventions — stateless helper, snake_case)
**ADR Decision Summary**: All variables, functions, and file names use `snake_case`; class name uses `PascalCase`. No cross-system signals — TableLayoutSystem is a synchronous query helper with no EventBus involvement.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `RandomNumberGenerator` (seeded) is stable in 4.3. `Rect2.get_center()` available. Direct autoload calls are correct for read-only queries per ADR-003.

**Control Manifest Rules (Core layer)**:
- Required: Direct autoload calls for read-only queries (`CardDatabase.get_card(id)`)
- Required: snake_case for all file and variable names; PascalCase for `class_name`
- Forbidden: No EventBus signals emitted — output is synchronous return values only

---

## Acceptance Criteria

*From GDD `design/gdd/table-layout-system.md`, scoped to this story:*

- [ ] `get_seed_card_positions(scene_data: Array) -> Array` returns one Dictionary per seed card entry in the format `{ "card_id": String, "position": Vector2, "seed_used": int }`
- [ ] `get_spawn_position(combination_point: Vector2, existing_cards: Array, spawn_seed) -> Dictionary` returns `{ "position": Vector2, "seed_used": int }`
- [ ] Both methods are pure functions: calling them multiple times with identical inputs (and same seed) returns identical outputs; no internal state is mutated between calls
- [ ] `validate card_id` against `CardDatabase.get_card(card_id)`: if card not found, `push_error` naming the unknown ID and return a null position for that entry
- [ ] If a zone `Rect2` is smaller than `card_size` (Vector2), `push_error` and return `zone.get_center()` as the position

---

## Implementation Notes

*Derived from ADR-001 + GDD table-layout-system.md Core Rules:*

- `class_name TableLayoutSystem extends Node`. Registered as autoload in `project.godot` at position 9 (after `CardSpawningSystem`) per ADR-004 §1 canonical order.
- Both methods receive all required data as parameters — no reading of global scene state inside the method body.
- `get_seed_card_positions` iterates the input `Array` of seed card data Dictionaries (each has `"card_id"`, `"zone"`, `"placement_seed"` keys). For each entry: validate card_id, resolve zone to Rect2, sample position (story-002 adds the seeded RNG; this story returns placeholder positions using zone center).
- `get_spawn_position` receives `combination_point: Vector2`, `existing_cards: Array` (of Vector2), and `spawn_seed` (int or null). Returns a Dictionary.
- For this story, the actual RNG sampling (story-002) and overlap avoidance (story-003) are stubbed with a return of `combination_point` so the API shape is testable. Add a `# TODO: implement seeded sampling in story-002` comment.
- `card_size: Vector2` is an `@export` variable (default `Vector2(80, 120)`). Zone Rect2 check: `if zone_rect.size.x < card_size.x or zone_rect.size.y < card_size.y`.
- Direct call to `CardDatabase.get_card(card_id)` — returns null if unknown. No EventBus signal.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Seeded RNG, actual sampling formula, null-seed logging, determinism
- [Story 003]: Overlap avoidance, zone → Rect2 mapping, tuning knobs

---

## QA Test Cases

- **AC-1**: get_seed_card_positions returns one entry per seed card
  - Given: scene_data = [{"card_id": "morning-light", "zone": "center", "placement_seed": 42}, {"card_id": "chester", "zone": "left", "placement_seed": 7}]
  - When: `TableLayoutSystem.get_seed_card_positions(scene_data)` called
  - Then: returns Array of 2 Dictionaries; each has keys "card_id", "position", "seed_used"; card_ids match input
  - Edge cases: empty scene_data → returns empty Array

- **AC-2**: Unknown card_id logs error and returns null position
  - Given: CardDatabase does not contain "nonexistent-card"
  - When: scene_data includes `{"card_id": "nonexistent-card", "zone": "center", "placement_seed": 1}`
  - Then: `push_error` called naming "nonexistent-card"; that entry's "position" is null or skipped; no crash

- **AC-3**: get_spawn_position returns correct Dictionary shape
  - Given: combination_point=Vector2(400,300), existing_cards=[], spawn_seed=99
  - When: `TableLayoutSystem.get_spawn_position(Vector2(400,300), [], 99)` called
  - Then: return value has keys "position" (Vector2) and "seed_used" (int); no crash

- **AC-4**: Zone smaller than card_size falls back to zone center
  - Given: a zone resolves to Rect2(Vector2(100,100), Vector2(10,10)); card_size=Vector2(80,120)
  - When: get_seed_card_positions called with that entry
  - Then: `push_error` called; "position" == Vector2(105, 105) (zone center)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/table_layout_system/api_scaffold_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/table_layout_system/api_scaffold_test.gd`

---

## Dependencies

- Depends on: card-database `story-003-card-database-autoload-load` must be DONE (CardDatabase autoload must exist for `get_card()` validation)
- Unlocks: story-002-seeded-rng-sampling, story-003-overlap-zone (both can begin once story-001 is Done)
