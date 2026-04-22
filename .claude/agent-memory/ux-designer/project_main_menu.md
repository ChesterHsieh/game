---
name: Main Menu GDD — UX design in progress
description: UX decisions made for the Main Menu GDD (system #17), including input flow, focus model, button layout, hover affordances, and edge cases
type: project
---

Main Menu GDD (`design/gdd/main-menu.md`) is in the Detailed Design phase as of 2026-04-20.

**Why:** Single-player gift game for Ju. Scope is title + Start + Quit only. No settings, no continue, no animations. "Quiet tone" and "she waits on purpose" are the primary UX constraints.

**Decisions proposed/confirmed (pending Chester approval):**

- No auto-focus on load. Focus granted only on first Tab press (focus-on-first-tab pattern).
- No press-any-key-to-start. Menu is still; she decides when to move.
- Esc from Main Menu quits the application (PC affordance; no in-game conflict). Debounced.
- Start above Quit, vertical layout. Meaningful gap between buttons (~1 button height minimum).
- Hover state: color shift only, no motion. Active/pressed: brief darkening (<100ms), no animation.
- `_transitioning` boolean guard on Start to prevent double-activation.
- Esc ignored once `_transitioning = true` (transition is committed, no abort path).
- Main Menu is a separate Godot scene with no STUI instance — STUI only exists in the game scene.

**How to apply:** Use these decisions when authoring the Detailed Design, Edge Cases, and Acceptance Criteria sections of main-menu.md.
