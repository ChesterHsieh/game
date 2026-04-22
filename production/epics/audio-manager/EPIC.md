# Epic: Audio Manager

> **Layer**: Foundation
> **GDD**: `design/gdd/audio-manager.md`
> **Architecture Module**: `AudioManager` (autoload singleton)
> **Status**: Ready
> **Stories**: 8 stories created 2026-04-21 — see table below

## Overview

AudioManager is the Foundation-layer autoload that owns all sound playback.
8-node SFX pool (fire-and-forget, priority-stealing for win events), 2 music
players with linear-dB crossfade, 3-bus tree (Master → Music, SFX) with
PascalCase bus names locked by Settings AC-SET-24. Connects to EventBus signals
in `_ready()` — one-way flow `EventBus → AudioManager → AudioStreamPlayer`.
Gameplay systems never play sound directly.

Per-event pitch + volume randomization, per-event cooldowns (80–500ms, or
once-per-scene for win), data-driven from `res://assets/data/audio_config.tres`,
silent-fallback mode on missing config. Public APIs: `set_bus_volume(bus, db)`
(Settings consumer) and `fade_out_all(duration)` (FES reveal — one-shot per
session).

Must load **after** EventBus in the 12-autoload order defined by ADR-004.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-001: Naming conventions | snake_case APIs + signals; PascalCase bus names locked by Settings | LOW |
| ADR-003: Signal bus (EventBus) | AudioManager is a listener for `drag_*`, `proximity_*`, `combination_executed`, `win_condition_met`, `scene_completed`, scene change signals | LOW |
| ADR-004: Runtime scene composition | Autoload order places AudioManager after EventBus; §6 wires EventBus→AudioManager in `_ready()` | LOW |
| ADR-005: `.tres` everywhere | `audio_config.tres` holds all SFX/music paths, pitch/volume ranges, cooldowns, variants | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-audio-manager-001 | Register as autoload singleton `AudioManager`, ordered after EventBus in autoload list | ADR-004 ✅ |
| TR-audio-manager-002 | Allocate fixed pool of 8 `AudioStreamPlayer` nodes at startup, all assigned to `SFX` bus | ADR-001 ✅ |
| TR-audio-manager-003 | Allocate 2 dedicated music players (`music_a`, `music_b`) on `Music` bus for crossfade support | ADR-001 ✅ |
| TR-audio-manager-004 | Configure audio bus tree: `Master` → `Music`, `SFX` (PascalCase names locked per Settings AC-SET-24) | ADR-001 ✅ |
| TR-audio-manager-005 | Connect to EventBus signals in `_ready()`; one-way flow EventBus → AudioManager → AudioStreamPlayer | ADR-003, ADR-004 ✅ |
| TR-audio-manager-006 | Claim first IDLE pool node on SFX request; return to IDLE on `finished` signal (fire-and-forget) | ADR-001 ✅ |
| TR-audio-manager-007 | Pool-full policy: silently drop non-win events; `win_condition_met` steals node with least remaining time | ADR-001 ✅ |
| TR-audio-manager-008 | Apply per-play pitch randomization via `pitch_scale = 2^(semitone_offset/12)`, range ±pitch_range | ADR-001 ✅ |
| TR-audio-manager-009 | Apply per-play volume randomization: `base_volume_db + uniform(±variance)` clamped to [−80, 0] dB | ADR-001 ✅ |
| TR-audio-manager-010 | Enforce per-event cooldowns via `Time.get_ticks_msec()` comparison (80–500ms plus once-per-scene for win) | ADR-001 ✅ |
| TR-audio-manager-011 | Run music state machine (STOPPED / PLAYING / CROSSFADING) with linear dB ramp over `crossfade_duration` | ADR-001 ✅ |
| TR-audio-manager-012 | Cancel in-flight crossfade on new track request; incoming node becomes outgoing at current dB | ADR-001 ✅ |
| TR-audio-manager-013 | Skip crossfade when consecutive scenes reference same track path (compare resource paths as strings) | ADR-001 ✅ |
| TR-audio-manager-014 | Load all sounds, ranges, cooldowns, variants from `assets/data/audio_config.tres`; no hardcoded paths | ADR-005 ✅ |
| TR-audio-manager-015 | On missing `audio_config.tres`, log error and enter silent-fallback mode; game runs without crash | ADR-005 ✅ |
| TR-audio-manager-016 | Expose public API `set_bus_volume(bus_name: String, volume_db: float)` clamped to [−80, 0] | ADR-001 ✅ |
| TR-audio-manager-017 | Expose public API `fade_out_all(duration: float)` linear dB ramp to −80 on all buses; one-shot per session | ADR-001 ✅ |
| TR-audio-manager-018 | Clamp `fade_out_all` duration to [0.1, 10.0]s; warn and no-op on subsequent calls after first completes | ADR-001 ✅ |
| TR-audio-manager-019 | Keep SFX cooldowns and pool transitions running even when Master bus is muted (mute = output gate only) | ADR-001 ✅ |
| TR-audio-manager-020 | Log warning and drop silently when EventBus signal has no corresponding entry in audio config | ADR-003 ✅ |

**Coverage**: 20 / 20 TRs ✅ (zero untraced)

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/audio-manager.md` (AC-AM-01 through AC-AM-19) are verified
- Logic stories (AC-AM-05/06/07/08: pitch, volume, crossfade, cooldown formulas) have passing unit tests in `tests/unit/audio_manager/` — **BLOCKING**
- Integration stories (AC-AM-01–04, 09–19) have integration tests or documented playtests — **BLOCKING**
- A seed `audio_config.tres` exists with at least the MVP event set (drag_start, drag_release, push_away, snap, spawn, combination_executed, win_condition_met)
- PascalCase bus tree (`Master` → `Music`, `SFX`) is created in `default_bus_layout.tres`

## Stories

| # | Story | Type | Status | ADR | TRs |
|---|-------|------|--------|-----|-----|
| 001 | [AudioManager autoload + bus layout + config load + silent fallback](story-001-autoload-bus-layout-config.md) | Integration | Ready | ADR-004, ADR-005 | TR-001, TR-004, TR-014, TR-015 |
| 002 | [SFX pool — allocation, fire-and-forget, pool-full + win priority](story-002-sfx-pool.md) | Integration | Ready | ADR-001 | TR-002, TR-006, TR-007 |
| 003 | [Pitch + volume randomization formulas](story-003-pitch-volume-randomization.md) | Logic | Ready | ADR-001 | TR-008, TR-009 |
| 004 | [Per-event cooldowns](story-004-per-event-cooldowns.md) | Logic | Ready | ADR-001 | TR-010 |
| 005 | [EventBus signal wiring + SFX dispatch + missing-event fallback](story-005-eventbus-signal-wiring.md) | Integration | Ready | ADR-003, ADR-004 | TR-005, TR-019, TR-020 |
| 006 | [Music players + crossfade state machine](story-006-music-crossfade.md) | Logic | Ready | ADR-001 | TR-003, TR-011, TR-012, TR-013 |
| 007 | [Public API — set_bus_volume + fade_out_all](story-007-public-api-bus-volume-fadeout.md) | Logic | Ready | ADR-001, ADR-003 | TR-016, TR-017, TR-018, TR-019 |
| 008 | [Seed audio_config.tres + default_bus_layout.tres](story-008-seed-audio-config.md) | Config/Data | Ready | ADR-005 | (data) |

**Coverage**: 20 / 20 TRs mapped to stories (TR-019 spans Stories 005 + 007).

## Next Step

Start implementation: `/story-readiness production/epics/audio-manager/story-001-autoload-bus-layout-config.md`
then `/dev-story` to begin. Work stories in order — each story's `Depends on:`
field lists what must be DONE first.
