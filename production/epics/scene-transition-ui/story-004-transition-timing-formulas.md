# Story 004: Transition timing formulas

> **Epic**: Scene Transition UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-transition-ui.md`
**Requirements**: `TR-scene-transition-ui-006`, `TR-scene-transition-ui-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-004: Runtime Scene Composition
**ADR Decision Summary**: ADR-004 §2 establishes STUI as a CanvasLayer scene with `process_mode = PROCESS_MODE_ALWAYS`. All tuning knobs are externally configurable; hardcoded values are forbidden per `coding-standards.md`. The Polygon2D vertex deformation and audio pitch variation are driven by per-transition random draws seeded fresh each transition.

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

- [ ] **AC-011** Formula 1 clamp: when `Σ D_i < T_MIN` (1700ms) all phases scale up to reach T_MIN; when `Σ D_i > T_MAX` (2200ms) scale down to T_MAX. Epilogue hold is excluded from the clamp.
- [ ] **AC-012** Formula 3: with `S_range = 4.0` and `r_p = 1.0`, resolved pitch equals `2^(4/12) ≈ 1.2599` (±0.001 tolerance). With `r_p = -1.0`, resolved pitch equals `2^(-4/12) ≈ 0.7937`. With `reduced_motion = true`, pitch is exactly 1.0.
- [ ] **AC-013** Formula 4 anchor: paper-breathe alpha at `t = 0` in HOLDING equals exactly 1.0; alpha remains in `[1.0 - A, 1.0]` for all t.

---

## Implementation Notes

*Derived from ADR-004 and GDD Formulas section:*

### Formula 1 — Per-Transition Phase Duration with Clamp

```
D_i      = D_i_nom + r_i * V_i          for each phase i (rise, hold, fade)
T_total  = Σ D_i
if T_total > T_MAX: scale = T_MAX / T_total; D_i *= scale for all i
if T_total < T_MIN: scale = T_MIN / T_total; D_i *= scale for all i
```

- Nominal values: rise=400ms, hold=1000ms, fade=500ms; variation: rise±80, hold±150, fade±80.
- `T_MIN = 1700`, `T_MAX = 2200` (default tuning knobs; configurable via export vars).
- `r_i` values are uniform draws in `[-1.0, 1.0]` seeded fresh at each transition start. Use `randf_range(-1.0, 1.0)` for each phase independently.
- **Clamp applies only to the standard path.** The reduced-motion path uses fixed durations and is not subject to `T_MIN`/`T_MAX` (GDD Formula 1, Clamp section).
- **Epilogue variant scaling**: rise and fade nominals (`D_i_nom`) scale by `epilogue_time_scale` (default 1.35×) before variation is applied. Variation ranges (`V_i`) do not scale. Epilogue hold is open-ended — excluded from both the `T_MIN/T_MAX` clamp and the epilogue scaling.
- **Joint knob constraint**: `Σ(D_i_nom − V_i) ≥ T_MIN` and `Σ(D_i_nom + V_i) ≤ T_MAX + 100` must hold. Log a warning at `_ready()` if the loaded knobs violate this constraint.

### Formula 2 — Curl Peak Rotation

```
θ = θ_nom + r_θ * V_θ
```

- Defaults: `θ_nom = 4.0°`, `V_θ = 1.5°`. Resolved range at defaults: `[2.5°, 5.5°]`.
- Applied as rotation of the leading-edge vertices of the Polygon2D at the curl sweep peak (~300ms = `curl_peak_time_frac * rise_duration` into the rise phase).
- **Reduced-motion path**: `θ = 0.0` — formula is not evaluated; Polygon2D stays flat.

### Formula 3 — Audio Pitch Scale (true semitone math)

```
p = 2^(r_p * S_range / 12)
```

- Defaults: `S_range = 4.0`. At `r_p = 1.0`: `p = 2^(4/12) ≈ 1.2599`. At `r_p = -1.0`: `p = 2^(-4/12) ≈ 0.7937`.
- Applied as `AudioStreamPlayer.pitch_scale = p` on the `RustleAudio` node at transition start.
- **Not linear interpolation** — the GDD explicitly rejects `±0.04 linear` as factually wrong for a ±4-semitone intent.
- **Reduced-motion path**: `p = 1.0` (forced; `r_p` is not drawn).

### Formula 4 — Paper-Breathe Alpha Modulation

```
α(t) = α_base - A * (1 - cos(2π * t / P)) / 2
```

- `α_base = 1.0` (always), `A = breathe_amplitude_nominal` (default 0.03, per-transition variation ±0.01), `P = breathe_period_sec` (default 0.7s), `t` = seconds since entering HOLDING.
- The `(1 - cos)/2` form ensures `α(0) = 1.0` exactly (no jump at HOLDING entry) and keeps the pulse nonneg.
- Implemented as a `_process` or Tween-based oscillator active only during `State.HOLDING`. Disable (set `A = 0`) on reduced-motion path and in EPILOGUE state.
- Alpha must remain in `[1.0 - A, 1.0]` for all `t` — enforced by the formula itself given `A ≤ 1.0`.

---

## Out of Scope

- Story 001: state machine transitions, signal subscriptions
- Story 002: scene instancing, Polygon2D geometry construction
- Story 003: cancel_drag(), InputBlocker mouse_filter management
- Story 005: epilogue variant full behaviour, FIRST_REVEAL, epilogue_cover_ready emission
- Story 006: transition-variants.tres config loading, reduced-motion path activation

---

## QA Test Cases

*Logic — automated (`tests/unit/scene-transition-ui/stui_formulas_test.gd`):*

- **AC-011**: Formula 1 clamp — scale up when below T_MIN
  - Given: Knobs configured so that `D_rise = 320ms`, `D_hold = 850ms`, `D_fade = 420ms` (Σ = 1590ms, below T_MIN=1700)
  - When: `_resolve_phase_durations()` is called with those inputs
  - Then: Each phase is scaled by `1700 / 1590 ≈ 1.0692`; `D_rise ≈ 342ms`, `D_hold ≈ 908ms`, `D_fade ≈ 449ms`; total = 1700ms (±1ms rounding tolerance)
  - Edge cases: Exact T_MIN boundary (Σ = 1700) — no scaling applied

- **AC-011**: Formula 1 clamp — scale down when above T_MAX
  - Given: Knobs configured so that `D_rise = 480ms`, `D_hold = 1150ms`, `D_fade = 580ms` (Σ = 2210ms, above T_MAX=2200)
  - When: `_resolve_phase_durations()` is called
  - Then: Each phase scaled by `2200 / 2210 ≈ 0.9955`; total = 2200ms (±1ms)
  - Edge cases: Σ = 2200 (exact ceiling) — no scaling; epilogue hold value passed in must be ignored by clamp

- **AC-012**: Formula 3 pitch — r_p=1.0, S_range=4.0
  - Given: `S_range = 4.0`, `r_p = 1.0`
  - When: `_compute_pitch_scale(r_p, S_range)` is called
  - Then: Returns value within `[1.2599 - 0.001, 1.2599 + 0.001]`
  - Edge cases: `r_p = 0.0` → returns exactly 1.0 (`2^0 = 1`)

- **AC-012**: Formula 3 pitch — r_p=-1.0
  - Given: `S_range = 4.0`, `r_p = -1.0`
  - When: `_compute_pitch_scale(r_p, S_range)` is called
  - Then: Returns value within `[0.7937 - 0.001, 0.7937 + 0.001]`
  - Edge cases: `S_range = 0.0` → returns exactly 1.0 for any r_p

- **AC-012**: Formula 3 pitch — reduced_motion locks to 1.0
  - Given: `reduced_motion = true`, any `r_p`, any `S_range`
  - When: `_compute_pitch_scale(r_p, S_range)` is called with `reduced_motion` active
  - Then: Returns exactly 1.0
  - Edge cases: Verify pitch_scale is not drawn even partially before being overridden

- **AC-013**: Formula 4 breathe anchor at t=0
  - Given: `A = 0.03`, `P = 0.7`, `t = 0.0`
  - When: `_compute_breathe_alpha(0.0, 0.03, 0.7)` is called
  - Then: Returns exactly 1.0 (cos(0) = 1.0; `(1-1)/2 = 0`; `1.0 - 0 = 1.0`)
  - Edge cases: `A = 0.0` → always returns 1.0 for any t

- **AC-013**: Formula 4 breathe range
  - Given: `A = 0.03`, `P = 0.7`; test t values: 0.0, 0.175, 0.35, 0.525, 0.7 (one full period)
  - When: `_compute_breathe_alpha(t, A, P)` is called for each t
  - Then: All returned values fall within `[1.0 - A, 1.0]` = `[0.97, 1.0]`; minimum value occurs at `t = P/2 = 0.35s` and equals `1.0 - A = 0.97`
  - Edge cases: `A = 0.08` (max knob value) → floor is `0.92`; must still be `≥ 0.92`

- **Formula 2 curl rotation — defaults**:
  - Given: `θ_nom = 4.0`, `V_θ = 1.5`, `r_θ = -0.4`
  - When: `_compute_curl_rotation(-0.4, 4.0, 1.5)` is called
  - Then: Returns `3.4` (±0.001)
  - Edge cases: `reduced_motion = true` → returns exactly `0.0`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scene-transition-ui/stui_formulas_test.gd` (automated, must pass)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (input blocking and drag cancel)
- Unlocks: Story 005 (epilogue variant and FIRST_REVEAL)
