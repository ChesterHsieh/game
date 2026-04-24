# Story 004: Bar Milestone Spawn

> **Epic**: Scene Goal System
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-goal-system.md`
**Requirement**: `TR-scene-goal-system-013`, `TR-scene-goal-system-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-005: Data File Format Convention
**ADR Decision Summary**: Per-scene config lives in `assets/data/scenes/[scene_id].tres` as a typed `SceneData` Resource; all scene-specific data (including milestones) is read from this file at `load_scene()` time.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `PackedStringArray` and `Array[Dictionary]` are stable in 4.3. `EventBus.bar_values_changed` signal already declared and tested.

**Control Manifest Rules (Feature layer)**:
- Required: Declare `milestone_cards_spawn` in `EventBus` before implementing the emitter (already done — `src/core/event_bus.gd`)
- Required: All cross-system events go through EventBus — SGS emits, Scene Manager listens and spawns
- Forbidden: SGS must not directly call Scene Manager or CardSpawner to spawn cards

---

## Acceptance Criteria

*From GDD `design/gdd/scene-goal-system.md`, scoped to this story:*

- [ ] When a bar reaches a milestone `value` for the first time, `EventBus.milestone_cards_spawn(card_ids)` fires with the correct `spawns` array from scene JSON
- [ ] A milestone fires at most once per `load_scene()` — reaching the same bar value again (or exceeding it) does not re-fire the same milestone
- [ ] A scene JSON with no `milestones` key loads and runs without error
- [ ] A milestone entry referencing a non-existent `bar_id` logs a warning and is skipped — does not crash

---

## Implementation Notes

*Derived from ADR-005 and GDD scene-goal-system.md §Core Rules #5:*

- `SceneData` Resource (or its `GoalSpec` sub-Resource) needs a new field:
  `milestones: Array[Dictionary]` — each dict has keys `bar_id: String`, `value: int`, `spawns: PackedStringArray`
- On `load_scene()`, parse `milestones` from the loaded `SceneData` and build an internal `_pending_milestones: Array[Dictionary]` (mutable copy — entries removed as they fire)
- Connect to `EventBus.bar_values_changed` in `_enter_active_state()` and disconnect in `reset()`
- In the `bar_values_changed` handler: iterate `_pending_milestones`; for each entry where `values[entry.bar_id] >= entry.value`, emit `EventBus.milestone_cards_spawn(entry.spawns)` and remove the entry from `_pending_milestones`
- On `reset()`: clear `_pending_milestones` alongside other Active-state cleanup

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Scene Manager** (separate epic): listens to `milestone_cards_spawn` and physically spawns the cards onto the table — not implemented here
- **Story 003**: win condition handling — do not modify `scene_completed` logic

---

## QA Test Cases

- **AC-1**: Milestone fires on first reach
  - Given: scene loaded with `milestones: [{ bar_id: "journey_progress", value: 2, spawns: ["good_scenery"] }]`
  - When: `EventBus.bar_values_changed.emit({ "journey_progress": 2 })` is called
  - Then: `EventBus.milestone_cards_spawn` emits with `["good_scenery"]`
  - Edge cases: value = 2.0 (float), value exactly at threshold vs. one below

- **AC-2**: Milestone fires at most once
  - Given: AC-1 setup, milestone already fired
  - When: `bar_values_changed` fires again with `{ "journey_progress": 2 }` or `{ "journey_progress": 3 }`
  - Then: `milestone_cards_spawn` does NOT emit a second time

- **AC-3**: No milestones key — no crash
  - Given: scene JSON with no `milestones` field in goal block
  - When: `load_scene()` called
  - Then: scene loads normally, no error, no signal emitted

- **AC-4**: Unknown bar_id — warning, no crash
  - Given: milestone entry with `bar_id: "nonexistent_bar"`
  - When: `bar_values_changed` fires with any values
  - Then: a `push_warning()` is logged, no crash, no signal emitted for that entry

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scene_goal_system/bar_milestone_spawn_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (win-condition handling) must be DONE
- Unlocks: Scene Manager story that consumes `milestone_cards_spawn` (separate epic)
