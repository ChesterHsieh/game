# Audio Manager

> **Status**: Needs Revision → amended 2026-04-21 (added `fade_out_all` API + ACs for FES integration; PascalCase bus names locked per Settings AC-SET-24)
> **Author**: Chester + Claude Code agents
> **Last Updated**: 2026-04-14
> **Implements Pillar**: Pillar 3 (Discovery Without Explanation), Pillar 4 (Personal Over Polished)

## Overview

Audio Manager is a Foundation-layer autoload singleton that owns all sound playback in Moments. It manages a pool of `AudioStreamPlayer` nodes for concurrent SFX (card snap, push-away, card spawn) and a dedicated music player with crossfade support for scene transitions. Systems never play audio directly — they emit events via EventBus (ADR-003), and Audio Manager listens and triggers the appropriate sound. This decouples audio from gameplay logic, allowing sounds to be added, swapped, or removed without touching any gameplay system.

The immediate scope is gameplay SFX (snap, push, spawn, win). Music playback with per-scene ambient tracks and crossfade transitions is designed here but deferred to later implementation. UI sounds are out of scope for this GDD.

## Player Fantasy

Audio Manager has no direct player fantasy — it is infrastructure. Players experience its effects through other systems, never the manager itself.

**Indirect role**: Audio is half of the feedback loop that teaches Moments without words (Pillar 3). The snap sound confirms compatibility. The push-away confirms non-match. The spawn sound signals something new has appeared. Without audio, the visual cues must carry the full weight of instruction — with it, they share the load, and each one can be subtler. Sound closes the distance between looking at a card and feeling a memory.

## Detailed Design

### Core Rules

**1. Singleton Architecture**
- Audio Manager is an autoload singleton (`AudioManager`), loaded before any gameplay scene.
- It connects to EventBus signals in `_ready()` and never calls back into gameplay systems. Signal flow is one-way: EventBus → Audio Manager → AudioStreamPlayer.

**2. SFX Pool**
- Audio Manager allocates a fixed pool of **8 `AudioStreamPlayer` nodes** at startup, all assigned to the `SFX` bus.
- Each pool node is either `IDLE` or `PLAYING`. No paused state — SFX are fire-and-forget.
- On playback request: claim the first `IDLE` node, assign the stream, apply pitch/volume randomization, and play. When the node emits `finished`, it returns to `IDLE`.
- **Pool-full policy**: If all 8 nodes are `PLAYING`, the request is silently dropped. Exception: `win_condition_met` steals the node with the least remaining time.
- Priority tiers (high → low): `win` > `snap` > `combination_executed` > `spawn` > `push_away` > `drag_start` / `drag_release`.

**3. Per-Play Randomization**
- Each SFX event defines a pitch range (semitones) and volume variance (dB). Audio Manager applies random values within these ranges on every play to prevent repetitive mechanical feel.
- Pitch randomization is bidirectional (up and down from base pitch).

**4. Cooldowns**
- Each SFX event has a minimum cooldown (ms) between consecutive plays to prevent audio spam during rapid interactions.
- Cooldowns are tracked per-event, not per-node.

| Event | Cooldown |
|---|---|
| `card_drag_start` | 80 ms |
| `card_drag_release` | 80 ms |
| `card_push_away` | 150 ms |
| `card_snap` | 200 ms |
| `card_spawn` | 300 ms |
| `combination_executed` | 500 ms |
| `win_condition_met` | Once per scene |

**5. Music Playback**
- Audio Manager owns **two dedicated `AudioStreamPlayer` nodes** for music (`music_a`, `music_b`), both assigned to the `Music` bus.
- Only one music track plays per scene. The track is determined by scene configuration data, not hardcoded.
- If the same track is assigned across consecutive scenes, playback continues uninterrupted (no crossfade).

**6. Music Crossfade**
- When a new scene requests a different track, Audio Manager crossfades: the outgoing player fades from current volume to −80 dB while the incoming player fades from −80 dB to target volume, simultaneously, over `crossfade_duration` seconds.
- If a second scene change arrives mid-crossfade, the current crossfade is cancelled — the incoming node becomes the new outgoing node at its current volume, and a fresh crossfade begins to the newly requested track.

**7. Audio Bus Structure**

| Bus | Parent | Purpose |
|---|---|---|
| `Master` | — | All output; global volume control |
| `Music` | `Master` | Both music players |
| `SFX` | `Master` | All 8 SFX pool nodes |

**8. Data-Driven Configuration**
- All sound file paths, randomization ranges, cooldowns, and variant lists are stored in an external resource (`assets/data/audio_config.tres`). No file paths are hardcoded in the script.
- Adding or changing a sound requires editing the config file only — no code changes.

### States and Transitions

**Music State Machine**

| State | Description |
|---|---|
| `STOPPED` | No music playing. Both music nodes idle. |
| `PLAYING` | One music node active, one idle. |
| `CROSSFADING` | Outgoing node fading out, incoming node fading in. |

**Transitions:**
- `STOPPED → PLAYING`: Scene loads with a registered music track.
- `PLAYING → CROSSFADING`: Scene change signal received with a different track.
- `CROSSFADING → PLAYING`: Crossfade completes. Outgoing node stops.
- `PLAYING → STOPPED`: Scene change signal received with no registered track.
- `CROSSFADING → STOPPED`: Mid-crossfade scene change to a scene with no track.

**SFX nodes have no state machine** — they are stateless fire-and-forget players managed by pool availability.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **EventBus** (ADR-003) | EventBus → Audio Manager | Audio Manager connects to gameplay signals and plays corresponding sounds. One-way; Audio Manager never emits signals back. |
| **Card Engine** | Indirect via EventBus | Emits `drag_started`, `drag_released`, `proximity_entered`/`exited`. Audio Manager maps these to drag and snap SFX. |
| **Interaction Template Framework** | Indirect via EventBus | Emits `combination_succeeded`, `combination_executed`. Audio Manager plays combination SFX. |
| **Card Spawning System** | Indirect via EventBus | Emits card spawn events. Audio Manager plays spawn SFX. |
| **Scene Goal System** | Indirect via EventBus | Emits `win_condition_met`, `scene_completed`. Audio Manager plays win SFX and triggers music crossfade. |
| **Scene Manager** | Indirect via EventBus | Emits scene change signals with scene ID. Audio Manager looks up the music track for the new scene and begins crossfade. |
| **Settings** (downstream) | Settings → Audio Manager | Settings calls `AudioManager.set_bus_volume(bus_name, volume_db)` with PascalCase bus names `"Master"`, `"Music"`, `"SFX"`. Specified in `design/gdd/settings.md`. |

## Formulas

### Pitch Randomization (Semitone → pitch_scale)

`pitch_scale = 2 ^ (semitone_offset / 12)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Semitone offset | `semitone_offset` | float | [−pitch_range, +pitch_range] | Random offset drawn uniformly from the event's configured range |
| Pitch range | `pitch_range` | float | [0, 12] | Per-event config value in semitones |
| Pitch scale | `pitch_scale` | float | [0.5, 2.0] | Godot `AudioStreamPlayer.pitch_scale` multiplier |

**Output Range:** 0.5 to 2.0 at ±12 semitones. Keep `pitch_range` ≤ 12 to stay perceptually safe.
**Example:** `pitch_range = 2`, `semitone_offset = 1.3` → `2 ^ (1.3 / 12) = 2 ^ 0.1083 ≈ 1.079`

### Volume Randomization (dB offset)

`final_volume_db = clamp(base_volume_db + uniform(−volume_variance, +volume_variance), −80, 0)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base volume | `base_volume_db` | float | [−80, 0] | Event's configured base volume in dB |
| Volume variance | `volume_variance` | float | [0, 6] | Per-event max deviation in dB |
| Final volume | `final_volume_db` | float | [−80, 0] | Clamped; assigned to `volume_db` |

**Output Range:** −80 to 0 dB (clamped after applying offset).
**Example:** `base = −6 dB`, `variance = 3`, `rand_offset = −1.8` → `−6 + (−1.8) = −7.8 dB`

### Music Crossfade (Linear dB ramp)

```
outgoing_volume_db(t) = current_volume − (current_volume − (−80)) × (t / crossfade_duration)
incoming_volume_db(t) = −80 + (target_volume − (−80)) × (t / crossfade_duration)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Elapsed time | `t` | float | [0, crossfade_duration] | Time into the fade in seconds |
| Crossfade duration | `crossfade_duration` | float | [0.1, 5.0] | Configured fade length in seconds |
| Current volume | `current_volume` | float | [−80, 0] | Outgoing player's volume at fade start |
| Target volume | `target_volume` | float | [−80, 0] | Incoming player's desired final volume |

**Output Range:** Both ramps bounded [−80, 0] by construction. Stop the outgoing player after tween completes.
**Example:** 2 s fade, `current = −3`, `target = −6`. At `t = 1`: outgoing = −41.5 dB, incoming = −43 dB.

### Cooldown Check

`ready = (current_time_ms − last_play_time_ms) >= cooldown_ms`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current time | `current_time_ms` | int | [0, ∞) | `Time.get_ticks_msec()` at call time |
| Last play time | `last_play_time_ms` | int | [0, ∞) | Timestamp of event's last play; 0 if never played |
| Cooldown | `cooldown_ms` | int | [0, 5000] | Per-event minimum interval in milliseconds |
| Ready | `ready` | bool | {true, false} | Whether the event may fire |

**Output Range:** Boolean. Initializing `last_play_time_ms = 0` ensures the first call is always `ready = true`.
**Example:** `cooldown = 200 ms`, `last_play = 4800`, `current = 4950` → `150 < 200` → `false`

## Edge Cases

### Pool Exhaustion

- **If all 8 nodes are `PLAYING` and `win_condition_met` fires**: Steal the node with the least remaining time, stop it immediately, and play the win SFX. Win is never silently dropped.
- **If all 8 nodes are `PLAYING` and a non-win event fires**: Silently drop the request. A missed snap sound is preferable to interrupting an existing sound.
- **If the generator template spawns 8+ cards in a single frame**: The 300 ms cooldown on `card_spawn` catches most spam. If cooldown has expired but the pool is full, the drop is silent and correct — not a bug.

### Music / Scene Transitions

- **If the same track is assigned to consecutive scenes**: Compare track resource paths (strings), not object identity. Playback continues uninterrupted — no crossfade.
- **If a scene change fires mid-crossfade**: Cancel the current crossfade. The incoming node becomes the new outgoing node at its current dB value (not snapped to its target), and a fresh crossfade begins to the new track.
- **If two scene changes fire within the same frame**: Only the second track request is honored. The mid-crossfade interrupt rule handles this naturally.
- **If `win_condition_met` fires during a crossfade**: Win SFX plays on the SFX bus, unaffected. Music crossfade continues uninterrupted. No interaction between the two buses.

### First Scene / Startup

- **If the first scene requests a music track**: Audio Manager initializes in `STOPPED`. The first track transitions directly `STOPPED → PLAYING` with no crossfade. Crossfade only applies when transitioning from `PLAYING` or `CROSSFADING`.
- **If EventBus is not yet initialized when Audio Manager's `_ready()` fires**: Audio Manager must be ordered after EventBus in the autoload list. This is a setup constraint, not a runtime guard.

### Missing Files / Config Errors

- **If `audio_config.tres` is missing at startup**: Audio Manager logs an error and enters silent-fallback mode. All EventBus connections are established but no streams are assigned. The game runs silently — no crash.
- **If a stream path in config resolves to null (file deleted/renamed)**: That event plays nothing and logs a warning. No pool node is claimed for a null stream.
- **If an EventBus signal fires that has no entry in audio config**: Log a warning with the event name, drop silently. New signals added before audio is wired degrade gracefully.

### Volume Edge Cases

- **If Master bus is muted**: SFX cooldowns still tick and the pool still claims/releases nodes. Mute is a bus-level output gate, not a playback gate.
- **If volume randomization produces a value below −80 dB**: Clamp to −80 dB and play anyway. The node cycle completes normally at effectively inaudible volume.
- **If `win_condition_met` fires twice in the same scene**: The "once per scene" cooldown blocks the second play. Audio Manager does not need to diagnose why the duplicate fired.

## Dependencies

### Upstream Dependencies (systems Audio Manager depends on)

| System | Type | Interface |
|---|---|---|
| **EventBus** (ADR-003) | Hard | Audio Manager connects to all gameplay signals in `_ready()`. Without EventBus, no audio triggers fire. |

Audio Manager has no gameplay system dependencies. It is a Foundation-layer system that listens passively.

### Downstream Dependents (systems that depend on Audio Manager)

| System | Type | Interface |
|---|---|---|
| **Settings** (#20) | Soft | Settings calls `set_bus_volume("Master" / "Music" / "SFX", volume_db)` to adjust bus volumes. Without Audio Manager, Settings has no audio controls to display. Bus-name casing locked to PascalCase by Settings AC-SET-24. |

### Autoload Order Constraint

Audio Manager must load **after** EventBus in the Godot autoload list. No other load-order dependencies.

### Data Dependencies

| Resource | Path | Required |
|---|---|---|
| Audio config | `assets/data/audio_config.tres` | Yes (silent-fallback if missing) |
| SFX files | `assets/audio/sfx/*.wav` | Per-event (warning if missing) |
| Music tracks | `assets/audio/music/*.ogg` | Per-scene (no music if missing) |
| Bus layout | `default_bus_layout.tres` | Yes (Godot editor-configured) |

## Tuning Knobs

### SFX Pool

| Knob | Default | Safe Range | Too Low | Too High |
|---|---|---|---|---|
| `sfx_pool_size` | 8 | 4–16 | Frequent silent drops during multi-card interactions | Wasted memory on unused AudioStreamPlayer nodes |

### Per-Event SFX Configuration

Each event in `audio_config.tres` exposes these knobs:

| Knob | Example Default | Safe Range | Effect |
|---|---|---|---|
| `pitch_range` | 2 semitones | 0–6 | Higher = more variation per play. 0 = no randomization. Above 6 sounds unnatural. |
| `volume_variance` | 2 dB | 0–6 | Higher = more dynamic volume per play. Above 6 makes some plays inaudible. |
| `base_volume_db` | −6 dB | −24 to 0 | Lower = quieter baseline. Keep relative to other events. |
| `cooldown_ms` | varies (80–500) | 0–2000 | Lower = allows rapid repeat. 0 = no cooldown (spam risk). Above 1000 = noticeable gaps. |
| `variants` | 2–4 files | 1–8 | More variants = less repetitive feel. Diminishing returns above 4 for subtle SFX. |

### Music

| Knob | Default | Safe Range | Too Low | Too High |
|---|---|---|---|---|
| `crossfade_duration` | 2.0 s | 0.5–5.0 | Abrupt cut feels jarring | Long fade feels sluggish during fast scene changes |
| `music_volume_db` | −12 dB | −24 to 0 | Music inaudible | Music overwhelms SFX and gameplay feel |

### Bus Volumes (Player-Facing via Settings)

| Knob | Default | Range | Notes |
|---|---|---|---|
| `master_volume_db` | 0 dB | −80 to 0 | Exposed to player in Settings UI |
| `music_bus_volume_db` | 0 dB | −80 to 0 | Exposed to player in Settings UI |
| `sfx_bus_volume_db` | 0 dB | −80 to 0 | Exposed to player in Settings UI |

### Public API (for Settings + FES)

| Method | Signature | Purpose |
|---|---|---|
| `set_bus_volume` | `(bus_name: String, volume_db: float) -> void` | Sets the volume of a Godot audio bus (`"Master"` / `"Music"` / `"SFX"` — PascalCase). Clamps to `[−80, 0]` dB. Called by Settings on slider changes. |
| `fade_out_all` | `(duration: float) -> void` | Smoothly fades every bus (Master + Music + SFX) from its current volume down to `−80 dB` over `duration` seconds using a linear dB ramp. Cancels any in-flight music crossfade. Used by Final Epilogue Screen on reveal entry so "the room goes quiet" as the illustrated memory rises. One-shot per session; subsequent calls log a warning. `duration` clamped to `[0.1, 10.0]` seconds. |

### Interactions Between Knobs

- `base_volume_db` per event + `sfx_bus_volume_db` + `master_volume_db` stack additively in dB. If all three are at −20 dB, effective output is −60 dB — nearly inaudible. Keep `base_volume_db` as the primary per-event control; bus volumes are global multipliers.
- `crossfade_duration` interacts with scene transition speed — if scenes can change faster than the crossfade completes, the mid-crossfade interrupt rule handles it, but very long crossfade durations with very fast scene changes produce abrupt volume jumps.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

### SFX Pool

- **AC-AM-01**: **GIVEN** the game launches, **WHEN** Audio Manager's `_ready()` completes, **THEN** exactly 8 `AudioStreamPlayer` nodes exist in the SFX pool, all `IDLE`, all assigned to the `SFX` bus.
- **AC-AM-02**: **GIVEN** at least one pool node is `IDLE`, **WHEN** a valid SFX event fires via EventBus, **THEN** the first `IDLE` node is claimed, the stream plays, and the node returns to `IDLE` automatically when `finished` emits.
- **AC-AM-03**: **GIVEN** all 8 pool nodes are `PLAYING`, **WHEN** a non-win SFX event fires, **THEN** the request is silently dropped — no error, no crash.
- **AC-AM-04**: **GIVEN** all 8 pool nodes are `PLAYING`, **WHEN** `win_condition_met` fires, **THEN** the node with the least remaining playback time is stopped and reassigned to the win SFX.

### Formulas

- **AC-AM-05**: **GIVEN** an event with `pitch_range = R`, **WHEN** it plays, **THEN** `pitch_scale = 2^(offset/12)` where offset is in `[-R, +R]`. Over 100 plays, all values fall within `[2^(-R/12), 2^(R/12)]`.
- **AC-AM-06**: **GIVEN** an event with `base_volume_db = -78` and `volume_variance = 6`, **WHEN** it plays, **THEN** `volume_db` is in `[-80, -72]` — never below −80 dB (clamp verified).
- **AC-AM-07**: **GIVEN** a crossfade of duration `D` from −3 dB to −6 dB, **WHEN** `t = D/2` elapses, **THEN** outgoing volume = −41.5 dB and incoming volume = −43 dB (±0.1 dB tolerance).
- **AC-AM-08**: **GIVEN** an event with `cooldown_ms = 200` last played at time `T`, **WHEN** a request arrives at `T + 150 ms`, **THEN** it is blocked. At `T + 200 ms` or later, it plays.

### Edge Cases

- **AC-AM-09**: **GIVEN** `win_condition_met` has already fired once this scene, **WHEN** it fires again, **THEN** the second play is blocked. After scene change, the cooldown resets.
- **AC-AM-10**: **GIVEN** a crossfade is in progress (outgoing at −30 dB, incoming at −52 dB), **WHEN** a scene change fires with a third track, **THEN** the incoming node becomes the new outgoing at exactly −52 dB, and a fresh crossfade begins.
- **AC-AM-11**: **GIVEN** `audio_config.tres` is missing at startup, **WHEN** the game launches, **THEN** Audio Manager logs an error, enters silent-fallback mode, and the game runs without audio — no crash.
- **AC-AM-12**: **GIVEN** Audio Manager is in `STOPPED` state, **WHEN** the first scene loads with a music track, **THEN** the track plays immediately with no crossfade.
- **AC-AM-13**: **GIVEN** track "ambient_A" is playing, **WHEN** the next scene also uses "ambient_A", **THEN** playback continues uninterrupted — no volume dip, no restart.

### Settings Integration

- **AC-AM-14**: **GIVEN** Settings calls `set_bus_volume("Music", -20.0)`, **WHEN** processed, **THEN** the `Music` bus volume equals −20 dB immediately.
- **AC-AM-15**: **GIVEN** the `Master` bus is muted, **WHEN** SFX events fire, **THEN** cooldowns still tick, pool nodes still claim/release, state transitions complete normally.
- **AC-AM-16**: **GIVEN** any bus volume call with a value outside [−80, 0], **WHEN** processed, **THEN** Audio Manager clamps to the nearest bound — no error.

### Fade-out API (FES integration)

- **AC-AM-17**: **GIVEN** Audio Manager is playing music at `−6 dB` and SFX at `−3 dB` base, **WHEN** `fade_out_all(2.0)` is called, **THEN** over 2 seconds Master/Music/SFX bus volumes all decay linearly (in dB) to `−80 dB` AND any in-flight music crossfade is cancelled in favour of the fade-out.
- **AC-AM-18**: **GIVEN** `fade_out_all(2.0)` has already completed, **WHEN** a subsequent `fade_out_all(1.0)` is called, **THEN** it is a no-op AND a warning is logged (one-shot per session).
- **AC-AM-19**: **GIVEN** `fade_out_all(0.05)` is called (below clamp floor), **WHEN** processed, **THEN** duration is clamped to `0.1` seconds AND the fade runs.

### Test Evidence Classification

- **Logic tests** (AC-AM-05, 06, 07, 08): Automated unit tests in `tests/unit/audio_manager/` — **BLOCKING** gate.
- **Integration tests** (AC-AM-01–04, 09–16): Integration test or documented playtest — **BLOCKING** gate.

## Open Questions

[To be designed]
