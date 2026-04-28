---
name: set-start-scene
description: Configure the dev-only start-scene override so launching the game jumps straight into a chosen scene (by id or manifest index), bypassing earlier scenes. Edits assets/data/debug-config.tres only — file is gitignored and excluded from release exports. Pass `clear` / `off` / `-1` to disable the override.
argument-hint: "[scene-id | index | clear]"
user-invocable: true
allowed-tools: Read, Write, Edit, Bash
---

# Set Start Scene

Configure the dev-only start-scene jump for fast iteration. The game's
`gameplay_root.gd` reads `assets/data/debug-config.tres` on boot and, if
`start_scene_index >= 0`, calls `SceneManager.set_resume_index()` before
emitting `game_start_requested`. Result: the game launches straight into
the chosen scene.

This file is gitignored and excluded from release exports — safe to leave
configured during dev work.

---

## Phase 1 — Parse Argument

The argument can be:

- **Scene id** (kebab-case string): `long-distance`, `drive`, `coffee-intro`
- **Manifest index** (integer ≥ 0): `0`, `1`, `2`
- **Clear/disable**: `clear`, `off`, `-1`, `none` — sets `start_scene_index = -1`

If no argument is given:
- Read current `start_scene_index` from `assets/data/debug-config.tres`
- Read `scene_ids` from `assets/data/scene-manifest.tres`
- Print current state and the available scene list, then stop.

---

## Phase 2 — Resolve Scene Index

If the argument is an integer:
- Use it directly as `start_scene_index`
- Validate it's `0 <= idx < scene_ids.size()` — error and stop if out of range

If the argument is a string scene-id:
- Read `scene_ids` from `assets/data/scene-manifest.tres`
- Find the index of `scene-id` in that array
- If not found: error with the available list, stop

If the argument is `clear` / `off` / `-1` / `none`:
- Set `start_scene_index = -1`

---

## Phase 3 — Ensure Infrastructure Exists

Check whether the wiring is in place:

1. `src/data/debug_config.gd` must declare `@export var start_scene_index: int`
2. `src/scenes/gameplay_root.gd` must call `_apply_debug_start_scene()` (or
   equivalent) before emitting `game_start_requested`
3. `.gitignore` must exclude `assets/data/debug-config.tres`

If any are missing, print a one-line note and stop with a recovery hint.
(Normally these are already in place from the original scene-3 jump
implementation; this skill just edits the .tres value.)

---

## Phase 4 — Write debug-config.tres

If the file exists: edit only the `start_scene_index = N` line, preserve
`force_unlock_all` and any other fields.

If the file does not exist: create it with sensible defaults:

```
[gd_resource type="Resource" script_class="DebugConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/data/debug_config.gd" id="1_debug"]

[resource]
script = ExtResource("1_debug")
force_unlock_all = false
start_scene_index = N
```

---

## Phase 5 — Smoke Verify

Run a quick Godot import to make sure the .tres parses:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import 2>&1 | tail -5
```

Errors mentioning `debug-config` or `DebugConfig` → surface them and stop.
Otherwise: PASS.

---

## Phase 6 — Summary

Print:

```
Start scene override: <scene-id> (index N)
File: assets/data/debug-config.tres
Run the game → it will skip straight into "<scene-id>".

To revert: /set-start-scene clear
```

If the user passed `clear`:

```
Start scene override: DISABLED
File: assets/data/debug-config.tres (start_scene_index = -1)
Game will boot from scene 0 (the manifest's first entry).
```

---

## Notes

- This skill is dev-only. The .tres file is gitignored and excluded from
  release exports per ADR-005 §7.
- The skill is data-only — never edits gd code unless Phase 3 detects
  missing wiring (in which case it stops and asks the user to install it
  rather than auto-editing engine code).
- Running this skill mid-game has no effect on the running session —
  the override is read once at gameplay scene load. Restart the game to
  apply.
