# Story 005: Epilogue variant and FIRST_REVEAL

> **Epic**: Scene Transition UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-transition-ui.md`
**Requirements**: `TR-scene-transition-ui-003`, `TR-scene-transition-ui-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-004: Runtime Scene Composition, ADR-003: Signal Bus
**ADR Decision Summary**: ADR-004 §4 defines the epilogue handoff sequence: STUI emits `EventBus.epilogue_cover_ready()` when the amber overlay reaches full opacity; FES (pre-instanced at layer=20 in Armed state) listens for this signal and reveals above STUI without a scene swap. ADR-003 requires that `epilogue_cover_ready` is declared in `event_bus.gd` before STUI emits it — this declaration already exists per ADR-003's 2026-04-21 expansion.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Tween API (`create_tween()`, `tween_property()`, `Tween.kill()`), `CanvasLayer`, `Polygon2D` vertex array write, `MOUSE_FILTER_STOP`/`MOUSE_FILTER_IGNORE`, `PROCESS_MODE_ALWAYS` all stable in 4.3. `CONNECT_ONE_SHOT` flag stable.

**Control Manifest Rules (Presentation Layer)**:
- Required: gameplay.tscn CanvasLayer stack — TransitionLayer at layer=10, EpilogueLayer at layer=20
- Required: STUI emits `epilogue_cover_ready` when amber cover reaches full opacity; FES waits on this
- Required: HudLayer hides itself on `epilogue_started`
- Forbidden: Never change CanvasLayer ordering without a new ADR
- Forbidden: Never call `change_scene_to_file` during epilogue handoff
- Forbidden: Never use `FileAccess` + JSON for data — use ResourceLoader + typed Resource

---

## Acceptance Criteria

*From GDD `design/gdd/scene-transition-ui.md`, scoped to this story:*

- [ ] **AC-006** `epilogue_started` in IDLE → EPILOGUE; after the rise Tween completes, `Overlay.modulate` carries amber tint and `EventBus.epilogue_cover_ready` is emitted exactly once.
- [ ] **AC-015** On first `scene_started` of a new session, STUI fades opaque cream to `alpha == 0.0` over `first_reveal_fade_ms` with no SFX, then enters IDLE.
- [ ] **AC-016** In EPILOGUE, paper-breathe is not applied (alpha constant at 1.0 throughout the open-ended hold).

---

## Implementation Notes

*Derived from ADR-004 §4, ADR-003, and GDD Core Rules 8 & 9:*

### Epilogue Variant (EPILOGUE state)

- On `EventBus.epilogue_started.emit()`: if STUI is in IDLE, enter `State.EPILOGUE` immediately. If STUI is mid-transition (FADING_OUT, HOLDING, or FADING_IN), finish the current rise to full opacity, then swap to amber tint and enter `EPILOGUE` (GDD Edge Case E-7, States table). EPILOGUE is a terminal state — no auto-fade.
- Rise and fade nominals scale by `epilogue_time_scale` (default 1.35×) before variation is applied. Variation ranges are unchanged (GDD Formula 1 — Epilogue variant scaling).
- Amber tint: `overlay.modulate = Color(1.0, 0.92, 0.78)` (GDD Core Rule 9, Tuning Knobs `overlay_color_amber`). Applied when the rise Tween completes — not at the moment `epilogue_started` fires.
- When the rise Tween completes and `overlay.modulate.a == 1.0`, emit `EventBus.epilogue_cover_ready.emit()` exactly once. Use `CONNECT_ONE_SHOT` when connecting the Tween's `finished` signal to the emit callback to enforce the one-shot contract (GDD TR-003). Log a warning if `epilogue_cover_ready` is ever about to be emitted a second time in the same session.
- Paper-breathe is disabled in EPILOGUE: `A = 0` → `α(t) = 1.0` constant throughout the open-ended hold (GDD Core Rule 9, AC-016).
- STUI holds in EPILOGUE indefinitely. It does not auto-fade. FES at layer=20 renders above STUI's amber overlay once FES receives `epilogue_cover_ready` and transitions from Armed to Loading to Ready (ADR-004 §4). STUI does not know about or coordinate with FES directly.
- `InputBlocker.mouse_filter = MOUSE_FILTER_STOP` during EPILOGUE — input remains blocked (GDD Core Rule 7).
- STUI must never call `change_scene_to_file` during the epilogue handoff (Control Manifest, Foundation Forbidden). `gameplay.tscn` remains loaded.

### FIRST_REVEAL state

- STUI begins in `State.FIRST_REVEAL` at game boot — not in IDLE. The Overlay starts fully opaque cream (`overlay.modulate.a = 1.0`, `overlay.modulate = Color(0.98, 0.95, 0.88)`) (GDD Core Rule 8).
- `InputBlocker.mouse_filter = MOUSE_FILTER_IGNORE` in FIRST_REVEAL — input is not blocked (the player has not interacted yet; there is nothing to cancel).
- On the first `EventBus.scene_started` signal received while in `State.FIRST_REVEAL`: start a Tween that animates `overlay.modulate.a` from 1.0 to 0.0 over `first_reveal_fade_ms` (default 1200ms). No SFX: `RustleAudio` does not play. No curl vertex deformation. Linear ease (no ease-in-quad/ease-out-cubic applied to FIRST_REVEAL).
- When the Tween completes: `overlay.modulate.a == 0.0`; enter `State.IDLE`. The FIRST_REVEAL → IDLE transition is one-shot only — it cannot be triggered again in the same session (GDD States table).
- If `scene_started` fires during FIRST_REVEAL while a fade Tween is already running, ignore the second signal (it is architecturally impossible in normal flow but safe to guard).

---

## Out of Scope

- Story 001: state machine enum, signal subscriptions, signal-storm guard
- Story 002: Polygon2D geometry, CanvasLayer instancing
- Story 003: cancel_drag(), InputBlocker mouse_filter transitions for standard states
- Story 004: Formula 1–4 math, timing clamp
- Story 006: transition-variants.tres config loading, reduced-motion path

---

## QA Test Cases

*Visual/Feel — manual (Chester sign-off required before Alpha):*

- **AC-006**: Epilogue transition reads as heavier and warmer
  - Setup: Use `_debug_force_transition()` to trigger `epilogue_started` from IDLE. The amber overlay should rise with 1.35× timing, reach full opacity, hold indefinitely. Confirm `epilogue_cover_ready` is emitted by watching the console debug log or FES response.
  - Verify: Overlay colour reads as distinctly warmer (amber) compared to a normal cream transition. Rise takes noticeably longer (~540ms vs ~400ms at nominal). Hold is indefinite — no auto-fade occurs.
  - Pass condition: Chester confirms the epilogue beat feels heavier and more emotionally charged than a normal page turn without any text, burst VFX, or celebration cue. `epilogue_cover_ready` appears exactly once in the log per epilogue trigger.

- **AC-015**: FIRST_REVEAL — opaque cream fades silently on first scene_started
  - Setup: Boot the game fresh (or force STUI into `State.FIRST_REVEAL` via debug seam). Confirm Overlay is fully opaque cream before `scene_started` fires.
  - When: The first scene's seed cards are placed and `scene_started` emits.
  - Verify: The overlay fades from fully opaque to invisible over ~1200ms (first_reveal_fade_ms). No rustle SFX plays. No curl deformation occurs on the Polygon2D. After fade, STUI is in IDLE.
  - Pass condition: Chester confirms the opening feels like a quiet, soft reveal — not a loading screen transition and not a page-turn. The silence is intentional.

- **AC-016**: EPILOGUE hold — alpha stays constant at 1.0
  - Setup: Trigger `epilogue_started`; let the rise Tween complete; observe the HOLDING phase.
  - Verify: For the duration of the open-ended hold, the Overlay alpha does not pulse or oscillate. `overlay.modulate.a` stays at exactly 1.0. There is no subtle breathing flicker (paper-breathe is disabled).
  - Pass condition: Amber overlay remains perfectly still and opaque for a minimum of 5 seconds of observation. Any perceptible alpha fluctuation is a failure.

- **AC-006 (logic assertion)**: epilogue_cover_ready emitted exactly once
  - Setup: Connect a counter to `EventBus.epilogue_cover_ready` before triggering epilogue.
  - When: Rise Tween completes.
  - Then: Counter equals exactly 1. A second `epilogue_started` cannot re-emit (EPILOGUE is terminal).
  - Pass condition: Counter equals 1 after one epilogue cycle; any count > 1 is a failure.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/stui-epilogue-first-reveal-evidence.md` (manual sign-off with Chester)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (transition timing formulas)
- Unlocks: Story 006 (config data and reduced-motion path)
