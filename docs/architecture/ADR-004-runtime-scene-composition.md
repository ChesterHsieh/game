# ADR-004: Runtime Scene Composition, Autoload Order, and Epilogue Handoff

## Status

Accepted

## Date

2026-04-21

## Last Verified

2026-04-21

## Decision Makers

Chester + Claude Code agents (creative-director, technical-director roles via `/review-all-gdds` cleanup pass)

## Summary

Three tightly-coupled runtime-architecture questions — the composition of `res://src/scenes/gameplay.tscn`, the canonical autoload order for 12 singletons, and the sequence of events during the epilogue handoff — are resolved together in this ADR because any of them decided alone produces contradictions. The chosen approach: a flat gameplay scene containing STUI + Final Epilogue Screen as sibling CanvasLayers, a single authoritative autoload order from `EventBus` to `SaveSystem`, and an epilogue handoff that stays inside the gameplay scene (no `change_scene_to_file` to FES — SM flips state; STUI emits `epilogue_cover_ready`; FES reveals above STUI without either system being freed).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.3 |
| **Domain** | Core (scene lifecycle + autoload initialization + CanvasLayer z-order) |
| **Knowledge Risk** | LOW — all APIs used (autoload, `CanvasLayer`, `SceneTree`, signal connection) are pre-training-cutoff and stable in 4.3 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; all 20 GDDs in `design/gdd/`; `ADR-003-signal-bus.md` (EventBus) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Runtime smoke test: Godot editor → play-on-start with all autoloads registered in the order below → Main Menu renders → Start → chapter 1 → complete → chapter 2. No console errors. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-003 (EventBus signal declarations) — must have the full signal list from the 2026-04-21 expansion. |
| **Enables** | All implementation stories across Main Menu, Scene Manager, Save/Progress, Settings, STUI, FES. |
| **Blocks** | `/create-epics` cannot begin until this ADR is Accepted — three BLOCKER-class review findings depend on it. |
| **Ordering Note** | Resolves Main Menu GDD OQ-1, Scene Manager GDD OQ-2 (watchdog), and the epilogue-handoff contradiction flagged by `/review-all-gdds` 2026-04-21 (BLOCKER-2, BLOCKER-4). |

## Context

### Problem Statement

The `/review-all-gdds` cross-review (2026-04-21) surfaced three BLOCKER-class issues that cannot be resolved in isolation:

1. **BLOCKER-2 (epilogue handoff contradiction)**: Scene Manager says "SM's role ends" on `epilogue_started`; FES says SM calls `change_scene_to_file("final_epilogue.tscn")`; STUI says it emits `epilogue_cover_ready` from inside gameplay.tscn. If SM changes scene, STUI is freed before it can emit — FES then waits for a signal from a freed node.
2. **BLOCKER-4 (autoload order contradiction)**: Scene Manager, Save/Progress, and Settings each specify a different ordering; none includes `CardDatabase` or `RecipeDatabase`; no single `project.godot` can satisfy all three.
3. **Main Menu OQ-1** (gameplay.tscn composition): composition of the target scene has been deferred to an ADR since Main Menu was designed. This ADR is that ADR.

Without a single authoritative decision on all three, implementation stories cannot be written — every downstream story would make conflicting assumptions.

### Current State

- `res://src/ui/main_menu/main_menu.tscn` exists conceptually (not yet built). Switches to `res://src/scenes/gameplay.tscn` on Start.
- `res://src/scenes/gameplay.tscn` is named by Main Menu and Save/Progress GDDs but has no defined composition.
- Autoload list in `project.godot` is not yet canonical; GDDs specify three conflicting orderings.
- Epilogue handoff is described three different ways across SM, FES, and STUI GDDs.

### Constraints

- **Engine**: Godot 4.3 autoloads initialize in `project.godot` order; all `_ready()` calls complete before any main-scene node's `_ready()` runs. CanvasLayer z-ordering is by `layer` property (higher = in front); children of higher-layer CanvasLayers render above lower-layer siblings regardless of tree order.
- **Signal dispatch**: Godot connects and dispatches signals synchronously in connection order within a single emission; listener order between two autoloads depends on whose `_ready()` runs first.
- **Pillar 4 (Personal Over Polished)**: the chosen architecture must minimize complexity. Extra scene swaps and lifecycle hops are complexity for its own sake.
- **Pillar 3 (Discovery Without Explanation)**: no technical error screens should ever be visible to Ju. All failure modes must degrade silently with internal logs.
- **N=1 target audience**: no hot-reload, no modding, no telemetry needed.

### Requirements

- A single `project.godot` autoload order that satisfies every GDD's declared dependency graph.
- A `gameplay.tscn` composition that supports the card table, scene transition, HUD (gear icon), and epilogue reveal without additional scene swaps.
- An epilogue handoff sequence where every emitter is alive at the moment it emits, and every listener is connected when the signal fires.
- A deterministic ordering for the `scene_completed` listener pair (SaveSystem vs SceneManager) so that the saved `resume_index` is always the post-increment value (addresses BLOCKER-6 at the architectural level; the save-system edit for BLOCKER-6 in a later cleanup step depends on this contract).

## Decision

### 1. Canonical autoload order

```
EventBus           # signal bus; depends on nothing; every autoload below uses it
CardDatabase       # static data; depends on nothing
RecipeDatabase     # static data; depends on CardDatabase
InputSystem        # wrapper over Godot Input; depends on EventBus
AudioManager       # listens to EventBus; depends on EventBus
SettingsManager    # reads settings file, applies volumes; depends on AudioManager + EventBus
SceneGoalSystem    # reads RecipeDatabase; emits via EventBus
CardSpawningSystem # listens to EventBus; uses CardDatabase
TableLayoutSystem  # helper, called by CSS; uses CardDatabase
MysteryUnlockTree  # depends on RecipeDatabase; listens via EventBus
SceneManager       # orchestrates SGS/CSS/TLS; emits via EventBus; owns the scene state machine
SaveSystem         # depends on SceneManager + MUT (calls setter APIs); listens via EventBus
```

This replaces the per-GDD orderings in scene-manager.md / save-progress-system.md / settings.md. Those GDDs will be updated in the stale-reference sweep to point at this ADR instead of restating the order.

**Why SaveSystem after SceneManager (contradicts Settings Rule 9 as written)**: SaveSystem calls `SceneManager.set_resume_index(N)` during `apply_loaded_state()`. That method must exist before the call. SM is the more fundamental dependency (owns the scene state machine); SaveSystem is a pure persistence wrapper around SM + MUT state. Settings Rule 9 will be corrected.

**All autoloads declare `process_mode = PROCESS_MODE_ALWAYS`** so pause states cannot strand signals.

### 2. `gameplay.tscn` composition

```
gameplay.tscn (Node — gameplay_root.gd is the orchestrator script)
├── CardTable (Node2D, layer defined by default canvas — z_index: 0)
│   ├── (Card instances spawned here by CardSpawningSystem)
│   └── (no pre-authored children; pure runtime population)
├── HudLayer (CanvasLayer, layer = 5)
│   ├── StatusBarUI        (res://src/ui/status_bar/status_bar_ui.tscn)
│   └── SettingsTrigger    (gear button — instantiated from res://src/ui/settings/settings_trigger.tscn)
├── TransitionLayer (CanvasLayer, layer = 10)
│   └── SceneTransitionUI  (res://src/ui/scene_transition/scene_transition_ui.tscn)
├── SettingsPanelHost (CanvasLayer, layer = 15 — initially empty)
│   └── (SettingsPanel instantiated here on gear press, queue_free on close)
└── EpilogueLayer (CanvasLayer, layer = 20)
    └── FinalEpilogueScreen (res://src/ui/final_epilogue/final_epilogue_screen.tscn)
         # Added as a child at scene build time, but with its internal state = Armed
         # (no rendering until SM enters Epilogue state + cover signal arrives).
```

**CanvasLayer assignment resolves the Settings↔STUI z-order collision** from `/review-all-gdds` scenario 4: Settings panel host is layer 15, above STUI's layer 10 — panel always renders above any transition overlay.

**FES is pre-instanced at layer 20, above every other CanvasLayer, including Settings.** FES starts in its `Armed` state (rendering nothing, transparent); it awaits `epilogue_cover_ready` from STUI before beginning its fade-in. Because FES is a sibling CanvasLayer of STUI inside the same scene, STUI is alive to emit the signal when FES needs it.

### 3. `gameplay_root.gd` responsibilities

The root script of `gameplay.tscn` is the boot orchestrator. Its `_ready()` runs once per game session:

```gdscript
# res://src/scenes/gameplay_root.gd
extends Node

func _ready() -> void:
    # All children (HudLayer, TransitionLayer, SettingsPanelHost, EpilogueLayer,
    # CardTable) have already received _ready() before this script's _ready()
    # runs — Godot guarantees depth-first bottom-up _ready() ordering.

    var load_result: int = SaveSystem.load_from_disk()
    if load_result == SaveSystem.LoadResult.OK:
        SaveSystem.apply_loaded_state()
    # NO_SAVE_FOUND and CORRUPT_RECOVERED: SM stays at index 0, MUT stays empty.

    EventBus.game_start_requested.emit()
```

Main Menu remains save-agnostic (preserves Main Menu Rule 6 "No Game-State Coupling"). Main Menu only does `change_scene_to_file("gameplay.tscn")`; the save orchestration lives in `gameplay_root.gd`.

### 4. Epilogue handoff sequence (replaces three contradictory GDD descriptions)

The final chapter completes. From `scene_completed` fire, the sequence is:

```
1. SceneGoalSystem emits `scene_completed(final_scene_id)` on EventBus.

2. Listeners fire in a specified order (see §5 below for ordering contract):
   a. SceneManager handler runs its completion sequence:
      - enter Transitioning
      - CardSpawningSystem.clear_all_cards()
      - await one frame
      - SceneGoalSystem.reset()
      - _current_index += 1
      - detect _current_index >= manifest.size() → enter Epilogue state
      - emit EventBus.epilogue_started()
   b. SaveSystem handler runs AFTER SM handler (post-increment). It reads
      SM.get_resume_index() which now returns manifest.size() (= epilogue
      marker) and writes the save file atomically.
   c. MysteryUnlockTree handler runs after both: transitions Active → Epilogue.
      If epilogue-required recipes are complete, MUT emits final_memory_ready().

3. STUI listens to epilogue_started() (already specified in STUI Rule 9). It
   begins the amber cover rise (replaces the normal page-turn for the epilogue
   transition). At full opacity, STUI emits EventBus.epilogue_cover_ready().

4. FinalEpilogueScreen (pre-instanced, Armed) listens to epilogue_cover_ready().
   On receipt:
   - transitions Armed → Loading (preloads the illustrated memory texture)
   - when load completes → Ready state → begins its own fade-in
   - renders above STUI's amber at layer 20

5. Scene Manager does NOT call change_scene_to_file at any point during the
   epilogue. The gameplay scene remains loaded — STUI and FES are both alive
   until the application quits. This is the key architectural simplification
   over the previous FES-proposed scene-swap model.
```

**No `final_memory_ready → change_scene_to_file` path exists.** FES Rule 2's description of SM calling `change_scene_to_file` is superseded by this ADR. `final_memory_ready` remains as an MUT → diagnostic signal only (optional consumer for save-at-epilogue logic; see §6).

### 5. Signal-listener ordering contract for `scene_completed`

Both SM and SaveSystem listen to `scene_completed`. Godot dispatches in connection order. Because autoload order puts SM before SaveSystem, and both connect in their own `_ready()`, SM's handler runs first.

**Rule**: listeners that must observe post-increment state (SaveSystem) connect *after* SM. Listeners that must observe pre-increment state (none currently; reserved for future analytics) would need to connect before SM via an explicit protocol.

The autoload order in §1 is load-bearing for this contract — do not reorder SaveSystem before SceneManager without revisiting this ADR.

### 6. Save-on-epilogue requirement

Because SM never emits a fresh `scene_completed` from the Epilogue state (it is terminal), SaveSystem would normally not persist MUT's post-epilogue `_final_memory_earned` flag. To fix this, `gameplay_root.gd` — or alternatively MUT — triggers a synchronous save on `final_memory_ready`:

```gdscript
# In gameplay_root.gd _ready() (after EventBus.game_start_requested.emit()):
EventBus.final_memory_ready.connect(_on_final_memory_ready)

func _on_final_memory_ready() -> void:
    SaveSystem.save_now()  # new synchronous method; see BLOCKER-6 fix
```

This makes re-launch-after-epilogue deterministic: save captures `_epilogue_conditions_emitted = true` AND MUT's `_final_memory_earned` state, so SM resumes directly to Epilogue state on next session.

### 7. Missing signal declarations — already addressed

The three signals FES requires (`final_memory_ready`, `epilogue_conditions_met`, `epilogue_cover_ready`) are declared in ADR-003's 2026-04-21 expansion. This ADR does not re-declare them — it only specifies their emission sequence.

## Key Interfaces

```gdscript
# SceneManager (new method beyond the existing get/set_resume_index)
func reset_to_waiting() -> void:
    # Resets SM to initial Waiting state. Clears _current_index to 0,
    # re-arms the CONNECT_ONE_SHOT on game_start_requested. Asserts that
    # Card Spawning System has already cleared cards.
    # Called by SaveSystem.clear_save() as part of Reset Progress flow.
    # Designed in the BLOCKER-3 fix; interface declared here for ADR completeness.

# SaveSystem (existing methods stay; one new)
func save_now() -> void:
    # Synchronous save. Used by gameplay_root on final_memory_ready when no
    # scene_completed will fire. Reads authoritative state the same way as
    # the scene_completed handler.

# gameplay_root.gd (new script)
extends Node
# Responsibilities: save-load orchestration + epilogue save hook.
# Owns NO gameplay state — only the boot sequence.
```

## Alternatives Considered

### Alternative 1: Scene-swap epilogue (FES GDD's original proposal)

- **Description**: SM calls `change_scene_to_file("final_epilogue.tscn")` on `final_memory_ready`. gameplay.tscn is freed; FES lives in its own scene.
- **Pros**: Clean separation of "gameplay" from "epilogue" in the project tree; FES scene can have its own bespoke structure without concern for layer math.
- **Cons**: STUI is freed before FES can receive `epilogue_cover_ready`. FES's 5-second fallback timer papers over the dangling dependency but the reveal chain is broken. Also requires SM to do double duty (scene swap + state machine transition) during the most emotionally important moment of the game.
- **Estimated Effort**: Same as chosen approach.
- **Rejection Reason**: Broken signal dependency at the exact moment the game cannot afford a bug.

### Alternative 2: FES as its own autoload

- **Description**: Make FES a singleton. It survives scene changes.
- **Pros**: Available from any scene.
- **Cons**: FES is a scene — texture-heavy, with its own layout. Autoloads should be logic singletons, not UI scenes. Violates the division between "autoload = long-lived service" and "scene = bounded UI". Also pre-instances FES at game launch for every session, even sessions that never reach epilogue — wasteful texture memory.
- **Estimated Effort**: Moderate — re-architect FES as an autoload.
- **Rejection Reason**: Architectural wrong-shape; wasteful on every non-epilogue session.

### Alternative 3: Deferred FES scene load

- **Description**: Keep scene-swap approach but delay the swap until *after* STUI has emitted `epilogue_cover_ready`.
- **Pros**: Preserves "FES is its own scene" intuition.
- **Cons**: Requires a bespoke hand-off state machine between STUI and FES that spans a `change_scene_to_file` boundary. Signal ordering across scene swaps is the exact failure mode that produced BLOCKER-2.
- **Estimated Effort**: Higher than chosen approach.
- **Rejection Reason**: Solves the symptom (dangling signal) without solving the structural problem (unnecessary scene swap).

## Consequences

### Positive

- All three BLOCKER findings (B-2 epilogue handoff, B-4 autoload order, Main Menu OQ-1) resolve together.
- gameplay.tscn is a single scene for the entire gameplay session. Debugging is simpler because the full tree is always visible in the remote scene inspector.
- Signal-listener ordering (B-6's architectural root cause) has a specified contract via autoload order.
- FES's 5-second fallback timer becomes redundant (safe to keep, but the normal path no longer needs it).
- `SettingsTrigger` and `SettingsPanelHost` are first-class children of gameplay.tscn, not runtime afterthoughts — ADR-level visibility.

### Negative

- `gameplay_root.gd` is a new script that owns cross-system orchestration. It must be carefully tested because a bug there cascades to every session.
- FES is pre-instanced at every session, even ones that don't reach epilogue. Measured texture cost: the final illustrated memory PNG is ~500KB–2MB depending on resolution; RAM impact is small but non-zero. Loading it into a `TextureRect` only happens on `epilogue_cover_ready`, so startup load time is unaffected.
- Settings Rule 9 and Save/Progress Rule 1 must both be updated to point at this ADR; Scene Manager's edge-case autoload-order note similarly.

### Neutral

- STUI's EPILOGUE state now represents "holding amber while FES reveals above," not a terminal state of its own. STUI text may need refinement but no behavioral change.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| `gameplay_root.gd`'s `_ready()` races autoload readiness | Low | High | Godot guarantees autoload `_ready()` completes before main-scene `_ready()`. Enforced by Godot engine invariant. |
| FES pre-instancing leaks memory if scene is reloaded | Low | Low | `gameplay.tscn` is freed only on application quit (normal gameplay) or Reset Progress (explicit tear-down). Both paths free FES cleanly. |
| Future engineer reorders autoloads, breaks `scene_completed` ordering | Medium | High | This ADR + ADR-003 are both cited in the session's `CLAUDE.md`. Autoload order change should require a new ADR. |
| STUI amber-cover is visible behind the Settings panel if Ju opens Settings during the epilogue transition | Low | Low | Settings panel host at layer 15, STUI at layer 10 — Settings draws above STUI (correct for Settings' always-on-top contract). Epilogue FES at layer 20 is above Settings — but Settings cannot open while SM is in Epilogue state because `SettingsTrigger` is hidden by the HudLayer's own visibility toggle on `epilogue_started` (added to Settings GDD in stale-sweep step). |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | N/A (no impl) | ~0.2ms extra for the idle FES CanvasLayer | 16.7ms |
| Memory | N/A | +2MB for pre-loaded FES scene | 256MB |
| Load Time | N/A | gameplay.tscn load ~50ms additional for STUI + FES nodes | N/A (one-time per session) |

## Migration Plan

1. Update `project.godot` — add all 12 autoloads in the §1 order. **Verification**: launch the editor in the project folder; check "Project Settings → AutoLoad" tab matches the order. No runtime testing yet — autoloads don't exist as scripts in full form.
2. Create stub `res://src/scenes/gameplay.tscn` with the §2 node tree. Each child is an empty placeholder `Node` until the real scene exists. **Verification**: open gameplay.tscn in editor, confirm tree matches.
3. Create stub `res://src/scenes/gameplay_root.gd` with the §3 `_ready()` body. **Verification**: print statements confirm order: children ready → SaveSystem.load_from_disk() called → game_start_requested emitted.
4. Update Scene Manager GDD to delete its "Autoload order" edge-case paragraph and add "See ADR-004 for canonical autoload order."
5. Update Save/Progress GDD Rule 1 similarly.
6. Update Settings GDD Rule 9 similarly.
7. Update Main Menu GDD OQ-1 — close as RESOLVED with pointer to this ADR.
8. Update FES GDD Rule 2 — replace "SM calls change_scene_to_file" with "SM does not swap scenes; FES renders as a sibling CanvasLayer in gameplay.tscn per ADR-004 §2."
9. Update STUI GDD — add note that its EPILOGUE state is "holding amber while FES reveals above, not terminal to the scene."

**Rollback plan**: if pre-instancing FES turns out to have a behavior problem not caught in review (e.g., FES consuming input events before STUI can), convert FES to lazy-instanced via `preload()` + `add_child()` inside `gameplay_root._on_epilogue_started`. This is a single-function change; no ADR revision needed. The decision to pre-instance is a convenience — not a correctness constraint.

## Validation Criteria

- [ ] `project.godot` lists 12 autoloads in §1 order, all with `process_mode = 3` (ALWAYS).
- [ ] `gameplay.tscn` node tree matches §2 exactly (layers 5/10/15/20, FES in Armed state at startup).
- [ ] `gameplay_root.gd` `_ready()` runs the save-load-orchestration sequence with zero runtime errors when no save file exists.
- [ ] First-time launch scenario: Main Menu → Start → chapter 1 seeds appear. No console errors.
- [ ] Resume launch scenario: with a valid save at resume_index=2, chapter 2 loads directly. No flash of chapter 0.
- [ ] Epilogue scenario: last chapter complete → STUI amber rises → FES reveals above amber → Audio fades → game waits for Esc. No console errors. No blank-screen gap. No visible z-order glitches between STUI and FES.
- [ ] Settings-during-transition: open Settings while STUI is mid-fade → panel renders above STUI amber → close → STUI completes normally.
- [ ] Reset-progress-during-gameplay: Reset commits → `SM.reset_to_waiting()` is called → SM is back in Waiting → scene switch to Main Menu → next Start loads chapter 0 cleanly.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/main-menu.md` | Main Menu | OQ-1: composition of `gameplay.tscn` and save-load orchestration sequence | §2 defines the composition; §3 defines the orchestration in `gameplay_root.gd` |
| `design/gdd/scene-manager.md` | Scene Manager | Edge Cases: autoload order; Open Question on epilogue handoff | §1 provides canonical order; §4 defines the handoff |
| `design/gdd/save-progress-system.md` | Save/Progress | Rule 1 autoload order; Rule 4 load orchestration | §1 + §3 supersede the per-GDD ordering language |
| `design/gdd/settings.md` | Settings | Rule 9 autoload order; panel host scene location | §1 supersedes; §2 defines SettingsPanelHost at layer 15 |
| `design/gdd/final-epilogue-screen.md` | Final Epilogue Screen | Rule 2: SM listener and scene swap; Rule 6: cover-ready gate | §4 replaces Rule 2's scene-swap model; §2 ensures STUI is alive to emit the cover signal |
| `design/gdd/scene-transition-ui.md` | Scene Transition UI | Rule 9: EPILOGUE state emitter of `epilogue_cover_ready` | §4 confirms STUI emits inside gameplay.tscn, pre-FES-reveal |
| `design/gdd/mystery-unlock-tree.md` | Mystery Unlock Tree | Rule §132: `final_memory_ready` emission timing | §4 step 2c sequences MUT's state transition after SM's |

## Related

- **ADR-003** (signal bus) — prerequisite; must declare all signals used in §4.
- **Future ADR (TBD)**: if gameplay.tscn composition needs to change for new systems (e.g., a photo album viewer for Alpha+), that ADR supersedes §2 of this one.

---

**Follow-up GDD updates required** (tracked in the `/review-all-gdds` cleanup pass):

- Scene Manager: add `reset_to_waiting()` method (BLOCKER-3 fix); delete autoload-order edge case; close OQ.
- Save/Progress: rewrite Rule 1 to cite ADR-004; add `save_now()` method (BLOCKER-6 fix); update Rule 4 pseudocode to call `save_now` on `final_memory_ready`.
- Settings: rewrite Rule 9 to cite ADR-004; bump panel CanvasLayer to layer 15 per §2; amend Reset Progress flow to call `SM.reset_to_waiting()` via `SaveSystem.clear_save()`.
- Main Menu: close OQ-1 as RESOLVED, cite ADR-004.
- FES: rewrite Rule 2 per §4; remove Rule 13's `_enter_tree` guard (no longer needed — FES is pre-instanced, not subscribed).
- STUI: add note that EPILOGUE state coexists with FES reveal at layer 20; no behavioral change.
- MUT: close OQ-11 (FES consumer is the pre-instanced FinalEpilogueScreen in gameplay.tscn); update Rule 7 block to drop "FES not yet authored" stale text.
