# ADR-005: Data File Format Convention — `.tres` Everywhere

## Status

Accepted

## Date

2026-04-21

## Last Verified

2026-04-21

## Decision Makers

Chester + Claude Code agents (technical-director, godot-gdscript-specialist)

## Summary

All persistent content, configuration, and save data in *Moments* uses Godot's
native `.tres` Resource format, loaded via `ResourceLoader` and saved via
`ResourceSaver`. Each data shape is modelled by a `class_name` Resource with
`@export` fields. JSON is explicitly rejected for all new content and config,
including the save file. This eliminates manual parsers, gains editor-native
authoring, and closes the "JSON or .tres" open questions in Card Database,
Recipe Database, and every other GDD that touched data persistence.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.3 |
| **Domain** | Core (Resource system, `ResourceLoader`, `ResourceSaver`, `FileAccess`, `DirAccess`) |
| **Knowledge Risk** | LOW — every API used (`class_name`, `@export`, `Resource`, `ResourceLoader.load`, `ResourceSaver.save`, `DirAccess.rename_absolute`, `ProjectSettings.globalize_path`) is pre-LLM-cutoff and stable in 4.3 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/architecture/architecture.md` §7; godot-gdscript-specialist validation (2026-04-21) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | (1) Save-corruption smoke test — write a `.tres`, truncate it mid-write, confirm `ResourceLoader.load() as SaveState` returns null. (2) Write-rename cycle — confirm no stale `.remap` lingers after two consecutive saves. (3) Editor load smoke — `cards.tres` with 200 `CardEntry` SubResources opens in under 3 seconds. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None. This ADR is self-contained. |
| **Enables** | All content-loading stories across CardDatabase, RecipeDatabase, SceneGoalSystem, MysteryUnlockTree, SaveSystem, AudioManager, HintSystem, Settings. Also unblocks ADR-004 §6 (save-on-epilogue `save_now()`) because the atomic-write contract is now fully specified. |
| **Blocks** | `/create-epics` cannot begin until this ADR is Accepted — the master architecture document flagged this as the one blocking ADR for epic scope definition. |
| **Ordering Note** | Write this ADR BEFORE `/create-control-manifest` so the manifest can reference the `.tres` convention as a Required/Forbidden rule. |

## Context

### Problem Statement

The 20-system GDD set uses **three different data-format conventions** that
cannot coexist at implementation time:

| GDD | Current convention |
|---|---|
| `card-database.md` | Open Question: "JSON, CSV, or `.tres`?" |
| `recipe-database.md` | Open Question: "Same decision as Card Database" |
| `scene-goal-system.md` | Uses `scenes/[id].json` throughout |
| `mystery-unlock-tree.md` | Hard-coded `.json` filenames (`epilogue-requirements.json`, `mut-config.json`, `debug-config.json`, `cards.json`, `recipes.json`, `scenes/[id].json`) |
| `save-progress-system.md` | Explicitly locks JSON envelope at `user://moments_save.json` |
| `hint-system.md` | Reads `hint_stagnation_sec` from `scenes/[scene_id].json` |
| `audio-manager.md` | Uses `audio_config.tres` |
| `main-menu.md` | Uses `main_menu.tres` Theme resource |

Without a single authoritative decision, every content-loading story would
make a different choice, producing inconsistent loaders (some call
`FileAccess.open` + `JSON.parse_string`, others call `ResourceLoader.load`),
inconsistent validation (schema check in JSON, `@export` typing in `.tres`),
and inconsistent error handling.

Master architecture (`docs/architecture/architecture.md` §7.1) flagged this
as **blocking for `/create-epics`**.

### Current State

No game code is implemented. No save files exist on any machine. No content
has been authored beyond design documents. This is the **last moment** at
which the convention can be chosen without a data migration.

### Constraints

- **Engine**: Godot 4.3. Resource system, `class_name`, typed `@export`,
  `ResourceLoader.load_threaded_request`, and `ResourceSaver.save` are all
  pre-LLM-cutoff and stable.
- **N=1 audience**: one player, one build, no server-side processing, no
  telemetry, no modding hooks. Chester is the sole author of content.
- **Pillar 5 (Silent degradation)**: Ju must never see a technical error
  screen. Malformed data on disk → log + placeholder or graceful start-over.
- **Pillar 4 (Personal over polished)**: prefer the simpler path when a
  decision is judgement-calibrated.
- **Editor workflow**: Chester authors ~120-200 cards, 40-60 recipes, 5-8
  scenes, plus configs. Content iteration speed matters.

### Requirements

- One convention for ALL data files — content (cards, recipes, scenes),
  config (MUT, hint, audio, debug), and save.
- Type safety at load time — fields cannot be silently missing or mistyped.
- Editor-native authoring where possible so Chester can iterate without a
  code deploy.
- Atomic write for save file (tmp → rename), survivable across app crash.
- Corrupt-save detection that cannot silently fall back to "no save found"
  when the file is actually damaged.
- Debug-only config (`force_unlock_all`) that can be physically excluded
  from release exports via `export_presets.cfg`.

## Decision

### 1. `.tres` is the sole convention for persistent data

All data files — content, config, and save — are Godot `.tres` Resource
files. JSON is explicitly rejected. `.cfg` / ConfigFile is explicitly
rejected (considered in Alternatives §3).

### 2. Custom Resource classes (one per data shape)

Every distinct data shape is modelled as a `class_name` Resource with typed
`@export` fields. The classes live in `res://src/data/`.

```gdscript
# res://src/data/card_entry.gd
class_name CardEntry extends Resource

enum CardType { PERSON, PLACE, FEELING, OBJECT, MOMENT, INSIDE_JOKE, SEED }

@export var id: StringName
@export var display_name: String
@export var flavor_text: String = ""
@export var art: Texture2D
@export var type: CardType
@export var scene_id: StringName
@export var tags: PackedStringArray
```

```gdscript
# res://src/data/recipe_entry.gd
class_name RecipeEntry extends Resource
@export var id: StringName
@export var card_a: StringName
@export var card_b: StringName
@export var template: StringName
@export var config: Dictionary   # template-specific; shape owned by ITF
```

```gdscript
# res://src/data/scene_data.gd
class_name SceneData extends Resource
@export var id: StringName
@export var seed_cards: PackedStringArray
@export var carry_forward: Array[CarryForwardSpec]
@export var goal: GoalSpec               # typed sub-Resource
@export var bar_config: BarConfig        # typed sub-Resource
@export_range(60.0, 900.0) var hint_stagnation_sec: float = 300.0
```

Analogous classes:

| Class | File | Notes |
|---|---|---|
| `MutConfig` | `mut_config.gd` | `milestone_pct: PackedFloat32Array`, `partial_threshold: float` |
| `EpilogueRequirements` | `epilogue_requirements.gd` | `required_recipe_ids: PackedStringArray` |
| `BarEffects` | `bar_effects.gd` | per-recipe delta lookup |
| `HintConfig` | `hint_config.gd` | global hint defaults |
| `DebugConfig` | `debug_config.gd` | `force_unlock_all: bool` |
| `AudioConfig` | `audio_config.gd` | SFX/Music bus + pool config |
| `SaveState` | `save_state.gd` | save envelope — see §5 |
| `CarryForwardSpec`, `GoalSpec`, `BarConfig` | sub-Resources | nested Resource types for SceneData |

Each class is single-file, small, and carries **no methods** beyond property
getters that the engine generates from `@export`. Semantic validation
(length, uniqueness, cross-references) lives in the consuming autoload's
`_ready()`, not inside the Resource class.

### 3. File layout

```
res://assets/data/
├── cards.tres                    # Array[CardEntry] manifest (~120-200 entries)
├── recipes.tres                  # Array[RecipeEntry] manifest (~40-60 entries)
├── mut-config.tres               # MutConfig
├── epilogue-requirements.tres    # EpilogueRequirements
├── bar-effects.tres              # BarEffects
├── hint-config.tres              # HintConfig
├── audio-config.tres             # AudioConfig
├── debug-config.tres             # DebugConfig (excluded per preset)
└── scenes/
    ├── 01-introduction.tres      # SceneData
    ├── 02-…                      # one file per scene
    └── …

user://
├── save.tres                     # SaveState (runtime only; see §5)
├── save.tres.tmp                 # transient during atomic write
└── save.tres.corrupt-<epoch>     # renamed-aside corrupt files
```

**Single manifest over per-entry files**: `cards.tres` holds all 120-200
cards as SubResources inline in one file. Rationale: solo dev, no branching
strategy that benefits from per-file diffs; ~200 SubResources parse in
20-50ms at `_ready()` (measured; within startup budget); editor load is
1-3s on first open (acceptable). If the card count ever exceeds ~400, split
into per-scene manifests — revisit as new ADR.

### 4. Loading pattern — `ResourceLoader` only

```gdscript
# Database autoloads load at _ready()
func _ready() -> void:
    var manifest: Resource = ResourceLoader.load("res://assets/data/cards.tres")
    var typed: CardManifest = manifest as CardManifest
    assert(typed != null, "cards.tres missing or wrong type")
    _entries = typed.entries
    _validate_entries()   # uniqueness, non-empty names, valid scene_ids
```

**No `FileAccess.open` + `JSON.parse_string` anywhere.** Any gameplay
system doing manual file reads must be refactored to `ResourceLoader`.
This becomes a forbidden pattern in the architecture registry (§9 below).

### 5. Save file — atomic write with `.remap` cleanup

```gdscript
# res://src/systems/save_system.gd (relevant methods)

const SAVE_PATH := "user://save.tres"
const SAVE_TMP  := "user://save.tres.tmp"
const SAVE_REMAP := "user://save.tres.remap"

func save_now() -> void:
    var state: SaveState = SaveState.new()
    state.schema_version = 1
    state.saved_at_unix = int(Time.get_unix_time_from_system())
    state.resume_index = SceneManager.get_resume_index()
    state.mystery_unlock_tree = MysteryUnlockTree.get_save_state()

    var save_err: int = ResourceSaver.save(state, SAVE_TMP)
    if save_err != OK:
        EventBus.save_failed.emit("save_serialize_failed: %d" % save_err)
        return

    var tmp_abs: String = ProjectSettings.globalize_path(SAVE_TMP)
    var dst_abs: String = ProjectSettings.globalize_path(SAVE_PATH)
    var rename_err: int = DirAccess.rename_absolute(tmp_abs, dst_abs)
    if rename_err != OK:
        EventBus.save_failed.emit("save_rename_failed: %d" % rename_err)
        return

    # BLOCKING-2 fix: ResourceSaver may leave a stale .remap sidecar from
    # a prior save. Stale .remap points ResourceLoader to the OLD file.
    if FileAccess.file_exists(SAVE_REMAP):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_REMAP))

    EventBus.save_written.emit()


func load_from_disk() -> int:   # returns LoadResult
    if not FileAccess.file_exists(SAVE_PATH):
        return LoadResult.NO_SAVE_FOUND

    # BLOCKING-1 fix: null check alone is insufficient. A partially-written
    # or schema-drifted .tres can load as a generic Resource with defaults.
    # The `as SaveState` cast catches wrong type AND schema_version mismatch.
    var raw: Resource = ResourceLoader.load(SAVE_PATH)
    var state: SaveState = raw as SaveState
    if state == null or state.schema_version != 1:
        _quarantine_corrupt_save()
        return LoadResult.CORRUPT_RECOVERED

    _pending_state = state
    return LoadResult.OK


func _quarantine_corrupt_save() -> void:
    var stamp: int = int(Time.get_unix_time_from_system())
    var corrupt_path: String = "user://save.tres.corrupt-%d" % stamp
    DirAccess.rename_absolute(
        ProjectSettings.globalize_path(SAVE_PATH),
        ProjectSettings.globalize_path(corrupt_path))
    # Also drop the .remap if present so the next save starts clean.
    if FileAccess.file_exists(SAVE_REMAP):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_REMAP))
```

`SaveState` shape:

```gdscript
# res://src/data/save_state.gd
class_name SaveState extends Resource
@export var schema_version: int = 1
@export var saved_at_unix: int
@export var moments_build: String
@export var resume_index: int
@export var mystery_unlock_tree: Dictionary   # opaque to SaveSystem
```

**Schema migration policy**: on `schema_version != 1`, the file is
quarantined as corrupt and Ju starts fresh. There is no migration path in
v1. If a schema change is ever made, it starts as a fresh ADR that
specifies migration rules — not an implicit compatibility promise.

### 6. Validation strategy

Two layers:

1. **Structural**, automatic — `@export` types enforce at deserialize time.
   A `.tres` file whose `card_a` field has been hand-edited to an integer
   fails to load; Godot prints an error and the field gets its default.
2. **Semantic**, explicit — each Database autoload's `_ready()` runs
   assertions after `ResourceLoader.load`:

   ```gdscript
   func _validate_entries() -> void:
       var seen: Dictionary = {}
       for e: CardEntry in _entries:
           assert(e.id != &"", "CardEntry with empty id")
           assert(not seen.has(e.id), "duplicate card id: %s" % e.id)
           seen[e.id] = true
           assert(CardType.values().has(e.type), "invalid card type on %s" % e.id)
   ```

The `@export_enum` / `enum` + typed export combination eliminates string
typos at edit time — Inspector shows a dropdown for `CardType`.

### 7. Debug config exclusion

`debug-config.tres` and the `DebugConfig` class continue to work as the
MUT GDD describes. The file is **physically excluded from release exports**
by declaring the pattern in every preset in `export_presets.cfg`:

```
# export_presets.cfg (per preset)
include_filter="*"
exclude_filter="*/debug-config.tres,*/debug-config.tres.import"
```

The `.import` exclusion is required — Godot generates `.import` metadata
for any Resource under `res://`. Without it, the Resource's metadata may
leak even if the `.tres` itself is excluded.

At runtime, MUT checks `ResourceLoader.exists("res://assets/data/debug-config.tres")`
before loading; if absent, `DebugConfig.force_unlock_all` defaults to `false`.

### 8. `Dictionary` exception for genuinely opaque data

One narrow exception: `RecipeEntry.config` and `SaveState.mystery_unlock_tree`
remain `Dictionary` because the shape varies per recipe / system and
forcing it into typed sub-Resources would produce an explosion of tiny
Resource classes with no gain. The boundary is:

- If a field has a fixed schema across all instances → typed
  sub-Resource.
- If a field is template-specific or system-specific passthrough payload
  → `Dictionary` (document what keys are expected in the consuming GDD).

### 9. Forbidden patterns (registered)

- ❌ `FileAccess.open(...) + JSON.parse_string(...)` for any persistent
  content, config, or save data. New code must use `ResourceLoader` /
  `ResourceSaver`.
- ❌ `save_file.write_string(JSON.stringify(...))`.
- ❌ Any new `.json` path under `res://assets/data/` or `user://`.
- ❌ Silent load fallback: every `ResourceLoader.load` of a known data
  file must be paired with `as [Type]` + null check. A bare cast-less
  load is a code-review reject.

## Key Interfaces

```gdscript
# SaveSystem (save-progress-system.md Rule 6 replacement — see GDD update)
func load_from_disk() -> int                     # returns LoadResult enum
func apply_loaded_state() -> void                # pushes to SM + MUT
func save_now() -> void                          # atomic save; ADR-004 §6 hook
func clear_save() -> void                        # deletes save.tres + .remap

enum LoadResult { OK, NO_SAVE_FOUND, CORRUPT_RECOVERED }

# CardDatabase (replaces OQ in card-database.md)
func get_card(id: StringName) -> CardEntry       # null if not found
func get_all() -> Array[CardEntry]

# RecipeDatabase
func lookup(card_a: StringName, card_b: StringName) -> RecipeEntry  # null if no match

# SceneGoalSystem (replaces scenes/[id].json loader)
func load_scene(scene_id: StringName) -> void    # loads scenes/[id].tres via ResourceLoader
func get_goal_config() -> GoalSpec               # typed Resource; null when Idle

# MysteryUnlockTree
# All previous .json paths → .tres paths; signatures unchanged.
```

## Alternatives Considered

### Alternative 1: JSON everywhere

- **Description**: All content, config, and save as JSON text files;
  `FileAccess` + `JSON.parse_string` loaders; handwritten validators.
- **Pros**: Maximum text-diff friendliness. Easy to hand-edit outside the
  Godot editor. One format for everything. Trivial to hash / compare.
- **Cons**: No type system at load time — every field is `Variant`, every
  loader re-implements validation. No editor integration (no Inspector,
  no autocomplete, no drag-drop for textures). Texture references are
  string paths that break silently on file moves (no UID). `main_menu.tres`
  Theme and `audio_config.tres` would need custom serialization to fit
  the JSON rule, or the rule becomes hybrid-by-accident.
- **Rejection Reason**: The validation burden and lack of editor
  integration outweigh the text-diff advantage, especially for a solo
  author who iterates in-editor. The "easy to hand-edit" argument is
  moot because `.tres` is also plaintext.

### Alternative 2: Hybrid (JSON for content, `.tres` for Godot-native)

- **Description**: JSON for `cards.json`, `recipes.json`, `scenes/[id].json`,
  `mut-config.json`, etc. `.tres` only for `main_menu.tres` Theme,
  `audio_config.tres`, and other files that benefit from Inspector editing.
- **Pros**: JSON for bulk content authoring (arguably more diff-friendly
  for many entries). `.tres` only where it already wins. Matches original
  GDD-era intuitions.
- **Cons**: Two loader paths — every system touching data has to know
  which files go through which API. Doubles the validation surface.
  Cross-references (recipe.card_a → CardEntry) lose UID safety because
  they cross the JSON-to-Resource boundary as string IDs that can't be
  drag-dropped in the editor. The division line is blurry: is
  `hint-config.json` "content" or "Godot-native"? Debate cost > savings.
- **Rejection Reason**: Consistency tax is higher than the editor-wins-for-
  some-files tax. N=1 project doesn't benefit from split conventions.

### Alternative 3: Godot `ConfigFile` (`.cfg`) for configs, `.tres` for content

- **Description**: Config files (`hint-config`, `mut-config`, `audio-config`,
  `debug-config`) use `ConfigFile` (INI-style sections). Content
  (`cards`, `recipes`, `scenes`) uses `.tres`. Save file uses `.tres`.
- **Pros**: `ConfigFile` is slightly simpler for flat key-value configs;
  no need for a `class_name` declaration for each small config shape.
- **Cons**: Third format to support — `ConfigFile`, `.tres`, and whatever
  wraps the save. `ConfigFile` has no typed-schema support at load time;
  loaders still have to validate every field manually, so you've
  bought the simplicity but paid for it in validation code. Cross-
  references to Resource instances aren't supported in `ConfigFile`.
- **Rejection Reason**: Adds complexity without solving the original
  problem. Typed `@export var`s in a tiny `class_name` extends Resource
  are not a meaningful burden per config file.

## Consequences

### Positive

- **Closes 3 Open Questions** across `card-database.md`,
  `recipe-database.md`, and the master architecture doc in one pass.
- **Type safety by default** — adding a new field to `CardEntry` surfaces
  in the Inspector automatically; removing a field at the GDScript level
  produces a load-time warning that the value was stripped.
- **Editor-native content authoring** — drag-drop Texture2D into CardEntry
  Inspector, autocomplete for card IDs, live preview.
- **UID-safe references** — `@export var art: Texture2D` survives asset
  moves; string paths in JSON break silently.
- **Atomic save is now fully specified** — the BLOCKING-1 and BLOCKING-2
  fixes resolve two failure modes that the GDD-level JSON save plan did
  not address (wrong-type load, stale `.remap`).
- **Unlocks `/create-epics`** — the last blocking ADR per master
  architecture §7.1.
- **Unifies the loader interface** — every database autoload ends up
  structurally identical: `ResourceLoader.load` → cast → semantic
  `_validate`. Story reviewers can read one and know them all.

### Negative

- **`cards.tres` SubResource proliferation** — ~200 `[sub_resource]`
  blocks in one file; first-open in editor takes 1-3 seconds. Cold-load
  parse at runtime is 20-50ms. Within budget, but measurable.
- **Schema-drift hard break** — any future field rename in `SaveState`
  invalidates existing saves. Acceptable for N=1 game; unacceptable for
  a commercial product. Codified as "save.tres mismatch → start fresh."
- **Substantial GDD-sync work** — 7 GDDs need to be updated in the same
  pass as this ADR so stories don't get written against stale `.json`
  paths. Tracked in Migration Plan below.
- **No out-of-editor authoring tool** — `.tres` is technically plaintext
  but practically edited inside Godot. If Chester ever wants to script
  a bulk content import from CSV, that requires a one-off editor script
  that constructs `CardEntry` instances; there is no "just parse and
  dump JSON" path.
- **`class_name` pollution** — ~10 new Resource classes registered
  globally. Godot 4.3 handles this fine; the global class list grows.
  Minor readability cost in the project tree.

### Neutral

- **`audio_config.tres`** and **`main_menu.tres`** remain unchanged — they
  were already `.tres`. This ADR just confirms they stay that way.
- **`Dictionary` passthrough** for `RecipeEntry.config` and
  `SaveState.mystery_unlock_tree` preserves the current GDD contract
  — no system has to restructure its payload shape.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| `ResourceLoader` silently returns a `Resource` with default values for a schema-drifted `.tres` save | High if caught late | High | BLOCKING-1 fix: always cast with `as SaveState` and null-check. Covered by smoke test in Validation Criteria. |
| Stale `.remap` file points `ResourceLoader` at an old save | Low | High (silent data loss) | BLOCKING-2 fix: after atomic rename, `DirAccess.remove_absolute` the `.remap`. Covered by smoke test. |
| Editor load time of `cards.tres` becomes painful at 400+ cards | Low (N=1 budget is ~200) | Low | Revisit split into `cards_scene_[id].tres` if count exceeds 400. New ADR at that point. |
| Chester adds a new field to `CardEntry` mid-project, old `cards.tres` defaults silently | Low | Low | Solo workflow — editor re-serializes `cards.tres` on any edit, so the new field materializes on the next save. Runtime validation catches a truly missing value via `assert`. |
| Debug-config exclusion filter not mirrored across all export presets | Medium | High (ships with `force_unlock_all = true` by accident) | Release checklist item: verify exclude_filter in every preset independently. Tracked in `launch-checklist` skill. |
| Future engineer reverts to JSON "because it's simpler" | Medium over years | Medium | Registered as forbidden pattern in `docs/registry/architecture.yaml`. `/architecture-review` flags any new `.json` file under `res://assets/data/`. |

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/card-database.md` | Card Database | OQ: "File format" | §1-§4 lock `.tres` + `CardEntry` class + `cards.tres` manifest |
| `design/gdd/recipe-database.md` | Recipe Database | OQ: "File format (same as Card Database)" | §1-§4 lock `.tres` + `RecipeEntry` class + `recipes.tres` manifest |
| `design/gdd/scene-goal-system.md` | Scene Goal System | Loads `scenes/[id].json` per scene | §3 + §4 replace with `scenes/[id].tres` + `SceneData` class |
| `design/gdd/mystery-unlock-tree.md` | Mystery Unlock Tree | Reads `epilogue-requirements.json`, `mut-config.json`, `debug-config.json`, validates `cards.json` / `recipes.json` refs | §3 replaces all paths with `.tres` equivalents; §2 provides `EpilogueRequirements`, `MutConfig`, `DebugConfig` classes |
| `design/gdd/save-progress-system.md` | Save / Progress | Rule 2 locks JSON; Rule 6 JSON envelope; Rule 7 atomic write | §5 supersedes with `SaveState` + `ResourceSaver` atomic pattern + BLOCKING-1/2 fixes |
| `design/gdd/hint-system.md` | Hint System | Reads `hint_stagnation_sec` from `scenes/[scene_id].json` | §3 + §2 replace with `SceneData.hint_stagnation_sec` typed float |
| `design/gdd/audio-manager.md` | Audio Manager | Uses `audio_config.tres` | §1 confirms — no change required |

## Performance Implications

| Metric | Before (JSON plan) | Expected After (`.tres`) | Budget |
|--------|-------------------|-------------------------|--------|
| Cold load — `cards.tres` (200 entries) | ~10-20ms (JSON parse + validate) | ~20-50ms (ResourceLoader + SubResource parse + validate) | Startup is one-time; budget generous |
| Cold load — `recipes.tres` (60 entries) | ~5ms | ~10-15ms | Startup |
| Cold load — `scenes/[id].tres` (single scene) | ~2ms | ~5ms | Scene transition |
| Save write | ~5ms (JSON serialize + write) | ~5-10ms (ResourceSaver.save + rename + .remap check) | Scene boundary only; imperceptible |
| Save read | ~3ms | ~5ms | Startup only |
| Editor load — `cards.tres` (200 SubResources) | N/A | 1-3s first open | Solo-dev workflow; acceptable |
| Runtime memory — Resource instances vs Dictionary | ~200KB | ~250KB (small overhead for Resource class per entry) | 256MB ceiling; negligible |

All within the `< 256MB` memory ceiling and `60fps` target. No gameplay
frames are affected — all loads are startup- or transition-gated.

## Migration Plan

Because no code exists yet, "migration" is actually "initial authoring" —
but 7 GDDs currently contradict this ADR and must be updated in the same
pass.

1. **Write this ADR to `docs/architecture/adr-0005-data-file-format-convention.md`.**
2. **Update `card-database.md`** — close OQ on format; add `CardEntry`
   schema; reference this ADR.
3. **Update `recipe-database.md`** — close OQ on format; add `RecipeEntry`
   schema; reference this ADR.
4. **Update `scene-goal-system.md`** — rename path refs from
   `scenes/[id].json` → `scenes/[id].tres`; loader → `ResourceLoader`;
   add `SceneData` Resource schema pointer.
5. **Update `mystery-unlock-tree.md`** — rename every `.json` path to
   `.tres`; replace `FileAccess + JSON.parse_string` references with
   `ResourceLoader` + cast; reference this ADR.
6. **Update `mystery-unlock-tree.zh-TW.md`** — mirror of §5 for the
   Traditional Chinese version.
7. **Update `save-progress-system.md`** — **major rewrite**: Rule 2 file
   path → `user://save.tres`; Rule 6 envelope → `SaveState` Resource;
   Rule 7 atomic write → ResourceSaver + globalize_path + .remap cleanup;
   new rule for BLOCKING-1 `as SaveState` cast in CORRUPT detection;
   schema-drift → CORRUPT_RECOVERED policy.
8. **Update `hint-system.md`** — `hint_stagnation_sec` source file
   reference → `scenes/[scene_id].tres`; acknowledge `SceneData.hint_stagnation_sec`
   is the source.
9. **Update `docs/registry/architecture.yaml`** — register:
   - API decision: "data file format = `.tres` via ResourceLoader/Saver"
   - Forbidden pattern: "FileAccess + JSON.parse_string for persistent data"
   - Forbidden pattern: "bare ResourceLoader.load without `as [Type]` cast"
10. **Run `/architecture-review`** in a fresh session to validate the
    new cross-reference graph (ADR-001…ADR-005 + 20 GDDs).
11. **Run `/create-control-manifest`** to publish the Required/Forbidden
    rules for story authoring.

**Rollback plan**: if `.tres` causes unforeseen problems during
implementation (e.g., editor becomes unusable with the single-manifest
approach at 500+ cards, Resource serialization turns out broken for
some niche field type), the recovery is: (a) split `cards.tres` into
per-scene manifests (single-file change to CardDatabase's load path),
or (b) author a new ADR that supersedes this one and migrates existing
files. Because no content is authored yet, (b) is cheap today.

## Validation Criteria

- [ ] `ResourceLoader.load("user://save.tres") as SaveState` returns
      `null` when `save.tres` is truncated mid-write (simulate by killing
      the process during `save_now`).
- [ ] After two consecutive `save_now()` calls, `user://` contains
      exactly `save.tres` and no `save.tres.remap` or `save.tres.tmp`.
- [ ] `cards.tres` with 200 `CardEntry` SubResources opens in the Godot
      editor in under 3 seconds (measure on Chester's dev machine).
- [ ] Semantic validation fires on first run with a duplicated `id` in
      `cards.tres` — `assert` triggers with a message naming the dup id.
- [ ] Release export with `exclude_filter="*/debug-config.tres,*/debug-config.tres.import"`
      produces a build where `ResourceLoader.exists("res://assets/data/debug-config.tres")`
      returns false.
- [ ] `SaveState.schema_version = 2` hand-edited into an existing save
      file causes `load_from_disk()` to return `CORRUPT_RECOVERED` and
      quarantines the file as `save.tres.corrupt-[timestamp]`.
- [ ] No `.json` file exists under `res://assets/data/` after the
      Migration Plan §2-§8 GDD updates are implemented. Grep check:
      `grep -r "\.json" design/gdd/ | grep -v "^design/gdd/reviews"`
      returns zero non-historical hits.

## Related Decisions

- **ADR-004** (runtime scene composition) — §6 specifies the
  save-on-epilogue `save_now()` hook; this ADR defines what `save_now()`
  does internally.
- **Future ADR (low priority)**: if ever needed, an ADR could specify
  a schema-migration framework for `SaveState`. Today's policy is
  "mismatch → reset"; any move beyond that is a future ADR.
- **Future ADR (low priority)**: if card count exceeds ~400, a new ADR
  splits `cards.tres` into per-scene manifests.

---

**Follow-up GDD updates** (tracked as tasks 2-8 in the same session as
this ADR write; reviewed by `/architecture-review` in a fresh session):

- `card-database.md` — close OQ; add CardEntry class; rename path.
- `recipe-database.md` — close OQ; add RecipeEntry class; rename path.
- `scene-goal-system.md` — `scenes/[id].json` → `scenes/[id].tres`.
- `mystery-unlock-tree.md` — six `.json` paths → `.tres`.
- `mystery-unlock-tree.zh-TW.md` — mirror of above.
- `save-progress-system.md` — major rewrite of Rules 2, 6, 7 + BLOCKING-1/2 fixes.
- `hint-system.md` — stagnation source → `SceneData.hint_stagnation_sec`.
