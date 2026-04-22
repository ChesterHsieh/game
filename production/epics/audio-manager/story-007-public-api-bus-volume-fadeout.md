# Story 007: Public API — set_bus_volume + fade_out_all

> **Epic**: audio-manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-manager-016` — `set_bus_volume(bus_name, volume_db)`
clamped to [−80, 0]. `TR-audio-manager-017` — `fade_out_all(duration)` linear
ramp to −80 on all buses, one-shot per session. `TR-audio-manager-018` —
clamp duration to [0.1, 10.0]s; warn on subsequent calls.
`TR-audio-manager-019` — cooldowns and pool transitions run even when muted.

**ADR Governing Implementation**: ADR-003 — direct autoload calls for
read-only queries and command methods; ADR-001 — naming conventions
**ADR Decision Summary**: `set_bus_volume` and `fade_out_all` are public
methods on the AudioManager autoload, called directly by Settings and FES
respectively (ADR-003 allows direct autoload calls for commands/queries).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `AudioServer.set_bus_volume_db(bus_idx, volume_db)` is
the engine API. `create_tween()` for the fade ramp. Both stable in 4.3.

**Control Manifest Rules (Foundation layer)**:
- Required: direct autoload calls for commands; PascalCase bus names.
- Forbidden: gameplay systems adjusting bus volumes directly via
  AudioServer (go through AudioManager).
- Guardrail: `set_bus_volume` is O(1); `fade_out_all` tween overhead
  negligible.

---

## Acceptance Criteria

*From GDD `design/gdd/audio-manager.md`:*

- [ ] `set_bus_volume(bus_name: String, volume_db: float)` sets the named
      bus volume immediately — AC-AM-14
- [ ] `set_bus_volume` clamps to [−80, 0] dB — no error on out-of-range
      values — AC-AM-16
- [ ] `set_bus_volume` accepts PascalCase bus names: `"Master"`, `"Music"`,
      `"SFX"`
- [ ] `fade_out_all(duration: float)` linearly ramps all 3 buses to −80 dB
      over `duration` seconds — AC-AM-17
- [ ] `fade_out_all` cancels any in-flight music crossfade — AC-AM-17
- [ ] `fade_out_all` clamps duration to [0.1, 10.0]s — AC-AM-19
- [ ] `fade_out_all` is one-shot per session: second call is no-op +
      push_warning — AC-AM-18
- [ ] When Master bus is muted (volume at −80 dB): SFX cooldowns still
      tick, pool nodes still claim/release — AC-AM-15

---

## Implementation Notes

*Derived from GDD Public API and Edge Cases:*

1. `set_bus_volume`:
   ```gdscript
   func set_bus_volume(bus_name: String, volume_db: float) -> void:
       var idx: int = AudioServer.get_bus_index(bus_name)
       if idx < 0:
           push_warning("AudioManager: unknown bus '%s'" % bus_name)
           return
       volume_db = clampf(volume_db, -80.0, 0.0)
       AudioServer.set_bus_volume_db(idx, volume_db)
   ```
2. `fade_out_all`:
   ```gdscript
   var _fade_out_completed: bool = false
   var _fade_out_tween: Tween = null

   func fade_out_all(duration: float) -> void:
       if _fade_out_completed:
           push_warning("AudioManager: fade_out_all already completed — no-op")
           return
       duration = clampf(duration, 0.1, 10.0)
       # Cancel music crossfade if running
       if _crossfade_tween and _crossfade_tween.is_running():
           _crossfade_tween.kill()
       _fade_out_tween = create_tween().set_parallel(true)
       for bus_name: String in ["Master", "Music", "SFX"]:
           var idx: int = AudioServer.get_bus_index(bus_name)
           if idx < 0:
               continue
           var current_db: float = AudioServer.get_bus_volume_db(idx)
           _fade_out_tween.tween_method(
               func(db: float) -> void: AudioServer.set_bus_volume_db(idx, db),
               current_db, -80.0, duration)
       _fade_out_tween.chain().tween_callback(func() -> void: _fade_out_completed = true)
   ```
3. `_fade_out_completed` is the one-shot guard. It persists for the session.
   No reset mechanism — FES only calls this once as the final epilogue
   reveal.
4. Mute behavior (TR-019): muting sets bus volume to −80 dB via
   `set_bus_volume`. This does NOT set a `muted` flag on the bus. Pool
   state and cooldowns are unaffected because they don't check bus volume.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload (prerequisite)
- Story 005: EventBus wiring (dispatch path)
- Story 006: music crossfade (this story kills it; Story 006 manages it)
- Settings UI sliders — Settings epic; they call `set_bus_volume`
- FES reveal — FES epic; it calls `fade_out_all`

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (set_bus_volume applies immediately)**:
  - Given: Music bus at 0 dB
  - When: `set_bus_volume("Music", -20.0)` called
  - Then: `AudioServer.get_bus_volume_db(music_idx) == -20.0` — AC-AM-14

- **AC-2 (set_bus_volume clamps to range)**:
  - Given: any bus
  - When: `set_bus_volume("SFX", -100.0)` called
  - Then: bus volume is −80.0 (clamped, no error) — AC-AM-16
  - Edge: `set_bus_volume("SFX", 10.0)` → clamped to 0.0

- **AC-3 (fade_out_all ramps to −80 dB)**:
  - Given: Master at 0 dB, Music at −6 dB, SFX at −3 dB
  - When: `fade_out_all(2.0)` called and 2s elapse
  - Then: all 3 buses at −80 dB — AC-AM-17

- **AC-4 (fade_out_all one-shot)**:
  - Given: `fade_out_all(2.0)` has completed
  - When: `fade_out_all(1.0)` called again
  - Then: no-op; push_warning logged — AC-AM-18

- **AC-5 (fade_out_all clamps duration)**:
  - Given: `fade_out_all(0.05)` called
  - When: processed
  - Then: duration clamped to 0.1s; fade runs — AC-AM-19

- **AC-6 (fade_out_all cancels music crossfade)**:
  - Given: music crossfade in progress
  - When: `fade_out_all(2.0)` called
  - Then: crossfade tween killed; all buses fade to −80 — AC-AM-17

- **AC-7 (muted bus: pool still runs)**:
  - Given: Master at −80 dB (muted)
  - When: SFX events fire
  - Then: cooldowns tick, pool nodes claim/release — AC-AM-15

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio_manager/public_api_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload + bus layout), Story 006 (music crossfade
  tween reference for cancel)
- Unlocks: Story 008 (seed data), and downstream consumers (Settings,
  Final Epilogue Screen)
