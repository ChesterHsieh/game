# Story 003: Overlap avoidance + zone placement + tuning knobs

> **Epic**: Table Layout System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/table-layout-system.md`
**Requirements**: `TR-table-layout-system-010`, `TR-table-layout-system-011`, `TR-table-layout-system-012`, `TR-table-layout-system-016`, `TR-table-layout-system-017`

**ADR Governing Implementation**: ADR-001 (naming; stateless design; exported tuning knobs)
**ADR Decision Summary**: TableLayoutSystem is stateless at runtime — overlap avoidance is best-effort, retrying up to `max_scatter_attempts` and accepting the least-bad candidate rather than failing. Zone → Rect2 mapping is pure data conversion with no side effects.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `Rect2` math (`Rect2.position`, `Rect2.end`, `Rect2.get_center()`) is stable. `Vector2.distance_to()` is a built-in method. `@export` on float/int fields works as expected in 4.3.

**Control Manifest Rules (Core layer)**:
- Required: Gameplay values (spacing, attempt counts, distance ranges) are exported — never hardcoded inside methods
- Required: Pure function — every call is independent; no retained state

---

## Acceptance Criteria

*From GDD `design/gdd/table-layout-system.md`, scoped to this story:*

- [ ] Returned positions do not overlap existing cards (best effort): a candidate within `min_card_spacing` of any existing card is rejected; a new candidate is sampled
- [ ] When `max_scatter_attempts` is exhausted, the least-overlapping candidate (highest minimum distance to any neighbor) is accepted and `push_warning` is logged; no crash; always returns a position
- [ ] Seed card entries are placed within their specified zone Rect2 (left / center / right / top / bottom)
- [ ] `spawn_min_distance` (default 80, safe range 40–120), `spawn_max_distance` (default 160, range 100–250), `min_card_spacing` (default 10, range 0–30), `max_scatter_attempts` (default 8, range 3–20) are all `@export` variables

---

## Implementation Notes

*Derived from GDD table-layout-system.md Spawn Placement Algorithm + Zone Definitions:*

- Replace story-002 stub (which returns first candidate) with the retry loop:
  ```gdscript
  var best_candidate := candidate
  var best_min_dist  := _min_dist_to_existing(candidate, existing_cards)

  for _attempt in range(max_scatter_attempts - 1):
      if best_min_dist >= min_card_spacing:
          break  # good enough
      # Resample (re-use rng — already seeded; subsequent calls give new values)
      offset   = rng.randf_range(s_min, s_max)
      angle    = rng.randf_range(0.0, TAU)
      candidate = cp + Vector2(cos(angle), sin(angle)) * offset
      candidate.x = clamp(candidate.x, ...)
      candidate.y = clamp(candidate.y, ...)
      var d := _min_dist_to_existing(candidate, existing_cards)
      if d > best_min_dist:
          best_min_dist = d
          best_candidate = candidate

  if best_min_dist < min_card_spacing:
      push_warning("TableLayoutSystem: max_scatter_attempts exhausted; accepting overlapping position")

  return { "position": best_candidate, "seed_used": actual_seed }
  ```
- `_min_dist_to_existing(pos: Vector2, existing: Array) -> float`: return minimum `pos.distance_to(p)` across all `p` in `existing`; return INF if `existing` is empty.
- **Zone → Rect2 mapping** (for `get_seed_card_positions`):
  ```gdscript
  func _zone_to_rect(zone: String) -> Rect2:
      var w := table_bounds.size.x
      var h := table_bounds.size.y
      match zone:
          "left":   return Rect2(table_bounds.position, Vector2(w * 0.33, h))
          "right":  return Rect2(table_bounds.position + Vector2(w * 0.67, 0), Vector2(w * 0.33, h))
          "center": return Rect2(table_bounds.position + Vector2(w * 0.33, 0), Vector2(w * 0.34, h))
          "top":    return Rect2(table_bounds.position, Vector2(w, h * 0.4))
          "bottom": return Rect2(table_bounds.position + Vector2(0, h * 0.6), Vector2(w, h * 0.4))
          _:
              push_warning("TableLayoutSystem: unknown zone '%s'; using full table" % zone)
              return table_bounds
  ```
- Exported tuning knobs (add to autoload with `@export`):
  ```gdscript
  @export var spawn_min_distance: float = 80.0
  @export var spawn_max_distance: float = 160.0
  @export var min_card_spacing:   float = 10.0
  @export var max_scatter_attempts: int = 8
  ```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: API shape and card_id validation
- [Story 002]: Seeded RNG, null seed logging, bounds clamping

---

## QA Test Cases

- **AC-1**: Overlap avoidance works for sparse table
  - Given: 3 existing cards at Vector2(200,200), Vector2(400,400), Vector2(600,600); min_card_spacing=10; card_size=Vector2(80,120); spawn_seed=42
  - When: `get_spawn_position(Vector2(300,300), [Vector2(200,200), Vector2(400,400), Vector2(600,600)], 42)`
  - Then: returned position is at least 90px from all 3 existing cards (min_card_spacing + some buffer)
  - Edge cases: empty existing_cards → returns first candidate (no avoidance needed)

- **AC-2**: Exhaustion logs warning, never crashes, returns a position
  - Given: existing_cards fills the area densely (20 cards at 80px spacing); max_scatter_attempts=3
  - When: `get_spawn_position` called
  - Then: returns a Dictionary with a valid "position" Vector2; `push_warning` was called; no crash; no null

- **AC-3**: Zone "left" places card in left third of table
  - Given: table_bounds=Rect2(0,0,1920,1080); seed card entry with zone="left" and placement_seed=1
  - When: `get_seed_card_positions([{"card_id":"morning-light","zone":"left","placement_seed":1}])` called
  - Then: returned position.x < 634 (33% of 1920); position.y ∈ [0, 1080]

- **AC-4**: Zone "right" places card in right third
  - Same as AC-3 but zone="right"; returned position.x > 1286 (67% of 1920)

- **AC-5**: Tuning knobs are exported and in-range defaults
  - Given: fresh TableLayoutSystem instance
  - When: reading exported properties
  - Then: spawn_min_distance==80.0; spawn_max_distance==160.0; min_card_spacing==10.0; max_scatter_attempts==8

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/table_layout_system/overlap_zone_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/table_layout_system/overlap_zone_test.gd`

---

## Dependencies

- Depends on: story-001-api-scaffold must be DONE (for zone-too-small guard + API shape)
- Unlocks: None (final TableLayoutSystem story)
