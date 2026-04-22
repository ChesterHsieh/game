# Story 005: EventBus signal wiring + SFX dispatch + missing-event fallback

> **Epic**: audio-manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-manager-005` — connect to EventBus signals in
`_ready()`; one-way flow EventBus → AudioManager → AudioStreamPlayer.
`TR-audio-manager-019` — cooldowns and pool transitions run even when muted.
`TR-audio-manager-020` — log warning and drop when EventBus signal has no
config entry.

**ADR Governing Implementation**: ADR-003 — EventBus is the sole event
channel; ADR-004 — AudioManager connects to EventBus in `_ready()`
**ADR Decision Summary**: AudioManager connects to gameplay signals
(`drag_started`, `drag_released`, `proximity_entered`, `combination_executed`,
`card_spawned`, `win_condition_met`, `scene_completed`, `scene_started`) in
`_ready()`. Each handler maps the signal to an event name, checks cooldown,
claims a pool node, applies randomization, and plays.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `signal.connect()` in `_ready()` is standard. Signal
handler arity must match the signal declaration in ADR-003.

**Control Manifest Rules (Foundation layer)**:
- Required: EventBus for cross-system events; one-way flow.
- Forbidden: AudioManager emitting signals back to gameplay systems.
- Guardrail: handler latency < 0.5 ms per signal.

---

## Acceptance Criteria

*From GDD `design/gdd/audio-manager.md`:*

- [ ] `_ready()` connects to all gameplay EventBus signals relevant to
      audio (drag, proximity, combination, spawn, win, scene lifecycle)
- [ ] Each signal handler maps to an event name in `audio_config.tres`
- [ ] The dispatch path: signal → event name → cooldown check → pool
      claim → randomization → play (integrating Stories 002–004)
- [ ] In silent-fallback mode: handlers still run (cooldowns tick, pool
      claims/releases) but no stream is loaded (TR-019) — AC-AM-15
- [ ] When an EventBus signal has no corresponding entry in
      `audio_config.tres`: log warning naming the event, drop silently
      (TR-020)
- [ ] AudioManager never emits signals back to EventBus or calls methods
      on gameplay systems (one-way flow)
- [ ] When Master bus is muted: dispatch still runs fully — cooldowns
      tick, pool nodes claim/release normally (AC-AM-15)

---

## Implementation Notes

*Derived from ADR-003 signal table and GDD Interactions:*

1. Signal connections in `_ready()`:
   ```gdscript
   func _connect_signals() -> void:
       EventBus.drag_started.connect(_on_drag_started)
       EventBus.drag_released.connect(_on_drag_released)
       EventBus.proximity_entered.connect(_on_proximity_entered)
       EventBus.combination_executed.connect(_on_combination_executed)
       EventBus.card_spawned.connect(_on_card_spawned)
       EventBus.win_condition_met.connect(_on_win_condition_met)
       EventBus.scene_completed.connect(_on_scene_completed)
       EventBus.scene_started.connect(_on_scene_started)
   ```
2. Handler example:
   ```gdscript
   func _on_drag_started(_card_id: String, _world_pos: Vector2) -> void:
       _dispatch_sfx("card_drag_start")

   func _dispatch_sfx(event_name: String) -> void:
       var event_config: Dictionary = _get_event_config(event_name)
       if event_config.is_empty():
           push_warning("AudioManager: no config for event '%s' — dropped" % event_name)
           return
       var cooldown_ms: int = event_config.get("cooldown_ms", 0)
       if not _is_cooldown_ready(event_name, cooldown_ms):
           return
       var is_win: bool = event_name == "win_condition_met"
       var node_idx: int = _claim_sfx_node(is_win)
       if node_idx < 0:
           return
       _record_play(event_name)
       if _silent_mode:
           return   # cooldown recorded, pool claimed, but no stream
       _play_on_node(node_idx, event_config)
   ```
3. `_on_combination_executed` must accept 6 parameters (per ADR-003's
   expanded signal: recipe_id, template, instance_id_a, instance_id_b,
   card_id_a, card_id_b). Most are unused by audio — just extract what's
   needed for event name mapping.
4. `_on_scene_completed` resets the win cooldown (Story 004).
   `_on_scene_started` can trigger music track lookup (Story 006).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: pool claim implementation
- Story 003: randomization formulas
- Story 004: cooldown logic
- Story 006: music crossfade (scene_started triggers music, not SFX)
- Story 007: set_bus_volume + fade_out_all APIs

---

## QA Test Cases

*For this Integration story — automated test specs:*

- **AC-1 (EventBus connections established)**:
  - Given: AudioManager `_ready()` completes
  - When: test checks EventBus signal connections
  - Then: AudioManager is connected to `drag_started`, `drag_released`,
    `proximity_entered`, `combination_executed`, `card_spawned`,
    `win_condition_met`, `scene_completed`, `scene_started`

- **AC-2 (full dispatch path: signal → sound)**:
  - Given: valid `audio_config.tres` with `card_drag_start` event entry
  - When: `EventBus.drag_started.emit("card-1", Vector2.ZERO)`
  - Then: a pool node claims and plays the configured SFX stream

- **AC-3 (missing event config → warning + drop)**:
  - Given: `audio_config.tres` has no entry for `"unknown_event"`
  - When: `_dispatch_sfx("unknown_event")` called
  - Then: push_warning logged containing `"unknown_event"`; no pool claim

- **AC-4 (silent mode: dispatch runs but no stream)**:
  - Given: AudioManager in `_silent_mode`
  - When: `EventBus.drag_started.emit("card-1", Vector2.ZERO)`
  - Then: cooldown recorded, pool node claimed and released, but no
    audio stream loaded/played

- **AC-5 (muted bus: dispatch still runs)**:
  - Given: Master bus volume set to −80 dB
  - When: EventBus signals fire
  - Then: cooldowns tick, pool claims/releases happen normally

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio_manager/signal_dispatch_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload + config), Story 002 (SFX pool),
  Story 003 (randomization), Story 004 (cooldowns);
  card-database Story 001 (EventBus must exist with signals declared)
- Unlocks: Story 006 (music uses scene_started signal), Story 007
  (public API is independent but full audio path needs this)
