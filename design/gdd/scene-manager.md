# Scene Manager

> **Status**: Designed
> **Author**: Chester + Claude Code agents
> **Last Updated**: 2026-04-21 (OQ-1 resolved; `get_resume_index()` / `set_resume_index()` API added for Save/Progress integration)
> **Implements Pillar**: Pillar 3 (Discovery Without Explanation)

## Overview

Scene Manager is the system that moves Ju through the chapters of her relationship story. Mechanically, it is a Feature-layer autoload singleton that owns the scene lifecycle: loading scene data, coordinating seed card placement, activating the Scene Goal System, and advancing to the next scene when a goal is met. Emotionally, it is the page-turn — the moment between one chapter and the next.

Scenes are ordered linearly. Scene 1 leads to Scene 2, Scene 2 to Scene 3, and so on through all 5–8 chapters. There is no branching, no scene selection screen, no player choice about which chapter comes next — the story is told in the order Chester wrote it.

On scene load, Scene Manager calls Scene Goal System's `load_scene(scene_id)` to configure the goal and bars, listens for `seed_cards_ready` to place seed cards via the Card Spawning System and Table Layout System, and then steps back. During gameplay, it is idle — the player interacts with cards, not scenes. When Scene Goal System emits `scene_completed(scene_id)`, Scene Manager clears the table and loads the next scene immediately. All inter-system communication flows through EventBus (ADR-003).

## Player Fantasy

Each scene transition is the sensation of looking back at a different version of yourself. The table clears, new cards appear, and the small shift in what's available — new words, new objects — communicates that time has moved without saying so. Ju feels the relationship growing through the vocabulary of cards, not through any announcement.

Scene Manager is successful when the transition between chapters feels like remembering — not like loading a level. The new seed cards orient her: "this is that part of us." No fanfare, no transition screen, no narration. The cards themselves signal the era. The shift is felt through content, not production.

## Detailed Design

### Core Rules

**1. Scene Manifest**
- Scene Manager holds a fixed, ordered array of `scene_id` strings loaded from `assets/data/scene-manifest.json`. This is the canonical playthrough order.
- Scene Manager tracks `_current_index: int` as its primary state. Index starts at 0.
- The manifest is authored data — no scene order is hardcoded.

**2. First Scene — Game Start**
- On `_ready()`, Scene Manager enters the `Waiting` state. It does **not** auto-load the first chapter.
- Scene Manager subscribes once to `EventBus.game_start_requested()` using `CONNECT_ONE_SHOT`. The handler calls `_load_scene_at_index(0)` to begin the first chapter and discards any subsequent emissions.
- Rationale: Main Menu (system #17) owns the "first doorway" — the player must open the moment by pressing Start. Auto-loading on `_ready()` would bypass the menu entirely. `CONNECT_ONE_SHOT` guards the one-emission-per-session invariant; duplicate signals (replay/reload edge cases) are safely discarded rather than triggering a double-load.

**3. Scene Load Sequence** (strictly ordered steps)
1. Emit `EventBus.scene_loading(scene_id)`.
2. Call `SceneGoalSystem.load_scene(scene_id)`.
3. Listen for `EventBus.seed_cards_ready(seed_cards[])` (emitted by Scene Goal System).
4. On `seed_cards_ready`: call `TableLayoutSystem.get_seed_card_positions(seed_cards[])` to get positions.
5. Call `CardSpawningSystem.spawn_card(card_id, position)` for each seed card.
6. Emit `EventBus.scene_started(scene_id)`. Enter `Active` state.

**4. Scene Completion Sequence**
1. On `EventBus.scene_completed(scene_id)`: enter `Transitioning` state immediately.
2. Call `CardSpawningSystem.clear_all_cards()` to remove all cards from the table.
3. Await one frame (`await get_tree().process_frame`) to ensure `queue_free()` completes before spawning new cards.
4. Call `SceneGoalSystem.reset()`.
5. Increment `_current_index`.

**5. Next Scene vs. Final Scene**
- If `_current_index < manifest.size()`: call `_load_scene_at_index(_current_index)` (restart the load sequence).
- If `_current_index >= manifest.size()`: this is the epilogue. Enter `Epilogue` state. Emit `EventBus.epilogue_started()`. Scene Manager's role ends — a dedicated epilogue handler (Final Epilogue Screen, #18) owns the illustrated memory reveal.

**6. Table Clearing**
- `clear_all_cards()` removes every card currently on the table via the Card Spawning System. No card survives a scene transition.
- During `Transitioning` state, no new spawns are accepted by Card Spawning System.

**7. Resume Index API (for Save/Progress System integration)**
- `get_resume_index() -> int`: returns `_current_index`. Pure read; no side effects. Safe to call from any state. Called by SaveSystem during every save write.
- `set_resume_index(index: int) -> void`: assigns `_current_index = index`. Guarded by `assert(_state == State.WAITING)` — only valid at startup, before the first scene loads. If called in any other state, logs an error and returns without mutating. Does NOT clamp negative values — logs an error and returns without mutating on `index < 0`. Does NOT clamp `index > manifest.size()` — accepted as-is so a saved "completed game" state (`index == manifest.size()`) correctly re-enters Epilogue on next launch.
- Neither method emits signals. These are synchronous query/setter helpers owned by SaveSystem's orchestration.

**8. Reset API (for Reset Progress flow)**
- `reset_to_waiting() -> void`: returns SM to its initial `Waiting` state from any state. Callable from the Reset Progress flow (`SaveSystem.clear_save()`). Steps:
  1. If `_state == Loading`: cancel the `seed_cards_ready` watchdog timer if active.
  2. If `_state == Active` or `Transitioning`: call `CardSpawningSystem.clear_all_cards()` (idempotent — no-op if already empty) and `SceneGoalSystem.reset()`.
  3. If `_state == Epilogue`: no cards to clear; skip the clear step. Epilogue has no SGS state to reset beyond what `reset()` handles.
  4. Reset `_current_index = 0`.
  5. Disconnect any stale `seed_cards_ready` / `scene_completed` handlers left dangling from the prior session's state machine (defensive).
  6. Re-connect to `EventBus.game_start_requested` using `CONNECT_ONE_SHOT` (the original one-shot was consumed on first launch; Reset re-arms it).
  7. Set `_state = WAITING`.
- `reset_to_waiting()` emits no signals. The caller is responsible for any scene switch that follows.
- After this call, SM is indistinguishable from its freshly-launched state: waiting on a new `game_start_requested` emission to begin at index 0.

**9. Startup handling of saved "completed game" index**
- When `game_start_requested` fires and `_current_index >= manifest.size()` (restored from a save where Ju previously completed the epilogue), SM transitions directly to `Epilogue` state, emits `epilogue_started()`, and does NOT call `_load_scene_at_index()`. This is the saved-completed-game resume path. The pre-instanced Final Epilogue Screen (per ADR-004 §2) receives `epilogue_started` and begins its reveal.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `Waiting` | `_ready()` completes | `game_start_requested` received | Idle; Main Menu owns the screen; no scene loaded, no cards spawned |
| `Loading` | `_load_scene_at_index()` called | `scene_started` emitted | Awaiting `seed_cards_ready`; no player input accepted |
| `Active` | `scene_started` emitted | `scene_completed` received | Idle — all gameplay owned by other systems |
| `Transitioning` | `scene_completed` received | New `_load_scene_at_index()` called or `epilogue_started` emitted | Table clearing; blocks new spawns |
| `Epilogue` | `_current_index >= manifest.size()` | N/A (terminal state) | Emits `epilogue_started`; hands off to Final Epilogue Screen |

**Transitions:**
- `Waiting → Loading`: `game_start_requested` received (emitted by Main Menu).
- `Loading → Active`: Seed cards placed, `scene_started` emitted.
- `Active → Transitioning`: Scene Goal System emits `scene_completed`.
- `Transitioning → Loading`: Table cleared, next scene begins loading.
- `Transitioning → Epilogue`: Table cleared, no more scenes in manifest.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Scene Goal System** | Scene Manager → SGS (calls) / SGS → Scene Manager (signals) | Calls `load_scene(scene_id)` and `reset()`. Listens to `seed_cards_ready(seed_cards[])` and `scene_completed(scene_id)` via EventBus. |
| **Card Spawning System** | Scene Manager → CSS (calls) | Calls `spawn_card(card_id, position)` for each seed card. Calls `clear_all_cards()` on scene completion. |
| **Table Layout System** | Scene Manager → TLS (calls) | Calls `get_seed_card_positions(seed_cards[])` to get world positions for seed cards. |
| **Audio Manager** | Indirect via EventBus | Audio Manager listens for `scene_loading` and `scene_started` to trigger music crossfade. Scene Manager does not call Audio Manager directly. |
| **Mystery Unlock Tree** (downstream) | Indirect via EventBus | Listens to `scene_started` and `scene_completed` for progression tracking. |
| **Scene Transition UI** (downstream) | Indirect via EventBus | Listens to `scene_started` and `epilogue_started` (per STUI r2 revision — `scene_loading` subscription was dropped). STUI does not need early-warning; its fade-out is driven by `scene_completed` from SGS. |
| **Main Menu** (#17, upstream trigger) | Indirect via EventBus | Main Menu emits `game_start_requested()` when the player presses Start. Scene Manager consumes this once (`CONNECT_ONE_SHOT`) to exit `Waiting` and load index 0. Main Menu holds no reference to Scene Manager — it scene-switches to the gameplay root and emits the signal. |
| **Save/Progress System** (downstream) | SaveSystem → SM (calls) / indirect via EventBus | Calls `SceneManager.get_resume_index() -> int` during save; calls `SceneManager.set_resume_index(index: int) -> void` during `apply_loaded_state()` at startup. Also listens to `scene_completed` via EventBus to trigger the save write. |
| **EventBus** (ADR-003) | Scene Manager emits and listens | Emits: `scene_loading(scene_id)`, `scene_started(scene_id)`, `epilogue_started()`. Listens to: `seed_cards_ready(seed_cards[])`, `scene_completed(scene_id)`. |

## Formulas

Scene Manager performs no calculations. It is a lifecycle coordinator that reads an ordered manifest and delegates all computation to downstream systems.

**Scene index arithmetic (trivial — documented for completeness):**

```
_current_index += 1                          // on scene_completed
is_epilogue = _current_index >= manifest.size()  // after increment
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `_current_index` | int | 0 to `manifest.size()` | Current position in the scene manifest. Starts at 0, increments by 1 on each scene completion. |
| `manifest.size()` | int | 5–8 (authored) | Total number of scenes. Read-only at runtime — defined by `scene-manifest.json`. |

**Output Range:** `_current_index` ranges from 0 (first scene) to `manifest.size()` (epilogue trigger). No clamping needed — the index never decrements.

All substantive math belongs to other systems:
- Bar values, decay, win thresholds → Status Bar System (`design/gdd/status-bar-system.md`)
- Spawn positions → Table Layout System (`design/gdd/table-layout-system.md`)
- Instance ID counters → Card Spawning System (`design/gdd/card-spawning-system.md`)

## Edge Cases

### State Machine Guards

- **If `scene_completed` is received while not in `Active` state** (Loading, Transitioning, or Epilogue): Ignore. Signal handlers must check `_state == State.ACTIVE` before processing. Stale or duplicate signals are silently discarded.

- **If `scene_completed` arrives with a `scene_id` that doesn't match `_manifest[_current_index]`**: Ignore and log a warning with both IDs. This is a stale signal from a previous scene's Scene Goal System that wasn't fully reset.

- **If `seed_cards_ready` is received while not in `Loading` state**: Ignore. Processing seed cards outside of Loading would duplicate cards on the table. Guard with `_state == State.LOADING`.

- **If `_load_scene_at_index()` is called while already in `Loading`** (re-entrant bug): Log a warning and abort the second call. The first load sequence must complete — re-entrancy during an async await corrupts state.

- **If `_load_scene_at_index()` is called while in `Epilogue`**: Log an error and return. Epilogue is a terminal state — no further scene loads.

- **If `game_start_requested` fires while `_current_index >= manifest.size()`** (saved-completed-game resume): SM does NOT call `_load_scene_at_index()` (out-of-bounds); per Core Rule 9, transition directly to `Epilogue`, emit `epilogue_started()`. The pre-instanced FES receives the signal and begins reveal.

- **If `reset_to_waiting()` is called while SM is in `Loading` state and the watchdog timer is running**: Cancel the timer before mutating state. Ensures no deferred `scene_started` emit fires into a `Waiting` state.

### Signal Timing

- **If `seed_cards_ready` never fires** (Scene Goal System failed to parse the scene JSON and stayed Idle): Scene Manager must not wait indefinitely. Race a safety timer (5 seconds) against the signal. On timeout: log an error with the `scene_id`, emit `scene_started` with zero seed cards, and enter `Active` so the game doesn't deadlock. A scene with no cards is playable but empty — better than a frozen screen.

- **If `seed_cards_ready` fires synchronously within the `SceneGoalSystem.load_scene()` call** (before the `await` is registered): Connect the `seed_cards_ready` signal *before* calling `load_scene()`. In GDScript, if the signal fires synchronously before `await` is reached, the await hangs forever.

### Data Validation

- **If `scene-manifest.json` is missing or unreadable**: Log a fatal error in `_ready()`. Enter Epilogue state immediately — the game cannot proceed without a manifest. Do not crash.

- **If `scene-manifest.json` is empty (`[]`)**: Check `manifest.size() == 0` after parsing. Skip directly to Epilogue state and emit `epilogue_started()`. Do not attempt `_load_scene_at_index(0)` — that's an out-of-bounds access.

- **If `scene-manifest.json` is malformed** (invalid JSON, or not an array of strings): Validate on load. Assert the parsed result is an Array with all String elements. On failure: log an error naming the parse issue and enter Epilogue.

- **If the manifest contains a `scene_id` with no corresponding scene JSON file**: Scene Manager delegates to Scene Goal System, which will fail and stay Idle. The `seed_cards_ready` timeout (5 seconds) catches this downstream failure. The scene is skipped gracefully.

- **If the manifest contains duplicate `scene_id` entries** (e.g., `["home", "park", "home"]`): Allow it. The manifest is an opaque ordered list — Chester may intentionally revisit a chapter. Log a debug note for awareness.

### Inter-System Coordination

- **If `TableLayoutSystem.get_seed_card_positions()` returns fewer positions than seed cards**: Spawn only the cards that received positions. Log a warning for each missing position. Do not abort the scene load for partial placement failure.

- **If `CardSpawningSystem.spawn_card()` returns null** (unknown `card_id`): Log a warning naming the card and scene. Continue spawning remaining seed cards. One bad card does not cancel the scene.

- **If `clear_all_cards()` is called when no cards exist on the table** (first scene load, or all cards already consumed): This is a no-op in Card Spawning System. Scene Manager does not need to check card count before calling — always safe to call.

### Godot Lifecycle

- **If Scene Manager's `_ready()` fires before dependency autoloads are initialized**: The canonical autoload order is specified in `docs/architecture/ADR-004-runtime-scene-composition.md` §1. SM is position 11 of 12; all dependencies (EventBus, CardDatabase, RecipeDatabase, SGS, CSS, TLS, MUT) are ordered before it. Validate in `_ready()` that critical singletons are non-null. Log a fatal error if any are missing.

- **If the first `_load_scene_at_index(0)` fires before the main scene tree is built** (autoloads initialize before the main scene): Defer the first load by one frame: `await get_tree().process_frame` at the top of `_ready()`. This ensures all autoloads and the main scene have completed their `_ready()` calls before signals start flowing.

- **If `await get_tree().process_frame` is called while the scene tree is paused**: The await hangs indefinitely because `process_frame` never fires during pause. Set `process_mode = PROCESS_MODE_ALWAYS` so Scene Manager processes even when the tree is paused.

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Scene Goal System** | `load_scene(scene_id)` to configure the scene's goal and bars. `reset()` to clear goal state between scenes. `seed_cards_ready(seed_cards[])` signal to know when seed cards are ready. `scene_completed(scene_id)` signal to trigger scene advance. | Hard — Scene Manager cannot load or complete scenes without it |
| **Card Spawning System** | `spawn_card(card_id, position)` to place seed cards on the table. `clear_all_cards()` to remove all cards on scene transition. | Hard — scenes cannot start (no cards) or end (table never clears) without it |
| **Table Layout System** | `get_seed_card_positions(seed_cards[])` to compute world-space positions for seed cards. | Hard — seed cards need positions; without it, cards have nowhere to go |
| **EventBus** (ADR-003) | Signal bus for all inter-system communication. Scene Manager emits and listens through EventBus. | Hard — no signals flow without it |

### Downstream (systems that depend on this)

| System | What They Need | Hardness |
|--------|---------------|----------|
| **Audio Manager** | `scene_loading(scene_id)` and `scene_started(scene_id)` signals to trigger music crossfade between scenes | Soft — game plays without music; audio is enhancement |
| **Mystery Unlock Tree** | `scene_started(scene_id)` and `scene_completed(scene_id)` for progression tracking | Soft at MVP — not required until Vertical Slice |
| **Scene Transition UI** | `scene_started(scene_id)` and `epilogue_started()` — fade-out triggered by SGS's `scene_completed`, not SM's signals | Soft — game functions without transition animation |
| **Save/Progress System** | `scene_completed(scene_id)` to persist scene completion | Soft at MVP — not required until Alpha |
| **Final Epilogue Screen** | `epilogue_started()` signal to begin the illustrated memory reveal | Hard for game completion — without it, epilogue never triggers |

### External Data

| Asset | Path | Description |
|-------|------|-------------|
| **Scene manifest** | `assets/data/scene-manifest.json` | Ordered array of `scene_id` strings — the canonical playthrough order |
| **Per-scene data** | `assets/data/scenes/[scene_id].json` | Read by Scene Goal System, not Scene Manager directly. SM passes the `scene_id`; SGS reads the file. |

### Signals Emitted

| Signal | Parameters | Fired When |
|--------|------------|-----------|
| `scene_loading` | `scene_id: String` | Step 1 of scene load sequence — before any systems are configured |
| `scene_started` | `scene_id: String` | After seed cards are placed and scene is playable |
| `epilogue_started` | *(none)* | When `_current_index >= manifest.size()` after the final scene completes |

### Signals Listened To

| Signal | Source | Handled When |
|--------|--------|-------------|
| `seed_cards_ready` | Scene Goal System (via EventBus) | During `Loading` state only — triggers seed card placement |
| `scene_completed` | Scene Goal System (via EventBus) | During `Active` state only — triggers scene transition |

**Cross-reference note**: Scene Goal System GDD lists Scene Manager as the caller of `load_scene()` and `reset()`, and as the listener of `seed_cards_ready` and `scene_completed` — bidirectionally consistent. Card Spawning System GDD lists Scene Manager as a caller of `spawn_card()` and `clear_all_cards()` — consistent. Table Layout System GDD lists Scene Manager as a caller of `get_seed_card_positions()` — consistent.

## Tuning Knobs

Scene Manager has one system-level knob. All scene content values (bar config, seed cards, goal parameters) are owned by per-scene JSON files and the Scene Goal System — Scene Manager passes them through without modification.

| Knob | Type | Default | Safe Range | Too Low | Too High |
|------|------|---------|------------|---------|----------|
| `seed_cards_ready_timeout_sec` | float (seconds) | 5.0 | 2–15 | False positives — SM gives up on valid scenes that take time to parse (unlikely unless disk is slow) | SM hangs too long on genuinely broken scenes; player stares at a blank table |

**Knobs owned by other systems (referenced for authoring context):**

| Knob | Owner | Description |
|------|-------|-------------|
| Scene order | `assets/data/scene-manifest.json` | Chester authors the playthrough order directly in the manifest file |
| Seed card list per scene | `assets/data/scenes/[scene_id].json` | Authored per-scene; read by Scene Goal System |
| Bar config, thresholds, decay | Scene Goal System / Status Bar System | All bar math parameters are per-scene authored data |

**Note**: The manifest itself is the primary "tuning knob" for Scene Manager — it controls the entire game structure. But it is authored data, not a runtime-configurable value.

## Visual/Audio Requirements

Scene Manager does not own any visual or audio assets directly. It emits lifecycle signals that downstream presentation systems consume.

**Audio responses (owned by Audio Manager):**
- `scene_loading(scene_id)` → Audio Manager should begin crossfading to the new scene's ambient music track. The crossfade duration and track selection are Audio Manager's responsibility.
- `scene_started(scene_id)` → Audio Manager may use this as confirmation that the new scene is active (e.g., completing a volume ramp-up).
- `epilogue_started()` → Audio Manager should transition to epilogue music or silence.

**Visual responses (owned by Scene Transition UI, #16):**
- `scene_loading(scene_id)` → Scene Transition UI may display a transition visual (e.g., a gentle fade or table-clearing animation).
- `scene_started(scene_id)` → Scene Transition UI should complete/dismiss the transition visual.

Scene Manager does not specify *what* the transition looks or sounds like — only when the signals fire. Creative direction for transitions belongs to the Scene Transition UI and Audio Manager GDDs.

## UI Requirements

Scene Manager has no direct UI. It does not render anything, display text, or interact with the player visually. All UI associated with scene transitions is owned by **Scene Transition UI** (#16, Vertical Slice), which listens to Scene Manager's signals.

The only implicit UI constraint: during `Loading` state, no player input should be accepted (cards should not be draggable). This is enforced by Card Engine observing the scene state, not by Scene Manager displaying a "loading" screen.

## Acceptance Criteria

### Manifest Loading
- **GIVEN** `scene-manifest.json` exists with `["home", "park", "cafe"]`, **WHEN** Scene Manager's `_ready()` fires, **THEN** `_manifest` contains `["home", "park", "cafe"]` in that order and `_current_index` is `0`.
- **GIVEN** `scene-manifest.json` contains `["park", "home"]` (reversed), **WHEN** Scene Manager loads the manifest, **THEN** scenes play in order `park` then `home` — no hardcoded override reorders them.

### Startup
- **GIVEN** Scene Manager's `_ready()` fires, **WHEN** the method begins, **THEN** it enters `Waiting` state and connects to `EventBus.game_start_requested` with `CONNECT_ONE_SHOT`. It does **not** call `_load_scene_at_index(0)`.
- **GIVEN** Scene Manager is in `Waiting` state AND no save was applied, **WHEN** `EventBus.game_start_requested()` is emitted (by `gameplay.tscn` root), **THEN** `_load_scene_at_index(0)` is called exactly once and the state transitions to `Loading`.
- **GIVEN** Scene Manager is in `Waiting` state AND `set_resume_index(2)` was just called by SaveSystem, **WHEN** `EventBus.game_start_requested()` is emitted, **THEN** `_load_scene_at_index(2)` is called (resumes from saved chapter) — *not* `_load_scene_at_index(0)`.
- **GIVEN** Scene Manager is in `Loading`/`Active`/`Transitioning`/`Epilogue` state, **WHEN** `game_start_requested()` is re-emitted, **THEN** the signal is silently ignored (already handled by `CONNECT_ONE_SHOT`).
- **GIVEN** Scene Manager is added to the scene tree, **WHEN** inspected at runtime, **THEN** `process_mode == PROCESS_MODE_ALWAYS`.
- **GIVEN** Scene Manager's `_ready()` fires, **WHEN** it checks for required autoloads, **THEN** EventBus, SceneGoalSystem, CardSpawningSystem, and TableLayoutSystem are verified non-null. If any is null, a fatal error is logged.

### Scene Load Sequence
- **GIVEN** `_current_index` is `0` and manifest has `"home"` at index 0, **WHEN** `_load_scene_at_index(0)` is called, **THEN** `EventBus.scene_loading("home")` is emitted before any system calls.
- **GIVEN** `scene_loading` has been emitted, **WHEN** the load sequence continues, **THEN** `SceneGoalSystem.load_scene("home")` is called.
- **GIVEN** Scene Manager is about to call `SceneGoalSystem.load_scene()`, **WHEN** preparing the load sequence, **THEN** the `seed_cards_ready` signal handler is connected *before* `load_scene()` is called.
- **GIVEN** `seed_cards_ready(["chester", "ju"])` is received during Loading, **WHEN** Scene Manager processes the signal, **THEN** it calls `TableLayoutSystem.get_seed_card_positions()` and then `CardSpawningSystem.spawn_card()` for each seed card at the returned positions.
- **GIVEN** all seed cards have been spawned, **WHEN** the load sequence completes, **THEN** `EventBus.scene_started("home")` is emitted and `_state` becomes `Active`.

### Scene Completion Sequence
- **GIVEN** `_state` is `Active` and current scene is `"home"`, **WHEN** `scene_completed("home")` is received, **THEN** `_state` immediately becomes `Transitioning`.
- **GIVEN** `_state` has entered `Transitioning`, **WHEN** the completion sequence runs, **THEN** `CardSpawningSystem.clear_all_cards()` is called, followed by a one-frame await, followed by `SceneGoalSystem.reset()`, followed by `_current_index` incrementing by exactly 1.

### Next Scene vs. Epilogue
- **GIVEN** manifest is `["home", "park", "cafe"]` and `_current_index` just became `1`, **WHEN** the completion sequence evaluates, **THEN** `_load_scene_at_index(1)` is called for `"park"`.
- **GIVEN** manifest is `["home", "park"]` and `_current_index` just became `2`, **WHEN** the completion sequence evaluates, **THEN** `_state` becomes `Epilogue`, `epilogue_started()` is emitted, and no further loads occur.

### Full Playthrough
- **GIVEN** manifest is `["home", "park", "cafe"]`, **WHEN** each scene is completed sequentially, **THEN** `_current_index` progresses 0→1→2→3, scenes load in order, and Epilogue is entered at index 3.

### Resume Index API (Save/Progress integration)
- **GIVEN** Scene Manager is in `Waiting` state, **WHEN** `set_resume_index(2)` is called, **THEN** `_current_index == 2` AND `_state` is still `Waiting` (no auto-load).
- **GIVEN** Scene Manager is in `Loading`, `Active`, `Transitioning`, or `Epilogue` state, **WHEN** `set_resume_index(N)` is called for any N, **THEN** `_current_index` is NOT modified AND an error is logged naming the invalid state.
- **GIVEN** Scene Manager is in `Waiting` state, **WHEN** `set_resume_index(-1)` is called, **THEN** `_current_index` is NOT modified AND an error is logged.
- **GIVEN** manifest has 3 scenes AND Scene Manager is in `Waiting`, **WHEN** `set_resume_index(3)` is called and then `game_start_requested()` is emitted, **THEN** Scene Manager transitions directly to `Epilogue` (because `_current_index >= manifest.size()`), emits `epilogue_started()`, and does not attempt to load a scene.
- **GIVEN** `_current_index == 2`, **WHEN** `get_resume_index()` is called, **THEN** it returns `2` AND `_current_index` is unchanged AND no signals are emitted.
- **GIVEN** Scene Manager is mid-gameplay (`Active` state), **WHEN** `get_resume_index()` is called (by SaveSystem on `scene_completed`), **THEN** it returns the current value of `_current_index` — this is a pure read and safe from any state.

### Reset API (Reset Progress integration)
- **GIVEN** Scene Manager is `Active` with `_current_index == 2` AND cards on the table, **WHEN** `reset_to_waiting()` is called, **THEN** `CardSpawningSystem.clear_all_cards()` was invoked AND `SceneGoalSystem.reset()` was invoked AND `_current_index == 0` AND `_state == WAITING` AND the `game_start_requested` CONNECT_ONE_SHOT handler is re-armed.
- **GIVEN** Scene Manager is in `Waiting` state already, **WHEN** `reset_to_waiting()` is called, **THEN** the call is idempotent — no error, no signals emitted, state unchanged except the handler re-arm is a no-op.
- **GIVEN** Scene Manager is `Loading` with the `seed_cards_ready_timeout_sec` watchdog running, **WHEN** `reset_to_waiting()` is called, **THEN** the watchdog timer is cancelled AND no deferred `scene_started` fires into `Waiting` state.
- **GIVEN** Scene Manager is in `Epilogue`, **WHEN** `reset_to_waiting()` is called, **THEN** no `clear_all_cards()` call is made (Epilogue has no cards) AND the rest of the reset runs normally.
- **GIVEN** `reset_to_waiting()` has just returned, **WHEN** `game_start_requested()` is emitted, **THEN** SM loads scene index 0 exactly as on first-session launch.

### State Guards
- **GIVEN** `_state` is `Waiting`, **WHEN** `scene_completed` or `seed_cards_ready` is received, **THEN** it is silently ignored (no scene loaded yet).
- **GIVEN** `_state` is `Loading`, **WHEN** `scene_completed` is received, **THEN** it is silently ignored.
- **GIVEN** `_state` is `Transitioning`, **WHEN** `scene_completed` is received, **THEN** it is silently ignored.
- **GIVEN** `_state` is `Epilogue`, **WHEN** `scene_completed` is received, **THEN** it is silently ignored.
- **GIVEN** `_state` is `Active` on scene `"park"`, **WHEN** `scene_completed("home")` arrives (mismatched), **THEN** it is ignored and a warning is logged with both IDs.
- **GIVEN** `_state` is `Active`, **WHEN** `seed_cards_ready` is received, **THEN** it is silently ignored.
- **GIVEN** `_state` is `Loading`, **WHEN** `_load_scene_at_index()` is called again (re-entrant), **THEN** the second call logs a warning and returns without corrupting state.
- **GIVEN** `_state` is `Epilogue`, **WHEN** `_load_scene_at_index()` is called, **THEN** an error is logged and the call returns.

### Timeout
- **GIVEN** `_state` is `Loading` and `seed_cards_ready` is not received, **WHEN** 5.0 seconds elapse, **THEN** Scene Manager logs an error, emits `scene_started` with zero cards, and enters `Active`.
- **GIVEN** `seed_cards_ready_timeout_sec` is `2.0`, **WHEN** `seed_cards_ready` is not received, **THEN** the timeout fires at ~2 seconds.
- **GIVEN** the timeout timer is running and `seed_cards_ready` arrives at 1.5 seconds, **WHEN** the signal is processed, **THEN** the timer is cancelled and seed cards are spawned normally.

### Data Validation
- **GIVEN** `scene-manifest.json` does not exist, **WHEN** `_ready()` attempts to load it, **THEN** a fatal error is logged, `_state` becomes `Epilogue`, and `epilogue_started()` is emitted.
- **GIVEN** `scene-manifest.json` contains `[]`, **WHEN** Scene Manager parses it, **THEN** Epilogue is entered immediately — `_load_scene_at_index(0)` is never called.
- **GIVEN** `scene-manifest.json` is invalid JSON, **WHEN** Scene Manager validates it, **THEN** a parse error is logged and Epilogue is entered.
- **GIVEN** manifest contains `["home", "park", "home"]`, **WHEN** loaded, **THEN** all three are accepted (duplicates allowed).

### Inter-System Coordination
- **GIVEN** `seed_cards_ready(["a", "b", "c"])` but `get_seed_card_positions()` returns only 2 positions, **WHEN** spawning, **THEN** only 2 cards are spawned, a warning is logged, and `scene_started` still emits.
- **GIVEN** `spawn_card("bad_card", pos)` returns null, **WHEN** processing seed cards, **THEN** a warning is logged and remaining cards are still spawned.
- **GIVEN** manifest contains `"nonexistent"` with no scene JSON, **WHEN** `load_scene("nonexistent")` fails and `seed_cards_ready` never fires, **THEN** the timeout handles it — Active with zero cards.

## Open Questions

1. **Save/restore of `_current_index`**: ~~Scene Manager always starts at index 0 on game launch.~~ **RESOLVED 2026-04-21** by Save/Progress System GDD (`design/gdd/save-progress-system.md` Core Rule 4). Scene Manager exposes two new public methods: `get_resume_index() -> int` (returns `_current_index` for serialization) and `set_resume_index(index: int) -> void` (injects the restored index; asserts `_state == Waiting`). The `gameplay.tscn` root script calls `SaveSystem.apply_loaded_state()` before emitting `EventBus.game_start_requested()`, so by the time SM's `CONNECT_ONE_SHOT` handler fires, `_current_index` already holds the saved value. No change to SM's core state machine — only the new setter and getter.

2. **Error recovery after timeout**: If `seed_cards_ready` times out and Scene Manager enters Active with zero cards, the player faces an empty table with no way to trigger `scene_completed`. Should Scene Manager auto-advance after N seconds of empty-table active time? Or is a timeout-degraded scene an authoring error that should only be caught during development? Recommendation: treat as dev-only error — log loudly, don't auto-advance in production.

   **Cross-GDD note (Main Menu dependency):** Main Menu's AC-FAIL-1 assumes Scene Manager owns the watchdog for deferred scene-switch failures. The Loading-timeout contract here (5.0s default) is the mechanism. If `change_scene_to_file()` fails deferred after Main Menu is freed, Main Menu is gone, and the load sequence never reaches `scene_started`. Scene Manager's Loading-state timeout fires, logs the error, and emits `scene_started` with zero cards — same dev-error path as a malformed scene JSON. This open question is load-bearing for Main Menu's "what if the scene switch fails silently?" edge case.

3. **ITF cooldown reset on scene transition**: The Interaction Template Framework GDD flagged this as unresolved. Does Scene Manager call `ITF.reset_cooldowns()` during the transition sequence? Recommendation (from SGS open questions): Scene Manager resets ITF cooldowns as part of the transition — after `clear_all_cards()` and before `SceneGoalSystem.reset()`. Scene Goal System should not reach into ITF directly.

4. **`scene_completed` payload enrichment**: Scene Transition UI and downstream systems may need additional data beyond `scene_id` when a scene completes — e.g., a "reward card" to display, a completion animation variant, or a narrative beat identifier. Options: (a) enrich the `scene_completed` signal with a `completion_data` dictionary; (b) let downstream systems read completion data from Scene Goal System directly. Resolve when designing Scene Transition UI.

5. **CSS spawn queue during transition**: Card Spawning System queues spawns during its `Clearing` state. If a Generator (ITF) queues a spawn during the transition clear, that spawn executes after clearing but before the next scene's seed cards. Should Scene Manager signal CSS to discard queued spawns on transition? Recommendation: yes — add `discard_queued_spawns()` to the transition sequence between `clear_all_cards()` and the next load.

6. **Autoload order enforcement**: The Edge Cases section specifies required order (EventBus → SceneGoalSystem → CSS → TLS → SceneManager), and acceptance criteria validate null-checks. But null-checks don't catch ordering violations where a singleton exists but hasn't finished `_ready()`. Worth documenting the required `project.godot` autoload order explicitly in the architecture, and possibly adding a readiness flag pattern.
