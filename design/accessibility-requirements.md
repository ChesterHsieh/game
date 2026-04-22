# Accessibility Requirements

> **Status**: Committed
> **Tier**: Basic
> **Last Updated**: 2026-04-21
> **Game**: Moments (2D card-discovery, PC, Keyboard/Mouse only)
> **Target Audience**: Single player (Ju — Chester's girlfriend)

---

## Committed Tier: Basic

**What "Basic" means for Moments:**

| Requirement | Status | Notes |
|---|---|---|
| **Input remapping** | Required | Mouse-primary game. Allow rebinding of `Esc` (pause) and any future keyboard shortcuts. Card drag is mouse-only — no remapping needed for drag. |
| **Subtitles / text alternatives** | Not applicable | Game has no spoken dialogue. Card labels are always visible. No voiceover. |
| **Pause accessible** | Required | `Esc` key always opens pause overlay. Pause icon always visible on screen (top-right, Zone C). |
| **No time-critical inputs** | Pass by design | No fail states, no timers that punish. Hint arcs are passive guidance, not countdowns. |
| **Colorblind safety** | Pass by design | No color-only information signaling. Status rings use opacity ramp. Hint arcs use shape + opacity. See art bible §4.6 for full analysis. |

---

## What Basic Does NOT Include (deferred / out of scope)

| Feature | Tier Required | Notes for Moments |
|---|---|---|
| Scalable UI | Standard | Cards are fixed 120×160px baseline. Ring is 48px diameter. If Ju has trouble seeing them, adjust in code — no UI scaling system needed for audience of one. |
| Colorblind modes (toggle) | Standard | Not needed — no color-only signaling exists. |
| Motor accessibility | Comprehensive | Mouse drag is the core mechanic. Alternative input (keyboard card selection, switch access) would require fundamental redesign and is out of scope for a gift project. |
| Screen reader | Comprehensive | Game is inherently visual. Not feasible without redesigning the core loop. |
| Reduced motion toggle | Standard | All animations are subtle (0.2–0.4s). If Ju reports discomfort, add a toggle in settings to disable glow/arc fade animations. |

---

## Accessibility in Existing Specs

- **Art bible §4.6**: Colorblind safety analysis — 4 pairs checked, all low-risk, each with shape/motion backup.
- **HUD spec**: Accessibility section documents current state against Basic tier. No blockers.
- **Settings screen**: Not yet specced. When authored, must include: input remapping section, pause keybind display.
