# Story 008: Reject Template (repulsion ×N + emote, no consumption)

> **Epic**: Interaction Template Framework
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/interaction-template-framework.md`
**Scene spec**: `design/scenes/drive.md` — `nav-reject` interaction (Section 4)

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton
**ADR Decision Summary**: The `reject` template is a pure-repulsion outcome: ITF calls
`CardEngine.on_combination_failed()` (triggering the existing push-away), but first reads
`config.repulsion_multiplier` to scale `PUSH_DISTANCE` for that one call, and optionally
fires an emote via `EventBus.emote_requested`. Both source cards are kept (neither is
consumed). No `combination_executed` is emitted — this is a deliberate non-recipe
interaction that leaves game state unchanged.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `CardEngine._begin_push_away` uses the module-level constant
`PUSH_DISTANCE = 60.0`. To honour `repulsion_multiplier`, ITF must call a new
overload `CardEngine.on_combination_rejected(id_a, id_b, push_multiplier: float)`
rather than the existing `on_combination_failed`, so `PUSH_DISTANCE` is scaled only
for this call and does not affect normal fail behaviour. Add the new public method to
`card_engine.gd`; keep `on_combination_failed` unchanged.

**Control Manifest Rules (Feature Layer)**:
- Required: Use EventBus for all cross-system events
- Forbidden: Hardcode push distance — read multiplier from recipe `config`

---

## Acceptance Criteria

- [ ] New `"reject"` template arm added to `_execute_template` match block in
  `interaction_template_framework.gd`
- [ ] `_execute_reject` reads `config.get("repulsion_multiplier", 1.0)` and
  `config.get("emote", "")` from the recipe config dict
- [ ] Calls `CardEngine.on_combination_rejected(instance_id_a, instance_id_b, multiplier)`
  — both cards pushed away, scaled by multiplier; neither card is consumed
- [ ] If `emote` is non-empty and not `"none"`: emits
  `EventBus.emote_requested(emote_name, midpoint)` where `midpoint` is the average
  of the two card positions (same pattern as `_on_merge_complete`)
- [ ] Does **not** emit `combination_executed` — reject is not a scored interaction
- [ ] Cooldown still applies — same `_is_on_cooldown` / `_fire_cooldown` logic as
  other templates (prevents rapid-fire repulsion spam)
- [ ] `CardEngine` gains public method
  `on_combination_rejected(id_a, id_b, push_multiplier: float)` that calls
  `_begin_push_away` for **both** cards (id_a away from id_b, id_b away from id_a)
  with `PUSH_DISTANCE * push_multiplier`

---

## Implementation Notes

### `interaction_template_framework.gd`

Add to `_execute_template` match:
```gdscript
"reject":
    _execute_reject(recipe, instance_id_a, instance_id_b, config)
```

New function:
```gdscript
func _execute_reject(recipe: Dictionary, instance_id_a: String, instance_id_b: String,
        config: Dictionary) -> void:
    var multiplier: float = float(config.get("repulsion_multiplier", 1.0))
    var node_a := CardSpawning.get_card_node(instance_id_a)
    var node_b := CardSpawning.get_card_node(instance_id_b)
    var midpoint := Vector2(300, 300)
    if node_a != null and node_b != null:
        midpoint = (node_a.position + node_b.position) * 0.5

    CardEngine.on_combination_rejected(instance_id_a, instance_id_b, multiplier)

    var emote_name: String = String(config.get("emote", ""))
    if emote_name != "" and emote_name != "none":
        EventBus.emote_requested.emit(emote_name, midpoint)

    # Cooldown so repeated drops don't spam the effect
    _last_fired[recipe["id"]] = Time.get_ticks_msec() / 1000.0
```

### `card_engine.gd`

New public method (after `on_combination_failed`):
```gdscript
## Called by ITF for the Reject template.
## Pushes both cards away from each other, scaled by push_multiplier.
func on_combination_rejected(instance_id_a: String, instance_id_b: String,
        push_multiplier: float = 1.0) -> void:
    _combination_in_flight = false
    _begin_push_away(instance_id_a, instance_id_b, push_multiplier)
    _begin_push_away(instance_id_b, instance_id_a, push_multiplier)
```

Extend `_begin_push_away` signature to accept an optional multiplier:
```gdscript
func _begin_push_away(instance_id: String, target_id: String,
        push_multiplier: float = 1.0) -> void:
    ...
    var push_target := (node.position + push_dir * PUSH_DISTANCE * push_multiplier).clamp(...)
```

### Recipe data (`nav-reject` in `recipes.tres`)

```
id:                  "nav-reject"
card_a:              "nav_info"
card_b:              "ju_driving"
template:            "reject"
config.repulsion_multiplier: 2.0
config.emote:        "anger"
```

---

## Out of Scope

- Emote system implementation — already live (`emote_bubble.gd`, `emote_handler.gd`)
- Other templates — stories 001-007
- `combination_executed` downstream effects — reject intentionally skips these

---

## QA Test Cases

**AC-1**: Reject fires repulsion on both cards
- Given: recipe `nav-reject` (template `"reject"`, `repulsion_multiplier: 2.0`)
- When: `combination_attempted("nav_info_0", "ju_driving_0")` fires
- Then: `CardEngine.on_combination_rejected("nav_info_0", "ju_driving_0", 2.0)` called;
  both cards pushed away ~120px (2× normal 60px); neither card removed from table

**AC-2**: Emote triggers at midpoint
- Given: `nav-reject` config has `emote: "anger"`
- When: reject executes
- Then: `EventBus.emote_requested` emitted with `("anger", midpoint)`

**AC-3**: combination_executed is NOT emitted
- Given: reject executes successfully
- Then: `combination_executed` signal is never emitted for this interaction

**AC-4**: Cooldown prevents spam
- Given: `nav-reject` just fired
- When: same pair dropped again within `COMBINATION_COOLDOWN_SEC`
- Then: `on_combination_failed` called (normal bounce), no emote, no double repulsion

**AC-5**: Reject with multiplier 1.0 behaves like normal fail push
- Given: a `reject` recipe with no `repulsion_multiplier` key
- Then: push distance equals `PUSH_DISTANCE * 1.0` — identical to normal fail

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/interaction_template_framework/reject_template_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload skeleton) must be DONE; Story 004 (merge template, emote pattern) must be DONE
- Unlocks: `drive` scene implementation (`/create-scene drive`)

---

## Completion Notes
**Completed**: 2026-04-24
**Criteria**: 7/7 passing
**Deviations**: AC-1 (both cards pushed, neither consumed) covered by code inspection at unit level; integration test stubbed at `tests/integration/interaction_template_framework/reject_template_integration_test.gd` — activate when scene scaffolding is ready.
**Test Evidence**: Logic — `tests/unit/interaction_template_framework/reject_template_test.gd` — 9/9 PASSED
**Code Review**: Complete (3 passes — suggestions applied: zero-distance push guard, to_lower() consistency, emote null-node guard, intentional-skip comment)
