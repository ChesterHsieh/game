# Interaction Pattern Library

> **Status**: Initialized
> **Author**: Chester + ux-designer
> **Last Updated**: 2026-04-21
> **Input Methods**: Keyboard/Mouse only
> **Template**: Interaction Pattern Library

---

## Overview

Catalog of reusable interaction patterns across all screens in *Moments*. Each
pattern is named and described so UX specs reference them by name rather than
re-specifying behavior. New patterns are added as screens are designed.

This library is initialized with patterns already committed in existing GDDs and
the HUD spec. Full pattern formalization happens during Vertical Slice implementation.

---

## Pattern Catalog

| Pattern | Category | Used In | Status |
|---|---|---|---|
| Card Drag | Input | Gameplay (card-engine GDD) | Defined in GDD — awaiting UX formalization |
| Magnetic Snap | Feedback | Gameplay (card-engine GDD, art bible §2.3) | Defined in GDD + art bible |
| Push-Away | Feedback | Gameplay (card-engine GDD, art bible §2.4) | Defined in GDD + art bible |
| Ring Fill | Data Display | HUD — Zone A (status-bar-ui GDD, HUD spec) | Defined |
| Hint Arc Fade | Feedback | HUD — Zone A (hint-system GDD, art bible §2.9) | Defined |
| Scene Transition Fade | Navigation | Between scenes (scene-transition-ui GDD, art bible §2.11) | Defined in GDD + art bible |
| Hover Reveal | Input | Pause icon (HUD spec) | Defined |
| Template: Additive | Feedback | Gameplay (interaction-template-framework GDD, art bible §2.5) | Defined |
| Template: Merge | Feedback | Gameplay (ITF GDD, art bible §2.6) | Defined |
| Template: Animate | Feedback | Gameplay (ITF GDD, art bible §2.7) | Defined |
| Template: Generator | Feedback | Gameplay (ITF GDD, art bible §2.8) | Defined |

---

## Patterns

*Individual pattern entries will be formalized here as they are implemented.
Current definitions live in their source GDDs and the art bible — this library
will consolidate them into a single reference during Production.*

---

## Gaps & Patterns Needed

| Gap | Needed For | Priority |
|---|---|---|
| Settings / Pause overlay interaction | Settings screen (not yet specced) | Before Production |
| Non-bar goal indicator interaction | `find_key` / `sequence` scenes | Before Vertical Slice |
| Main Menu interaction | Main menu screen (not yet specced) | Before Vertical Slice |
| Card selection (keyboard) | Accessibility — if keyboard-only play is added | Deferred (Basic tier = not required) |

---

## Open Questions

1. Should each interaction template pattern (Additive/Merge/Animate/Generator) be
   formalized as a separate pattern entry, or grouped under a single "Template
   Execution" meta-pattern with variants?
2. Card Drag pattern needs sub-states documented: pickup → hold → approach target →
   snap zone entry → release. Formalize during card-engine implementation.
