# Save / Progress System

> **Status**: In Design
> **Author**: Chester + Claude Code agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: Indirect — supports Pillar 3 (Discovery Without Explanation) by removing "where was I?" friction across sessions

## Overview

Save / Progress System is the Persistence-layer autoload singleton that preserves what Ju has seen across sessions. It serializes two pieces of state on every scene completion: the next scene index owned by Scene Manager, and the full discovery dictionary owned by Mystery Unlock Tree. When the game launches, Save / Progress loads the file from disk (if present) and injects the restored state into Scene Manager and Mystery Unlock Tree *before* Main Menu's Start button emits `game_start_requested`, so the first chapter that appears is the one Ju left on — not scene 0.

The system is intentionally narrow. It owns file I/O, schema versioning, corruption recovery, and load-sequence orchestration. It does **not** own any gameplay state itself — every field written to disk belongs to another system and is fetched through a query method (`MUT.get_save_state()`, `SceneManager.get_resume_index()`). This keeps the serialization contract flat: one `Dictionary` in, one JSON file out, one Dictionary back.

The save format is a single JSON file at `user://moments_save.json`. Single slot, human-readable, Chester-debuggable. Corruption is handled by renaming the bad file to `moments_save.json.corrupt.<timestamp>` and starting fresh — Ju never sees a technical error screen.

## Player Fantasy

Ju closes her laptop in the middle of the week, comes back on Saturday, and the game is exactly where she left it — the same chapter, the same cards she had discovered, the same shape of the story so far. There is no "continue or new game?" screen. There is no slot picker. She presses Start; the world she left re-appears.

The fantasy is absence-of-friction. A scrapbook doesn't ask which page you were on — it falls open to where the ribbon is. Save / Progress is the ribbon. Its success is measured in the player *not noticing it exists* — no loading spinner longer than a frame, no dialog, no interruption to the emotional continuity of the story.

If the save file is damaged (disk hiccup, OS quirk, laptop crash mid-write), the game quietly backs it up and starts fresh. Ju may re-discover a chapter, but she will never see a red error screen that breaks the tone of the gift. Silent resilience over technical honesty — this is a love letter, not a SaaS product.

## Detailed Design

### Core Rules

**1. SaveSystem is an autoload singleton** registered as `SaveSystem` in project autoloads. Autoload order is specified canonically in `docs/architecture/ADR-004-runtime-scene-composition.md` §1; SaveSystem is position 12 of 12 (last), so it can call into every other autoload during `apply_loaded_state()`.

**2. Single canonical save file.** Path: `user://moments_save.json`. One file per install. No slot selection. JSON format, UTF-8 encoded, pretty-printed (indent=2) for Chester-side debuggability.

**3. Save trigger is `scene_completed` + `final_memory_ready`.** SaveSystem subscribes to two signals:
- `EventBus.scene_completed(scene_id)` — fires on every chapter completion. Writes one save per chapter.
- `EventBus.final_memory_ready()` — fires from MUT when the epilogue condition is met mid-epilogue. Since SM's Epilogue state is terminal (no further `scene_completed`), this second hook ensures the saved state captures MUT's `_final_memory_earned` = true. Without it, a crash/quit during the Epilogue fade would leave the final-memory flag unpersisted and the next session would replay the epilogue setup instead of going straight to Epilogue.

Mid-scene state (partial bar values, cards currently on the table, in-flight Interaction Template animations) is **never** persisted. The chapter is the save boundary. `final_memory_ready` handling uses the same `save_now()` code path as the `scene_completed` handler — one write, atomic, idempotent.

**Listener-ordering contract (per ADR-004 §5)**: both SaveSystem and SceneManager listen to `scene_completed`. Because autoload order places SaveSystem AFTER SceneManager, SM's handler runs FIRST and completes its increment (`_current_index += 1`) before SaveSystem's handler calls `SceneManager.get_resume_index()`. The save therefore captures the post-increment value — the index of the *next* chapter to play, not the just-completed one. Do NOT reorder these autoloads without updating ADR-004.

**4. Load happens once, during startup, before `game_start_requested`.** The canonical startup sequence:
1. All autoloads complete `_ready()`. SaveSystem's own `_ready()` does NOT auto-load — it only prepares state. Main Menu is the project's `run/main_scene` and renders.
2. The player presses Start. Main Menu calls `get_tree().change_scene_to_file("res://src/scenes/gameplay.tscn")` per its own GDD (Main Menu Rule 4). Main Menu never touches SaveSystem — this preserves Main Menu Rule 6 (No Game-State Coupling).
3. `gameplay.tscn`'s root script `_ready()` runs after its children are ready. This root script is the save-load orchestrator. It performs, in strict order:
   a. `var result = SaveSystem.load_from_disk()` (synchronous — returns `LoadResult` enum).
   b. If `result == LoadResult.OK`: `SaveSystem.apply_loaded_state()`. SaveSystem pushes state into downstream systems via direct query/setter calls:
      - `SceneManager.set_resume_index(saved_index)` — new public method on SM
      - `MysteryUnlockTree.load_save_state(saved_dict)` — already exists per MUT GDD
   c. If `result == LoadResult.NO_SAVE_FOUND` or `LoadResult.CORRUPT_RECOVERED`: skip `apply_loaded_state()`. SM and MUT keep their defaults (SM at index 0, MUT empty).
   d. Emit `EventBus.game_start_requested()`.
4. Scene Manager's `CONNECT_ONE_SHOT` handler fires; it reads its own `_current_index` (now set to the saved value, or still 0) and calls `_load_scene_at_index(_current_index)`.

This ordering resolves Scene Manager OQ-1: `gameplay.tscn`'s root script (`gameplay_root.gd`, specified in ADR-004 §3) orchestrates; SaveSystem exposes the load/apply API; SM exposes a setter; resume is explicit, not magic. The orchestration lives in `gameplay.tscn`'s root because that script owns the `game_start_requested` emission per ADR-004 §3, making SaveSystem's calls a natural pre-emit step.

`gameplay_root.gd` additionally connects `EventBus.final_memory_ready → SaveSystem.save_now()` (per ADR-004 §6) so that the final-memory state is persisted in Epilogue, where no further `scene_completed` will fire.

**5. Save content is authoritative from source systems.** SaveSystem does not cache gameplay state. On save, it queries:
- `SceneManager.get_resume_index() -> int` — the index of the **next** scene to play after the just-completed chapter. This is `_current_index` post-increment (see SM Rule 4 step 5). New public method on SM.
- `MysteryUnlockTree.get_save_state() -> Dictionary` — full discovery snapshot. Already exists per MUT GDD.

Source systems own their serialization format. SaveSystem wraps them in an envelope.

**6. Save envelope schema (version 1).**

```json
{
  "schema_version": 1,
  "saved_at_unix": 1744000000,
  "moments_build": "0.1.0",
  "scene": {
    "resume_index": 2
  },
  "mystery_unlock_tree": { /* opaque to SaveSystem — whatever MUT.get_save_state() returns */ }
}
```

`schema_version` is the migration key. `saved_at_unix` and `moments_build` are diagnostic only — never gate behavior on them. `scene.resume_index` is the integer SM resumes from. `mystery_unlock_tree` is passed through unread.

**7. Atomic writes.** Every save follows tmp-then-rename to prevent corruption from mid-write crashes:
1. Serialize the Dictionary to a JSON string.
2. Open `user://moments_save.json.tmp` for write, write all bytes, close.
3. `DirAccess.rename_absolute()` from `.tmp` to `moments_save.json`. Rename is atomic on all target filesystems (APFS/NTFS/ext4).
4. On any step failing, log the error, leave the previous good file untouched, and emit `EventBus.save_failed(reason)` for debug logging. Do NOT block gameplay — the next scene completion will retry.

**8. Corruption recovery.** On load, if JSON parsing fails OR `schema_version` is missing OR the envelope fails validation (required keys missing):
1. Rename the bad file to `user://moments_save.json.corrupt.<iso8601-timestamp>` (e.g., `moments_save.json.corrupt.2026-04-21T14-32-01`). Colons are replaced with dashes for cross-platform filename safety.
2. Log a loud error with the reason (parse error, missing key, etc.).
3. Return `LoadResult.CORRUPT_RECOVERED` — caller (Main Menu) treats this identically to `NO_SAVE_FOUND` (start fresh from index 0).
4. The backup is never read automatically — it exists only for Chester-side post-mortem.

**9. Schema migration.** If `schema_version < CURRENT_SCHEMA_VERSION` (currently 1), SaveSystem runs a migration chain: `_migrate_v1_to_v2(data)`, `_migrate_v2_to_v3(data)`, etc. Each migration is an internal function that takes a Dictionary and returns a Dictionary. If `schema_version > CURRENT_SCHEMA_VERSION` (save from a newer build), treat as corrupt (rule 8). At v1 there are no migrations — the chain is empty. The structure exists so Alpha+Full Vision expansions (e.g., Settings persistence) can be added without breaking existing saves.

**10. New-game reset.** `SaveSystem.clear_save()`:
1. Calls `SceneManager.reset_to_waiting()` FIRST (clears cards, resets SM state machine, re-arms `CONNECT_ONE_SHOT`). This step brings SM back to a state where `set_resume_index()` is legal.
2. Calls `SceneManager.set_resume_index(0)`.
3. Calls `MysteryUnlockTree.load_save_state({})` — MUT accepts empty dict as clean-wipe equivalent (clears discoveries and the `_epilogue_conditions_emitted` flag).
4. Deletes `user://moments_save.json` from disk (if present).
5. Emits `EventBus.save_written()` for observability (the save file is now authoritatively empty/absent).

Exposed to the player via Settings' Reset Progress button (see `design/gdd/settings.md` Rule 6). The call ordering in this rule is intentional: `reset_to_waiting()` before `set_resume_index()` ensures the `set_resume_index` assertion (`_state == WAITING`) does not fire.

**10b. Synchronous save-now for the epilogue hook.** `SaveSystem.save_now()` performs the same atomic-write sequence as the `scene_completed` handler, invoked directly rather than via signal. Used by `gameplay_root.gd`'s `final_memory_ready` listener (per ADR-004 §6). Same failure semantics: on disk failure, emits `save_failed(reason)`, does not block.

**11. No in-memory save cache.** SaveSystem does not hold a copy of the last-saved Dictionary after `load_from_disk()` + `apply_loaded_state()` complete. The downstream systems own their state. On next `scene_completed`, SaveSystem re-queries sources. This prevents the cache from drifting out of sync with the actual runtime state.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `Idle` | `_ready()` completes | `load_from_disk()` called | No file I/O happening; ready to load or save |
| `Loading` | `load_from_disk()` called | Load completes (any LoadResult) | Reading + parsing JSON; blocks on synchronous I/O |
| `LoadedReady` | Valid save parsed, `apply_loaded_state()` pending | `apply_loaded_state()` called | Holds parsed dict in temporary buffer; waiting for Main Menu to request application |
| `Active` | `apply_loaded_state()` completes OR no save existed | Never — runtime steady state | Listening for `scene_completed`; save on each emission |
| `Saving` | `scene_completed` received while `Active` | Write finishes (success or fail) | Writing tmp + rename; `Active` re-entered after |

**Transitions:**
- `Idle → Loading`: `load_from_disk()` invoked by Main Menu.
- `Loading → LoadedReady`: Parse succeeded, `LoadResult.OK` returned.
- `Loading → Active`: No file OR corruption recovered. `LoadResult.NO_SAVE_FOUND` or `LoadResult.CORRUPT_RECOVERED` returned. Downstream systems stay at defaults.
- `LoadedReady → Active`: `apply_loaded_state()` pushed state into SM + MUT; temporary buffer discarded.
- `Active → Saving`: `scene_completed` received.
- `Saving → Active`: Write complete (or failed — gameplay continues either way).

`Active` is the steady state during gameplay. The save→Active cycle fires once per chapter.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Scene Manager** | SaveSystem → SM (calls) | `SceneManager.get_resume_index() -> int` during save; `SceneManager.set_resume_index(index: int)` during `apply_loaded_state()`. Both are new public methods added to SM (see post-design updates). |
| **Mystery Unlock Tree** | SaveSystem → MUT (calls) | `MUT.get_save_state() -> Dictionary` during save; `MUT.load_save_state(data: Dictionary)` during `apply_loaded_state()`. Both already specified in MUT GDD. |
| **`gameplay.tscn` root script** | gameplay.tscn root → SaveSystem (calls) | On its `_ready()` (after children ready, before emitting `game_start_requested`): (1) `SaveSystem.load_from_disk() -> LoadResult`, (2) if OK → `SaveSystem.apply_loaded_state()`, (3) emit `EventBus.game_start_requested()`. The gameplay-scene root script is the orchestrator — Main Menu remains save-agnostic per its own Rule 6. |
| **Main Menu** | No direct coupling | Main Menu does not call SaveSystem. The scene switch to `gameplay.tscn` is Main Menu's sole responsibility; orchestration happens in the target scene's root script. |
| **EventBus** (ADR-003) | SaveSystem listens + emits | Listens to `scene_completed(scene_id: String)` and `final_memory_ready()` in Active state only. Emits `save_written()` and `save_failed(reason: String)` for debug/telemetry. Listener ordering vs SceneManager is locked by autoload order per ADR-004 §5 — SM's `scene_completed` handler runs before SaveSystem's. |
| **Final Epilogue Screen** (indirect) | SaveSystem writes during the last `scene_completed` before Epilogue | Epilogue consumes MUT state directly; SaveSystem ensures MUT state is persisted on the last chapter completion before Epilogue triggers. |
| **Filesystem** (Godot `FileAccess` / `DirAccess`) | SaveSystem → OS | Writes `user://moments_save.json` + `.tmp`; renames corrupt files with timestamp suffix. All paths resolve through Godot's `user://` protocol for cross-platform safety. |

## Formulas

Save / Progress System performs no gameplay calculations. It serializes and deserializes — every number it handles is owned by another GDD. The "formulas" here are the serialization contract: how a runtime Dictionary becomes JSON bytes, and how JSON bytes become a runtime Dictionary.

### Save Envelope (v1)

The envelope is a strict Dictionary schema:

```
save_dict = {
    "schema_version":       int,          # always 1 at MVP
    "saved_at_unix":        int,          # Time.get_unix_time_from_system() at write
    "moments_build":        String,       # ProjectSettings.get_setting("application/config/version")
    "scene": {
        "resume_index":     int           # SceneManager.get_resume_index()
    },
    "mystery_unlock_tree":  Dictionary    # MUT.get_save_state() — opaque pass-through
}
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `schema_version` | v | int | [1, CURRENT_SCHEMA_VERSION] | Migration key. At MVP, always 1. |
| `saved_at_unix` | t | int | [0, 2^31] | Unix epoch seconds at save time. Diagnostic only. |
| `moments_build` | b | String | semver string | Build tag at save time. Diagnostic only. |
| `resume_index` | r | int | [0, manifest.size()] | Next scene to play. `manifest.size()` means the epilogue has been reached. |
| `mystery_unlock_tree` | m | Dictionary | MUT-defined | Opaque; SaveSystem never inspects fields. |

**Output Range:** `resume_index` is exactly `SceneManager._current_index` after post-completion increment — so on save after the last scene completes, it equals `manifest.size()` and on next launch, SM enters Epilogue state immediately. This is the correct behavior: a player who finished the game re-launches into the Final Epilogue Screen, not scene 0.

**Example** (manifest = `["home", "park", "cafe"]`, Ju just completed "park"):
```json
{
  "schema_version": 1,
  "saved_at_unix": 1744218000,
  "moments_build": "0.1.0",
  "scene": { "resume_index": 2 },
  "mystery_unlock_tree": { "discoveries": { /* ... */ }, "epilogue_conditions_emitted": false }
}
```

On next launch, SM resumes at index 2 (`"cafe"`). MUT restores its internal dictionaries via `load_save_state(...)`.

### JSON Serialization Rules

The `encode` function is Godot's built-in `JSON.stringify(dict, "  ")` (indent 2). Decoding uses `JSON.parse_string(text)` which returns `Variant` (Dictionary on success, `null` on parse failure).

**Validation predicate** — `is_valid_envelope(parsed: Variant) -> bool`:
```
valid = parsed is Dictionary
     AND parsed.has("schema_version") AND parsed.schema_version is int
     AND parsed.has("scene") AND parsed.scene is Dictionary
     AND parsed.scene.has("resume_index") AND parsed.scene.resume_index is int
     AND parsed.has("mystery_unlock_tree") AND parsed.mystery_unlock_tree is Dictionary
```

Any failure → treat as corrupt (Rule 8).

### Migration Chain

```
migrate(data: Dictionary) -> Dictionary:
    v = data.schema_version
    while v < CURRENT_SCHEMA_VERSION:
        data = _migrate_step(v, data)   # dispatches by v
        v += 1
    return data
```

At MVP, `CURRENT_SCHEMA_VERSION = 1` and the loop runs zero times. The structure is defined now so Alpha/Full Vision additions (Settings persistence, per-scene checkpointing, analytics opt-in) can bump the version without breaking existing saves.

## Edge Cases

### File Absence & First Launch

- **If `user://moments_save.json` does not exist** (first launch): `load_from_disk()` returns `LoadResult.NO_SAVE_FOUND`. SaveSystem enters `Active` without touching SM or MUT (they keep defaults — SM at index 0, MUT with empty discoveries). Main Menu treats NO_SAVE_FOUND identically to CORRUPT_RECOVERED — press Start, begin scene 0.

- **If the `user://` directory itself is missing** (fresh OS install, sandboxed environment): Godot auto-creates `user://` on first `FileAccess.open()` for write. SaveSystem relies on this — no explicit `DirAccess.make_dir()` call needed.

### Corruption & Parse Errors

- **If `JSON.parse_string()` returns `null`** (malformed JSON — truncated file, binary garbage, BOM): Rename to `moments_save.json.corrupt.<iso8601>`, log error with the raw text length and first 200 bytes, return `LoadResult.CORRUPT_RECOVERED`. Downstream systems stay at defaults.

- **If the parsed value is not a Dictionary** (JSON array or scalar at root): Same as above — rename + log + CORRUPT_RECOVERED.

- **If `schema_version` key is missing or non-int**: Same corruption path. Do not try to guess the version.

- **If required keys `scene.resume_index` or `mystery_unlock_tree` are missing**: Same corruption path. Partial recovery is explicitly rejected — it risks restoring into an inconsistent cross-system state.

- **If `mystery_unlock_tree` passes SaveSystem validation but `MUT.load_save_state(data)` internally rejects it** (MUT's own schema mismatch): MUT is authoritative for its own format. MUT logs its own error and resets its state. SaveSystem does not second-guess the call. The scene index is still applied — Ju may see Chapter 3 with zero prior discoveries, but the game is playable.

### Write Failures

- **If the tmp file cannot be opened for write** (disk full, permissions): Log error, emit `EventBus.save_failed("open_tmp_failed: " + error_code)`, stay in `Active`. Previous good save file is untouched. Next `scene_completed` will retry.

- **If `store_string()` partially writes then fails**: The tmp file is in a bad state, but the real save file is untouched because the rename hasn't happened. On next save attempt, SaveSystem overwrites the tmp. No special cleanup needed.

- **If `DirAccess.rename_absolute(tmp, real)` fails**: Both files may exist on disk. On next load, SaveSystem reads the real file (unaffected). The stale tmp is overwritten on next save. SaveSystem does not proactively delete stale `.tmp` files — it's not worth the complexity and the OS cleans `user://` on uninstall anyway.

- **If the disk is full**: All writes fail per above. The game remains playable; progress simply doesn't persist. This is a degraded mode — worth logging loudly so Chester can diagnose Ju's machine if she reports it.

### Schema Version Edge Cases

- **If `schema_version` is greater than `CURRENT_SCHEMA_VERSION`** (save made by a newer build, then Ju installed an older build): Treat as corrupt. Rename + log + fresh start. Rationale: forward-compatibility is impossible without knowing the future schema. Losing progress is better than loading an unknown structure and crashing on access.

- **If `schema_version` is less than `CURRENT_SCHEMA_VERSION`** (save from older build): Run the migration chain. Each `_migrate_vN_to_vN+1` is a pure function that takes a Dictionary and returns a Dictionary. If any migration throws, treat as corrupt.

- **If a migration step returns a Dictionary that fails validation after migration**: Treat as corrupt. Each migration is responsible for producing a valid Dictionary for the next version.

### Load / Apply Ordering

- **If `apply_loaded_state()` is called without a prior `load_from_disk()` OR when `load_from_disk()` returned non-OK**: This is a programmer error. Assert `_state == LoadedReady` at the top of `apply_loaded_state()`. On assert failure, log an error and return without touching SM or MUT.

- **If `apply_loaded_state()` is called after `game_start_requested` has already fired** (gameplay.tscn root script order bug): The call still executes — `SM.set_resume_index(N)` and `MUT.load_save_state(dict)` don't check state. But Scene Manager has already advanced past `Waiting`, so setting its `_current_index` is useless and MUT may be mid-scene. This is a programmer error, not a user-facing edge case. Assert in dev; ship with a log warning.

- **If the gameplay.tscn root script crashes between `load_from_disk()` and `apply_loaded_state()`**: The parsed save is lost from memory, but the disk file is unchanged. Next launch re-loads it. No corruption risk.

### Save Trigger Edge Cases

- **If `scene_completed` fires while `SaveSystem._state == Loading`** (autoload timing race): Defer by one frame — `call_deferred("_on_scene_completed", scene_id)`. Loading is bounded (synchronous file read), so the deferred call will find SaveSystem in `Active` on the next frame.

- **If `scene_completed` fires while already `Saving`** (previous save still flushing — extremely unlikely given synchronous writes, but possible on slow disks): Queue the signal and process it after the current write finishes. Only one save is queued at a time — a second pending save replaces the first. This matches "save is a snapshot of current authoritative state, not a log."

- **If `scene_completed` fires with a `scene_id` that doesn't match `SceneManager._manifest[_current_index - 1]`** (stale signal per SM edge-cases): SaveSystem does not re-validate — it trusts SM. If SM was going to ignore the stale signal, it won't have incremented `_current_index`, so the save would persist the same index as last time. Idempotent; harmless.

- **If the game reaches Epilogue and no further `scene_completed` fires**: The last save (with `resume_index == manifest.size()`) was written on the final chapter's completion. On next launch, SM immediately enters Epilogue. This is the intended behavior — Ju re-launches straight into the final memory reveal.

### Multi-Instance & External Modification

- **If two game instances run simultaneously** (e.g., Ju accidentally double-clicks the shortcut): Each process will read the file on startup and write on `scene_completed`. Last-write-wins. Not defended against — a personal gift game is not expected to need file locking. If observed, surface to Chester for mitigation.

- **If the save file is edited externally** (Chester opens it in a text editor to debug): On next load, whatever is in the file is read. If the edit is valid JSON matching the schema, it's used. If not, corruption path fires. This is the intended debuggability of JSON format — Chester can manually reset `resume_index` for Ju's system if needed.

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Scene Manager** | `get_resume_index() -> int` for save; `set_resume_index(index: int)` for load apply. Both are new public methods added to SM (see post-design updates). | Hard — without a stable resume index, persistence is meaningless |
| **Mystery Unlock Tree** | `get_save_state() -> Dictionary` and `load_save_state(data: Dictionary)` — already specified in MUT GDD Section C Rule 3 & OQ-4. | Hard — discovery state is the primary game progress |
| **`gameplay.tscn` root script** | Calls `load_from_disk()` and `apply_loaded_state()` in order, then emits `game_start_requested`. Owned by the gameplay scene root (composition specified by Main Menu OQ-1 ADR). Main Menu itself does NOT call SaveSystem. | Hard — no other script is positioned to invoke SaveSystem at the right moment in the boot sequence |
| **EventBus** (ADR-003) | Listens to `scene_completed(scene_id: String)` during Active state. Emits `save_written()` and `save_failed(reason: String)`. | Hard — the save trigger flows through EventBus |
| **Godot `FileAccess` / `DirAccess` / `JSON`** | Synchronous file I/O, atomic rename, JSON encode/decode. All stable in Godot 4.3. | Hard — engine primitives |

### Downstream (systems that depend on this)

| System | What They Need | Hardness |
|--------|---------------|----------|
| **Scene Manager** | (Symmetric dependency) Reads its `_current_index` from the value SaveSystem injected via `set_resume_index()` at startup. If SaveSystem is absent, SM defaults to 0 — game still playable from the beginning. | Soft — SM functions without SaveSystem, just doesn't resume |
| **Mystery Unlock Tree** | (Symmetric dependency) Restores its discovery dictionaries from `load_save_state(data)` at startup. Without SaveSystem, MUT starts empty every session — game still playable. | Soft — MUT functions without SaveSystem |
| **Final Epilogue Screen** (indirect) | Relies on MUT state being persisted correctly. SaveSystem is the reason Ju reaches the Epilogue on re-launch after completing the final scene. | Soft — Epilogue works in a single session regardless |

### External Data

| Asset | Path | Description |
|-------|------|-------------|
| **Save file** | `user://moments_save.json` | The canonical save. Created on first `scene_completed`. |
| **Atomic write staging** | `user://moments_save.json.tmp` | Temporary file during write. Renamed to real path on success. |
| **Corruption backups** | `user://moments_save.json.corrupt.<iso8601>` | Written when parsing fails. Never read by SaveSystem; exists for Chester-side debugging. |

### Signals Emitted

| Signal | Parameters | Fired When |
|--------|------------|-----------|
| `save_written` | *(none)* | After a successful atomic write (rename succeeded) |
| `save_failed` | `reason: String` | When any step of the save fails (open, write, rename). Diagnostic only — no gameplay consumer. |

### Signals Listened To

| Signal | Source | Handled When |
|--------|--------|-------------|
| `scene_completed` | Scene Goal System (via EventBus) | During `Active` state — triggers a save write. Deferred one frame if still `Loading`. |

**Cross-reference notes:**
- **Scene Manager GDD** (`design/gdd/scene-manager.md`): Open Question OQ-1 ("Save/restore of `_current_index`") is resolved by this GDD's Core Rule 4 + 5. SM's Interactions table lists Save/Progress as "listens to `scene_completed` to persist progress" — consistent. New methods `get_resume_index()` and `set_resume_index()` must be added to SM Section C.3 Interactions and Section H Acceptance Criteria (post-design update #10).
- **Mystery Unlock Tree GDD** (`design/gdd/mystery-unlock-tree.md`): Interactions table already names `MUT.get_save_state()` and `MUT.load_save_state()` with Save/Progress as the caller. OQ-4 ("Session reset API for New Game") is referenced by this GDD's Core Rule 10 (`clear_save()`); actual implementation deferred to Settings GDD.
- **Main Menu GDD** (`design/gdd/main-menu.md`): Main Menu Rule 6 (No Game-State Coupling) prohibits direct SaveSystem calls from Main Menu. Resolution: the `gameplay.tscn` root script (OQ-1 in Main Menu GDD) is the orchestrator — it calls `SaveSystem.load_from_disk()` + `apply_loaded_state()` before emitting `game_start_requested`. Main Menu itself is unchanged; it remains a pure doorway that switches scenes. Main Menu holds no save-specific UI state (no "Continue" vs "New Game" buttons at MVP — press Start, resume from wherever you were). Post-design update amends Main Menu OQ-1 to specify the SaveSystem call sequence in the `gameplay.tscn` root script.
- **EventBus** (`docs/architecture/ADR-003-signal-bus.md`): Must declare `signal save_written()` and `signal save_failed(reason: String)`. Already declares `scene_completed(scene_id: String)`. Post-design update.

## Tuning Knobs

SaveSystem's runtime knobs are minimal — the design is intentionally rigid to keep the serialization contract stable. Most values are constants, not tunables.

| Knob | Type | Default | Safe Range | Too Low | Too High |
|------|------|---------|------------|---------|----------|
| `CURRENT_SCHEMA_VERSION` | int (const) | `1` | `1`–`N` | N/A — only incremented when schema changes | Never decrement |
| `SAVE_FILE_NAME` | String (const) | `"moments_save.json"` | — | Changing breaks all existing saves | Changing breaks all existing saves |
| `SAVE_TMP_SUFFIX` | String (const) | `".tmp"` | — | Collision with real save name | — |
| `CORRUPT_SUFFIX_FORMAT` | String (const) | `".corrupt.%s"` (ISO 8601 timestamp, colons→dashes) | — | — | — |
| `JSON_INDENT` | String (const) | `"  "` (two spaces) | 0–4 spaces | Unreadable when debugging | Larger file size (negligible) |
| `SAVE_DEFER_RETRY_FRAMES` | int | `1` | 1–3 | May not clear Loading state race | Delays save until player notices |

**Knobs owned by other systems (referenced for authoring context):**

| Knob | Owner | Description |
|------|-------|-------------|
| Scene manifest order | `assets/data/scene-manifest.json` | Defines what `resume_index` means — if order changes between builds, old saves resume into the wrong chapter. Chester must never reorder the shipped manifest post-launch. |
| MUT save schema | Mystery Unlock Tree GDD | SaveSystem passes MUT data through without inspection. MUT owns its own forward compatibility. |
| `moments_build` value | `project.godot` → `application/config/version` | Read at save time; diagnostic only. |

**Schema evolution policy:**
- Never mutate the shape of schema v1. If new fields are needed, bump to v2 and write a migration.
- Never remove existing fields in v1. Deprecate in v2+.
- Never reuse a deprecated field name with a different type.

**Design stance on tunability**: Save file format is not a gameplay knob. Chester should not treat it as "easy to iterate" during development — every change incurs a migration cost once Ju has played. The system favors rigidity over flexibility on purpose.

## Visual/Audio Requirements

Save / Progress System is a Persistence-layer infrastructure system — it has no direct visual or audio output. No toast, no "Saved!" icon, no sound cue on write. Silence is the specification: the player should never notice a save happening.

**Justification against common patterns:**
- *No save icon in HUD*: Would add a UI element during scene transitions, which Scene Transition UI owns. Adding a save indicator would fight the "clearing page turn" aesthetic established in Scene Manager's fantasy.
- *No audio cue*: Pillar 3 (Discovery Without Explanation) extends to persistence — saves are automatic, invisible, never announced.
- *No error dialog on save failure*: Per Corruption Recovery (Rule 8) and Edge Cases, failures log silently. Ju never sees a technical error screen.

If the game ever needs to surface a save-related state to the player in a future Settings screen (e.g., "reset progress" confirmation), that visual specification belongs to Settings GDD (#20), not here.

## UI Requirements

SaveSystem has no direct UI at MVP. It does not render or display anything to the player.

**Implicit UI contracts owned by other systems:**
- **Main Menu** — a single "Start" button. No "Continue" vs "New Game" distinction at MVP. Pressing Start always resumes wherever the save left off (or index 0 on first launch / corruption). The Main Menu GDD already reflects this (Pillar 4 single-button design).
- **Settings** (future, #20) — may expose a "Reset Progress" option that calls `SaveSystem.clear_save()`. Confirmation dialog spec belongs to Settings GDD.
- **Dev / debug overlay** (not in scope) — Chester may want a debug keybind to dump save state to the console. If added later, it belongs to a dev tooling system, not SaveSystem.

## Acceptance Criteria

### Autoload & Startup (AC-SP-01 – AC-SP-04)

**AC-SP-01 [Logic] — Autoload presence and order.**
GIVEN `project.godot` is configured, WHEN the game launches, THEN `SaveSystem` is registered as an autoload AND its `_ready()` runs *after* `EventBus`, `SceneGoalSystem`, `CardSpawningSystem`, `TableLayoutSystem`, `MysteryUnlockTree`, and `SceneManager`.

**AC-SP-02 [Logic] — `_ready()` does not auto-load.**
GIVEN a valid save file exists at `user://moments_save.json`, WHEN SaveSystem's `_ready()` completes, THEN no file I/O has occurred AND `SceneManager._current_index` is still `0` AND `MysteryUnlockTree` has no discoveries. `load_from_disk()` must be called explicitly.

**AC-SP-03 [Logic] — Initial state.**
GIVEN SaveSystem has just completed `_ready()`, WHEN inspected, THEN `_state == Idle` AND no scene_completed listener is yet connected (connected lazily on first `apply_loaded_state()` to prevent premature saves).

**AC-SP-04 [Integration] — Full startup orchestration.**
GIVEN a valid save with `resume_index: 2` and MUT data for 5 discoveries, WHEN Main Menu's Start press triggers `change_scene_to_file("gameplay.tscn")` and the gameplay scene's root script `_ready()` then runs (1) `load_from_disk()` → returns `LoadResult.OK`, (2) `apply_loaded_state()`, (3) `EventBus.game_start_requested.emit()`, THEN `SceneManager._current_index == 2` before `_load_scene_at_index()` is invoked AND `MUT.get_discovery_count() == 5` AND scene `cafe` (index 2) begins loading.

### Load From Disk (AC-SP-05 – AC-SP-12)

**AC-SP-05 [Logic] — No save file returns NO_SAVE_FOUND.**
GIVEN `user://moments_save.json` does not exist, WHEN `load_from_disk()` is called, THEN it returns `LoadResult.NO_SAVE_FOUND` AND `_state` becomes `Active` AND no exception is thrown.

**AC-SP-06 [Logic] — Valid save returns OK and enters LoadedReady.**
GIVEN a valid save file exists, WHEN `load_from_disk()` is called, THEN it returns `LoadResult.OK` AND `_state` becomes `LoadedReady` AND the parsed Dictionary is buffered internally.

**AC-SP-07 [Logic] — Malformed JSON is treated as corrupt.**
GIVEN `user://moments_save.json` contains `"not valid json"`, WHEN `load_from_disk()` is called, THEN it returns `LoadResult.CORRUPT_RECOVERED` AND the bad file has been renamed to `user://moments_save.json.corrupt.<iso8601>` AND `_state` becomes `Active` AND an error is logged.

**AC-SP-08 [Logic] — Missing schema_version is treated as corrupt.**
GIVEN the save file contains `{"scene": {"resume_index": 1}}` (no `schema_version`), WHEN `load_from_disk()` is called, THEN it returns `CORRUPT_RECOVERED` AND the file is renamed.

**AC-SP-09 [Logic] — Missing required keys are treated as corrupt.**
GIVEN the save file has valid JSON but omits `mystery_unlock_tree`, WHEN `load_from_disk()` is called, THEN it returns `CORRUPT_RECOVERED`.

**AC-SP-10 [Logic] — Future schema version is rejected.**
GIVEN the save file's `schema_version` is `99` and `CURRENT_SCHEMA_VERSION` is `1`, WHEN `load_from_disk()` is called, THEN it returns `CORRUPT_RECOVERED` AND the file is renamed.

**AC-SP-11 [Logic] — Corruption backup filename uses ISO 8601 with dashes.**
GIVEN a corrupt save at `user://moments_save.json`, WHEN `load_from_disk()` recovers from it at 2026-04-21 14:32:01 UTC, THEN the backup path matches the pattern `user://moments_save.json.corrupt.2026-04-21T14-32-01` (colons replaced).

**AC-SP-12 [Logic] — Load does not mutate downstream state.**
GIVEN SaveSystem returns `OK` from `load_from_disk()`, WHEN inspected immediately after, THEN `SceneManager._current_index` is unchanged (still 0) AND MUT state is unchanged. State application happens only in `apply_loaded_state()`.

### Apply Loaded State (AC-SP-13 – AC-SP-15)

**AC-SP-13 [Logic] — apply_loaded_state pushes into SM and MUT.**
GIVEN `_state == LoadedReady` with buffered `{"scene": {"resume_index": 3}, "mystery_unlock_tree": {...}}`, WHEN `apply_loaded_state()` is called, THEN `SceneManager.set_resume_index(3)` was invoked AND `MUT.load_save_state({...})` was invoked AND `_state` becomes `Active`.

**AC-SP-14 [Logic] — apply_loaded_state asserts LoadedReady.**
GIVEN `_state == Idle` (no prior load), WHEN `apply_loaded_state()` is called, THEN an error is logged AND SM and MUT are not modified AND `_state` is unchanged.

**AC-SP-15 [Logic] — After apply, buffer is discarded.**
GIVEN `apply_loaded_state()` has just returned, WHEN inspected, THEN the internal parsed buffer is empty/null. SaveSystem no longer caches the loaded data.

### Save Trigger (AC-SP-16 – AC-SP-20)

**AC-SP-16 [Integration] — scene_completed triggers atomic save with post-increment index.**
GIVEN SaveSystem is `Active` AND the autoload order per ADR-004 §1 is in effect (SM before SaveSystem), WHEN `EventBus.scene_completed.emit("home")` fires AND SM's handler runs first (incrementing `_current_index` from 0 to 1) AND SaveSystem's handler runs after, THEN SaveSystem reads `SceneManager.get_resume_index() == 1` AND `user://moments_save.json.tmp` was written AND renamed to `user://moments_save.json` AND the file contains `"resume_index": 1` AND `save_written` is emitted. The post-increment value — NOT the pre-increment value — is always what persists.

**AC-SP-17 [Logic] — Save writes current authoritative values, not cached.**
GIVEN a save has just occurred with `resume_index: 1`, WHEN `SceneManager._current_index` changes to `2` and the next `scene_completed` fires, THEN the resulting save file contains `"resume_index": 2` AND MUT state reflects current MUT discoveries (not a cached snapshot).

**AC-SP-18 [Logic] — Save during Loading defers one frame.**
GIVEN `_state == Loading`, WHEN `scene_completed` is received, THEN the handler is deferred via `call_deferred` AND when Loading completes and state becomes Active, the save executes.

**AC-SP-19 [Logic] — Atomic rename preserves previous save on tmp failure.**
GIVEN a valid save exists AND the disk rejects writing `moments_save.json.tmp` (simulated via permissions or mock), WHEN `scene_completed` fires, THEN `moments_save.json` on disk still contains the previous good content AND `save_failed(reason)` is emitted AND gameplay continues.

**AC-SP-20 [Logic] — Save after final scene contains epilogue-trigger index.**
GIVEN manifest is `["home", "park", "cafe"]` AND Ju completes "cafe" (the last chapter), WHEN the save fires, THEN the file contains `"resume_index": 3` (== `manifest.size()`) AND on next launch, SM enters Epilogue state immediately without loading a scene.

### Schema & Migration (AC-SP-21 – AC-SP-23)

**AC-SP-21 [Logic] — v1 save round-trips intact.**
GIVEN a v1 save is written with known values `{scene.resume_index: 2, mut: X}`, WHEN `load_from_disk()` → `apply_loaded_state()` is performed in a fresh game instance, THEN `SM._current_index == 2` AND `MUT.get_save_state()` returns a Dictionary deep-equal to `X`.

**AC-SP-22 [Logic] — Migration chain runs for older schema.**
GIVEN `CURRENT_SCHEMA_VERSION == 2` (hypothetical future state) AND a save with `schema_version: 1`, WHEN `load_from_disk()` is called, THEN `_migrate_v1_to_v2()` is invoked AND the resulting Dictionary has `schema_version: 2` AND passes validation.

**AC-SP-23 [Logic] — Migration failure treated as corrupt.**
GIVEN a save whose `_migrate_v1_to_v2()` throws (hypothetical), WHEN `load_from_disk()` is called, THEN the file is renamed to `.corrupt.<timestamp>` AND `LoadResult.CORRUPT_RECOVERED` is returned.

### New Game Reset (AC-SP-24)

**AC-SP-24 [Logic] — clear_save resets file and downstream state in the correct order.**
GIVEN a valid save file exists AND MUT has 4 discoveries AND `SM._state == ACTIVE` with `_current_index == 2`, WHEN `SaveSystem.clear_save()` is called, THEN the sequence is: (1) `SceneManager.reset_to_waiting()` invoked → SM state back to WAITING, cards cleared, `_current_index == 0`, CONNECT_ONE_SHOT re-armed; (2) `SceneManager.set_resume_index(0)` invoked and accepted (SM is now WAITING); (3) `MUT.load_save_state({})` invoked and MUT has zero discoveries + `_epilogue_conditions_emitted == false`; (4) `user://moments_save.json` no longer exists on disk; (5) `save_written` emitted. The ordering is load-bearing — calling `set_resume_index` BEFORE `reset_to_waiting` would trigger SM's `_state == WAITING` assertion and fail silently.

### Epilogue Save Hook (AC-SP-28 – AC-SP-29)

**AC-SP-28 [Logic] — save_now() performs the same atomic write as scene_completed path.**
GIVEN SaveSystem is in `Active` state AND MUT's `_final_memory_earned == true`, WHEN `SaveSystem.save_now()` is called synchronously (not via signal), THEN the save file is written atomically AND `save_written` is emitted AND `_state` returns to `Active` after.

**AC-SP-29 [Integration] — final_memory_ready triggers save_now via gameplay_root.**
GIVEN the gameplay scene is loaded AND MUT emits `EventBus.final_memory_ready()`, WHEN the signal propagates, THEN `gameplay_root.gd`'s handler calls `SaveSystem.save_now()` AND the resulting save file contains MUT data where `_epilogue_conditions_emitted == true` AND `_final_memory_earned == true` are preserved. On next launch, SM reads `resume_index == manifest.size()` from the save and enters Epilogue per SM Core Rule 9.

### Cross-System Contracts (AC-SP-25 – AC-SP-27)

**AC-SP-25 [Integration] — Scene Manager OQ-1 resolution contract.**
GIVEN SM has new public method `set_resume_index(index: int)`, WHEN called with `index=5` on an SM in `Waiting` state, THEN `SM._current_index == 5` AND SM is still in `Waiting` state (no auto-load triggered).

**AC-SP-26 [Integration] — `set_resume_index` clamps out-of-range.**
GIVEN manifest has 3 scenes, WHEN `set_resume_index(10)` is called, THEN `SM._current_index == 10` is accepted (no clamp) AND on subsequent `game_start_requested`, SM immediately enters `Epilogue` state (since `10 >= manifest.size()`). Rationale: a too-large index degrades gracefully to Epilogue; re-clamping would hide a bug.

**AC-SP-27 [Integration] — Negative resume index is rejected.**
GIVEN `SM.set_resume_index(-1)` is called (corrupt-but-passed-validation edge case), THEN SM logs an error AND `_current_index` remains unchanged at its previous value (default 0 or last-set positive value).

## Open Questions

| ID | Question | Owner | Target |
|----|----------|-------|--------|
| OQ-1 | ~~**"Reset Progress" exposure in Settings.**~~ **RESOLVED 2026-04-21** by Settings GDD (`design/gdd/settings.md` Core Rule 6). The Settings panel exposes a "Reset Progress" button with a two-tap 3-second countdown confirmation flow. On commit, `SaveSystem.clear_save()` is called and, if the player was in gameplay, the scene switches to Main Menu. Volume preferences persist (separate file). | — | Closed |
| OQ-2 | **Platform-specific `user://` resolution.** Godot resolves `user://` differently per OS (`~/Library/Application Support/Godot/app_userdata/Moments/` on macOS, `%APPDATA%/Godot/app_userdata/Moments/` on Windows). For a macOS-only gift (Ju's laptop), this is fine. If Chester ever ships a Windows build for family, confirm path works there. | engine-programmer | Verify at first Windows export |
| OQ-3 | **Cloud sync / backup strategy.** Not in scope for a single-machine gift. But: if Ju's laptop dies, is the save recoverable? Current answer: no — it's local-only. Chester may want to occasionally copy `user://moments_save.json` to a backup location manually. Document for the player release notes (internal). | Chester (operational decision) | Pre-ship ops note |
| OQ-4 | **Telemetry on save failures.** `save_failed(reason)` is emitted but has no listener at MVP. Post-launch, Chester may want to know if Ju's machine is rejecting writes (full disk, permissions). Could wire to a file-based debug log. | analytics-engineer (if/when added) | Deferred — only if a real issue surfaces |
| OQ-5 | **Quit-mid-scene safety.** Current design loses within-scene progress (card table state, partial bar values) on quit. If Ju quits mid-scene, she re-enters that chapter at its start. Is this acceptable? MVP answer: yes, aligns with "chapter = page turn" mental model. If playtest reveals friction, consider a lightweight mid-scene checkpoint on `WM_CLOSE_REQUEST`. | playtester + game-designer | Reactive — only if friction observed |
| OQ-6 | **Multi-install / re-gift scenario.** If Chester ships the game to a second person (a sibling, a future gift), they will share the same `user://` dir only if using the same OS user account. Different OS users get separate saves automatically. No action needed unless gifting strategy changes. | Chester | Non-issue for current scope |
