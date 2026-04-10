# Sprint 03 — Feature Layer

**Start**: 2026-03-27
**Goal**: Combinations resolve, bars move, the win condition fires, and the hint
         system watches for stagnation. The first complete game loop is playable.

---

## Systems in Scope

| System | GDD | Effort |
|--------|-----|--------|
| Interaction Template Framework | design/gdd/interaction-template-framework.md | L |
| Status Bar System | design/gdd/status-bar-system.md | M |
| Scene Goal System | design/gdd/scene-goal-system.md | M |
| Hint System | design/gdd/hint-system.md | S |

**MVP scope**: Additive + Merge templates only. Animate + Generator deferred.
`sustain_above` goal type only. `find_key` / `sequence` / `reach_value` deferred.

**Dependency order**: ITF → Status Bar → Scene Goal → Hint System

---

## Data Files

- [ ] `assets/data/bar-effects.json` — recipe_id → bar deltas
- [ ] `assets/data/scenes/home.json` — home scene config (seed cards, goal)

---

## Tasks

### ITF (`src/gameplay/interaction_template_framework.gd`)
- [ ] Autoload singleton
- [ ] Connect to `CardEngine.combination_attempted` on `_ready()`
- [ ] Connect to `CardEngine.merge_complete` on `_ready()`
- [ ] Strip instance suffix to derive card_id: `"chester_0" → "chester"`
- [ ] Lookup recipe via `RecipeDatabase.get_recipe(card_id_a, card_id_b, scene_id)`
- [ ] Cooldown tracking per recipe_id (`combination_cooldown_sec = 30s`)
- [ ] Execute Additive: call `CardEngine.on_combination_succeeded`, spawn result cards
- [ ] Execute Merge: call `CardEngine.on_combination_succeeded`, wait for `merge_complete`, remove source cards, spawn result
- [ ] On no recipe / cooldown: call `CardEngine.on_combination_failed`
- [ ] Emit `combination_executed(recipe_id, template, instance_id_a, instance_id_b)` on success
- [ ] `set_scene_id(scene_id)` — ITF needs current scene to pass to RecipeDatabase lookup
- [ ] Register `ITF` as Autoload

### Status Bar System (`src/gameplay/status_bar_system.gd`)
- [ ] Autoload singleton; starts Dormant
- [ ] `configure(scene_bar_config)` — sets bars, decay, win condition; enters Active
- [ ] Load `assets/data/bar-effects.json` on `_ready()`
- [ ] Listen to `ITF.combination_executed` → apply bar deltas from data file
- [ ] Decay all bars per frame while Active
- [ ] `sustain_above` win check per frame: track time both bars ≥ threshold
- [ ] Emit `bar_values_changed(values: Dictionary)` on every value change
- [ ] Emit `win_condition_met()` when sustain condition satisfied
- [ ] Reset to Dormant on `reset()`
- [ ] Register `StatusBarSystem` as Autoload

### Scene Goal System (`src/gameplay/scene_goal_system.gd`)
- [ ] Autoload singleton; starts Idle
- [ ] `load_scene(scene_id)` — reads `assets/data/scenes/{scene_id}.json`
- [ ] Calls `StatusBarSystem.configure()` for bar-type goals
- [ ] Emits `seed_cards_ready(seed_cards: Array)` after parse
- [ ] Listens to `StatusBarSystem.win_condition_met()` → emits `scene_completed(scene_id)`
- [ ] `get_goal_config() -> Dictionary` — returns current goal data
- [ ] `reset()` — returns to Idle
- [ ] Register `SceneGoal` as Autoload

### Hint System (`src/gameplay/hint_system.gd`)
- [ ] Autoload singleton; starts Dormant
- [ ] On `SceneGoal.seed_cards_ready`: check goal type; if bar goal → enter Watching
- [ ] Stagnation timer increments per frame in Watching/Hint1 states
- [ ] On `ITF.combination_executed`: reset timer, emit `hint_level_changed(0)` if active
- [ ] Level 1 at `stagnation_sec` (300s production, exposed as constant)
- [ ] Level 2 at `stagnation_sec * 2`
- [ ] On `StatusBarSystem.win_condition_met()`: enter Dormant, emit `hint_level_changed(0)`
- [ ] Emit `hint_level_changed(level: int)` — 0=hidden, 1=faint, 2=full
- [ ] Register `HintSystem` as Autoload

---

## Definition of Done

- [ ] Chester+Ju combined → both cards merge, morning-together spawns
- [ ] Chester+Home combined → coffee spawns nearby, both cards stay
- [ ] Unknown pair → push-away fires
- [ ] Bar values rise on combination, decay over time
- [ ] Both bars above 60 for 30s → `win_condition_met` fires
- [ ] `hint_level_changed(1)` fires after 300s of no combinations
- [ ] All autoloads load without errors
