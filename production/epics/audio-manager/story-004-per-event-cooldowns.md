# Story 004: Per-event cooldowns

> **Epic**: audio-manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-manager-010` — enforce per-event cooldowns via
`Time.get_ticks_msec()` comparison (80–500ms plus once-per-scene for win).

**ADR Governing Implementation**: ADR-001 — naming conventions
**ADR Decision Summary**: Cooldowns are tracked per event name, not per
pool node. Each event has a configurable `cooldown_ms` in
`audio_config.tres`. The `win_condition_met` event has a special
"once-per-scene" cooldown that resets on `scene_completed`.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `Time.get_ticks_msec()` returns monotonic milliseconds,
stable in 4.3. No overflow concern for game sessions (wraps at ~49 days).

**Control Manifest Rules (Foundation layer)**:
- Required: cooldown values from config, not hardcoded.
- Forbidden: hardcoded cooldown values in code.
- Guardrail: cooldown check O(1) per event — dictionary lookup.

---

## Acceptance Criteria

*From GDD `design/gdd/audio-manager.md`:*

- [ ] Each event has a per-event cooldown tracked via
      `Time.get_ticks_msec()` — AC-AM-08
- [ ] Request at `T + 150ms` with `cooldown_ms = 200` is blocked;
      at `T + 200ms` it plays — AC-AM-08
- [ ] `win_condition_met` has "once per scene" cooldown: fires once, then
      blocked until `scene_completed` resets it — AC-AM-09
- [ ] First play of any event is always allowed (last_play_time initialized
      to 0)
- [ ] Cooldown values are read from `audio_config.tres`
- [ ] Cooldowns still tick even when Master bus is muted (TR-019) — the
      cooldown check runs regardless of playback output
- [ ] Missing cooldown in config defaults to 0 (no cooldown)

---

## Implementation Notes

*Derived from GDD Formulas "Cooldown Check" section:*

1. Cooldown tracking:
   ```gdscript
   var _last_play_time: Dictionary = {}   # event_name → int (msec)
   var _win_played_this_scene: bool = false

   func _is_cooldown_ready(event_name: String, cooldown_ms: int) -> bool:
       if event_name == "win_condition_met":
           return not _win_played_this_scene
       var now: int = Time.get_ticks_msec()
       var last: int = _last_play_time.get(event_name, 0)
       return (now - last) >= cooldown_ms

   func _record_play(event_name: String) -> void:
       _last_play_time[event_name] = Time.get_ticks_msec()
       if event_name == "win_condition_met":
           _win_played_this_scene = true
   ```
2. Scene reset — connect to `EventBus.scene_completed` in Story 005:
   ```gdscript
   func _on_scene_completed(_scene_id: String) -> void:
       _win_played_this_scene = false
   ```
3. The GDD cooldown table: drag_start 80ms, drag_release 80ms, push_away
   150ms, snap 200ms, spawn 300ms, combination_executed 500ms. These values
   live in `audio_config.tres`, not in code.
4. Cooldown is checked BEFORE pool claim. If cooldown blocks, no pool node
   is consumed.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: pool claim (cooldown gates the claim)
- Story 003: randomization (applied after cooldown check passes)
- Story 005: EventBus wiring (invokes cooldown check)
- Story 006: music (music has no cooldown mechanism)

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (cooldown blocks rapid re-play)**:
  - Given: event "card_snap" with `cooldown_ms = 200`, last played at T
  - When: request at T + 150ms
  - Then: `_is_cooldown_ready("card_snap", 200)` returns `false`

- **AC-2 (cooldown allows after expiry)**:
  - Given: event "card_snap" with `cooldown_ms = 200`, last played at T
  - When: request at T + 200ms
  - Then: `_is_cooldown_ready("card_snap", 200)` returns `true`

- **AC-3 (first play always allowed)**:
  - Given: event "card_snap" never played (not in `_last_play_time`)
  - When: `_is_cooldown_ready("card_snap", 200)` called
  - Then: returns `true` (last = 0, now − 0 >= 200)

- **AC-4 (win once-per-scene)**:
  - Given: `_win_played_this_scene == false`
  - When: `_is_cooldown_ready("win_condition_met", 0)` called
  - Then: returns `true`
  - After: `_record_play("win_condition_met")` sets flag
  - When: second call
  - Then: returns `false`

- **AC-5 (win cooldown resets on scene_completed)**:
  - Given: `_win_played_this_scene == true`
  - When: `_on_scene_completed("scene-01")` fires
  - Then: `_win_played_this_scene == false`; next win request allowed

- **AC-6 (cooldowns tick when muted)**:
  - Given: Master bus muted; event played at time T
  - When: cooldown checked at T + 300ms
  - Then: cooldown correctly reports `true` (elapsed >= cooldown_ms)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio_manager/cooldown_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (config loaded with cooldown values)
- Unlocks: Story 005 (EventBus dispatch checks cooldown before play)
