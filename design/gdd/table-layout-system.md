# Table Layout System

> **Status**: Designed
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-23
> **Implements Pillar**: Discovery without Explanation (table feels like a natural space to explore)

## Overview

The Table Layout System is responsible for placing cards in 2D space. It computes
where seed cards appear when a scene begins and where newly spawned cards land
after a combination fires. It defines the table's visual bounds and uses a
seeded random algorithm so that spawn positions can be iterated on during
authoring and locked in permanently once they look right. At runtime the system
is passive — once it provides a position, the Card Engine owns that card's location.

## Player Fantasy

The table should feel like a surface with room to breathe. Seed cards at scene
start feel intentionally arranged, not mechanical. Newly discovered cards appear
near their source in available space. The table never feels cluttered or hostile.
From the author's perspective: Chester can place every card exactly where he wants
it by fixing a seed — the table is as intentional as a physical arrangement of
photographs on a desk.

## Detailed Design

### Core Rules

1. The Table Layout System is **stateless at runtime** — it computes positions on request and returns them. It does not track where cards currently are.
2. All positions returned are in Godot world coordinates, clamped to table bounds.
3. Every placement uses a **seeded random number generator**. If a seed is provided, the position is deterministic. If no seed is provided, a random seed is generated and logged to console so the author can record and fix it.
4. The system never moves cards — it only provides target positions. The Card Spawning System and Scene Manager use those positions to place cards.
5. Overlap avoidance: if a computed position is within `min_card_spacing` of an existing card, the algorithm attempts up to `max_scatter_attempts` alternative positions before accepting the best available.

### Seed Card Placement

At scene load, the Scene Manager calls `get_seed_card_positions(scene_data)` with the scene's card list. Each seed card entry in the scene data has:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `card_id` | string | Yes | Card to place |
| `zone` | enum | Yes | `left` \| `center` \| `right` \| `top` \| `bottom` — rough area of the table |
| `placement_seed` | int | No | Fixed seed for deterministic position within the zone. If null, random seed is used and logged. |

The algorithm for each seed card:
1. Resolve the zone to a `Rect2` region of the table (see Table Bounds)
2. Initialize RNG with `placement_seed` (or random if null)
3. Sample a position within the zone rect
4. Check overlap against already-placed cards; scatter if needed
5. Return the position and the seed used (so null seeds can be fixed by the author)

### Spawn Placement Algorithm

When a combination fires and a new card is spawned, the Card Spawning System calls `get_spawn_position(combination_point, existing_cards, spawn_seed)`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `combination_point` | Vector2 | World position where the combination occurred (midpoint of the two source cards) |
| `existing_cards` | Vector2[] | Positions of all current cards on the table (provided by caller) |
| `spawn_seed` | int \| null | Fixed seed from the recipe's `spawn_seed` field, or null for random |

Algorithm:
1. Initialize RNG with `spawn_seed` (or random if null). Log the seed used.
2. Sample a candidate position near `combination_point`:
   ```
   offset = RNG.randf_range(spawn_min_distance, spawn_max_distance)
   angle  = RNG.randf_range(0, TAU)
   candidate = combination_point + Vector2(cos(angle), sin(angle)) * offset
   ```
3. Clamp `candidate` to table bounds.
4. If `candidate` is within `min_card_spacing` of any existing card, resample (up to `max_scatter_attempts`).
5. Return the best candidate found and the seed used.

The `spawn_seed` field in the Recipe Database is where Chester locks in placements he likes. During development: leave null, play, observe where cards land, copy the logged seed into the recipe file.

### Table Bounds

The table is a fixed `Rect2` in world space. Cards may not be placed (by this system) outside it.

| Zone | Approx portion of table |
|------|------------------------|
| `left` | Left 33% |
| `center` | Middle 34% |
| `right` | Right 33% |
| `top` | Top 40% |
| `bottom` | Bottom 40% |

Zones can overlap (e.g., a card in `center` may overlap with `top`). They are coarse guides, not hard partitions.

The table bounds are a tuning knob — set once per project based on the scene background art size.

### States and Transitions

The Table Layout System is stateless. It has no internal state machine. Every call is a pure function: inputs → position output.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Card Database** | Reads | Validates that card IDs in placement requests exist. Reads `scene_id` to confirm card belongs to the requested scene. |
| **Card Spawning System** | Serves | Provides spawn positions on request via `get_spawn_position()` |
| **Scene Manager** | Serves | Provides seed card positions on scene load via `get_seed_card_positions()` |
| **Input System** | No direct relationship | Input System reads card positions from Card Engine nodes at runtime, not from Table Layout |

## Formulas

### Spawn Position Sampling

```
offset    = RNG.randf_range(spawn_min_distance, spawn_max_distance)
angle     = RNG.randf_range(0, TAU)
candidate = combination_point + Vector2(cos(angle), sin(angle)) * offset
candidate = clamp(candidate, table_bounds.position, table_bounds.end - card_size)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `spawn_min_distance` | float | 60–120px | Tuning knob | Minimum distance from combination point |
| `spawn_max_distance` | float | 120–220px | Tuning knob | Maximum distance from combination point |
| `angle` | float | 0–2π | RNG | Direction from combination point |
| `combination_point` | Vector2 | table bounds | Card Spawning caller | Midpoint of the two source cards |
| `card_size` | Vector2 | fixed | Card Visual | Used to keep card fully inside table bounds |

**Expected output**: a world-space position within `spawn_min_distance`–`spawn_max_distance` of the combination, inside table bounds, not overlapping existing cards (best effort).

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **Table is full — no valid spawn position found** | `max_scatter_attempts` exhausted, all candidates overlap | Accept the least-overlapping candidate. Log a warning with the scene and card ID. Never refuse to spawn. |
| **`spawn_seed` = 0** | Author explicitly sets seed to 0 | Treat as a valid fixed seed (0 is a legal RNG seed, not "null"). Only `null` means "use random." |
| **Zone rect is too small for card** | A zone Rect2 is smaller than card size | Log an error. Fall back to placing at zone center. |
| **`combination_point` is outside table bounds** | Edge case from a mid-tween combination | Clamp `combination_point` to table bounds before sampling. |
| **`spawn_min_distance` > `spawn_max_distance`** | Misconfigured tuning knobs | Swap values and log a warning. |
| **Seed logged but not recorded by author** | Author forgets to fix the seed before shipping | Positions will vary between playthroughs. Not a crash, but unintended for a handcrafted experience. Authoring guide should remind Chester to fix all seeds before final build. |

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Card Database** | Card ID validation; `scene_id` to confirm a card belongs to a scene | Soft — system still places cards without it, but can't validate |

### Downstream (systems that depend on this)

| System | What They Need |
|--------|---------------|
| **Card Spawning System** | `get_spawn_position(combination_point, existing_cards, spawn_seed)` → `Vector2` + seed used |
| **Scene Manager** | `get_seed_card_positions(scene_data)` → list of `{card_id, position, seed_used}` |

## Tuning Knobs

| Knob | Type | Default | Safe Range | Too Low | Too High |
|------|------|---------|------------|---------|----------|
| `spawn_min_distance` | float (px) | 80 | 40–120 | Cards spawn on top of source; visually confusing | Cards spawn far away; breaks the sense of connection to the combination |
| `spawn_max_distance` | float (px) | 160 | 100–250 | (see min) | Cards spawn at edges of table frequently |
| `min_card_spacing` | float (px) | 10 | 0–30 | Cards overlap completely; table looks broken | Cards spread too far apart; table feels empty |
| `max_scatter_attempts` | int | 8 | 3–20 | Gives up too quickly; frequent overlaps | Performance cost for very full tables |
| `table_bounds` | Rect2 | Set per project | Based on scene art | Cards spawn outside visible area | N/A — set to match background art dimensions |

**Note**: `spawn_seed` and `placement_seed` are per-recipe / per-scene-card-entry authoring values, not global knobs.

## Acceptance Criteria

- [ ] Given the same `spawn_seed`, `get_spawn_position()` always returns the same position
- [ ] Given `spawn_seed = null`, a random seed is generated and printed to console
- [ ] Returned positions are always inside table bounds (never off-screen)
- [ ] Returned positions do not overlap existing cards (best effort; warns if impossible)
- [ ] Seed cards are placed within their specified zone rect
- [ ] `placement_seed = null` generates and logs a seed for the author to fix
- [ ] `spawn_seed = 0` is treated as a valid fixed seed (not null)
- [ ] When `max_scatter_attempts` is exhausted, system accepts best candidate and logs warning (no crash)
- [ ] `get_seed_card_positions()` returns one entry per seed card with `{card_id, position, seed_used}`
- [ ] Misconfigured `spawn_min > spawn_max` is self-corrected with a warning

## Open Questions

- **Seed logging UX**: Where are unfixed seeds logged? Console only, or also written to a dev file (e.g., `logs/unfixed-seeds.txt`) for easy collection? A dev file would make the seed-fixing workflow smoother.
- **Card size constant**: The overlap check uses `card_size`. This should come from Card Visual — needs to be agreed on before implementation.
- **Zone definitions**: Are 5 zones (left/center/right/top/bottom) enough, or should scenes be able to define custom zone rects? Could be useful for scenes with specific background art that shapes card placement naturally.
