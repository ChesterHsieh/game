# Story 003: Pitch + volume randomization formulas

> **Epic**: audio-manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-manager-008` — pitch randomization via
`pitch_scale = 2^(semitone_offset/12)`, range ±pitch_range.
`TR-audio-manager-009` — volume randomization:
`base_volume_db + uniform(±variance)` clamped to [−80, 0] dB.

**ADR Governing Implementation**: ADR-001 — naming conventions
**ADR Decision Summary**: Per-play randomization parameters come from
`audio_config.tres`. Formulas are defined in the GDD Formulas section.
These are pure functions that can be unit-tested independently.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `AudioStreamPlayer.pitch_scale` and `.volume_db` are
standard properties. `randf_range()` for uniform random is stable.
`pow(2.0, x)` for the pitch formula is standard GDScript.

**Control Manifest Rules (Foundation layer)**:
- Required: data-driven from config; no hardcoded values.
- Forbidden: hardcoded pitch/volume values in code.
- Guardrail: randomization calculation < 0.01 ms per play.

---

## Acceptance Criteria

*From GDD `design/gdd/audio-manager.md` Formulas section:*

- [ ] Pitch randomization: `pitch_scale = 2^(semitone_offset / 12)` where
      `semitone_offset` is drawn uniformly from `[−pitch_range, +pitch_range]`
      — AC-AM-05
- [ ] Over 100 plays with `pitch_range = R`, all pitch_scale values fall
      within `[2^(−R/12), 2^(R/12)]` — AC-AM-05
- [ ] Volume randomization: `final_volume_db = clamp(base_volume_db + uniform(−variance, +variance), −80, 0)`
      — AC-AM-06
- [ ] Volume clamp: `base_volume_db = −78`, `variance = 6` → final in
      `[−80, −72]`, never below −80 dB — AC-AM-06
- [ ] Randomization values are read from `audio_config.tres` per event
- [ ] `pitch_range = 0` → no pitch randomization (pitch_scale = 1.0)
- [ ] `volume_variance = 0` → no volume randomization (volume_db = base)

---

## Implementation Notes

*Derived from GDD Formulas section:*

1. Pure functions for randomization:
   ```gdscript
   static func _randomize_pitch(pitch_range: float) -> float:
       if pitch_range <= 0.0:
           return 1.0
       var offset: float = randf_range(-pitch_range, pitch_range)
       return pow(2.0, offset / 12.0)

   static func _randomize_volume(base_db: float, variance: float) -> float:
       if variance <= 0.0:
           return clampf(base_db, -80.0, 0.0)
       var offset: float = randf_range(-variance, variance)
       return clampf(base_db + offset, -80.0, 0.0)
   ```
2. Applied during SFX play (integrates with Story 002's pool claim):
   ```gdscript
   func _play_on_node(index: int, event_config: Dictionary) -> void:
       var player: AudioStreamPlayer = _sfx_pool[index]
       player.stream = load(event_config.get("path", ""))
       player.pitch_scale = _randomize_pitch(event_config.get("pitch_range", 0.0))
       player.volume_db = _randomize_volume(
           event_config.get("base_volume_db", 0.0),
           event_config.get("volume_variance", 0.0))
       _sfx_pool_state[index] = true
       player.play()
   ```
3. Static functions allow unit testing without an AudioStreamPlayer node.
   Pass in the config values, verify the output range.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: SFX pool (provides the player node)
- Story 004: cooldown checks (runs before randomization)
- Story 005: EventBus wiring (triggers the play path)
- Variant selection (picking a random file from a variants list) — can be
  added alongside the randomization but the GDD describes it in Tuning Knobs
  as "2–4 files"; implement as a simple random choice if needed

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (pitch formula correctness)**:
  - Given: `pitch_range = 2`
  - When: `_randomize_pitch(2.0)` is called 100 times
  - Then: all results in `[2^(-2/12), 2^(2/12)]` = `[0.891, 1.122]`
  - Edge cases: `pitch_range = 0` → always returns `1.0`

- **AC-2 (pitch formula at boundary)**:
  - Given: `pitch_range = 12` (full octave)
  - When: `_randomize_pitch(12.0)` called
  - Then: result in `[0.5, 2.0]`

- **AC-3 (volume formula correctness)**:
  - Given: `base_volume_db = -6.0`, `variance = 3.0`
  - When: `_randomize_volume(-6.0, 3.0)` called 100 times
  - Then: all results in `[-9.0, -3.0]`

- **AC-4 (volume clamp at −80 dB floor)**:
  - Given: `base_volume_db = -78.0`, `variance = 6.0`
  - When: `_randomize_volume(-78.0, 6.0)` called 100 times
  - Then: all results in `[-80.0, -72.0]` — never below −80

- **AC-5 (volume clamp at 0 dB ceiling)**:
  - Given: `base_volume_db = -1.0`, `variance = 3.0`
  - When: `_randomize_volume(-1.0, 3.0)` called 100 times
  - Then: all results in `[-4.0, 0.0]` — never above 0

- **AC-6 (zero variance = no randomization)**:
  - Given: `pitch_range = 0`, `volume_variance = 0`
  - When: called multiple times
  - Then: pitch always `1.0`; volume always `base_volume_db` (clamped)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio_manager/randomization_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (config loaded), Story 002 (pool node to apply to)
- Unlocks: Story 005 (full SFX dispatch path)
