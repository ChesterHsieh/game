# Story 003: Save/load round-trip + force_unlock_all dev bypass

> **Epic**: Mystery Unlock Tree
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/mystery-unlock-tree.md`
**Requirements**: `TR-mystery-unlock-tree-012`, `TR-013`, `TR-014`, `TR-020`

**ADR Governing Implementation**: ADR-005 (`debug-config.tres` loaded at `_ready()` as typed Resource; excluded from release export via `export_presets.cfg` per-preset exclude filter) + ADR-004 (bulk-load bypass runs in `_ready()` after RecipeDB is queried, before any scene signals can arrive; `_suppress_signals` flag prevents milestone/epilogue emissions during bulk fill)
**ADR Decision Summary**: `get_save_state()` serializes all three dictionaries plus `_epilogue_conditions_emitted`. `load_save_state()` restores them and prunes any recipe_ids that no longer exist in RecipeDatabase (stale data), logging a warning per pruned entry and recalculating `_discovery_order_counter`. `force_unlock_all` bypass bulk-fills all three dictionaries under `_suppress_signals = true` — no `recipe_discovered`, milestone, or epilogue signals emitted.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `debug-config.tres` exclusion from release builds is configured in `export_presets.cfg` via the resource exclude filter — not a code-level check. Code uses `ResourceLoader.load()` — if the file is absent (release build), the returned null is treated as "bypass disabled".

---

## Acceptance Criteria

- [ ] `get_save_state() -> Dictionary`: returns serializable snapshot of `_discovered_recipes`, `_scene_discoveries`, `_cards_in_discoveries`, `_epilogue_conditions_emitted`, `_final_memory_earned`; no signals, no mutations
- [ ] `load_save_state(data: Dictionary) -> void`: restores all five fields; prunes stale recipe_ids (not in RecipeDatabase) from all three dictionaries; logs warning per pruned entry; recalculates `_discovery_order_counter` from surviving entries
- [ ] Stale recipe on load: pruned from `_discovered_recipes`, from all `_scene_discoveries` arrays, and from `_cards_in_discoveries` where relevant; `_discovery_order_counter` set to count of surviving entries
- [ ] `force_unlock_all` bypass: load `debug-config.tres` at `_ready()` (after RecipeDB available, before scene signals); if present and `force_unlock_all == true`: set `_suppress_signals = true`; write all recipes into all three dictionaries under scene_id `"__debug__"`; set `_discovery_order_counter = R_authored`; set `_epilogue_conditions_emitted = true`; set `_final_memory_earned = true`; restore `_suppress_signals = false`; log one warning naming count
- [ ] No `recipe_discovered`, `discovery_milestone_reached`, or `epilogue_conditions_met` emitted during `force_unlock_all` bulk-load
- [ ] `debug-config.tres` absent (release build): bypass silently disabled; `_suppress_signals` remains false
- [ ] `_inject_config(config: Dictionary)` and `_inject_debug_config(config: Variant)` test seams available (not production paths)

---

## Implementation Notes

*Derived from ADR-005 + ADR-004 + GDD mystery-unlock-tree.md:*

```gdscript
func get_save_state() -> Dictionary:
    return {
        "discovered_recipes": _discovered_recipes.duplicate(true),
        "scene_discoveries": _scene_discoveries.duplicate(true),
        "cards_in_discoveries": _cards_in_discoveries.duplicate(true),
        "epilogue_conditions_emitted": _epilogue_conditions_emitted,
        "final_memory_earned": _final_memory_earned,
    }

func load_save_state(data: Dictionary) -> void:
    _discovered_recipes = data.get("discovered_recipes", {}).duplicate(true)
    _scene_discoveries = data.get("scene_discoveries", {}).duplicate(true)
    _cards_in_discoveries = data.get("cards_in_discoveries", {}).duplicate(true)
    _epilogue_conditions_emitted = data.get("epilogue_conditions_emitted", false)
    _final_memory_earned = data.get("final_memory_earned", false)
    _prune_stale_recipes()
    _recalculate_counter()

func _prune_stale_recipes() -> void:
    var stale: Array[String] = []
    for rid in _discovered_recipes.keys():
        if not RecipeDatabase.has_recipe(rid):
            stale.append(rid)
    for rid in stale:
        push_warning("MUT: pruning stale recipe_id '%s' from save state" % rid)
        _discovered_recipes.erase(rid)
        for scene_id in _scene_discoveries.keys():
            _scene_discoveries[scene_id].erase(rid)

func _recalculate_counter() -> void:
    _discovery_order_counter = _discovered_recipes.size()

func _run_force_unlock_all() -> void:
    var debug_cfg = ResourceLoader.load("res://assets/data/debug-config.tres")
    if debug_cfg == null or not debug_cfg.get("force_unlock_all", false):
        return
    _suppress_signals = true
    var recipes := RecipeDatabase.get_all_recipe_ids()
    _scene_discoveries["__debug__"] = Array([], TYPE_STRING, "", null)
    for rid in recipes:
        if rid not in _discovered_recipes:
            _discovery_order_counter += 1
            _discovered_recipes[rid] = {
                "order": _discovery_order_counter, "scene_id": "__debug__",
                "template": "", "card_id_a": "", "card_id_b": ""
            }
            _scene_discoveries["__debug__"].append(rid)
    _discovery_order_counter = RecipeDatabase.get_recipe_count()
    _epilogue_conditions_emitted = true
    _final_memory_earned = true
    _suppress_signals = false
    push_warning("MUT: force_unlock_all active — %d recipes bulk-marked (DEV ONLY)" % _discovery_order_counter)
```

- `_inject_config` and `_inject_debug_config` are test seams that override the file-load paths. They replace the `ResourceLoader.load()` call result with in-memory data. Called in test `_ready()` before config is consumed.
- `duplicate(true)` performs a deep copy — nested Dictionaries and Arrays are not shared by reference.

---

## Out of Scope

- [Story 001]: Core discovery recording and state machine
- [Story 002]: Milestones, epilogue conditions, carry-forward API

---

## QA Test Cases

- **AC-1**: get_save_state round-trips correctly
  - Given: MUT with 3 discoveries, `_epilogue_conditions_emitted = true`
  - When: `data = get_save_state()`; new MUT instance calls `load_save_state(data)`
  - Then: `_discovered_recipes` identical; `_epilogue_conditions_emitted == true`; `_discovery_order_counter == 3`

- **AC-2**: Stale recipe pruned on load
  - Given: save data contains recipe_id "old-recipe" not in RecipeDatabase
  - When: `load_save_state(data)` called
  - Then: "old-recipe" not in `_discovered_recipes`; warning logged; `_discovery_order_counter` reflects surviving count

- **AC-3**: force_unlock_all bulk-marks without signals
  - Given: `debug-config.tres` with `force_unlock_all = true`; 5 recipes in RecipeDatabase; signal listener attached
  - When: `_run_force_unlock_all()` runs
  - Then: all 5 recipes in `_discovered_recipes`; `recipe_discovered` NOT emitted; `_epilogue_conditions_emitted == true`; `_suppress_signals == false` after completion

- **AC-4**: force_unlock_all absent (release build)
  - Given: `debug-config.tres` not present
  - When: MUT `_ready()` runs
  - Then: `_discovered_recipes` empty; `_suppress_signals == false`; no bypass-related log

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/mystery_unlock_tree/save_load_bypass_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: story-002-milestones-epilogue must be DONE
- Unlocks: None (final MysteryUnlockTree story)
