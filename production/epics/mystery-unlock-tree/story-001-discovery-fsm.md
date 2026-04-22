# Story 001: MUT autoload + discovery recording + state machine

> **Epic**: Mystery Unlock Tree
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/mystery-unlock-tree.md`
**Requirements**: `TR-mystery-unlock-tree-001`, `TR-002`, `TR-003`, `TR-004`, `TR-005`, `TR-015`, `TR-017`, `TR-018`, `TR-019`

**ADR Governing Implementation**: ADR-003 (listens to `combination_executed` 6-param, `scene_started`, `scene_completed`, `epilogue_started` via EventBus; emits `recipe_discovered`) + ADR-004 (MUT is autoload position 10; pure observer — no card spawning, no recipe gating)
**ADR Decision Summary**: MUT is a pure-observer autoload that records first-time recipe discoveries. It processes `combination_executed` only in Active state. Duplicate recipe_ids are silently discarded without incrementing the counter. The 6-param handler reads `recipe_id`, `card_id_a`, `card_id_b` and ignores `template`, `instance_id_a`, `instance_id_b`. `_scene_discoveries` values are initialized as `Array[String]` (typed array, not plain Array).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: 6-param `combination_executed` handler must declare all 6 params (arity-strict in Godot 4.3). Typed array `Array[String]` initialization in Dictionary requires `_scene_discoveries[scene_id] = Array([], TYPE_STRING, "", null)` in GDScript 4.3.

---

## Acceptance Criteria

- [ ] MUT is autoload singleton; `class_name MysteryUnlockTree extends Node`; pure observer (no spawning, no recipe gating, no signal blocking)
- [ ] State machine: `enum _State { INACTIVE, ACTIVE, TRANSITIONING, EPILOGUE }`; starts `INACTIVE`
- [ ] `scene_started(scene_id)`: Inactive/Transitioning → Active; set `_active_scene_id`; initialize `_scene_discoveries[scene_id]` as `Array[String]` if not present
- [ ] `scene_completed(scene_id)`: Active → Transitioning (only if scene_id matches `_active_scene_id`; mismatches silently ignored)
- [ ] `epilogue_started()`: any non-terminal state → Epilogue (terminal); log warning if coming from Active
- [ ] `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)`: declare all 6 params; only process in Active state; ignore otherwise
- [ ] First-time discovery: validate recipe_id in RecipeDatabase (push_warning + skip if unknown); increment `_discovery_order_counter`; store 5-field record in `_discovered_recipes`; append recipe_id to `_scene_discoveries[_active_scene_id]`; first-writer-wins for `_cards_in_discoveries`; emit `recipe_discovered(recipe_id, card_id_a, card_id_b, _active_scene_id)`
- [ ] Duplicate recipe_id: silently return; counter unchanged; no `recipe_discovered` emitted
- [ ] All query API methods (`is_recipe_discovered`, `get_discovery_count`, `get_scene_discoveries`, `get_discovery_record`, `is_card_in_discovery`) are side-effect-free
- [ ] `R_authored == 0` at startup (RecipeDatabase load failure): skip milestone resolution; set `_milestone_thresholds = []`; log error

---

## Implementation Notes

*Derived from ADR-003 + ADR-004 + GDD mystery-unlock-tree.md:*

```gdscript
class_name MysteryUnlockTree extends Node

enum _State { INACTIVE, ACTIVE, TRANSITIONING, EPILOGUE }
var _state := _State.INACTIVE

# Primary storage
var _discovered_recipes: Dictionary = {}  # recipe_id -> { order, scene_id, template, card_id_a, card_id_b }
var _discovery_order_counter: int = 0
var _active_scene_id: String = ""

# Secondary indices
var _scene_discoveries: Dictionary = {}  # scene_id -> Array[String]
var _cards_in_discoveries: Dictionary = {}  # card_id -> scene_id (first-writer-wins)

func _on_combination_executed(recipe_id: String, _template: String,
        _iid_a: String, _iid_b: String, card_id_a: String, card_id_b: String) -> void:
    if _state != _State.ACTIVE:
        return
    if recipe_id in _discovered_recipes:
        return
    if not RecipeDatabase.has_recipe(recipe_id):
        push_warning("MUT: unknown recipe_id '%s' — skipping" % recipe_id)
        return
    _discovery_order_counter += 1
    _discovered_recipes[recipe_id] = {
        "order": _discovery_order_counter,
        "scene_id": _active_scene_id,
        "template": _template,
        "card_id_a": card_id_a,
        "card_id_b": card_id_b,
    }
    _scene_discoveries[_active_scene_id].append(recipe_id)
    if card_id_a and card_id_a not in _cards_in_discoveries:
        _cards_in_discoveries[card_id_a] = _active_scene_id
    if card_id_b and card_id_b not in _cards_in_discoveries:
        _cards_in_discoveries[card_id_b] = _active_scene_id
    EventBus.recipe_discovered.emit(recipe_id, card_id_a, card_id_b, _active_scene_id)
    if not _suppress_signals:
        _evaluate_milestones()
        _evaluate_epilogue_conditions()
```

- `_suppress_signals` flag (bool, default false): controls milestone/epilogue evaluation bypass — used only by `force_unlock_all` (story-003).
- `_scene_discoveries[scene_id]` initialized as `Array([], TYPE_STRING, "", null)` on `scene_started`.
- Empty `card_id_a`/`card_id_b`: skip `_cards_in_discoveries` update for the empty id; log warning.

---

## Out of Scope

- [Story 002]: Milestone resolution, epilogue conditions, `final_memory_ready`, carry-forward API
- [Story 003]: Save/load round-trip, `force_unlock_all` dev bypass

---

## QA Test Cases

- **AC-1**: First discovery recorded and recipe_discovered emitted
  - Given: MUT Active; recipe "home-rain-walk" not in `_discovered_recipes`; RecipeDatabase has the recipe
  - When: `combination_executed("home-rain-walk", "additive", "rain_1", "walk_1", "rain", "walk")` fires
  - Then: `_discovered_recipes["home-rain-walk"]` exists with order=1; `recipe_discovered("home-rain-walk", "rain", "walk", _active_scene_id)` emitted; `_discovery_order_counter == 1`

- **AC-2**: Duplicate recipe silently ignored
  - Given: "home-rain-walk" already in `_discovered_recipes`; counter=1
  - When: same `combination_executed` fires again
  - Then: counter still 1; `recipe_discovered` NOT emitted a second time

- **AC-3**: combination_executed ignored when not Active
  - Given: MUT in Inactive state
  - When: `combination_executed(...)` fires
  - Then: `_discovered_recipes` unchanged; no signals emitted

- **AC-4**: State transitions follow FSM
  - Given: MUT Inactive
  - When: `scene_started("home")` fires, then `scene_completed("home")`, then `epilogue_started()`
  - Then: after scene_started → Active; after scene_completed → Transitioning; after epilogue_started → Epilogue

- **AC-5**: Unknown recipe_id skipped with warning
  - Given: MUT Active; recipe_id "fake" not in RecipeDatabase
  - When: `combination_executed("fake", ...)` fires
  - Then: warning logged; `_discovered_recipes` unchanged; `recipe_discovered` NOT emitted

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/mystery_unlock_tree/discovery_fsm_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: foundation/recipe-database must be DONE (RecipeDatabase.has_recipe() available); interaction-template-framework `story-003-additive-template` must be DONE (combination_executed signal established); scene-manager `story-003` must be DONE (scene_started/scene_completed/epilogue_started flowing)
- Unlocks: story-002-milestones-epilogue
