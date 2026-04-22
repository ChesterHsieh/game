# Story 008: Seed audio_config.tres + default_bus_layout.tres

> **Epic**: audio-manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: No single TR — this story provides the data artefacts that
all other audio-manager stories consume. Covers the data side of TR-004
(bus layout), TR-014 (config file), and TR-015 (config must exist for
non-silent mode).

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere
**ADR Decision Summary**: `audio_config.tres` is a typed Resource loaded by
AudioManager. `default_bus_layout.tres` is Godot's built-in bus layout.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `default_bus_layout.tres` is Godot's standard audio bus
layout file, referenced automatically by `project.godot`. SubResource
syntax for typed Resources is stable.

**Control Manifest Rules (Foundation layer)**:
- Required: `.tres` for all persistent data.
- Forbidden: JSON config; hardcoded audio paths.
- Guardrail: config load < 5 ms.

---

## Acceptance Criteria

*From GDD `design/gdd/audio-manager.md`:*

- [ ] `default_bus_layout.tres` exists with 3 buses: `Master` (root),
      `Music` (child of Master), `SFX` (child of Master) — PascalCase
- [ ] `res://src/data/audio_config.gd` exists with
      `class_name AudioConfig extends Resource` and appropriate typed
      `@export` fields for event entries
- [ ] `res://assets/data/audio_config.tres` exists as a valid
      `AudioConfig` resource
- [ ] Config contains at least the MVP event set: `card_drag_start`,
      `card_drag_release`, `card_push_away`, `card_snap`, `card_spawn`,
      `combination_executed`, `win_condition_met`
- [ ] Each event entry includes: path (to audio file), pitch_range,
      volume_variance, base_volume_db, cooldown_ms
- [ ] At least one music track entry for scene-01
- [ ] AudioManager loads the config without errors (passes Story 001
      config load)
- [ ] Placeholder `.wav` or `.ogg` files exist at referenced paths
      (can be silence/tones for MVP)

---

## Implementation Notes

*Derived from ADR-005 §2 and GDD Data-Driven Configuration:*

1. `AudioConfig` Resource class (`res://src/data/audio_config.gd`):
   ```gdscript
   class_name AudioConfig extends Resource

   @export var events: Dictionary   # String → Dictionary per-event config
   @export var music_tracks: Dictionary   # scene_id → track path
   @export var crossfade_duration: float = 2.0
   ```
2. Per-event config Dictionary shape (documented, not enforced by type):
   ```
   {
     "path": "res://assets/audio/sfx/card_snap.wav",
     "pitch_range": 2.0,
     "volume_variance": 2.0,
     "base_volume_db": -6.0,
     "cooldown_ms": 200
   }
   ```
3. `default_bus_layout.tres` — create via Godot's Audio Bus editor:
   - Master (index 0)
   - Music (index 1, parent: Master)
   - SFX (index 2, parent: Master)
4. Placeholder audio files: generate short sine wave or silence `.wav`
   files for each MVP event. Real audio assets will replace these later.
5. Music track for scene-01: a placeholder `.ogg` loop.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001–007: all code implementation
- Real audio assets (final sounds, music) — content production phase
- Per-scene music track assignments beyond scene-01

---

## QA Test Cases

*For this Config/Data story — smoke check:*

- **SC-1 (bus layout loads correctly)**:
  - Given: `default_bus_layout.tres` exists
  - When: game starts
  - Then: `AudioServer.get_bus_index("Music") >= 0` and
    `AudioServer.get_bus_index("SFX") >= 0`

- **SC-2 (config loads without errors)**:
  - Given: `audio_config.tres` exists
  - When: AudioManager `_ready()` runs
  - Then: no assertion failures; `_silent_mode == false`

- **SC-3 (MVP events present)**:
  - Given: loaded config
  - When: inspecting `events` dictionary
  - Then: all 7 MVP event names present with valid entries

- **SC-4 (placeholder audio files exist)**:
  - Given: each event entry has a `path`
  - When: `ResourceLoader.exists(path)` checked
  - Then: all paths resolve to existing files

- **SC-5 (music track for scene-01)**:
  - Given: `music_tracks` dictionary
  - When: querying for `"scene-01"`
  - Then: returns a valid path to an existing `.ogg` file

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-audio-config-[date].md`
(smoke check pass) — must exist.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (AudioConfig class must be defined for the .tres
  to reference it)
- Unlocks: all Stories 002–007 (need config data to function); downstream
  consumers (Settings reads bus names, FES calls fade_out_all)
