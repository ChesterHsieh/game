# Story 006: Music players + crossfade state machine

> **Epic**: audio-manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-manager-003` — 2 music players on Music bus.
`TR-audio-manager-011` — music state machine (STOPPED / PLAYING /
CROSSFADING) with linear dB ramp. `TR-audio-manager-012` — cancel
in-flight crossfade on new track request. `TR-audio-manager-013` — skip
crossfade when same track path.

**ADR Governing Implementation**: ADR-001 — naming conventions
**ADR Decision Summary**: Two AudioStreamPlayer nodes for music enable
seamless crossfade. A 3-state FSM manages transitions. The crossfade
formula uses linear dB ramp over `crossfade_duration`.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `create_tween()` with `.tween_property("volume_db", ...)`
for linear dB ramps is stable in 4.3. Two AudioStreamPlayer nodes on the
Music bus is standard.

**Control Manifest Rules (Foundation layer)**:
- Required: music nodes on `Music` bus.
- Forbidden: more than one track playing outside of crossfade transition.
- Guardrail: crossfade tween < 0.01 ms per frame overhead.

---

## Acceptance Criteria

*From GDD `design/gdd/audio-manager.md`:*

- [ ] Two `AudioStreamPlayer` nodes (`music_a`, `music_b`) created in
      `_ready()`, both on `Music` bus
- [ ] Music state machine: STOPPED → PLAYING → CROSSFADING with defined
      transitions per GDD States and Transitions — AC-AM-12
- [ ] First scene with music: STOPPED → PLAYING, no crossfade — AC-AM-12
- [ ] Scene change with different track: PLAYING → CROSSFADING with
      linear dB ramp over `crossfade_duration` — AC-AM-07
- [ ] Mid-crossfade scene change: cancel current crossfade; incoming becomes
      outgoing at current dB; fresh crossfade to new track — AC-AM-10
- [ ] Same track on consecutive scenes: playback continues uninterrupted,
      no crossfade — AC-AM-13
- [ ] Crossfade formula: outgoing ramps from current_volume to −80 dB;
      incoming ramps from −80 dB to target_volume — AC-AM-07
- [ ] At `t = D/2` for a fade from −3 dB to −6 dB target: outgoing ≈ −41.5 dB,
      incoming ≈ −43 dB (±0.1 dB) — AC-AM-07

---

## Implementation Notes

*Derived from GDD Music Crossfade formula and States:*

1. Music player initialization:
   ```gdscript
   enum MusicState { STOPPED, PLAYING, CROSSFADING }

   var _music_state: MusicState = MusicState.STOPPED
   var _music_a: AudioStreamPlayer
   var _music_b: AudioStreamPlayer
   var _active_music: AudioStreamPlayer   # currently playing
   var _current_track_path: String = ""
   var _crossfade_tween: Tween = null

   func _init_music_players() -> void:
       _music_a = AudioStreamPlayer.new()
       _music_a.bus = &"Music"
       add_child(_music_a)
       _music_b = AudioStreamPlayer.new()
       _music_b.bus = &"Music"
       add_child(_music_b)
   ```
2. Track change logic triggered by `scene_started`:
   ```gdscript
   func _play_music_for_scene(scene_id: String) -> void:
       var track_path: String = _get_music_track(scene_id)
       if track_path.is_empty():
           _stop_music()
           return
       if track_path == _current_track_path:
           return   # same track — no crossfade
       _start_crossfade(track_path)
   ```
3. Crossfade with Tween:
   ```gdscript
   func _start_crossfade(new_track_path: String) -> void:
       if _crossfade_tween and _crossfade_tween.is_running():
           _crossfade_tween.kill()
       var outgoing: AudioStreamPlayer = _active_music
       var incoming: AudioStreamPlayer = _music_a if _active_music == _music_b else _music_b
       incoming.stream = load(new_track_path)
       incoming.volume_db = -80.0
       incoming.play()
       var duration: float = _config.crossfade_duration if _config else 2.0
       _crossfade_tween = create_tween()
       _crossfade_tween.set_parallel(true)
       if outgoing and outgoing.playing:
           _crossfade_tween.tween_property(outgoing, "volume_db", -80.0, duration)
       _crossfade_tween.tween_property(incoming, "volume_db", 0.0, duration)
       _crossfade_tween.chain().tween_callback(_on_crossfade_complete.bind(outgoing))
       _active_music = incoming
       _current_track_path = new_track_path
       _music_state = MusicState.CROSSFADING
   ```
4. Mid-crossfade interrupt: killing the tween freezes the outgoing node at
   its current dB. The new incoming player starts from −80 dB. The old
   incoming (now outgoing) fades from wherever it currently is.
5. STOPPED → PLAYING (first scene): set stream, set volume to target,
   play directly — no tween, no crossfade.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload + config
- Story 002: SFX pool (separate concern)
- Story 005: EventBus wiring (provides scene_started trigger)
- Story 007: fade_out_all (cancels music crossfade — Story 007 calls into
  this state machine)
- Music track configuration per scene — that's content in audio_config.tres

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (two music players on Music bus)**:
  - Given: AudioManager `_ready()` completes
  - When: test inspects music nodes
  - Then: 2 AudioStreamPlayer children on `Music` bus

- **AC-2 (STOPPED → PLAYING on first scene: no crossfade)**:
  - Given: music state STOPPED; first scene has track "ambient_a"
  - When: `_play_music_for_scene("scene-01")` called
  - Then: music plays immediately; no tween; state = PLAYING — AC-AM-12

- **AC-3 (PLAYING → CROSSFADING on different track)**:
  - Given: music PLAYING track "ambient_a"
  - When: scene changes to "scene-02" with track "ambient_b"
  - Then: crossfade starts; outgoing fades to −80, incoming from −80 to
    target; state = CROSSFADING

- **AC-4 (crossfade formula midpoint)**:
  - Given: crossfade duration 2.0s, outgoing at −3 dB, target −6 dB
  - When: t = 1.0s (halfway)
  - Then: outgoing ≈ −41.5 dB, incoming ≈ −43 dB (±0.1 dB) — AC-AM-07

- **AC-5 (mid-crossfade interrupt)**:
  - Given: crossfade in progress, incoming at −52 dB, outgoing at −30 dB
  - When: third track request arrives
  - Then: current tween killed; incoming becomes outgoing at −52 dB;
    fresh crossfade to third track — AC-AM-10

- **AC-6 (same track: no crossfade)**:
  - Given: music PLAYING "ambient_a"
  - When: next scene also uses "ambient_a"
  - Then: playback continues uninterrupted; no volume dip — AC-AM-13

- **AC-7 (scene with no track: PLAYING → STOPPED)**:
  - Given: music PLAYING
  - When: scene changes to one with no registered track
  - Then: music stops; state = STOPPED

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio_manager/crossfade_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload + config + bus layout),
  Story 005 (EventBus wiring provides scene_started trigger)
- Unlocks: Story 007 (fade_out_all cancels music crossfade),
  Story 008 (seed config includes music tracks)
