---
name: Art Bible authoring status — Moments
description: Tracks which art bible sections are locked/complete and key decisions made in each
type: project
---

Art bible lives at `design/art/art-bible.md`. Scope this pass: Sections 1–4. Sections 5–9 deferred until after Vertical Slice.

**Section 1 — Visual Identity Statement**: LOCKED
- One-line rule: "Would Ju recognize herself in this?"
- Three principles: Borrowed Architecture Painterly Soul / Recognition Before Decoration / Silence Over Annotation
- Open gap (to close in later sections): Pillar 2 (Interaction Is Expression) needs visual anchoring

**Section 2 — Mood & Atmosphere**: COMPLETE 2026-04-21
- 13 game states specified
- Table Idle baseline: `#C8B89A` table tint, 2px shadow at 15% opacity, no glow
- Magnetic Snap: 64px warm-gold ring `#F5E0A0`, 0.4s dissolve — small and sure, not celebratory
- Push-Away: 1-frame desaturation + 16px travel, no bounce — enforces no-fail-state anti-pillar
- Four templates distinguished by *what changes*, not hue: Additive (warmth arrives from outside), Merge (cool during convergence → warm on land), Animate (motion only, palette unchanged), Generator (drop shadow pulse at production interval)
- Final Illustrated Memory: only moment at full saturation — deliberate palette break signals arrival
- Scene Transition: fade through `#1A1510` (warm dark, not pure black)
- Ambient hint arcs: warm grey `#B0A090`, 25% opacity cap, 8s ease-in — always below gameplay in visual hierarchy

**Section 3 — Shape Language**: COMPLETE 2026-04-21
- Card: 120×160px baseline, 8px radius, double-border (1.5px outer `#C0AE9A` / 1px inner `#F0EAE0`), 2px gap
- Composition zones: subject (top 75%), label strip (bottom 25%, no cost/resource data), tiny corner accent
- Stack offset: 6px down, max 3 visible layers, compresses to 3px at 8+ cards
- Subject rule: centred, 55–65% of subject zone height, flat cream ground, silhouette-legible at 120px
- Status bars: circular rings, 72px OD, 6px stroke, clockwise fill in warm gold `#F5E0A0`
- Hint arc: 3px, 41px radius (ring OD + 5px), 270° counterclockwise, tapered ends
- Chrome: 2px table border `#B0A090` at 50%; utility buttons top-right, outside table, 30% idle opacity; no side panels
- Hierarchy rule: cards → rings → arcs → chrome
**Section 4 — Color System**: COMPLETE 2026-04-21
- Primary palette: 5 named colors (Parchment `#C8B89A`, Cream `#F5EDDF`, Dusk `#1A1510`, Warm Grey `#B0A090`, Honey Gold `#F5E0A0`)
- Per-scene strategy: HYBRID — cards/UI hold palette; backgrounds shift via CanvasModulate per chapter
- Hard-time chapter tint `#B0AEAD` is the only cool note in the game; all other chapter tints are warm
- Status ring: empty `#C0AE9A` at 40%, fill `#F5E0A0` scales 70%→100% opacity, stroke `#C0AE9A` at 100%
- One accent only: Honey Gold — means "something arrived that was expected"
- Prohibitions: pure black, pure white, any red, saturated primaries, cool neutrals outside hard-time chapter
- Open questions: card/table contrast at 1080p; hint arc vs cool chapter tint; partial ring fill floor opacity

**Why:** Art bible is the visual source of truth for a game with a target audience of one (Ju). Every decision is calibrated for recognition by her specifically.

**How to apply:** Before proposing any asset spec or visual system, check against Section 1 principles and Section 2 mood targets. Consistency with the Table Idle baseline is the default state — all other states are defined as departures from it.
