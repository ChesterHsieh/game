# Evidence: Scene Transition UI — Epilogue + First-Reveal

**Story**: `production/epics/scene-transition-ui/story-005-epilogue-first-reveal.md`
**Type**: Visual/Feel
**Date**: 2026-04-23
**Sign-off**: [ ] Chester — pending manual verification

---

## Setup

Launch the game from `src/scenes/game.tscn`. Ensure SceneTransitionUI is
instanced at CanvasLayer layer=10. For the epilogue path, advance play until
`EventBus.epilogue_started` fires (all scene goals met + MUT final memory
earned).

## Verify — First-Reveal (boot)

1. On first frame, STUI overlay is opaque cream (Color approximately
   `Color(0.98, 0.95, 0.88, 1)`).
2. On the first `EventBus.scene_started` signal, STUI begins a
   `first_reveal_fade_ms` (1200ms default) alpha fade from 1.0 → 0.0.
3. No curl deformation, no SFX, no paper-breathe during this fade.
4. State machine enters IDLE at fade completion.

## Verify — Epilogue Amber

1. When `epilogue_started` fires, STUI enters EPILOGUE state.
2. Overlay tint is amber (approx `Color(1.0, 0.92, 0.78, 1)`), distinct from the
   standard cream tint.
3. Rise timing matches `epilogue_rise_ms` (slower than standard — nominally 1000ms).
4. Paper-breathe is disabled in EPILOGUE.
5. At full opacity, STUI emits `EventBus.epilogue_cover_ready()` exactly once.
6. State remains EPILOGUE indefinitely — no automatic fade-out.
7. `CONNECT_ONE_SHOT` is used on `epilogue_cover_ready` consumption side (FES).

## Pass Condition

- First-reveal fade is perceptibly smoother than default transition (no curl,
  no audio).
- Epilogue tint is distinctly warmer than the standard cream and the timing
  feels ~1.5x slower.
- `epilogue_cover_ready` is emitted once and only once.
- No visual artifact (pop, jitter) at state transitions.

## Screenshots (attach during manual verification)

- `screenshots/stui-first-reveal-frame-0.png` — opaque cream at boot
- `screenshots/stui-first-reveal-frame-mid.png` — mid-fade
- `screenshots/stui-epilogue-amber.png` — amber overlay at full opacity
- `screenshots/stui-state-transitions.mp4` — short clip of both flows

## Notes / Deviations

_To be filled in during manual verification._
