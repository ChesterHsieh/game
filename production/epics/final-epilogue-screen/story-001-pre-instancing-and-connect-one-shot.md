# Story 001: Pre-instancing and CONNECT_ONE_SHOT

> **Epic**: Final Epilogue Screen
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/final-epilogue-screen.md`
**Requirements**: `TR-final-epilogue-screen-001`, `TR-final-epilogue-screen-002`, `TR-final-epilogue-screen-012`, `TR-final-epilogue-screen-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-004: Runtime Scene Composition, Autoload Order, and Epilogue Handoff; ADR-003: Inter-System Communication — EventBus Singleton
**ADR Decision Summary**: FES is pre-instanced at gameplay scene build time as a child of `EpilogueLayer (CanvasLayer, layer=20)` inside `gameplay.tscn` — no `change_scene_to_file` is ever called. FES connects to `EventBus.epilogue_cover_ready` with `CONNECT_ONE_SHOT` in its `_ready()`; the one-shot flag ensures the handler disconnects after first receipt, making subsequent emissions a no-op at the FES level.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `CONNECT_ONE_SHOT` flag on `Signal.connect()` is stable in 4.3. `CanvasLayer.layer` property is stable. `has_method()` is stable. `get_tree().quit()` is stable. `MysteryUnlockTree.is_final_memory_earned()` is a direct autoload query call (read-only), consistent with ADR-003's direct-call pattern for queries.

**Control Manifest Rules (Presentation Layer)**:
- Required: EpilogueLayer is CanvasLayer layer=20; FES pre-instanced in Armed state
- Required: HudLayer hides itself on `epilogue_started`
- Required: STUI emits `epilogue_cover_ready`; FES waits on this before fading in
- Forbidden: Never make FES its own autoload or use `change_scene_to_file` to reach it
- Forbidden: Never call `change_scene_to_file` during epilogue handoff

---

## Acceptance Criteria

*From GDD `design/gdd/final-epilogue-screen.md`, scoped to this story:*

- [x] **AC-TRIGGER-1**: Given a save state where `MUT.is_final_memory_earned() == false` and Ju completes the final required recipe during the final chapter, when `EventBus.final_memory_ready` is emitted, `gameplay_root.gd` calls `SaveSystem.save_now()` exactly once. The FES reveal is triggered separately by `epilogue_cover_ready` from STUI, not by `final_memory_ready`.
- [x] **AC-TRIGGER-2**: Given a save state where `MUT.is_final_memory_earned() == true` AND `resume_index == manifest.size()`, when the app starts, Scene Manager enters Epilogue state directly on `game_start_requested` (per SM Core Rule 9) and emits `epilogue_started()` exactly once. STUI begins its amber cover, emits `epilogue_cover_ready`, and FES reveals.
- [x] **AC-ONESHOT-1**: A single triggering session results in exactly one FES reveal, regardless of how many times `epilogue_cover_ready` is emitted. Emitting `epilogue_cover_ready` three times in succession causes FES to transition `Armed → Loading` exactly once (`CONNECT_ONE_SHOT` disconnects after first receipt).
- [ ] **AC-ONESHOT-2**: FES writes no files and modifies no persistent state. A crash or force-quit during FES leaves save state unchanged relative to pre-FES.
- [ ] **AC-FAIL-1**: If `MUT.is_final_memory_earned()` returns `false` when FES `_ready()` runs, FES logs an error and calls `get_tree().quit()` within 1 frame. No partial screen render.

---

## Implementation Notes

*Derived from ADR-004 §2 and §4, and ADR-003:*

**Scene placement (ADR-004 §2)**: `FinalEpilogueScreen` is a child of `EpilogueLayer (CanvasLayer, layer=20)` inside `gameplay.tscn`. It is authored into the scene at build time with its internal state = Armed. It renders nothing (transparent) until `epilogue_cover_ready` is received.

**`_ready()` sequence — order is load-bearing (GDD Core Rule 5)**:
1. Call `MysteryUnlockTree.is_final_memory_earned()`. If `false`: log error to stderr, call `get_tree().quit()`. Do not proceed past this guard.
2. Set `self.modulate = Color(1.0, 1.0, 1.0, 0.0)` — alpha=0 BEFORE any Tween is created. This prevents a one-frame flash on scene load.
3. Connect `EventBus.epilogue_cover_ready.connect(_on_epilogue_cover_ready, CONNECT_ONE_SHOT)`.

**CONNECT_ONE_SHOT enforcement (ADR-003)**: The `CONNECT_ONE_SHOT` flag causes Godot to automatically disconnect the signal handler after the first emission it receives. A second or third `epilogue_cover_ready` emission is silently ignored at the signal-dispatch level — no guard logic needed inside `_on_epilogue_cover_ready`. This replaces the `_enter_tree` guard that was described in early versions of the FES GDD; that guard is no longer required.

**FES writes no save state**: FES is a terminal leaf node. `SaveSystem.save_now()` is called by `gameplay_root.gd` on `final_memory_ready` (ADR-004 §6), not by FES. FES has no `_on_final_memory_ready` handler and holds no `FileAccess` reference.

**AC-TRIGGER-2 (relaunch path)**: On session resume when `_final_memory_earned == true` AND `resume_index == manifest.size()`, SM enters Epilogue directly on `game_start_requested`. SM emits `epilogue_started`; STUI begins amber cover; STUI emits `epilogue_cover_ready`; FES (pre-instanced with `CONNECT_ONE_SHOT`) receives it and begins reveal. FES's `_ready()` runs at `gameplay.tscn` load time and the `CONNECT_ONE_SHOT` is armed — this is the same code path as first-run, with no special-casing needed.

---

## Out of Scope

- Story 002: The fade-in Tween, state machine transitions, and input blackout timer
- Story 003: The `_unhandled_input` filter logic and dismiss path
- Story 004: `AudioManager.fade_out_all()` call and the COVER_READY_TIMEOUT safety timer
- Story 005: Visual layout (scene root, ColorRect, TextureRect, missing-PNG fallback)

---

## QA Test Cases

*Integration — automated (`tests/integration/final-epilogue-screen/fes_pre_instance_test.gd`):*

- **AC-TRIGGER-1**: `gameplay_root.gd` calls `save_now()` on `final_memory_ready`; FES reveal is gated on `epilogue_cover_ready`
  - Given: MUT save state with `discovered_count == required_count - 1`; FES pre-instanced; SaveSystem spy connected
  - When: final recipe is triggered, causing MUT to emit `final_memory_ready`
  - Then: `SaveSystem.save_now()` is called exactly once; FES `modulate.a` remains 0.0 until `epilogue_cover_ready` is subsequently emitted; after `epilogue_cover_ready`, FES Tween starts within 1 frame
  - Edge cases: emitting `final_memory_ready` twice must not call `save_now()` twice; `epilogue_cover_ready` emitted before `final_memory_ready` must still be handled by FES (CONNECT_ONE_SHOT already armed at `_ready()`)

- **AC-TRIGGER-2**: Relaunch-after-completion path
  - Given: save file with `_final_memory_earned = true` and `resume_index == manifest.size()`; FES pre-instanced via gameplay.tscn
  - When: app starts; `gameplay_root._ready()` runs; `game_start_requested` is emitted
  - Then: SM emits `epilogue_started()` exactly once; STUI begins amber cover; `epilogue_cover_ready` fires; FES `modulate.a` transitions from 0 to 1 over `FADE_IN_DURATION`
  - Edge cases: `EventBus.final_memory_ready.get_connections()` must contain no SM callback (SM does not re-subscribe on resume)

- **AC-ONESHOT-1**: `CONNECT_ONE_SHOT` — triple emission is a no-op after first
  - Given: FES is in Armed state; `_on_epilogue_cover_ready` spy counting invocations
  - When: `EventBus.epilogue_cover_ready.emit()` is called three times in succession (within same frame or sequential frames)
  - Then: `_on_epilogue_cover_ready` is invoked exactly once; FES transitions `Armed → Loading` exactly once; `modulate.a` Tween starts exactly once
  - Edge cases: Tween must not be created twice; second/third emissions must produce no visible state change

- **AC-ONESHOT-2**: FES writes no persistent state
  - Given: save file snapshot taken (bitwise) immediately before `epilogue_cover_ready` is emitted
  - When: FES receives `epilogue_cover_ready`, begins fade-in; mid-reveal: force-terminate process (simulate crash by calling `get_tree().quit()` prematurely in test harness)
  - Then: re-read save file; assert bitwise identical to pre-FES snapshot
  - Edge cases: `user://save.tres` must not be touched; no `.remap` sidecar must be created

- **AC-FAIL-1**: `is_final_memory_earned()` returns false → quit within 1 frame
  - Given: MUT state with `_final_memory_earned = false`; FES scene instantiated directly (bypassing normal epilogue path)
  - When: FES `_ready()` runs
  - Then: stderr contains the error string (e.g. "FES: is_final_memory_earned() returned false — ordering bug"); `get_tree().quit()` is called within 1 frame; `modulate.a` remains 0.0 (no partial render)
  - Edge cases: no Tween must be created; no `epilogue_cover_ready` connection must be established before quit is called

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/final-epilogue-screen/fes_pre_instance_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (this is the foundation story for the epic)
- Unlocks: Story 002 (Reveal state machine and fade-in)
