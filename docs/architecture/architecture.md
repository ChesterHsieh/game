# Moments — Master Architecture

## Document Status

| Field | Value |
|---|---|
| **Version** | 1 |
| **Last Updated** | 2026-04-21 |
| **Engine** | Godot 4.3 (pinned 2026-03-25; risk LOW — within LLM training cutoff May 2025) |
| **GDDs Covered** | 20 system GDDs + game-concept.md + systems-index.md (all `Designed`) |
| **ADRs Referenced** | ADR-001, ADR-002, ADR-003, ADR-004, ADR-005 (all Accepted) |
| **TR Baseline** | 298 TRs across 20 systems (see `tr-registry.yaml`) |
| **Review Mode** | Lean (PR-EPIC and LP-FEASIBILITY gates skipped per director-gates.md) |
| **Technical Director Sign-Off** | 2026-04-21 — APPROVED (all blocking ADRs accepted; ADR-005 `.tres everywhere` resolved the last condition) |
| **Lead Programmer Feasibility** | SKIPPED — Lean mode |

---

## 1. Engine Knowledge Gap Summary

Godot 4.3 is fully within the LLM's training data (cutoff May 2025). Every engine API
used across the 20 GDDs and 4 ADRs — `Node`, `CanvasLayer`, `Tween`, `AudioStreamPlayer`,
`FileAccess`, `DirAccess.rename_absolute()`, `ResourceLoader.load_threaded_request`,
autoload singletons, `CONNECT_ONE_SHOT`, `_process`, `_ready` — is pre-cutoff and stable.

- **HIGH RISK domains**: None
- **MEDIUM RISK domains**: None
- **LOW RISK domains**: Rendering (2D / Node2D), Input, Tween, Signals, Autoload, FileAccess, CanvasLayer, Audio bus, Scene tree, ResourceLoader

Changes documented in `docs/engine-reference/godot/breaking-changes.md` and `deprecated-apis.md`
for versions 4.4, 4.5, and 4.6 are **not applicable** to this project. When the project
eventually upgrades from 4.3, the items flagged in those reference docs become load-bearing.

No Engine-Compatibility warnings are required on any module in this architecture.

---

## 2. System Layer Map

Architectural layers are organised by lifecycle and coupling, not by game-design categorisation.
This differs from `systems-index.md`'s layers (which are a recommended design order).

```
┌──────────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER (scene-instanced nodes, render above gameplay)   │
│    CardVisual · StatusBarUI · SceneTransitionUI · MainMenu · FES     │
├──────────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER (gameplay logic — some autoloaded, some per-scene)    │
│    InteractionTemplateFramework · StatusBarSystem · SceneGoalSystem  │
│    HintSystem · MysteryUnlockTree                                    │
├──────────────────────────────────────────────────────────────────────┤
│  CORE LAYER (card feel — input-critical)                             │
│    CardEngine · TableLayoutSystem · CardSpawningSystem               │
├──────────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER (12 autoloaded singletons — always alive)          │
│    EventBus · CardDatabase · RecipeDatabase · InputSystem            │
│    AudioManager · SettingsManager · SceneGoalSystem · CSS · TLS      │
│    MysteryUnlockTree · SceneManager · SaveSystem                     │
├──────────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER (Godot 4.3 engine APIs — see engine-reference/godot) │
│    SceneTree · Node · Node2D · CanvasLayer · Tween · Input · File    │
└──────────────────────────────────────────────────────────────────────┘
```

**Note on layer membership**: Several systems span architectural layers because they combine
an autoloaded Foundation-layer singleton (always-alive service) with per-scene instanced nodes.

| System | Foundation role | Scene-level role |
|---|---|---|
| SceneGoalSystem | Autoload — loads scene JSON, owns goal state | — |
| CardSpawningSystem | Autoload — owns card pool, emits lifecycle signals | — |
| StatusBarSystem | Autoload — owns bar values, win-condition logic | — |
| HintSystem | Autoload — owns stagnation timer | — |
| SceneManager | Autoload — scene state machine, manifest | — |
| MysteryUnlockTree | Autoload — discovery registry, epilogue hook | — |
| SaveSystem | Autoload — persistence | — |
| CardVisual | — | Per-card instance rendering |
| StatusBarUI | — | Scene-instanced HUD |
| SceneTransitionUI | — | CanvasLayer instance in gameplay.tscn |
| MainMenu | — | Top-level scene (res://src/ui/main_menu/main_menu.tscn) |
| FinalEpilogueScreen | — | Pre-instanced in gameplay.tscn at layer 20 |

---

## 3. Module Ownership

### 3.1 Canonical autoload order (from ADR-004 §1)

```
 1. EventBus           — signal hub; declares all 30 signals (ADR-003)
 2. CardDatabase       — static data; loaded at _ready
 3. RecipeDatabase     — static data; depends on CardDatabase at validation time
 4. InputSystem        — mouse wrapper; emits drag_* and proximity_* signals
 5. AudioManager       — bus management; SFX/Music pools; listens to EventBus
 6. SettingsManager    — user://settings.tres I/O (SettingsState Resource); applies volumes to AudioManager
 7. SceneGoalSystem    — per-scene .tres loader (SceneData Resource); owns Idle/Active/Complete FSM
 8. CardSpawningSystem — owns card pool (ADR-002); sole queue_free authority
 9. TableLayoutSystem  — stateless; pure positional helpers
10. MysteryUnlockTree  — discovery registry; emits recipe_discovered / milestone
11. SceneManager       — scene state machine; scene_completed listener (post-increment first)
12. SaveSystem         — save/load orchestrator; scene_completed listener (runs AFTER SM)
```

Every autoload has `process_mode = PROCESS_MODE_ALWAYS`.

### 3.2 `gameplay.tscn` tree (from ADR-004 §2)

```
gameplay.tscn — Node (gameplay_root.gd as script)
├── CardTable              (Node2D, z_index 0) — CSS spawns card instances here
├── HudLayer               (CanvasLayer, layer = 5)
│   ├── StatusBarUI
│   └── SettingsTrigger    (gear button)
├── TransitionLayer        (CanvasLayer, layer = 10)
│   └── SceneTransitionUI
├── SettingsPanelHost      (CanvasLayer, layer = 15)
│   └── (SettingsPanel — instantiated on gear press, freed on close)
└── EpilogueLayer          (CanvasLayer, layer = 20)
    └── FinalEpilogueScreen (pre-instanced, Armed state)
```

### 3.3 Ownership table

| Module | Owns | Exposes | Consumes |
|---|---|---|---|
| EventBus | 30 signal declarations | All signals (emit + connect) | — |
| CardDatabase | Card entries keyed by `card_id` | `get_card(id)`, `get_all()` | `.tres` Resource data (ADR-005) |
| RecipeDatabase | Recipe entries keyed by pair | `lookup(id_a, id_b)` | CardDatabase validation |
| InputSystem | Drag state machine (Idle/Dragging) | `cancel_drag()` | Godot `Input`, `Camera2D` |
| AudioManager | 8 SFX + 2 music pool players | `set_bus_volume()`, `fade_out_all()` | EventBus signals, `audio_config.tres` |
| SettingsManager | Settings file state, volumes | `apply_all_volumes()`, `flush_pending_save()` | AudioManager |
| SceneGoalSystem | Per-scene goal FSM | `load_scene(id)`, `reset()`, `get_goal_config()` | scenes/[id].tres (SceneData Resource) |
| CardSpawningSystem | Card pool + instance_id registry | `spawn_card`, `remove_card`, `clear_all_cards`, `spawn_seed_cards` | CardDatabase |
| TableLayoutSystem | Stateless | `get_seed_card_positions`, `get_spawn_position` | RNG, bounds config |
| MysteryUnlockTree | Discovery registry, indices | `get_save_state`, `load_save_state`, `get_carry_forward_cards` | RecipeDatabase, mut-config.tres (MutConfig Resource) |
| SceneManager | Scene FSM, manifest, `_current_index` | `get_resume_index`, `set_resume_index`, `reset_to_waiting` | SGS, CSS, TLS |
| SaveSystem | Save file state, LoadResult enum | `load_from_disk`, `apply_loaded_state`, `save_now`, `clear_save` | SM, MUT |
| CardEngine | Per-card FSM (6 states), tweens | `combination_attempted` emission | InputSystem signals, CardVisual |
| ITF | Per-recipe cooldowns, `_active_generators` | `suspend`, `resume` | RecipeDatabase, CardEngine, CSS, TLS |
| StatusBarSystem | Bar values, win timer | `configure`, `reset` | ITF `combination_executed`, decay timer |
| HintSystem | Stagnation timer, hint_level | — | SGS goal config, combination_executed |
| CardVisual | Per-card view state | — | CardDatabase, CardEngine FSM state |
| StatusBarUI | Bar fill tween, arc tween | — | SBS, HS signals |
| SceneTransitionUI | Transition FSM, polygon overlay | `epilogue_cover_ready` emission | SM, SGS signals |
| MainMenu | Idle/Starting state only | — | Nothing (Rule 6 no coupling) |
| FinalEpilogueScreen | Armed/Loading/Ready/Revealing FSM | — | MUT query, AudioManager, `epilogue_cover_ready` |

---

## 4. Data Flow

### 4.1 Frame update path (card feel — input-critical)

```
Godot _process / InputEvent
   │
   ▼
InputSystem (hit-test, drag FSM)
   │  drag_started(card_id, world_pos)
   │  drag_moved(card_id, world_pos, delta)
   │  drag_released(card_id, world_pos)
   │  proximity_entered / proximity_exited(dragged_id, target_id)
   ▼
EventBus (synchronous dispatch)
   │
   ▼
CardEngine (per-card FSM: Idle → Dragged → Attracting → Snapping → Pushed → Executing)
   │  ↳ Tween on card Node2D.position (cancellable mid-flight)
   │  ↳ emits combination_attempted(instance_a, instance_b) on snap complete
   ▼
CardVisual reads CardEngine state → applies scale/shadow/z-order
```

Frame budget: 16.7ms. Tween-based motion only — no physics simulation.

### 4.2 Combination event path

```
CardEngine.combination_attempted(a, b)
   │
   ▼
ITF (sole listener)
   ├─ RecipeDatabase.lookup(card_id_a, card_id_b) → recipe | null
   ├─ emits combination_failed(a, b)   — on null
   └─ emits combination_succeeded(a, b, template, config) + dispatches template handler
       │
       ▼
ITF emits combination_executed(recipe_id, template, instance_a, instance_b, card_id_a, card_id_b)
   │  (6 params — Godot 4.3 arity-strict; all handlers MUST declare 6)
   ▼
Parallel handlers (all connect via EventBus):
  • StatusBarSystem — applies bar deltas from bar-effects.tres
  • SceneGoalSystem — advances find_key / sequence goals
  • MysteryUnlockTree — records discovery if first-time
  • HintSystem — resets stagnation_timer to 0
```

### 4.3 Save/load path

**Boot sequence** (from ADR-004 §3):

```
gameplay_root._ready()  [runs AFTER all 12 autoloads are ready]
   │
   ▼
SaveSystem.load_from_disk() → LoadResult (OK / NO_SAVE_FOUND / CORRUPT_RECOVERED)
   │
   ▼  (if OK)
SaveSystem.apply_loaded_state()
   ├─ SceneManager.set_resume_index(saved_index)
   └─ MysteryUnlockTree.load_save_state(saved_mut)
   │
   ▼
EventBus.game_start_requested.emit()   [SceneManager has CONNECT_ONE_SHOT]
```

**Save-on-scene-complete** (listener-ordering contract, ADR-004 §5):

```
SceneGoalSystem.scene_completed(scene_id)
   │
   ▼  (handler order governed by autoload order — SM before SaveSystem)
SceneManager handler
   ├─ CSS.clear_all_cards()
   ├─ await one process_frame
   ├─ SGS.reset()
   ├─ _current_index += 1              [POST-INCREMENT — contract-locked]
   └─ emits epilogue_started if at terminal index
   ▼
SaveSystem handler (runs AFTER SM; reads SM.get_resume_index() = post-increment value)
   ├─ builds schema-v1 envelope
   ├─ atomic write: .tmp → DirAccess.rename_absolute()
   └─ emits save_written or save_failed(reason)
   ▼
MysteryUnlockTree handler (state transition only; no save write)
```

**Save-on-epilogue** (ADR-004 §6): `gameplay_root` subscribes to `final_memory_ready` and
calls `SaveSystem.save_now()` synchronously, because SM never emits a fresh `scene_completed`
from the terminal Epilogue state.

### 4.4 Initialisation order (from ADR-004 §1 + §3)

```
1. Godot engine boots
2. 12 autoloads initialize bottom-up in project.godot order → each _ready() runs to completion
3. Main scene (MainMenu on cold start, or gameplay.tscn on subsequent change_scene_to_file)
4. If MainMenu: user presses Start → change_scene_to_file("gameplay.tscn")
5. gameplay.tscn children _ready() bottom-up → gameplay_root _ready() last
6. gameplay_root orchestrates save load → apply → EventBus.game_start_requested
```

**No cross-thread communication.** All gameplay systems run on the main thread. Only
`ResourceLoader.load_threaded_request` in FES preloading uses a background thread, and
its result is polled on the main thread.

---

## 5. API Boundaries

The full API surface is defined by the Technical Requirements in `tr-registry.yaml`.
The cross-module contracts that stories implement against are:

### 5.1 EventBus — signal hub (ADR-003)

All 30 signals declared in `res://src/core/event_bus.gd`. Systems emit via
`EventBus.signal_name.emit(...)`, connect via `EventBus.signal_name.connect(handler)`.

Signal domains (see ADR-003 for full declaration):
- Input / Card Engine: `drag_started`, `drag_moved`, `drag_released`, `proximity_entered`, `proximity_exited`
- Combination / ITF: `combination_attempted`, `combination_succeeded`, `combination_failed`, `combination_executed(6)`, `merge_animation_complete`, `animate_complete`
- Card lifecycle: `card_spawned`, `card_removing`, `card_removed`
- Status / Goal / Hint: `bar_values_changed`, `win_condition_met`, `hint_level_changed`
- Scene lifecycle: `seed_cards_ready`, `scene_loading`, `scene_started`, `scene_completed`, `epilogue_started`
- MUT: `recipe_discovered`, `discovery_milestone_reached`, `epilogue_conditions_met`, `final_memory_ready`
- Transition: `epilogue_cover_ready`
- Startup: `game_start_requested`
- Persistence: `save_written`, `save_failed(reason)`

### 5.2 Read-only query autoloads (no events, direct calls)

```gdscript
CardDatabase.get_card(id: String) -> Dictionary
RecipeDatabase.lookup(card_a: String, card_b: String) -> Dictionary   # or null
SceneGoalSystem.get_goal_config() -> Dictionary                        # or null when Idle
SceneManager.get_resume_index() -> int
MysteryUnlockTree.get_carry_forward_cards(spec: Dictionary) -> Array[String]
MysteryUnlockTree.is_final_memory_earned() -> bool
```

### 5.3 Public mutation APIs (non-signal; cross-module)

| Module | Method | Callers |
|---|---|---|
| SceneManager | `set_resume_index(i: int)` | SaveSystem |
| SceneManager | `reset_to_waiting()` | SaveSystem.clear_save |
| SaveSystem | `load_from_disk() -> LoadResult` | gameplay_root |
| SaveSystem | `apply_loaded_state()` | gameplay_root |
| SaveSystem | `save_now()` | gameplay_root on final_memory_ready |
| SaveSystem | `clear_save()` | SettingsManager Reset Progress |
| CardSpawningSystem | `spawn_card(card_id, pos) -> instance_id` | ITF, SceneManager |
| CardSpawningSystem | `remove_card(instance_id)` | ITF |
| CardSpawningSystem | `clear_all_cards()` | SceneManager |
| CardSpawningSystem | `spawn_seed_cards(scene_data)` | SceneManager |
| StatusBarSystem | `configure(bar_config)` | SceneGoalSystem |
| StatusBarSystem | `reset()` | SceneManager |
| SceneGoalSystem | `load_scene(id)` | SceneManager |
| SceneGoalSystem | `reset()` | SceneManager |
| ITF | `suspend()`, `resume()` | SceneManager |
| MysteryUnlockTree | `load_save_state(data)` | SaveSystem |
| MysteryUnlockTree | `get_save_state() -> Dictionary` | SaveSystem |
| AudioManager | `set_bus_volume(bus, db)` | SettingsManager |
| AudioManager | `fade_out_all(duration)` | FinalEpilogueScreen |
| InputSystem | `cancel_drag()` | SceneTransitionUI, SettingsManager |

### 5.4 Invariants callers must respect

- **No `queue_free()` on card nodes** outside CardSpawningSystem. Use `remove_card(instance_id)`.
- **All signal handlers for `combination_executed`** MUST declare 6 parameters (Godot 4.3 is arity-strict).
- **`EventBus.scene_completed` listener order**: SceneManager first (connects in its own `_ready`),
  SaveSystem second. Connection timing is load-bearing and must not be reordered.
- **No direct node references** between systems. Systems communicate via EventBus signals and
  autoload method calls only. Node paths are owned by the scene that instantiates the node.

---

## 6. ADR Audit

### 6.1 Quality check

| ADR | Title | Engine Compat | Version Recorded | GDD Linkage | Conflicts | Valid |
|---|---|---|---|---|---|---|
| ADR-001 | Naming conventions — snake_case | ❌ missing | ❌ (implicit 4.3) | ❌ (cross-cutting — all systems) | None | ✅ |
| ADR-002 | Card scene structure — object pool | ❌ missing | ❌ (implicit 4.3) | ❌ (implicit — CardSpawningSystem) | None | ✅ |
| ADR-003 | Inter-system communication — EventBus | ❌ missing | partial (inline mentions) | ⚠️ (inline GDD links, not a dedicated section) | None | ✅ |
| ADR-004 | Runtime scene composition + autoload | ✅ | ✅ | ✅ | None | ✅ |
| ADR-005 | Data file format — `.tres` everywhere | ✅ | ✅ | ✅ | None | ✅ |

**Retrofit work (non-blocking, follow-up ticket):**
- Add `## Engine Compatibility` section to ADR-001, ADR-002, ADR-003 (all LOW-risk — trivial fill)
- Add `## GDD Requirements Addressed` section to ADR-001, ADR-002, ADR-003
- Add `## ADR Dependencies` section to ADR-001, ADR-002, ADR-003

None of the above blocks `/create-epics`. The information exists; it's a formatting gap.

### 6.2 Traceability coverage (summarised — full mapping in `tr-registry.yaml`)

| ADR | Covers TR groups |
|---|---|
| ADR-001 | All TRs — naming is cross-cutting |
| ADR-002 | TR-card-spawning-001/004/006 (pool semantics, instance_id counter discipline) |
| ADR-003 | All `-Signals` domain TRs across 20 systems (~80 TRs) |
| ADR-004 | TR-scene-manager-001/005/017, TR-save-progress-system-001/004/009/013, TR-settings-001/007, TR-main-menu-009, TR-final-epilogue-screen-001/002/012, TR-scene-transition-ui-001, TR-mystery-unlock-tree-005, TR-card-spawning-system-013 (autoload + scene composition + epilogue handoff + listener order) |

### 6.3 Uncovered requirement groups

The following TR groups have **no ADR** but are not urgent enough to block `/create-epics`
— the GDD itself serves as the contract. They become **Required New ADRs** only if multiple
systems disagree on implementation choice:

1. ~~**Data file format**~~ — **RESOLVED by ADR-005** (`.tres` everywhere). All content data
   uses `class_name` Resource classes loaded via `ResourceLoader`. No longer blocking.
2. **Card Engine FSM and motion formulas** — GDD is the contract; no ADR needed unless an
   alternative implementation is proposed.
3. **Per-scene data layout** (`assets/data/scenes/[scene_id].tres` schema) — shared by SGS, HS, MUT.
   Works as long as all three read the same `SceneData` Resource fields; could be ADR for long-term clarity.
4. **Tween cancellation protocol on `card_removing`** — already required in multiple GDDs;
   could be promoted to ADR but implementation is a one-line discipline.

---

## 7. Required ADRs

### 7.1 Blocking for `/create-epics`

~~**ADR-005: Data File Format Convention**~~ — **RESOLVED.** ADR-005 (`.tres everywhere`)
is Accepted. All persistent data uses `class_name` Resource classes loaded via
`ResourceLoader`/`ResourceSaver`. GDDs swept to remove all `.json` references (2026-04-21).
No remaining blockers for `/create-epics`.

### 7.2 Should have before relevant system is built (non-blocking)

- **ADR-006: Tween Usage Standard** — cancellation protocol on `card_removing` and scene
  transitions; tween ownership (per-system vs per-node). Implementation discipline exists
  across GDDs; an ADR formalises it for future engineers.
- **ADR-007: Per-Scene Data Layout Schema** — locks the `scenes/[id].tres` SceneData Resource
  schema consumed by SGS/HS/MUT. Currently implicit in ADR-005 §4.

### 7.3 Can defer to implementation

- ~~**ADR-008: Test harness choice (GUT vs gdUnit4)**~~ — **RESOLVED.** gdUnit4 v5.0.3
  chosen (2026-04-21). Installed at `addons/gdUnit4/`, CI configured in `.github/workflows/tests.yml`.
  Test helpers scaffolded in `tests/helpers/`.

### 7.4 Retrofit (low priority — does not block anything)

- Add Engine Compatibility / GDD Requirements Addressed / ADR Dependencies sections to
  ADR-001, ADR-002, ADR-003 to match the project ADR template.

---

## 8. Architecture Principles

These five principles govern all technical decisions on Moments. Any story or ADR that
appears to violate one of these must be escalated before implementation.

1. **Signal-first, reference-free communication.** Systems never hold direct node
   references to other systems. All inter-system events flow through `EventBus` (ADR-003).
   Exceptions are read-only autoload queries (CardDatabase, SceneGoalSystem.get_goal_config)
   and documented mutation APIs (see §5.3).

2. **Single source of truth per piece of state.** `_current_index` lives in SceneManager.
   Bar values live in StatusBarSystem. Discovered recipes live in MysteryUnlockTree. No
   duplicate state, no cached mirrors. SaveSystem reads authoritative state at write time;
   it never shadows.

3. **Determinism under replay.** TableLayoutSystem's RNG is seeded; Status Bar decay uses
   `delta_time` not ticks; all `Time.get_ticks_msec()` usage is for cooldowns (non-visual)
   only. The same inputs produce the same outcomes — critical for debugging Chester's gift.

4. **Personal over polished.** N=1 audience. No telemetry, no hot-reload, no modding hooks,
   no feature flags. When in doubt, choose the simpler path. ADR-004 chose pre-instanced
   FES over scene swap partly for this reason.

5. **Silent degradation, never a visible error to Ju.** Missing assets → log + placeholder.
   Corrupt save → rename + start fresh. Missing signal handler → log + drop. Pillar 3
   (Discovery Without Explanation) extends to failure modes: Ju never sees a stack trace.

---

## 9. Open Questions

These must be resolved before the relevant layer is implemented:

1. ~~**ADR-005: data file format**~~ — **RESOLVED** 2026-04-21. ADR-005 Accepted (`.tres` everywhere).
2. ~~**Test harness choice**~~ — **RESOLVED** 2026-04-21. gdUnit4 v5.0.3 chosen and installed.
3. **W-D1 from `/review-all-gdds` cleanup**: `discovery_milestone_reached` signal rename —
   deferred as creative-director call, not architectural. Documented for traceability.
4. **W-D2 from `/review-all-gdds` cleanup**: STUI polish budget (vertex-deformed curl
   feasibility) — production decision at first playtest milestone. Not architectural.

---

## 10. Handoff

Next steps in order:

1. ~~**Write ADR-005 (data file format)**~~ — **DONE** (Accepted 2026-04-21).
2. **(Optional, low priority) Retrofit** ADR-001/002/003 Engine Compatibility sections.
3. ~~**Run `/create-control-manifest`**~~ — **DONE** (control-manifest.md created 2026-04-21).
4. **Run `/gate-check pre-production`** — ADR-005 Accepted + control manifest exists. Ready.
5. **Run `/create-epics`** once the gate passes.

The TR baseline in `tr-registry.yaml` is the authoritative list of what every story must
address. Stories embed TR-IDs directly and reference this architecture document for
cross-module context.
