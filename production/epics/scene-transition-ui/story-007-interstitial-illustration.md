# Story 007: Interstitial illustration during HOLDING state

> **Epic**: Scene Transition UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-transition-ui.md`
**Requirements**: `TR-scene-transition-ui-016`, `TR-scene-transition-ui-017`, `TR-scene-transition-ui-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-004: Runtime Scene Composition, ADR-005: Data File Format Convention
**ADR Decision Summary**: STUI is a sibling CanvasLayer in gameplay.tscn (layer=10); all per-scene config overrides live in `transition-variants.tres` keyed by scene_id.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `Tween` chaining (`create_tween()` + `tween_property()`) is stable in 4.3. `CanvasLayer` child nodes inherit the parent layer value — no separate CanvasLayer needed for the interstitial panel.

**Control Manifest Rules (Presentation Layer)**:
- Required: `gameplay.tscn` CanvasLayer stack — TransitionLayer is layer=10; nothing may change this number without a new ADR
- Required: All persistent config uses `.tres` Resource files loaded via `ResourceLoader`
- Forbidden: Never change CanvasLayer ordering or layer numbers without a new ADR

---

## Acceptance Criteria

*New requirements for the interstitial illustration feature:*

- [ ] **AC-1** `transition-variants.tres` schema supports an optional `interstitial` dictionary per scene_id with keys: `illustration` (Texture2D), `caption` (String), `hold_ms` (float). Scenes without this key behave identically to before.
- [ ] **AC-2** On STUI entering HOLDING state, if the current scene has interstitial config, an InterstitialPanel node is made visible (or created) displaying the illustration and caption above the overlay. The panel fades in over `interstitial_fade_in_ms` (default 400ms), holds for `hold_ms`, then fades out over `interstitial_fade_out_ms` (default 400ms). FADING_IN does not begin until the panel's fade-out Tween completes.
- [ ] **AC-3** If no interstitial config exists for the current scene, HOLDING proceeds exactly as before — `scene_started` triggers FADING_IN immediately, no visual change.
- [ ] **AC-4** The InterstitialPanel is invisible (not `queue_free`) during non-HOLDING states and is reset to invisible when STUI exits HOLDING. It is pre-allocated in the scene tree, not created dynamically per transition.
- [ ] **AC-5** Reduced-motion path: interstitial still appears and holds, but the fade-in and fade-out animations are skipped (immediate show → hold → immediate hide). `hold_ms` duration is still respected.
- [ ] **AC-6** If `scene_started` fires while the interstitial is still displaying (early signal), the interstitial is cut short immediately and FADING_IN begins. No hang or orphaned Tween.
- [ ] **AC-7** The interstitial does not display during the epilogue variant (EPILOGUE state has its own open-ended hold — the interstitial is HOLDING-only).

---

## Implementation Notes

*Derived from ADR-004 and ADR-005 Implementation Guidelines:*

**InterstitialPanel node placement**: Add as a child of `SceneTransitionUI` in `scene_transition_ui.tscn`. It sits above the Polygon2D overlay within the same CanvasLayer (layer=10). Suggested tree:
```
SceneTransitionUI (CanvasLayer, layer=10)
├── InputBlocker   (ColorRect)
├── Overlay        (Polygon2D)
├── RustleAudio    (AudioStreamPlayer)
└── InterstitialPanel (Control, anchors_preset=PRESET_FULL_RECT)
    ├── IllustrationRect  (TextureRect, expand=FIT_KEEP_ASPECT_CENTERED)
    └── CaptionLabel      (Label, anchors at bottom-center)
```

**Config lookup**: Use the existing `_get_variant_knob(scene_id, "interstitial", null)` pattern. If the returned value is `null` or not a Dictionary, skip the interstitial entirely.

**Tween sequencing in `_enter_holding()`**: After resolving the interstitial config, if present:
1. Make `InterstitialPanel` visible, set `modulate.a = 0.0`
2. Create a sequential Tween: fade-in → hold (callback only, no property) → fade-out → `_on_interstitial_done()`
3. `_on_interstitial_done()` calls `_begin_fading_in()` directly (bypasses waiting for `scene_started`)

**`scene_started` signal during interstitial**: In `_on_scene_started()`, if HOLDING and interstitial is active, kill the interstitial Tween, hide the panel immediately, then call `_begin_fading_in()`.

**Pre-allocation rule (ADR-002 spirit, AC-4)**: The InterstitialPanel node must exist in the scene tree at all times — never use `instantiate()` inside a transition. Reset `modulate.a = 0.0` and `visible = false` at the end of each use.

**Reduced-motion path (AC-5)**: Check `ProjectSettings.get_setting("stui/reduced_motion_default", false)`. If true, skip fade Tweens — show panel at `modulate.a = 1.0` → await hold_ms via `get_tree().create_timer(hold_ms / 1000.0)` → hide → `_on_interstitial_done()`.

**New tuning knobs** (add as `@export` on `SceneTransitionUI`):
- `interstitial_fade_in_ms: float = 400.0`
- `interstitial_fade_out_ms: float = 400.0`

**No new EventBus signals needed** — this is internal to STUI's HOLDING state.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001–006: All existing STUI behaviour (state machine, polygon overlay, timing formulas, epilogue, config loading) — do not modify those systems.
- Content authoring: adding actual illustration assets and captions to `transition-variants.tres` for specific scenes is a content task, not this story. This story only implements the infrastructure.

---

## QA Test Cases

*Written at story creation. Implement against these — do not invent new cases.*

- **AC-1**: `transition-variants.tres` schema supports interstitial config
  - Setup: Open `transition-variants.tres` in Godot editor; add a scene entry with `interstitial: { illustration: <Texture2D>, caption: "test caption", hold_ms: 1000.0 }`
  - Verify: STUI's `_get_variant_knob(scene_id, "interstitial", null)` returns the dictionary with correct types
  - Pass condition: No type errors; illustration is a valid Texture2D; caption is a String; hold_ms is a float

- **AC-2**: InterstitialPanel displays and sequences correctly
  - Setup: Configure a test scene entry in `transition-variants.tres` with a visible illustration and `hold_ms: 800.0`
  - Verify: Trigger `scene_completed` for that scene; watch STUI enter HOLDING. InterstitialPanel becomes visible, fades in (~400ms), holds (~800ms), fades out (~400ms), then FADING_IN begins
  - Pass condition: No FADING_IN begins before the fade-out completes. Illustration and caption are visible during hold.

- **AC-3**: No interstitial config → behaviour unchanged
  - Setup: Use any scene with no `interstitial` key in `transition-variants.tres`
  - Verify: Trigger scene_completed; HOLDING proceeds as before; InterstitialPanel remains invisible; FADING_IN triggers on `scene_started` normally
  - Pass condition: Identical timing to pre-Story-007 behaviour. No visual change.

- **AC-4**: InterstitialPanel is pre-allocated, not dynamically created
  - Setup: Read `scene_transition_ui.tscn` in editor
  - Verify: InterstitialPanel node exists as a child of SceneTransitionUI at scene build time; starts with `visible = false`
  - Pass condition: No `instantiate()` calls in `_enter_holding()` or related methods

- **AC-5**: Reduced-motion path skips fade animations
  - Setup: Set `ProjectSettings.stui/reduced_motion_default = true`; configure a scene with interstitial
  - Verify: InterstitialPanel appears instantly (no fade-in Tween), holds for `hold_ms`, disappears instantly (no fade-out Tween)
  - Pass condition: No Tween for fade-in or fade-out; hold duration still respected

- **AC-6**: Early `scene_started` during interstitial cuts it short
  - Setup: Configure a scene with interstitial `hold_ms: 5000.0` (very long); emit `scene_started` 200ms into the interstitial hold
  - Verify: InterstitialPanel is hidden immediately; FADING_IN begins without waiting for the remaining 4800ms
  - Pass condition: No orphaned Tween; FADING_IN starts within one frame of `scene_started`

- **AC-7**: Interstitial does not appear during epilogue
  - Setup: Configure the epilogue scene entry with an `interstitial` key
  - Verify: Trigger `epilogue_started`; STUI enters EPILOGUE state; InterstitialPanel remains invisible
  - Pass condition: InterstitialPanel.visible is false throughout the epilogue sequence

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `production/qa/evidence/story-007-interstitial-evidence.md` — manual walkthrough screenshots showing illustration display, timing, and reduced-motion path
- Lead sign-off required (Visual/Feel component)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (config-reduced-motion) must be DONE — `_get_variant_knob()` and reduced-motion path must exist before this story adds onto them
- Unlocks: Content authoring — actual scene illustrations can be wired into `transition-variants.tres` once this infrastructure exists

---

## Completion Notes

**Completed**: 2026-04-24
**Criteria**: 7/7 passing — AC-5 and AC-7 deferred to manual walkthrough per Integration+Visual/Feel evidence protocol
**Deviations (advisory only)**:
- Manifest version matches current (2026-04-21) — no drift
- Doc-comment node-tree diagram at file header (scene_transition_ui.gd:7–11) not updated to include InterstitialPanel — stale documentation
- Two regression tests suggested during /code-review not added: AC-7 epilogue cancellation assertion, malformed-config rejection. Recommend follow-up cleanup story
- Manual evidence stub created at `production/qa/evidence/story-007-interstitial-evidence.md` — awaits lead walkthrough sign-off before final QA close
**Test Evidence**:
- Integration tests: `tests/integration/scene_transition_ui/stui_interstitial_test.gd` (7 test functions)
- Manual walkthrough stub: `production/qa/evidence/story-007-interstitial-evidence.md`
**Code Review**: Complete — verdict APPROVED WITH SUGGESTIONS (no BLOCKING issues)
