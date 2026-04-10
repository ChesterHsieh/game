# Sprint 02 — Core Layer

**Start**: 2026-03-27
**Goal**: Cards can appear on the table, be dragged, attracted, snapped, and trigger
         combination attempts. The physical feel of the game is fully implemented.

---

## Systems in Scope

| System | GDD | Layer | Effort |
|--------|-----|-------|--------|
| Table Layout System | design/gdd/table-layout-system.md | Core | S |
| Card Spawning System | design/gdd/card-spawning-system.md | Core | M |
| Card Engine | design/gdd/card-engine.md | Core | L |

**Dependency order**: Table Layout → Card Spawning → Card Engine

**Out of scope**: ITF, Status Bar, Scene Goal, Hint System, Card Visual, Status Bar UI.
Card Engine fires `combination_attempted` but nothing responds yet — that's Sprint 03.

---

## Tasks

### Table Layout System (`src/gameplay/table_layout_system.gd`)

- [ ] Implement as plain Node (not Autoload — stateless, used by Card Spawning)
- [ ] `get_seed_positions(seed_cards: Array, rng_seed: int) -> Dictionary`
      Returns `{ card_id → Vector2 }` for each seed card
- [ ] `get_spawn_position(combination_point: Vector2, occupied: Array[Vector2], rng_seed: int) -> Vector2`
      Returns a position near `combination_point`, avoiding `occupied` positions
- [ ] Table bounds constant (safe area within viewport: 120px inset from edges)
- [ ] Overlap avoidance: up to 8 scatter attempts before accepting best result
- [ ] Log the seed used when `rng_seed == -1` (random) so Chester can fix it

### Card Spawning System (`src/gameplay/card_spawning_system.gd`)

- [ ] Implement as Autoload singleton
- [ ] `spawn_card(card_id: String, position: Vector2) -> String` — returns instance_id
- [ ] `remove_card(instance_id: String) -> void`
- [ ] `get_card_node(instance_id: String) -> Node2D`
- [ ] `get_all_instance_ids() -> Array[String]`
- [ ] `get_all_card_positions() -> Array[Vector2]`
- [ ] Instance ID format: `"{card_id}_{counter}"` — counter never reused
- [ ] Signals: `card_spawned(instance_id, card_id, position)`, `card_removed(instance_id)`
- [ ] Validates card_id against CardDatabase before spawning
- [ ] Registers/unregisters spawned nodes with InputSystem
- [ ] Register `CardSpawning` as Autoload in project.godot

### Card Node (`src/gameplay/card_node.gd` + `card_node.tscn`)

- [ ] Minimal Node2D — data container only (no visual rendering yet, that's Sprint 03)
- [ ] Exported: `instance_id: String`, `card_id: String`
- [ ] z_index managed by Card Engine

### Card Engine (`src/gameplay/card_engine.gd`)

- [ ] Implement as Autoload singleton
- [ ] Connect to all 5 InputSystem signals on `_ready()`
- [ ] State machine per card: Idle | Dragged | Attracting | Snapping | Pushed | Executing
- [ ] Drag: `drag_started` → card follows cursor world pos each frame
- [ ] Attract: `proximity_entered` → lerp(cursor, target, attraction_factor) each frame
- [ ] Snap: `drag_released` while Attracting → tween to target + offset → fire `combination_attempted`
- [ ] Push: `combination_failed` received → tween away from target
- [ ] Merge: `combination_succeeded` with Merge template → tween to midpoint, scale/fade to 0
- [ ] Additive: `combination_succeeded` → both cards return to Idle
- [ ] All tuning knobs as constants (from validated prototype values)
- [ ] Signals: `combination_attempted(a, b)`, `merge_complete(a, b, midpoint)`
- [ ] Register `CardEngine` as Autoload in project.godot

### Tuning Constants (validated in card-engine prototype)

| Knob | Value |
|------|-------|
| `attraction_factor` | 0.4 |
| `snap_duration_sec` | 0.12 |
| `push_distance` | 60px |
| `push_duration_sec` | 0.18 |
| `merge_duration_sec` | 0.55 |
| `snap_offset` | Vector2(16, 16) |

---

## Definition of Done

- [ ] `CardSpawning.spawn_card("chester", Vector2(300, 300))` creates a node at that position
- [ ] Spawned node is registered with InputSystem — can be dragged immediately
- [ ] Dragging a card follows cursor with zero perceptible lag
- [ ] Entering snap radius causes visible attraction drift toward target
- [ ] Releasing in snap radius fires `combination_attempted` with both instance IDs
- [ ] `combination_failed` plays push-away; card ends at new position (not origin)
- [ ] `combination_succeeded` Merge: both cards tween to midpoint and disappear
- [ ] `combination_succeeded` Additive: both cards stay in place
- [ ] Table Layout places seed cards with no overlaps (min spacing 100px)

---

## Notes

- Card Engine does NOT look up recipes — it fires `combination_attempted` and waits
- ITF doesn't exist yet; for sprint verification, stub `combination_failed` response
- Card Visual (Sprint 03) will add face rendering — cards are invisible rectangles this sprint
- The card_node.tscn just needs a collision area for InputSystem hit-testing
