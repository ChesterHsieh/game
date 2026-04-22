# HUD Design

> **Status**: In Design
> **Author**: Chester + ux-designer
> **Last Updated**: 2026-04-21
> **Template**: HUD Design
> **Input Methods**: Keyboard/Mouse only
> **Art Bible**: `design/art/art-bible.md` Sections 1–4 locked

---

## HUD Philosophy

**Adaptive minimal — the table leads, the HUD whispers.**

Cards are the primary information layer. The HUD adapts per scene type:

- **Bar-goal scenes** (`sustain_both`): Two unlabelled status rings track progress;
  ambient hint arcs emerge after stalling (>5 min). Rings are the only persistent overlay.
- **Non-bar-goal scenes** (`find_key`, `sequence`): A different visual goal indicator
  replaces the rings — silhouette slots, sequence markers, or similar. Resolved per
  goal type during Vertical Slice implementation.
- **All scenes**: A subtle, non-text goal progress cue exists on screen so the player
  has a sense of "how far along am I" without words.

No numeric readouts, no text labels, no minimap. A pause/settings access point exists
but visually recedes into the table. Information is communicated through card behavior
(snap/push), fill levels, and ambient visual cues — never through annotation.

---

## Information Architecture

### Full Information Inventory

| # | Information Item | Source GDD | Update Frequency |
|---|---|---|---|
| 1 | Card faces (label + circular art + optional badge) | card-visual | On spawn / state change |
| 2 | Card interaction state (idle / dragged / snap / push) | card-engine → card-visual | Real-time during drag |
| 3 | Status ring fill (bar A) | status-bar-ui | On `bar_values_changed` |
| 4 | Status ring fill (bar B) | status-bar-ui | On `bar_values_changed` |
| 5 | Hint arc opacity (Level 0/1/2) | hint-system → status-bar-ui | On `hint_level_changed` |
| 6 | Non-bar goal indicator | scene-goal-system | Per scene load |
| 7 | Scene progress sense (ambient "how far") | scene-goal-system | Gradual / event-driven |
| 8 | Pause / Settings access point | (implied — no GDD yet) | Static |
| 9 | Scene transition overlay | scene-transition-ui | On scene change |
| 10 | Final illustrated memory | final-epilogue-screen | One-time endgame event |

### Categorization

| Category | Items | Rationale |
|---|---|---|
| **Must Show** | Cards on table (#1); Pause/Settings (#8) | Cards ARE the game. Pause must always be reachable. |
| **Contextual** | Status ring fill (#3, #4); Hint arcs (#5); Non-bar goal indicator (#6); Scene progress (#7); Card state feedback (#2) | Appear only in relevant scenes or during interaction. Rings only in bar-goal scenes; arcs only after stalling; card state only during drag. |
| **Hidden** | Scene transition (#9); Final memory (#10) | Triggered by game events, not player-queryable. Full-screen takeovers, not HUD elements. |
| **On Demand** | (none) | No toggle-able overlays exist. Consistent with Pillar 3 — nothing is hidden behind a button press. |

**Philosophy alignment check**: Must Show list has exactly 2 items (cards + pause).
This is consistent with "adaptive minimal" — the table IS the interface, and only
a single chrome element (pause) persists.

---

## Layout Zones

```
┌──────────────────────────────────────────────────────────────┐
│ [A] Status    │                                    [C] Pause │
│  Ring A       │                                        ⚙     │
│  Ring B       │                                              │
│               │                                              │
│               │           [B] CARD TABLE                     │
│               │        (full remaining area)                 │
│               │                                              │
│               │       Cards sit, dragged, snap,              │
│               │       push-away here                         │
│               │                                              │
│               │                                              │
└──────────────────────────────────────────────────────────────┘
```

| Zone | Position | Size | Content |
|---|---|---|---|
| **A — Goal Panel** | Top-left corner, inset 24px from table border | ~120×280px (stacks 2 rings vertically; adapts to 1 ring or non-ring indicator) | Status rings + hint arcs (bar-goal scenes) OR non-bar goal indicator |
| **B — Card Table** | Remaining area after A and C | Fills viewport minus panel/chrome | All cards. No fixed grid — cards are freely placed by Card Engine / player drag. |
| **C — Pause Chrome** | Top-right corner, inset 24px from table border | Single icon, ~32×32px | Pause / settings gear. Warm Grey `#A09080`, 40% opacity at rest — fades to 80% on hover. |

**Zone hierarchy** (visual priority): B (cards) > A (goal panel) > C (pause).
Cards always draw above the table. Goal panel draws above table but below cards
if they overlap. Pause chrome is the lowest-priority visual element.

**Non-bar-goal scenes**: Zone A adapts. When `get_goal_config()` returns `find_key`
or `sequence`, the ring sub-elements are hidden and a goal-type-specific indicator
replaces them. Shape and content of this indicator is an open question — resolved
during Vertical Slice when those goal types are prototyped.

---

## HUD Elements

### Element 1: Status Ring (×2, bar-goal scenes only)

| Field | Value |
|---|---|
| **Category** | Contextual (bar-goal scenes only) |
| **Visual form** | Circular ring per art bible §3.3 — 48px diameter, 4px stroke |
| **Fill treatment** | Opacity ramp 70%→100% per art bible §4.4 |
| **Ring stroke color** | Warm Grey `#A09080` (from art bible §4) |
| **Ring fill color** | Warm — exact tone resolved in prototype (art bible says "warm, not gamey") |
| **Update behavior** | Event-driven: tweens on `bar_values_changed` per status-bar-ui GDD |
| **Empty ring** | Stroke only, no fill |
| **Full ring** | 100% opacity fill — no celebration particle, no flash |
| **Position within Zone A** | Stacked vertically, 16px gap between rings |
| **Label** | None. Ever. (Pillar 3) |

### Element 2: Hint Arc (per ring, ambient cue)

| Field | Value |
|---|---|
| **Category** | Contextual (appears >5 min stall only) |
| **Visual form** | 270° counterclockwise arc, 3px stroke, gap bottom-right (art bible §3.4) |
| **Color** | Warm Grey `#B0A090`, 25% opacity cap (art bible §2 + §4) |
| **Fade-in** | 0%→25% opacity over 8 seconds (art bible §2.9) |
| **Levels** | L0 = hidden; L1 = faint (25%); L2 = full (100%) |
| **Update behavior** | Event-driven: on `hint_level_changed` |

### Element 3: Non-Bar Goal Indicator (non-bar scenes)

| Field | Value |
|---|---|
| **Category** | Contextual (non-bar-goal scenes only) |
| **Visual form** | **Open question** — silhouette slots, sequence dots, or mystery card shapes. Depends on goal type (`find_key`, `sequence`). |
| **Position** | Zone A, replaces rings |
| **Update behavior** | Event-driven: on goal-related signals |
| **Design status** | Deferred to Vertical Slice — goal types beyond `sustain_both` are not yet prototyped |

### Element 4: Pause / Settings

| Field | Value |
|---|---|
| **Category** | Must Show (always accessible) |
| **Visual form** | Small gear icon, 32×32px, soft painterly rendering matching art bible §1 |
| **Color** | Warm Grey `#A09080`, 40% opacity at rest |
| **Hover state** | Fades to 80% opacity over 0.2s |
| **Click action** | Opens settings/pause overlay (settings screen UX spec — not yet authored) |
| **Keyboard shortcut** | `Esc` opens same overlay |
| **Position** | Zone C — top-right, inset 24px |

### Element 5: Cards on Table

| Field | Value |
|---|---|
| **Category** | Must Show (the game itself) |
| **Visual form** | Per card-visual GDD: 120×160px, double border, cream ground, circular art, label strip |
| **Position** | Zone B — freely placed by Card Engine |
| **Z-order** | Dragged card on top; others by spawn order |
| **Update behavior** | Real-time: position from Card Engine, visual state from card state enum |
| **Interaction** | Mouse drag. See card-engine GDD for snap/push mechanics. |

---

## Dynamic Behaviors

| Trigger | What Changes | Duration |
|---|---|---|
| Scene loads as `sustain_both` | Zone A shows 2 status rings (or 1 if scene JSON defines 1 bar) | Instant on scene ready |
| Scene loads as `find_key` / `sequence` | Zone A shows non-bar goal indicator instead of rings | Instant on scene ready |
| `bar_values_changed` signal | Ring fill tweens to new level | `bar_tween_sec` (tuning knob, default 0.3s) |
| `hint_level_changed(1)` | Hint arcs fade in to 25% opacity around rings | 8s ease-in |
| `hint_level_changed(2)` | Hint arcs increase to 100% opacity | `arc_fade_sec` (tuning knob) |
| `hint_level_changed(0)` | Hint arcs fade to hidden | `arc_fade_sec` |
| `win_condition_met` | Rings freeze; scene win sequence begins (art bible §2.10) | 1.5s warm overlay |
| Card dragged | Dragged card gains glow + lift (art bible §2.2); table dims 10% | Duration of drag |
| Magnetic snap | Snap ring (64px, gold `#F5E0A0`) expands and dissolves (art bible §2.3) | 0.4s |
| Push-away | 1-frame desaturation on both cards; 16px repel (art bible §2.4) | 0.25s ease-out |
| Mouse hovers pause icon | Icon fades from 40%→80% opacity | 0.2s |

**HUD density never changes mid-scene.** Zone A content is set at scene load and
does not toggle during gameplay. This is a deliberate simplification — no adaptive
HUD switching during play.

---

## Platform & Input Variants

| Platform | Input | Notes |
|---|---|---|
| **PC (primary)** | Mouse + Keyboard | Mouse: drag cards, hover pause icon. Keyboard: `Esc` for pause. No other keyboard shortcuts for HUD interaction. |
| Mobile / Gamepad | Not supported | If added later, touch drag maps 1:1 to mouse drag. Gamepad would need a cursor mode for card selection — not designed here. |

**Aspect ratio**: Target 16:9. Zone A and C inset from table border (24px) — scale
with viewport. Cards in Zone B are freely placed so no layout breaks at different ratios.
At 4:3, Zone A may overlap card space — acceptable given low card density (~20 cards max).

---

## Accessibility

**Accessibility tier**: Not yet committed (`design/accessibility-requirements.md` does not exist).
The following baseline is designed for a "Basic" tier:

| Requirement | Status | Notes |
|---|---|---|
| Keyboard-only navigation | Partial | `Esc` for pause. No keyboard card interaction designed (mouse-only for drag). |
| Focus indicators | N/A | No focusable HUD elements — pause icon is mouse-hover only. If keyboard nav added, focus ring needed. |
| Text contrast | N/A | No text in HUD during gameplay. Settings menu text contrast is an art-bible open question (§4.3). |
| Color-independent info | Pass | Status rings use opacity ramp not hue. Hint arcs use shape (arc) + opacity. No color-only signaling. |
| Screen reader | Not designed | Game is inherently visual — card art, ring fill, ambient arcs. Screen reader support would require fundamental redesign. |
| Reduced motion | Not designed | All animations are subtle (0.2–0.4s tweens). Consider a reduced-motion toggle that disables glow/arc animations if needed. |

**Open**: Full accessibility spec deferred until `design/accessibility-requirements.md`
commits a tier. Current HUD design does not block any tier choice.

---

## Open Questions

1. **Non-bar goal indicator shape** — `find_key` and `sequence` goal types need a
   visual indicator in Zone A. Resolve during Vertical Slice when those goal types
   are prototyped. Candidates: silhouette card slots, sequence dots, mystery icons.

2. **Ring fill color** — Art bible §4 says "warm, not gamey" but does not commit a
   hex value for the ring interior fill. Resolve in prototype — test 2–3 warm tones
   against the ring stroke color (`#A09080`).

3. **1 ring vs. 2 rings layout** — Status-bar-ui GDD allows 1-bar scenes. Zone A
   layout should center a single ring when only one exists. Confirm in implementation.

4. **Pause overlay / settings screen** — Clicking the pause icon opens a settings
   overlay. No UX spec exists for this screen yet. Author `design/ux/settings.md`
   before Production.

5. **Scene progress "how far" cue** — HUD Philosophy says "a subtle, non-text goal
   progress cue exists on screen." For bar-goal scenes, the ring fill IS this cue.
   For non-bar scenes, this cue is undefined. Resolve with the non-bar goal indicator.

6. **Keyboard card interaction** — Current design is mouse-only for card drag. If
   accessibility tier requires keyboard-only play, a card selection + combine system
   would need to be designed. Flag for accessibility-requirements decision.
