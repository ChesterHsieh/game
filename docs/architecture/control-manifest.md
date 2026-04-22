# Control Manifest

> **Engine**: Godot 4.3
> **Last Updated**: 2026-04-21
> **Manifest Version**: 2026-04-21
> **ADRs Covered**: ADR-001, ADR-002, ADR-003, ADR-004, ADR-005
> **Status**: Active — regenerate with `/create-control-manifest` when ADRs change
> **Review Mode**: `lean` — TD-MANIFEST gate skipped per `.claude/docs/director-gates.md`

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
`.claude/docs/technical-preferences.md`, and `docs/engine-reference/godot/`.
For the reasoning behind each rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: EventBus signal architecture, autoload lifecycle, scene composition,
save/load, data loading, engine initialisation.*

### Required Patterns

- **Use `EventBus` autoload singleton for all cross-system events** — systems
  `emit` and `connect` through EventBus; no system holds a reference to another.
  Source: ADR-003.
- **Declare every new signal in `res://src/core/event_bus.gd` before implementing
  the emitter** — EventBus is the single source of truth; GDD "Signals Emitted"
  tables are references, not alternatives. Source: ADR-003.
- **Direct autoload calls are reserved for read-only queries**
  (`CardDatabase.get_card(id)`, `SceneGoalSystem.get_goal_config()`). EventBus
  is for events, not queries. Source: ADR-003.
- **`project.godot` declares the 12 autoloads in the canonical order**:
  `EventBus` → `CardDatabase` → `RecipeDatabase` → `InputSystem` → `AudioManager`
  → `SettingsManager` → `SceneGoalSystem` → `CardSpawningSystem` →
  `TableLayoutSystem` → `MysteryUnlockTree` → `SceneManager` → `SaveSystem`.
  Source: ADR-004 §1.
- **Every autoload sets `process_mode = PROCESS_MODE_ALWAYS`** — pause states
  must not strand signals. Source: ADR-004 §1.
- **`SaveSystem` connects to `scene_completed` AFTER `SceneManager` connects** —
  SaveSystem needs the post-increment `resume_index`; ordering is load-bearing.
  Source: ADR-004 §5.
- **`gameplay_root.gd` owns boot orchestration**: in `_ready()` call
  `SaveSystem.load_from_disk()` → `apply_loaded_state()` (on OK) →
  `EventBus.game_start_requested.emit()`. Source: ADR-004 §3.
- **`gameplay_root.gd` calls `SaveSystem.save_now()` on `final_memory_ready`** —
  the epilogue is terminal, so no `scene_completed` will fire to auto-save.
  Source: ADR-004 §6.
- **All persistent data (content, config, save) uses `.tres` Resource files** —
  loaded via `ResourceLoader.load()`, saved via `ResourceSaver.save()`.
  Source: ADR-005 §1.
- **Every data shape is a `class_name <X> extends Resource` with typed `@export`
  fields** — classes live in `res://src/data/`; no methods beyond engine-generated
  getters. Source: ADR-005 §2.
- **Every `ResourceLoader.load()` of a known data file is paired with
  `as <CustomClass>` cast + null check** — bare null checks on raw `Resource`
  are insufficient because a schema-drifted `.tres` loads as generic Resource
  with default fields (BLOCKING-1). Source: ADR-005 §4, §9; registry
  `bare_null_check_on_resource_load`.
- **Semantic validation (uniqueness, cross-refs, ranges) runs in the consuming
  autoload's `_ready()` via `assert`** — not inside the Resource class.
  Source: ADR-005 §2, §6.
- **Save writes are atomic**: `ResourceSaver.save(state, SAVE_TMP)` →
  `DirAccess.rename_absolute(globalize_path(tmp), globalize_path(real))` →
  if `FileAccess.file_exists(SAVE_REMAP)` then
  `DirAccess.remove_absolute(globalize_path(SAVE_REMAP))`.
  Source: ADR-005 §5; registry `atomic_file_rename`, `resource_remap_hygiene`.
- **`SaveState.schema_version != 1` is treated as `CORRUPT_RECOVERED`** —
  quarantine as `user://save.tres.corrupt-<epoch>`, remove stale `.remap`,
  start fresh. No migration chain at v1. Source: ADR-005 §5; registry
  `schema_migration_at_v1`.
- **Corrupt-save quarantine also removes `.remap` sidecar** — same hygiene as
  the happy-path save. Source: ADR-005 §5.
- **`debug-config.tres` is excluded from release exports** via
  `exclude_filter="*/debug-config.tres,*/debug-config.tres.import"` in every
  preset of `export_presets.cfg`. MUT checks `ResourceLoader.exists(...)` at
  runtime and defaults `force_unlock_all = false` when absent.
  Source: ADR-005 §7.

### Forbidden Approaches

- **Never use direct node references or hardcoded node paths for inter-system
  communication** — use EventBus. — Source: ADR-003.
- **Never declare a signal in a GDD's "Signals Emitted" table without adding
  it to EventBus** — runtime error at emit time. — Source: ADR-003.
- **Never add new signals outside `EventBus`** — EventBus is the single source
  of truth for the event graph. — Source: ADR-003.
- **Never use `FileAccess.open(...) + JSON.parse_string(...)` for persistent
  content, config, or save data** — untyped Dictionaries drift silently; use
  `ResourceLoader` + typed Resource. — Source: ADR-005 §4, §9; registry
  `json_for_authored_data`.
- **Never use `save_file.write_string(JSON.stringify(...))`** — same reason as
  above. — Source: ADR-005 §9.
- **Never add a `.json` path under `res://assets/data/` or `user://`** — any
  new `.json` is a code-review reject. — Source: ADR-005 §9; registry
  `json_for_authored_data`.
- **Never call `ResourceLoader.load(...)` without `as <Type>` cast + null
  check** — BLOCKING-1: a schema-drifted `.tres` loads as generic Resource
  and passes a bare null check. — Source: ADR-005 §9; registry
  `bare_null_check_on_resource_load`.
- **Never rename a `.tres` atomically without also removing the `.remap`
  sidecar** — BLOCKING-2: stale `.remap` silently redirects
  `ResourceLoader.load` to the old file (silent data loss). — Source:
  ADR-005 §5; registry `missing_remap_cleanup_after_rename`.
- **Never implement schema migration at `schema_version = 1`** — hard break
  only. Introducing migrations requires a new ADR. — Source: ADR-005 §5;
  registry `schema_migration_at_v1`.
- **Never reorder `SaveSystem` before `SceneManager` in the autoload list** —
  breaks the post-increment `scene_completed` listener contract. — Source:
  ADR-004 §5.
- **Never call `change_scene_to_file` during the epilogue handoff** — STUI
  would be freed before it can emit `epilogue_cover_ready`. FES stays as a
  sibling CanvasLayer inside `gameplay.tscn`. — Source: ADR-004 §4,
  Alternative 1 rejected.

### Performance Guardrails

- **`gameplay.tscn` pre-instance cost**: ≈ +2 MB memory, ≈ +50 ms load (STUI +
  FES nodes). — Source: ADR-004 Performance Implications.
- **Idle FES CanvasLayer**: ≈ 0.2 ms extra per frame. — Source: ADR-004.
- **`cards.tres` (≈200 entries) cold load**: 20–50 ms (within startup budget).
  Editor first-open: 1–3 s. — Source: ADR-005 Performance.
- **`recipes.tres` (≈60 entries) cold load**: 10–15 ms. — Source: ADR-005.
- **Save write (`save_now`)**: 5–10 ms (scene boundary only; imperceptible).
  — Source: ADR-005.
- **Save read (`load_from_disk`)**: ≈ 5 ms (startup only). — Source: ADR-005.

---

## Core Layer Rules

*Applies to: core gameplay loop, card engine, card spawning / pooling,
scene goal system, main player interaction.*

### Required Patterns

- **Card Spawning System owns a pre-instantiated object pool** of size
  `pool_size = 30` — children of a pool container node; visibility and
  position change at runtime. Source: ADR-002.
- **On spawn**: take a card from the free list, configure it (set `card_id`,
  show). **On removal**: reset the card (clear data, hide), return to free
  list. Source: ADR-002.
- **Pool exhaustion logs a warning and falls back to dynamic instantiation** —
  not expected in normal play (safe ceiling of 30). Source: ADR-002.
- **`SceneGoalSystem.load_scene(scene_id)` loads `assets/data/scenes/[id].tres`
  via `ResourceLoader` + `as SceneData` cast**. Source: ADR-005 §4 + Key
  Interfaces.

### Forbidden Approaches

- **Never create or destroy card instances via `instantiate()` / `queue_free()`
  outside the Card Spawning System pool API** — other systems must go through
  the pool. — Source: ADR-002.

### Performance Guardrails

- **Card pool size = 30** is a safe ceiling for any scene; the game is designed
  around ~20 cards on screen maximum. — Source: ADR-002;
  `technical-preferences.md`.

---

## Feature Layer Rules

*Applies to: secondary mechanics — Mystery Unlock Tree, Hint System, Audio,
Settings, scene transition, final epilogue screen.*

### Required Patterns

- **`Hint System` reads `hint_stagnation_sec` from `SceneData.tres` per scene**
  — not from a separate config file. Source: ADR-005 GDD Requirements row for
  `hint-system.md`.
- **`MysteryUnlockTree` reads `mut-config.tres`, `epilogue-requirements.tres`,
  and (optional) `debug-config.tres`** via `ResourceLoader` + typed cast.
  Source: ADR-005 §3, §7.
- **`STUI` emits `epilogue_cover_ready` when the amber cover reaches full
  opacity** — FES waits on this signal before fading in. Source: ADR-004 §4.
- **`MUT` state transition (Active → Epilogue) occurs after both SM and
  SaveSystem have handled `scene_completed`** — step 2c of the epilogue
  handoff. Source: ADR-004 §4.

### Forbidden Approaches

- **Never make `FinalEpilogueScreen` its own autoload or rely on
  `change_scene_to_file` to reach it** — FES is pre-instanced as a sibling
  CanvasLayer in `gameplay.tscn` with its own `Armed → Loading → Ready` state
  machine. — Source: ADR-004 Alternatives 1 & 2 rejected.

---

## Presentation Layer Rules

*Applies to: rendering order, CanvasLayer stack, HUD visibility, UI composition.*

### Required Patterns

- **`gameplay.tscn` CanvasLayer stack (z-order bottom → top)**:
  - `CardTable` (Node2D, `z_index: 0`)
  - `HudLayer` (CanvasLayer, `layer = 5`) — StatusBarUI + SettingsTrigger
  - `TransitionLayer` (CanvasLayer, `layer = 10`) — SceneTransitionUI
  - `SettingsPanelHost` (CanvasLayer, `layer = 15`) — panel instantiated on
    gear press, `queue_free` on close
  - `EpilogueLayer` (CanvasLayer, `layer = 20`) — pre-instanced
    FinalEpilogueScreen in Armed state.
  Source: ADR-004 §2.
- **FinalEpilogueScreen is pre-instanced at scene build time in Armed state**
  (no rendering, transparent) — awaits `epilogue_cover_ready` before fading
  in above STUI. Source: ADR-004 §2, §4.
- **`HudLayer` hides itself on `epilogue_started`** so the gear icon cannot
  open Settings during the epilogue transition. Source: ADR-004 Risks row.
- **Card visuals use `Tween` via `create_tween()` + chained `tween_property()`**
  for all card motion — card positions are code-driven, not physics-simulated.
  Source: `technical-preferences.md` (Physics: Not used);
  `docs/engine-reference/godot/VERSION.md` (Tween usage note).

### Forbidden Approaches

- **Never change CanvasLayer ordering or layer numbers without a new ADR** —
  the layer stack enforces Settings-above-STUI and FES-above-everything.
  — Source: ADR-004 §2, Risks.

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Classes / Nodes | `PascalCase` | `CardVisual`, `StatusBarSystem` |
| Autoloads (singletons) | `PascalCase` | `EventBus`, `CardDatabase` |
| Variables / Functions | `snake_case` | `card_value`, `get_goal_config()` |
| Signals | `snake_case` | `bar_values_changed`, `hint_level_changed` |
| Files (`.gd` / `.tscn`) | `snake_case` | `card_visual.gd`, `status_bar_system.tscn` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_VALUE`, `SNAP_RADIUS`, `STAGNATION_SEC` |

Source: ADR-001; `technical-preferences.md` §Naming Conventions.

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60 fps |
| Frame budget | 16.7 ms |
| Draw calls | < 50 per frame |
| Memory ceiling | < 256 MB (desktop/Mac target) |

Source: `technical-preferences.md` §Performance Budgets.

### Testing

| Setting | Value |
|---------|-------|
| Framework | **gdUnit4** |
| Minimum coverage | Core gameplay systems (Card Engine, Status Bar System, Hint System) |
| Required tests | Card Engine state machine, bar math formulas, hint timer logic |

Source: `technical-preferences.md` §Testing (decision recorded 2026-04-21).

### Approved Libraries / Addons

- gdUnit4 — approved for testing framework (Godot addon).
- No other third-party addons approved.

Source: `technical-preferences.md` §Allowed Libraries / Addons.

### Forbidden APIs (Godot 4.3)

These APIs and patterns are deprecated. If an agent or contributor suggests
any item on the left, replace with the right-hand alternative.

**Nodes & classes**

| Forbidden | Use Instead | Deprecated Since |
|-----------|-------------|------------------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 |

**Methods & properties**

| Forbidden | Use Instead | Deprecated Since |
|-----------|-------------|------------------|
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` / `PackedScene.instance()` | `instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `Skeleton3D.bone_pose_updated` | `skeleton_updated` | 4.3 |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |

**Deprecated patterns**

| Forbidden | Use Instead |
|-----------|-------------|
| String-based `connect()` | Typed signal connections (`signal.connect(callable)`) |
| `$NodePath` inside `_process()` | `@onready var` cached reference |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables |

Source: `docs/engine-reference/godot/deprecated-apis.md`.

### Cross-Cutting Constraints

- **Doc comments on every public API** — all game code includes a doc comment
  on public methods and classes. Source: `.claude/docs/coding-standards.md`.
- **Every system has a corresponding ADR** in `docs/architecture/`. Source:
  `.claude/docs/coding-standards.md`.
- **Gameplay values are data-driven** — never hardcoded in `.gd` files; read
  from `.tres` per ADR-005. Source: `.claude/docs/coding-standards.md`.
- **Public methods are unit-testable** — prefer dependency injection over
  singletons for anything that must be mocked. Autoloads are acceptable for
  read-only queries; testable logic should not be trapped inside autoload
  state. Source: `.claude/docs/coding-standards.md`.
- **Determinism in tests** — no random seeds, no time-dependent assertions;
  fixtures come from constants or factory functions. Source:
  `CLAUDE.md` → Testing Standards.
- **CI gate**: automated tests run on every push to main and every PR; no
  merge if tests fail; never disable a failing test to make CI pass. Source:
  `CLAUDE.md` → Testing Standards.

---

## Manifest Maintenance

- Regenerate (`/create-control-manifest`) whenever a new ADR is Accepted or
  an existing ADR is revised.
- Bump `Last Updated` and `Manifest Version` on every regeneration — stories
  that embed an older version are flagged by `/story-readiness`.
- When a rule is removed, link the superseding ADR in place of the deletion
  rather than silently dropping the line.
