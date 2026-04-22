# Story 002: Milestones + carry-forward + epilogue conditions

> **Epic**: Mystery Unlock Tree
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/mystery-unlock-tree.md`
**Requirements**: `TR-mystery-unlock-tree-006`, `TR-007`, `TR-008`, `TR-009`, `TR-010`, `TR-011`, `TR-016`

**ADR Governing Implementation**: ADR-005 (`mut-config.tres` and `epilogue-requirements.tres` loaded at `_ready()` as typed Resources; null check required) + ADR-003 (emits `discovery_milestone_reached`, `epilogue_conditions_met`, `final_memory_ready` via EventBus)
**ADR Decision Summary**: Milestone percentages are resolved to absolute counts at `_ready()` using `R_authored` from RecipeDatabase. Post-resolution dedup drops duplicate thresholds and logs a warning. `epilogue_conditions_met()` fires at most once per session (guarded by `_epilogue_conditions_emitted`); suppressed entirely when `partial_threshold == 0.0`. `final_memory_ready()` is evaluated on `epilogue_started()` only.

**Engine**: Godot 4.3 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] Load `mut-config.tres` at `_ready()`; null → use defaults (`_milestone_pct = [0.15, 0.50, 0.80]`, `partial_threshold = 0.80`)
- [ ] Load `epilogue-requirements.tres` at `_ready()`; null or empty → log error; suppress `epilogue_conditions_met` and `final_memory_ready` entirely (`_epilogue_required_ids = []`)
- [ ] Resolve `_milestone_pct` to `_milestone_thresholds`: `T_i = max(1, ceil(P_i * R_authored))` for each P_i; `R_authored == 0` → skip resolution, log error
- [ ] Post-resolution dedup: remove duplicate T_i values (keep lowest-index); log warning naming dropped entries; surviving thresholds remain strictly ascending
- [ ] After each first-time discovery: check `_discovery_order_counter` against each unfired threshold; emit `discovery_milestone_reached(milestone_id, count)` on match; `milestone_id = "milestone_" + str(i)` (0-indexed in deduplicated array)
- [ ] Each threshold fires at most once per session
- [ ] `epilogue_conditions_met()` emitted when `R_found >= ceil(R_total * partial_threshold)` and `_epilogue_conditions_emitted == false` and `partial_threshold > 0.0`; set `_epilogue_conditions_emitted = true` on first emission
- [ ] `partial_threshold == 0.0`: mid-session `epilogue_conditions_met` suppressed entirely; `final_memory_ready` still evaluated on `epilogue_started`
- [ ] Empty `_epilogue_required_ids` (`R_total == 0`): suppress both `epilogue_conditions_met` and `final_memory_ready`; log error
- [ ] `epilogue_started()` received: evaluate `R_found >= ceil(R_total * partial_threshold)`; if true emit `final_memory_ready()`; enter Epilogue state
- [ ] `get_carry_forward_cards(carry_forward_spec: Array) -> Array[String]`: for each entry check all `requires_recipes` in `_discovered_recipes`; return qualifying card_ids; empty `requires_recipes: []` → vacuously eligible
- [ ] Carry-forward called while Inactive: `_discovered_recipes` is empty; all conditions fail; return empty array

---

## Implementation Notes

*Derived from ADR-005 + ADR-003 + GDD mystery-unlock-tree.md:*

```gdscript
var _milestone_thresholds: Array[int] = []
var _fired_milestones: Array[bool] = []  # parallel to _milestone_thresholds
var _epilogue_required_ids: Array[String] = []
var _epilogue_conditions_emitted: bool = false
var _final_memory_earned: bool = false
var _partial_threshold: float = 0.80

func _load_config() -> void:
    var config = ResourceLoader.load("res://assets/data/mut-config.tres")
    # if null: use defaults (already assigned above)
    var epi_res = ResourceLoader.load("res://assets/data/epilogue-requirements.tres")
    if epi_res == null:
        push_error("MUT: epilogue-requirements.tres missing — suppressing epilogue signals")
        return
    _epilogue_required_ids = epi_res.recipe_ids  # typed field
    if _epilogue_required_ids.is_empty():
        push_error("MUT: epilogue-requirements.tres is empty — suppressing epilogue signals")

func _resolve_milestones() -> void:
    var R_authored: int = RecipeDatabase.get_recipe_count()
    if R_authored == 0:
        push_error("MUT: R_authored == 0 — skipping milestone resolution")
        return
    var raw: Array[int] = []
    for p in _milestone_pct:
        raw.append(maxi(1, ceili(p * R_authored)))
    # dedup: keep first occurrence of each unique value
    var seen: Dictionary = {}
    for i in raw.size():
        if raw[i] not in seen:
            seen[raw[i]] = true
            _milestone_thresholds.append(raw[i])
        else:
            push_warning("MUT: milestone_pct[%d] resolved to duplicate threshold %d — dropped" % [i, raw[i]])
    _fired_milestones.resize(_milestone_thresholds.size())
    _fired_milestones.fill(false)

func _evaluate_milestones() -> void:
    for i in _milestone_thresholds.size():
        if not _fired_milestones[i] and _discovery_order_counter == _milestone_thresholds[i]:
            _fired_milestones[i] = true
            EventBus.discovery_milestone_reached.emit("milestone_" + str(i), _discovery_order_counter)

func _evaluate_epilogue_conditions() -> void:
    if _epilogue_required_ids.is_empty() or _partial_threshold == 0.0 or _epilogue_conditions_emitted:
        return
    var R_found := _count_epilogue_found()
    var threshold := ceili(_epilogue_required_ids.size() * _partial_threshold)
    if R_found >= threshold:
        _epilogue_conditions_emitted = true
        EventBus.epilogue_conditions_met.emit()

func _on_epilogue_started() -> void:
    _state = _State.EPILOGUE
    if _epilogue_required_ids.is_empty():
        return
    var R_found := _count_epilogue_found()
    var threshold := ceili(_epilogue_required_ids.size() * _partial_threshold)
    if R_found >= threshold:
        _final_memory_earned = true
        EventBus.final_memory_ready.emit()

func get_carry_forward_cards(carry_forward_spec: Array) -> Array[String]:
    var result: Array[String] = []
    for entry in carry_forward_spec:
        var eligible := true
        for r_id in entry.get("requires_recipes", []):
            if r_id not in _discovered_recipes:
                eligible = false
                break
        if eligible:
            result.append(entry["card_id"])
    return result
```

- `_count_epilogue_found()`: `var count := 0; for r in _epilogue_required_ids: if r in _discovered_recipes: count += 1; return count`
- Intra-discovery ordering contract: milestones evaluated before epilogue conditions (Rule 8 before Rule 9 per GDD).

---

## Out of Scope

- [Story 001]: Core discovery recording and state machine
- [Story 003]: Save/load round-trip and force_unlock_all dev bypass

---

## QA Test Cases

- **AC-1**: Milestone fires at threshold
  - Given: MUT Active; `_milestone_thresholds = [5, 10]`; `_discovery_order_counter = 4`
  - When: 5th unique recipe discovered
  - Then: `discovery_milestone_reached("milestone_0", 5)` emitted; threshold not re-fired on 6th

- **AC-2**: Duplicate threshold dropped with warning
  - Given: `_milestone_pct = [0.01, 0.02]`; `R_authored = 10`
  - When: `_resolve_milestones()` runs
  - Then: `_milestone_thresholds = [1]`; warning logged for dropped entry

- **AC-3**: epilogue_conditions_met emitted at partial_threshold
  - Given: `_epilogue_required_ids = ["r1","r2","r3"]`; `partial_threshold = 0.67`; discoveries include "r1","r2"
  - When: "r2" is the 2nd discovery (2 >= ceil(3*0.67)=2)
  - Then: `epilogue_conditions_met()` emitted; `_epilogue_conditions_emitted == true`

- **AC-4**: epilogue_conditions_met suppressed when partial_threshold == 0.0
  - Given: `partial_threshold = 0.0`
  - When: any discovery fires
  - Then: `epilogue_conditions_met()` NOT emitted mid-session

- **AC-5**: final_memory_ready fires on epilogue_started
  - Given: all epilogue required recipes discovered; `partial_threshold = 0.80`
  - When: `epilogue_started()` fires
  - Then: `final_memory_ready()` emitted

- **AC-6**: carry-forward returns only fully-qualified cards
  - Given: `_discovered_recipes` contains "home-chester-photo" but not "home-coffee-rain"
  - When: `get_carry_forward_cards([{card_id:"old-photo", requires_recipes:["home-chester-photo"]}, {card_id:"umbrella", requires_recipes:["home-rain-walk","home-coffee-rain"]}])` called
  - Then: returns `["old-photo"]`; umbrella excluded

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/mystery_unlock_tree/milestones_epilogue_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: story-001-discovery-fsm must be DONE
- Unlocks: story-003-save-load-bypass
