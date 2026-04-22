# Story 001: AudioManager autoload + bus layout + config load + silent fallback

> **Epic**: audio-manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-manager-001` — register as autoload singleton,
ordered after EventBus. `TR-audio-manager-004` — 3-bus tree (Master →
Music, SFX) with PascalCase names. `TR-audio-manager-014` — load all
sounds/ranges/cooldowns from `audio_config.tres`. `TR-audio-manager-015` —
silent-fallback on missing config.

**ADR Governing Implementation**: ADR-004 — autoload order (#5: AudioManager
after InputSystem); ADR-005 — `.tres` data files
**ADR Decision Summary**: AudioManager is autoload #5 in the 12-autoload
canonical order. Config is loaded from `res://assets/data/audio_config.tres`
as a typed Resource. If missing, log error and enter silent mode.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `default_bus_layout.tres` is Godot's built-in bus layout
file, edited in the Audio Bus editor. `AudioServer.get_bus_index()` for
runtime bus queries is stable.

**Control Manifest Rules (Foundation layer)**:
- Required: autoload order per ADR-004 §1; `process_mode = PROCESS_MODE_ALWAYS`;
  `.tres` for all data.
- Forbidden: hardcoded audio paths; JSON config.
- Guardrail: config load < 5 ms.

---

## Acceptance Criteria

*From GDD `design/gdd/audio-manager.md`:*

- [ ] `res://src/core/audio_manager.gd` exists with `extends Node`
- [ ] Registered as autoload #5 in `project.godot`, after `InputSystem`,
      with `process_mode = PROCESS_MODE_ALWAYS`
- [ ] `default_bus_layout.tres` has 3 buses: `Master` → `Music`, `SFX`
      (PascalCase names per Settings AC-SET-24)
- [ ] `_ready()` loads `res://assets/data/audio_config.tres` via
      `ResourceLoader.load() as AudioConfig` + null-check
- [ ] On successful load, config data is stored on the autoload instance
- [ ] On missing config: logs `push_error`, enters silent-fallback mode
      (no crash, game runs without audio) — AC-AM-11
- [ ] Silent-fallback mode flag is readable for downstream stories

---

## Implementation Notes

*Derived from ADR-004 §1 and GDD Edge Case "Missing Files":*

1. `res://src/core/audio_manager.gd`:
   ```gdscript
   class_name AudioManager extends Node

   const CONFIG_PATH := "res://assets/data/audio_config.tres"

   var _config: AudioConfig = null
   var _silent_mode: bool = false

   func _ready() -> void:
       process_mode = PROCESS_MODE_ALWAYS
       var raw: Resource = ResourceLoader.load(CONFIG_PATH)
       var config: AudioConfig = raw as AudioConfig
       if config == null:
           push_error("AudioManager: %s is missing or not an AudioConfig — entering silent mode" % CONFIG_PATH)
           _silent_mode = true
           return
       _config = config
       # Story 002 adds SFX pool init here
       # Story 005 adds EventBus connections here
       # Story 006 adds music player init here
   ```
2. `AudioConfig` Resource class: `res://src/data/audio_config.gd` —
   this is a data shape class per ADR-005 §2. Exact fields depend on
   what stories 002–007 need. Minimal skeleton here:
   ```gdscript
   class_name AudioConfig extends Resource
   @export var events: Dictionary   # event_name → config dict
   @export var crossfade_duration: float = 2.0
   ```
3. `project.godot` → `[autoload]` section, fifth line:
   ```
   AudioManager="*res://src/core/audio_manager.gd"
   ```
4. `default_bus_layout.tres` must be edited in the Godot Audio Bus editor
   to create the 3-bus hierarchy. Bus names are PascalCase (locked by
   Settings AC-SET-24).
5. Silent-fallback mode: all subsequent stories check `_silent_mode` and
   skip playback if true. EventBus connections are still established
   (cooldowns tick, pool state transitions) — TR-019.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: SFX pool allocation
- Story 003: pitch + volume randomization
- Story 004: per-event cooldowns
- Story 005: EventBus signal wiring
- Story 006: music crossfade state machine
- Story 007: public API (set_bus_volume, fade_out_all)
- Story 008: seed audio_config.tres content

---

## QA Test Cases

*For this Integration story — automated test specs:*

- **AC-1 (autoload position #5)**:
  - Given: project running
  - When: test reads `project.godot` `[autoload]` section
  - Then: fifth autoload entry is `AudioManager=...`; after InputSystem

- **AC-2 (process_mode)**:
  - Given: AudioManager autoload loaded
  - When: test queries `AudioManager.process_mode`
  - Then: `process_mode == PROCESS_MODE_ALWAYS`

- **AC-3 (bus layout)**:
  - Given: project running
  - When: test queries `AudioServer.get_bus_index("Music")` and
    `AudioServer.get_bus_index("SFX")`
  - Then: both return valid indices (not -1); both are children of Master

- **AC-4 (happy-path config load)**:
  - Given: `audio_config.tres` exists with valid AudioConfig
  - When: `_ready()` runs
  - Then: `_config != null`; `_silent_mode == false`

- **AC-5 (missing config — silent fallback)**:
  - Given: no file at CONFIG_PATH
  - When: `_ready()` runs
  - Then: `_silent_mode == true`; push_error logged; no crash
  - Edge cases: config exists but is wrong type → also enters silent mode

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio_manager/autoload_config_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: card-database Story 001 (EventBus must exist — AudioManager
  connects to it in Story 005)
- Unlocks: Stories 002–008 (all audio features depend on the autoload)
