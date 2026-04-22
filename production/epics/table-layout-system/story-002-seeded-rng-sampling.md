# Story 002: Seeded RNG + spawn position sampling

> **Epic**: Table Layout System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/table-layout-system.md`
**Requirements**: `TR-table-layout-system-004`, `TR-table-layout-system-005`, `TR-table-layout-system-006`, `TR-table-layout-system-007`, `TR-table-layout-system-008`, `TR-table-layout-system-009`, `TR-table-layout-system-013`, `TR-table-layout-system-014`

**ADR Governing Implementation**: ADR-001 (naming) + ADR-002 (determinism under replay — seeded RNG is load-bearing for reproducible card placement)
**ADR Decision Summary**: TableLayoutSystem uses a seeded `RandomNumberGenerator` so any spawn position is reproducible given the same seed. Chester can record a logged seed into the recipe `.tres` file to lock a card position permanently (ADR-005 data-driven values).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `RandomNumberGenerator` class with `.seed` property and `.randf_range()` / `.randi()` methods is stable and pre-training-cutoff in 4.3. `Vector2(cos(angle), sin(angle))` polar → Cartesian conversion is pure GDScript math.

**Control Manifest Rules (Core layer)**:
- Required: Gameplay values are data-driven — seed values come from `.tres` recipe/scene data, never hardcoded
- Required: Deterministic output — no random without an explicit seed path

---

## Acceptance Criteria

*From GDD `design/gdd/table-layout-system.md`, scoped to this story:*

- [ ] Given the same `spawn_seed`, `get_spawn_position()` always returns the same position (deterministic)
- [ ] Given `spawn_seed = null`, a random seed is generated; the seed value is printed to console so the author can capture and fix it
- [ ] `spawn_seed = 0` is treated as a valid fixed seed (not null); deterministic output
- [ ] Returned position is always inside table bounds (clamped: `Rect2(table_bounds.position, table_bounds.end - card_size)`)
- [ ] `combination_point` is clamped to table bounds before sampling to handle mid-tween edge cases
- [ ] When `spawn_min_distance > spawn_max_distance`, values are swapped and `push_warning` is called; sampling continues with corrected values

---

## Implementation Notes

*Derived from GDD table-layout-system.md Spawn Placement Algorithm section:*

- Replace story-001 stub in `get_spawn_position` with the full algorithm:
  ```gdscript
  var rng := RandomNumberGenerator.new()
  var actual_seed: int
  if spawn_seed == null:
      rng.randomize()
      actual_seed = rng.seed
      print("TableLayoutSystem: random spawn_seed used = %d" % actual_seed)
  else:
      actual_seed = int(spawn_seed)
      rng.seed = actual_seed

  # Self-correct misconfigured min/max
  var s_min := spawn_min_distance
  var s_max := spawn_max_distance
  if s_min > s_max:
      push_warning("TableLayoutSystem: spawn_min_distance > spawn_max_distance — swapping")
      var tmp := s_min; s_min = s_max; s_max = tmp

  # Clamp combination_point to table bounds
  var cp := Vector2(
      clamp(combination_point.x, table_bounds.position.x, table_bounds.end.x),
      clamp(combination_point.y, table_bounds.position.y, table_bounds.end.y)
  )

  var offset := rng.randf_range(s_min, s_max)
  var angle  := rng.randf_range(0.0, TAU)
  var candidate := cp + Vector2(cos(angle), sin(angle)) * offset

  # Clamp to table bounds accounting for card size
  candidate.x = clamp(candidate.x, table_bounds.position.x, table_bounds.end.x - card_size.x)
  candidate.y = clamp(candidate.y, table_bounds.position.y, table_bounds.end.y - card_size.y)

  return { "position": candidate, "seed_used": actual_seed }
  ```
- Same seeded RNG approach applies to `get_seed_card_positions` for `placement_seed` (replace story-001 stub).
- `table_bounds: Rect2` is an `@export` variable; default set to `Rect2(0, 0, 1920, 1080)` until project art dimensions are locked.
- `spawn_min_distance` and `spawn_max_distance` are `@export` floats with defaults 80.0 and 160.0.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: API shape, card_id validation, zone-too-small fallback
- [Story 003]: Overlap avoidance loop (this story returns the first candidate without overlap checking)

---

## QA Test Cases

- **AC-1**: Deterministic output for same seed
  - Given: combination_point=Vector2(500,400), existing_cards=[], spawn_seed=12345
  - When: `get_spawn_position(Vector2(500,400), [], 12345)` called twice
  - Then: both calls return Dictionary with identical "position" Vector2 values

- **AC-2**: Null seed generates and logs a seed
  - Given: spawn_seed = null
  - When: `get_spawn_position(Vector2(500,400), [], null)` called
  - Then: returned Dictionary has "position" (valid Vector2, not null) and "seed_used" (non-zero int); console output contains the seed value
  - Edge cases: two separate calls with null return different positions (different random seeds each time)

- **AC-3**: Seed 0 is deterministic (not treated as null)
  - Given: spawn_seed = 0
  - When: called twice
  - Then: both return same position; console does NOT print a "random seed used" message for seed 0

- **AC-4**: Position always inside table bounds
  - Given: table_bounds=Rect2(0,0,1920,1080), card_size=Vector2(80,120); combination_point anywhere in bounds
  - When: get_spawn_position called 50 times with random seeds
  - Then: every returned position.x ∈ [0, 1840]; position.y ∈ [0, 960]
  - Edge cases: combination_point at (0,0) — candidate still inside bounds

- **AC-5**: combination_point outside bounds is clamped before sampling
  - Given: combination_point=Vector2(-100, 2000) (outside table_bounds)
  - When: get_spawn_position called
  - Then: no crash; candidate starts from a clamped point inside bounds; returned position inside bounds

- **AC-6**: swap + warning on min > max
  - Given: spawn_min_distance=200, spawn_max_distance=50 (misconfigured)
  - When: get_spawn_position called
  - Then: `push_warning` was called; returned position is at a distance between 50 and 200 from combination_point (sampling used corrected range)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/table_layout_system/seeded_rng_sampling_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/table_layout_system/seeded_rng_sampling_test.gd`

---

## Dependencies

- Depends on: story-001-api-scaffold must be DONE
- Unlocks: story-003-overlap-zone
