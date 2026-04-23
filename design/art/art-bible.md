# Moments — Art Bible

> **Status**: Authoring in progress (2026-04-21)
> **Scope this pass**: Visual Identity Core — Sections 1–4 only. Sections 5–9 deferred.
> **Engine**: Godot 4.3 (2D, CanvasItem / Node2D)
> **Source pillars**: `design/gdd/game-concept.md` — Recognition / Interaction / Discovery / Personal
> **Review mode**: lean (AD-ART-BIBLE sign-off will run at full completion, not at this pass)

---

## Reference Set (anchors for this pass)

| Reference | What we take | What we diverge from |
|---|---|---|
| **Stacklands** (screenshot) | Table-surface layout; card stacking grammar; small corner icons; hand-drawn background; uncluttered information layer | Card art is painterly not line-art; palette is warmer and more muted; no quest-list HUD |
| **Hand-painted owl card** (reference image) | Card face rendering: gouache-like soft paint, cream/beige palette, no hard outlines, centred subject, double-border card frame, intimate handcraft quality | — (this IS the card-art target) |

---

## Section 1 — Visual Identity Statement

### The One-Line Visual Rule

> **Every visual choice asks: would Ju recognize herself in this?**
> If yes, keep it. If it could belong to anyone else's story, remove it.

### Supporting Visual Principles

**1. Borrowed Architecture, Painterly Soul**

Take Stacklands' spatial grammar — small cards on an open table, stacking offset
layers, uncluttered negative space — but render every card face in the gouache-like
style of the hand-painted owl card: soft edges, cream grounds, no hard outlines,
warm muted palette.

*Design test:* When deciding how to render a card's subject, this principle says:
choose soft paint over line-art. The UI chrome (layout, stacking, table border)
follows Stacklands. The card face never does.

*Pillar linkage:* **Personal Over Polished** — line-art iconography reads as
generic game asset. Painterly soft rendering reads as made by hand, for one person.

**2. Recognition Before Decoration**

Every card label, card subject, and combination result is named and rendered to
maximise Ju's moment of "I know exactly what this is" — not to create beauty,
narrative mystery, or aesthetic interest for a stranger.

*Design test:* When a card's label is ambiguous between an evocative poetic phrase
and their actual inside joke, this principle says: use the inside joke. Legibility
to Ju beats legibility to anyone else.

*Pillar linkage:* **Recognition Over Reward** — the visual language carries the
same mandate as the design pillar. An unfamiliar player finding the game beautiful
is not the win condition. Ju laughing because she sees her own name for a thing is.

**3. Silence Over Annotation**

No status bar label, no tooltip, no instructional overlay. The only visual
information on screen is what a card is and what it does when touched. Ambient
cues — counterclockwise arcs, faint rings — appear only after time has passed.
The table breathes.

*Design test:* When a UI element's purpose is unclear to a first-time player,
this principle says: remove the text and trust the shape. If the shape is still
unclear, redesign the shape. Adding a label is never the first answer.

*Pillar linkage:* **Discovery Without Explanation** — visual silence is the direct
implementation of this pillar. A table without annotations feels like a private
space. That is the intended feeling.

### Why this direction

Stacklands proved the UI grammar works: open table, small cards, stacking offset,
hand-drawn background. We do not need to invent that layer. What Stacklands cannot
give us is intimacy — its line-art icons are efficient and warm, but they are for
everyone. The owl card reference is the counterweight: a specific rendering style
that signals "a person made this for you specifically." The tension between these
two references is not a problem to resolve — it is the creative brief. We borrow
Stacklands' architecture as infrastructure and place the owl card's rendering
language on top of it.

This game has a target audience of one. That is not a constraint on the visual
language; it is the entire point of it. Every principle above is calibrated not
for clarity at scale, but for recognition by a single person who will play this
once and feel it for a long time.

### Open gap (to address in later sections)

Pillar 2 (**Interaction Is Expression**) is not yet covered by a visual principle.
The four interaction templates (Additive / Merge / Animate / Generator) each
communicate a different emotional register; Section 2 (Mood & Atmosphere) and
Section 7 (UI/HUD Visual Direction, deferred) will define how the visual language
distinguishes them.

---

## Section 2 — Mood & Atmosphere

---

### Baseline Reference: Table Idle

Everything below is defined *relative to* this state. Know Table Idle, and you know what each shift means.

---

### State Mood Targets

---

**1. Table Idle**
- **Mood target**: A Sunday afternoon she doesn't know she'll remember.
- **Color temperature**: Warm neutral. Table: desaturated sage-green, slightly amber-shifted. Card faces: cream grounds with natural paper warmth.
- **Contrast**: Low. No element competes for attention. Background recedes; cards are present but unhurried.
- **Atmospheric descriptors**: still, inhabited, undemanding, familiar, late-afternoon.
- **Energy level**: Contemplative.
- **Visual carrier**: Table background tint `#C8B89A` (warm parchment); each card rests with a 2px drop shadow at 15% opacity, no glow. The table breathes by doing nothing.

---

**2. Drag Active**
- **Mood target**: Reaching for something you already know you want.
- **Color temperature**: Dragged card warms +8% saturation, cream shifts toward ivory. Table dims 10% behind it.
- **Contrast**: Lifted card reads against a slightly dimmed table — not spotlight, just presence.
- **Atmospheric descriptors**: intentional, suspended, quiet-tension, close, focused.
- **Energy level**: Measured.
- **Visual carrier**: Dragged card gains a 6px warm-white diffuse glow (no hard edge, 30% opacity). Table behind it dims via CanvasModulate at 90% brightness. The lifted card feels held, not clutched.

---

**3. Magnetic Snap (compatible)**
- **Mood target**: Recognizing someone across a crowded room — not surprise, but certainty.
- **Color temperature**: Sudden warm bloom — both cards pulse to a 2-frame ivory-gold flash, then settle to warm neutral. The flash is brief enough that you wonder if you imagined it.
- **Contrast**: High for exactly 4 frames (the flash), then returns to Table Idle contrast immediately.
- **Atmospheric descriptors**: electric, inevitable, tender, brief, held.
- **Energy level**: Suspended — one beat of held breath, then exhale.
- **Visual carrier**: A radial soft-glow ring (sprite, 64px radius, warm gold `#F5E0A0`, 60% → 0% opacity over 0.4s) expands from the snap point and dissolves. No particle noise. The ring feels like warmth spreading from a touched hand, not a celebration. Must be *small* and *sure*, not large and festive — this is the single most important visual event in the game.

---

**4. Push-Away (incompatible)**
- **Mood target**: Reaching for the wrong pocket.
- **Color temperature**: Cards briefly cool — a 1-frame blue-grey desaturation on both, then immediately warm back to Table Idle.
- **Contrast**: Unchanged from Table Idle.
- **Atmospheric descriptors**: gentle, mistaken, soft, unconcerned, returning.
- **Energy level**: Measured. The repel arc is smooth ease-out, not a bounce.
- **Visual carrier**: Both cards travel 16px apart on a 0.25s ease-out Tween, no glow, no particle. The only signal is the brief desaturation — the game shrugs and moves on.

---

**5. Template: Additive** *(both cards stay; new card spawns)*
- **Mood target**: The afternoon that somehow became three days.
- **Color temperature**: Spawn point glows warm amber before the new card appears — warmth that was always there, now made visible.
- **Atmospheric descriptors**: generous, expanding, unhurried, accumulating, soft.
- **Energy level**: Measured.
- **Visual carrier**: New card fades in over 0.6s from 0% opacity, scale 0.8→1.0. A warm-amber ring (48px, 40% → 0% opacity) pulses outward from spawn point. Existing cards remain still — they gave something, and it arrived.

---

**6. Template: Merge** *(two cards become one)*
- **Mood target**: The moment two separate things stopped having separate names.
- **Color temperature**: Both source cards shift cool-neutral as they converge — a brief loss of individual warmth — then the merged card arrives warmer than either source.
- **Atmospheric descriptors**: convergent, tender, final, inevitable, quiet.
- **Energy level**: Contemplative.
- **Visual carrier**: Source cards slide toward center on 0.4s ease-in, opacity dropping to 0% as they meet. Merged card appears at center with a 0.3s scale bloom (0.6→1.0) and a warm ivory glow that dissipates in 0.5s. Cooler during the journey, warmer at the arrival.

---

**7. Template: Animate** *(cards drift, orbit, move)*
- **Mood target**: A song she associates with a specific month, still playing.
- **Color temperature**: No shift from Table Idle — the movement IS the expression. Palette stays warm neutral.
- **Atmospheric descriptors**: recurring, drifting, looping, nostalgic, gentle.
- **Energy level**: Contemplative, with a slow pulse.
- **Visual carrier**: Orbiting cards carry a 2px warm-white trailing glow on the last 20% of their arc, fading to 0% at the arc's start point. Nothing flashes. The motion pattern itself signals that this memory keeps returning.

---

**8. Template: Generator** *(card slowly produces new cards over time)*
- **Mood target**: Noticing the coffee is always made before she wakes up.
- **Color temperature**: Generator card has a very slow warm pulse — one heartbeat per production interval (4–6s). Not a glow. A breathing.
- **Atmospheric descriptors**: patient, habitual, domestic, reliable, slow.
- **Energy level**: Suspended.
- **Visual carrier**: Generator card's drop shadow brightens from 15% to 35% opacity and back over the production interval. When a new card spawns, it uses the Additive spawn animation (fade-in + amber ring) for consistent vocabulary.

---

**9. Ambient Cue Emerges** *(hint arcs fade in after >5 min stall)*
- **Mood target**: A hand placed gently on a shoulder — not a tap.
- **Color temperature**: Arcs are warm grey `#B0A090` — they belong to the table, not the UI layer.
- **Atmospheric descriptors**: patient, surrounding, belonging, unhurried, quiet.
- **Energy level**: Contemplative. Arcs breathe at Table Idle rate; they do not pulse.
- **Visual carrier**: Counterclockwise arcs ease from 0% to 25% opacity over 8 seconds — slow enough that she may not notice the moment they arrived. 25% opacity cap keeps them permanently beneath gameplay in the visual hierarchy.

---

**10. Scene Win**
- **Mood target**: The last page of a letter.
- **Color temperature**: Full screen warms — CanvasModulate shifts to `#FFF5E0` (warm ivory) over 1.5s. Revealed card or image appears in full saturation against the warmed field.
- **Atmospheric descriptors**: completing, warm, quiet, arriving, full.
- **Energy level**: Suspended, then released.
- **Visual carrier**: Winning card or illustrated memory fades in center-screen, scale 0.9→1.0 over 0.8s. Surrounding cards dim to 40% opacity. No fanfare particles. The screen holds the moment for 2s before any prompt appears.

---

**11. Scene Transition**
- **Mood target**: Closing your eyes on a train, opening them somewhere else.
- **Color temperature**: Fade through `#1A1510` (warm dark — not pure black). Incoming scene arrives with a slight warm tone that settles to its baseline.
- **Atmospheric descriptors**: breathing, passing, interval, quiet, between.
- **Energy level**: Contemplative.
- **Visual carrier**: Full-screen alpha fade to `#1A1510` over 0.8s, hold 0.3s, fade in over 0.8s. No slide, no wipe. The warm dark is a held breath between chapters.

---

**12. Final Illustrated Memory (endgame)**
- **Mood target**: Seeing a photograph of a moment you lived but didn't notice you were living.
- **Color temperature**: The illustrated memory arrives in full saturation — the only image in the game that is *not* muted. After the entire game's warm-neutral palette, full saturation reads as arrival, not decoration.
- **Contrast**: High. The illustrated memory fills the screen. Everything else is gone.
- **Atmospheric descriptors**: full, still, seen, received, complete.
- **Energy level**: Suspended — the player receives, does not act.
- **Visual carrier**: The illustrated memory fades in over 2s from `#1A1510`, reaching 100% opacity with no other elements present. It holds indefinitely. A single warm-white vignette (radial, 20% opacity) at frame edges keeps it from reading as a gallery display — it should feel like a window, not a painting. This is the only moment in the game where color speaks at full volume.

---

**13. Main Menu**
- **Mood target**: Standing outside a door you haven't opened yet, knowing what's inside.
- **Color temperature**: Table Idle palette but slightly cooler and lower contrast — the warmth isn't earned yet.
- **Atmospheric descriptors**: anticipating, private, still, threshold, held.
- **Energy level**: Contemplative.
- **Visual carrier**: Table surface visible; one card face-down at center, no label. Title "Moments" in handwritten-style font, warm grey, no glow. The warmth of Table Idle is withheld here on purpose — it arrives only when she turns the first card.

---

### Mood Differentiation Summary: The Four Templates

| Template | Core shift from Table Idle | Distinguishing carrier |
|---|---|---|
| **Additive** | Warmth arrives from outside | New card fade-in + amber ring from spawn point |
| **Merge** | Cool during convergence, warm at arrival | Cards cool while moving; merged card warms on land |
| **Animate** | Movement as expression; palette unchanged | Trailing glow arc on the last 20% of orbit path |
| **Generator** | Slow breathing warmth on the source card | Drop shadow pulse at production interval |

Each template is distinguishable by *what changes* — origin of warmth, direction of card motion, or deliberate absence of palette shift — rather than by hue or intensity alone. This keeps all four legible under the same warm-neutral palette without introducing new colors.

---

## Section 3 — Shape Language

> **Baseline dimension**: all measurements pin to a **120×160px card** (portrait).
> This is the logical pixel size at 1× UI scale. Every number below scales proportionally
> with Godot's `UIScale` factor — never hardcode pixels in the renderer.

---

### 3.1 Card Shape

**Aspect ratio**: 3:4 portrait (120×160px baseline). Matches the owl reference card proportions.

**Corner radius**: 8px at 1× scale. Soft enough to read as handcrafted; firm enough to distinguish
the card as a discrete object against the table. Not a stadium (which reads as a token), not a
rectangle (which reads as a UI panel).

**Border**: Double-border, matching the owl reference.
- Outer border: 1.5px, warm grey `#C0AE9A` (one tone darker than card face cream).
- Inner border: 1px, pale warm white `#F0EAE0` (one tone lighter than card face cream).
- Gap between borders: 2px (filled with the card face cream ground `#F5EDDF`).
- Total border footprint: 7px inset from card edge to inner content area.
The double border signals "handmade object" without requiring a texture. It is the card's
single most legible frame element at thumbnail size.

**Card face composition zones** (measured from inner content area, 106×146px net):
- **Subject zone**: centered, spans the full inner width and top 75% of inner height (approx. 106×110px).
  Subject is painted directly into this zone — no sub-frame, no border, no background label behind it.
- **Label strip**: bottom 25% of inner height (approx. 106×36px). Warm cream ground, slightly darker
  than the subject zone (`#EDE4D4`). Card name in handwritten-style font, horizontally centered,
  vertically centered in the strip. No cost icon, no resource counter. Moments has no economy layer —
  the Stacklands bottom-strip pattern is present as a compositional anchor, not a data carrier.
- **Corner accent**: a single small decorative motif (2–4px, warm grey) at top-left corner, echoing
  the owl card's tiny accent. Purely ornamental — reinforces handcraft quality, never carries information.

**Stacking offset**: Each layer in a stack shifts 6px down and 0px horizontal from the layer below.
Maximum visible layers: 3 (the top card + 2 offset shadows behind it). A fourth card in the stack
renders the bottom two layers as a single merged shadow at 50% opacity. No "..." truncation label —
depth is communicated by the physical stack geometry, not by text. If a stack exceeds 8 cards,
the offset spacing compresses to 3px to keep the stack footprint from overflowing its table zone.

---

### 3.2 Subject Silhouette Philosophy

**Legibility at thumbnail**: Yes — every card subject must be identifiable from silhouette alone
at 120px card width. The owl is the baseline: a single centred shape, clear exterior contour,
no ambiguity about what it depicts. If a subject requires fine detail to be recognisable, the
composition is wrong — simplify the subject or increase its scale within the card face.

*Rationale: Pillar 2 (Recognition Before Decoration). At the table, Ju reads 6–12 cards simultaneously.
Recognition must happen pre-consciously, not via inspection.*

**Composition rule**: Centred. The subject sits at the horizontal and vertical centre of the subject
zone. Off-centre composition is not used — it imports a design-forward dynamism that competes with
the handcrafted intimacy target. The subject is simply *there*, the way a photograph on a shelf is
simply there.

**Subject scale**: Subject fills 55–65% of the subject zone height (60–72px at 1×). The owl
fills approximately 60% — that is the target. A subject smaller than 55% reads as lonely;
larger than 65% reads as crowded.

**Background treatment**: Flat cream ground (`#F5EDDF`) behind every subject. No gradient, no scenery,
no implied light source, no depth cues. The subject exists on a neutral field. This is a deliberate
*anti-realism* choice — the painting technique supplies warmth and texture; the background never does.

---

### 3.3 Status Bar Geometry

**Shape**: Circular ring (annular arc). Not a horizontal bar, not a vertical bar.

*Justification via Pillar 3 (Silence Over Annotation):* A horizontal or vertical bar carries the
spatial grammar of a progress bar — it implies direction, implies a start and end, and invites
labelling. A circular ring implies completeness and containment without implying a direction.
It is a shape without a default reading. Combined with the existing commitment to counterclockwise
hint arcs, a circular ring is the only geometry that the hint arc can orbit naturally — an arc
around a horizontal bar would look like an underline, not an embrace.

**Diameter**: 72px outer diameter at 1× scale. Two rings fit side-by-side on a 360px wide table
zone with 108px between centres — sufficient breathing room to prevent visual crowding.

**Stroke weight**: 6px. Thin enough to read as delicate; thick enough to hold the warm `#F5E0A0`
fill color against the table background at Table Idle contrast.

**Fill state**: Fill advances clockwise from 12 o'clock. Empty arc: warm grey `#C0AE9A` at 40%
opacity. Filled arc: warm gold `#F5E0A0` at 100% opacity. The fill color matches the Magnetic
Snap ring intentionally — both signal positive progress in the same visual language.

**Position**: Both rings sit in the lower-center of the table, horizontally centered, 24px above
the bottom edge of the visible table zone. They are the only non-card permanent elements on screen.

**Corner treatment**: N/A (circular). Stroke end treatment specified in 3.4.

---

### 3.4 Ambient Hint Arc Geometry

Building on locked commitments: counterclockwise, warm grey `#B0A090`, 25% opacity cap, 8s fade-in.

**Arc thickness**: 3px. Thinner than the status ring (6px) so the hint arc reads as a whisper
*around* the ring, not as a competing element. The 3:6 ratio (hint arc : ring) maintains clear
visual hierarchy.

**Arc radius**: Drawn at the outer edge of the status ring + 5px clearance. At 1× scale:
status ring outer radius is 36px; hint arc radius is 41px. The 5px gap creates a visible
separation that prevents the arc from merging with the ring fill at low opacity.

**Arc span**: 270° of the full circle (three-quarters), running counterclockwise from 12 o'clock
to 9 o'clock (i.e., the arc leaves the bottom-right quadrant open). The open quadrant faces
toward the card table — it does not fully encircle the ring, so it reads as approaching rather
than trapping. The 25% opacity cap ensures even the 270° arc remains ambient.

**Stroke end treatment**: Tapered. Both arc endpoints fade from full stroke weight (3px) to 0px
over the last 12° of the arc. This prevents hard termination points that would read as intentional
UI boundaries. The arc simply dissolves into the table at both ends.

---

### 3.5 UI Chrome Shapes

**Table surface border**: A single inset border, 2px, warm grey `#B0A090` at 50% opacity, inset
4px from the viewport edge. Softer than Stacklands' bright white border — the white border reads
as a game frame; this version reads as a surface edge, like the corner of a kitchen table visible
in a photograph. It defines the play space without announcing it.

**Utility controls (pause, settings, return to menu)**: Three icon buttons, positioned top-right
corner, 28×28px each at 1×, spaced 8px apart. They sit *outside* the table border — in the frame,
not on the table. This preserves the table as Ju's private space; controls are in the margin.
At Table Idle, buttons render at 30% opacity. On pointer hover, they rise to 80% opacity over
0.15s. They are present but undemanding.

**Icon shape grammar**: Soft and painterly, not utilitarian. Icons use 1.5px rounded strokes,
no fills, warm grey `#B0A090`. A pause icon is two vertical rounded-cap lines. A settings icon
is a simple circle with three evenly spaced exterior dots (no gear teeth — gear teeth are mechanical,
this game is not). A return-to-menu icon is a small house outline with a rounded roof. All icons
are designed to a 16×16px grid within their 28×28px button area, leaving a 6px soft margin.
They must not compete visually with card subjects — they exist in the margin for a reason.

**Side panels**: None. There is no HUD panel, no inventory sidebar, no recipe list. The table
is the entire screen. The only persistent non-card elements are the two status rings (3.3) and
the three corner utility buttons. Everything else appears only in response to interaction.

---

### 3.6 Shape Hierarchy Rule

> **Cards first, rings second, arcs third, chrome last.**

When multiple shape elements are on screen simultaneously, this is the intended reading order:
cards (primary objects, highest contrast, largest relative footprint) → status rings (permanent
but peripheral, below-center, smaller) → hint arcs (ambient, always at or below 25% opacity) →
chrome (margin, 30% opacity at rest). No chrome element ever competes with a card for attention.
No hint arc ever competes with a status ring. The hierarchy is enforced through opacity and position,
not through explicit visual separation or drop shadows.

---

### Open Questions (prototype-driven validation required)

1. **Snap ring vs. hint arc radius at 1080p**: The 64px Magnetic Snap ring (Section 2) and the
   41px hint arc (3.4) were specified at 1× logical scale. At 1080p with a larger UIScale factor,
   do these remain proportionally correct, or does the snap ring overwhelm the status ring?
   Validate in-engine before locking Section 4.
2. **Stack overflow at 8+ cards**: The 3px compressed offset rule (3.1) is a heuristic — test
   whether the compressed stack still reads as a single coherent object or dissolves into visual noise.
3. **Double-border legibility at small screen sizes**: The 1px inner border may anti-alias to
   invisibility below 80px card width. Define a breakpoint at which the double border collapses
   to a single 2px border.

---

## Section 4 — Color System

> All hex values in this section are *final decisions*, not suggestions. Any
> value that changes must be updated across Sections 2, 3, and 4 simultaneously.

---

### 4.1 Primary Palette

Five named colors form the entire game world. UI chrome shares this palette —
there is no separate utility register.

| Name | Hex | Semantic role | Where it appears |
|---|---|---|---|
| **Parchment** | `#C8B89A` | The table itself — the world Ju inhabits. Warm, worn, specific. Not decorative. | Table background tint (Table Idle baseline) |
| **Cream** | `#F5EDDF` | The card's own material — the thing she holds and turns. | Card face ground (all cards); label strip base |
| **Dusk** | `#1A1510` | The held breath between moments. Warm dark — not void, not nothing. | Scene Transition fade; Final Illustrated Memory arrival field |
| **Warm Grey** | `#B0A090` | The table speaking quietly — when it wants to help but won't interrupt. | Hint arcs (25% opacity cap); table surface border (50% opacity); utility icon strokes (30% idle opacity); outer card border (`#C0AE9A` is one tone darker — see note below) |
| **Honey Gold** | `#F5E0A0` | The only moment of certainty in the game. Used once per snap, nowhere else at rest. | Magnetic Snap ring; status ring fill (100% opacity); Scene Win CanvasModulate |

> **Border note:** The outer card border (`#C0AE9A`) and inner card border
> (`#F0EAE0`) from Section 3 sit between Warm Grey and Cream on the warmth
> scale. They are card-specific tones, not new palette entries — the outer
> border darkens Cream one step; the inner border lightens it one step.
> Neither appears outside the card frame.

---

### 4.2 Per-Scene Palette Strategy

**Decision: Hybrid.**

Cards and UI chrome hold the five-color palette across all scenes — Cream,
Parchment, Warm Grey, Honey Gold, and Dusk are constant. Chapter backgrounds
shift via `CanvasModulate` tint applied to the table layer only.

*Justification:* Cards are Ju's world. The table is the chapter's atmosphere.
Keeping the cards palette-locked preserves the intimacy continuity: the things
she interacts with always feel like the same place, even as the emotional context
shifts. The background tint carries the chapter's register without destabilizing
the objects she recognizes.

*Why not unified:* Five-to-eight chapters represent distinct emotional registers —
morning-of-meeting has a different light than the hard time. A single table tint
would make every chapter feel like the same afternoon, which would undercut
the "this moment specifically" mandate.

*Why not full per-scene palette:* Changing card colors per chapter would require
the card art itself to change temperature, which the painterly rendering (soft
gouache on cream ground) resists. More critically, it would make Honey Gold
ambiguous — is this snap significant, or is this just the amber chapter?

**Chapter tint register (5 example chapters):**

| Chapter | Story beat | CanvasModulate tint | Effect |
|---|---|---|---|
| How we met | First encounter, tentative, bright | `#FFF8F0` — near-white with barely-warm cream | Table feels overexposed like a sun-washed memory |
| Early moments | Easy days, unhurried | `#C8B89A` — Parchment baseline, no shift | Table Idle; no modulation needed |
| A hard time | Distance, difficulty, quiet | `#B0AEAD` — cool blue-grey, desaturated | Table cools noticeably; warmth is withdrawn |
| A trip | Somewhere new, open | `#D4C09A` — warm amber, slightly richer | Table feels like afternoon light through a train window |
| Home / Now | Present, familiar, earned | `#C4B090` — same warmth as baseline but slightly deeper | Table feels older and more settled than early chapters |

The hard-time chapter (`#B0AEAD`) is the only tint that crosses into cool
territory. It is intentional — the game never punishes, but it acknowledges.
The coolness is a *register shift*, not a danger signal.

---

### 4.3 UI Palette Divergence

There is no separate utility palette. UI chrome uses Warm Grey (`#B0A090`)
for all icons, the table border, and hint arcs. This is a deliberate choice:
chrome that shares the world's palette recedes into it. Chrome in a contrasting
utility color (e.g. a blue-tinted icon) would read as interface intruding on
table space.

**Settings menu text color**: Warm Grey `#B0A090` on Parchment `#C8B89A`
achieves approximately 2.5:1 contrast — below WCAG AA (4.5:1 for small text),
but the settings menu is not the primary game surface and this game has a
single-person audience whose visual acuity is not a variable. If legibility
concerns arise in testing, the text color shifts to Dusk `#1A1510` at 60%
opacity on the same background, which lifts contrast to approximately 4:1
without introducing a foreign color.

**Deliberate divergences from card-world palette:**
- Utility buttons at 30% idle opacity (not 100%) — they are *in* the palette
  but deferring to the table by rendering below full presence.
- The hard-time chapter tint (`#B0AEAD`) introduces the only cool note in the
  entire game. It is not a divergence from the palette; it is the palette
  demonstrating its range.

---

### 4.4 Status Ring Fill Treatment

Locked from Section 3; canonized here as single source of truth.

| Ring state | Color | Opacity | Notes |
|---|---|---|---|
| Empty arc | `#C0AE9A` (Warm Grey +1 step) | 40% | Below the visual threshold of notice. Ring is present but undemanding. |
| Partial fill | `#F5E0A0` (Honey Gold) | Scales 70%→100% as fill progresses | Saturation holds constant; opacity lifts as the goal nears completion. |
| Full / complete | `#F5E0A0` (Honey Gold) | 100% | Same color as the Magnetic Snap ring. Full ring and successful snap share the same visual language: certainty. |
| Ring stroke | `#C0AE9A` | 100% | The outer line that contains the fill. One tone darker than the empty fill, one tone lighter than Parchment, so the ring reads as a contained object, not a floating arc. |

**On full-ring appearance:** The complete ring must NOT look like an achievement
badge. The Honey Gold fill is identical to the snap ring, which appears for 0.4s
and dissolves. The status ring does not dissolve; it rests at full fill, warm and
quiet. This works because the ring is small (72px OD) and positioned at the
table's lower edge — it cannot read as a celebration from that position and at
that size. It reads as completion.

**Hint arc contrast at empty vs. full:** The hint arc (`#B0A090`, 25% opacity cap)
runs outside the ring stroke at 41px radius. Against an empty ring (`#C0AE9A` at
40%), the arc is one tone lighter at lower opacity — sufficient separation. Against
a full ring (`#F5E0A0` at 100%), the arc shifts from near-invisible to visibly
distinct: warm grey arc against warm gold ring. The contrast actually increases
as the ring fills, which is correct — the hint arc is less needed when the ring
is nearly full, but it remains present as a rhythm element.

---

### 4.5 Accent Colors and Their Uses

**One accent: Honey Gold `#F5E0A0`.**

Honey Gold is the sole accent in this game. It appears in:
- The Magnetic Snap ring (most emotionally significant use)
- The status ring fill at completion
- The Additive template's spawn-point amber ring (at 40% opacity — a softer
  appearance of the same gold, not a new color)
- The Scene Win CanvasModulate tint (`#FFF5E0` — cream-shifted gold, not the
  pure accent, but in the family)

Honey Gold means: *something arrived that was expected.* Magnetic snap, goal
completion, new card spawned from a generous source — these are all the same
emotional beat. One accent color for one emotional beat.

**What is explicitly NOT an accent:**
- Warm Grey `#B0A090` appears too frequently to be accent — it is structural.
- Cream `#F5EDDF` is material, not signal.
- Parchment `#C8B89A` is world, not event.
- There is no second accent. The chapter tints (4.2) are atmospheric modulation,
  not accent colors — they never appear on cards or interactive elements.

---

### 4.6 Colorblind Safety and Shape Redundancy

The game's near-absence of semantic color dramatically reduces colorblind risk.
The few color-distinguishable pairs are:

| Color pair | Colorblind risk | Non-color backup cue |
|---|---|---|
| Compatible snap (warm gold bloom) vs. Push-Away (brief desaturation) | Low — these are temperature shifts, not hue changes; deuteranopia may reduce the warmth contrast but not eliminate it | Motion: snap produces a ring that expands outward; push-away produces card travel of 16px with ease-out. Shape and direction differ entirely. |
| Full status ring (Honey Gold at 100%) vs. partial ring (Honey Gold at 70–100% opacity ramp) | Very low — this is an opacity difference, not hue | Arc span: a full ring is 360°; a partial ring is the arc length of its progress. Geometry carries the reading independently. |
| Hard-time chapter tint (cool `#B0AEAD`) vs. other chapters (warm tints) | Low-medium — the cool shift may be less readable for tritanopia | Scene transition: every chapter arrives via the fade-through-Dusk (`#1A1510`) transition, which signals chapter change independently of tint. |
| Final Illustrated Memory (full saturation) vs. all other states (muted) | N/A — this is saturation magnitude, not hue. Any level of color vision will register the shift. | Duration: the memory holds indefinitely; no other full-screen image does. |

No element in this game uses red-green opposition as its primary signal. The
Push-Away desaturation is a single frame of blue-grey shift — not red, not
green, not a hue pair.

---

### 4.7 Color Prohibitions

**Banned colors:**

1. **Pure black `#000000`** — replaced throughout by Dusk `#1A1510`. Pure black reads as
   void; Dusk reads as a held breath. This is an absolute rule, not a preference.

2. **Pure white `#FFFFFF`** — replaced throughout by Cream `#F5EDDF` or the near-white
   chapter tint `#FFF8F0`. Pure white is clinical; it breaks the table's material quality.

3. **Red in any form** — there is no danger state, no damage, no failure. Red serves nothing
   in this game and would permanently contaminate the intimate register.

4. **Saturated primaries** (hue saturation above 70% for any hue angle in the blue, green,
   or pure-yellow range) — the palette's character is muted and warm. A saturated primary
   on screen would read as either a bug or a brand intrusion.

5. **Cool neutrals except in the hard-time chapter tint** — cool grey not in service of the
   hard-time chapter (`#B0AEAD`) has no authorized use. Warm Grey `#B0A090` is the only
   grey in the palette; any grey shifted toward blue is out of palette.

---

### Open Questions (prototype validation required)

1. **`#C8B89A` table + `#F5EDDF` cream card ground contrast at 1080p**: The card's cream
   ground reads against Parchment at approximately 1.4:1 luminance contrast. At 1080p
   with anti-aliased card edges, confirm the card face is legible without a drop shadow
   carrying additional separation work beyond the 15% baseline.

2. **Hard-time chapter tint legibility of hint arcs**: The hint arc (`#B0A090` warm grey)
   was specified against the Parchment baseline. Against the cool `#B0AEAD` tint, the warm
   grey arc may read as slightly yellow-shifted. Verify in-engine that the arc still reads
   as ambient and not as a competing warm element.

3. **Honey Gold at 70% opacity (partial ring fill)**: At 70% opacity of `#F5E0A0` over
   `#C8B89A` Parchment, the partial fill may not be visually distinct from the 40% empty
   arc. Set minimum fill opacity to 80% if this collapses in prototype testing.

---

## Section 5 — Character Design Direction

**Scope**: this game has two on-screen characters — **Chester** and **Ju** —
plus an implied third-person "shared friend" card. There are no full-body
character turnarounds, no combat stances, no expression sheets. Characters
exist only as card portraits (≈200×300 px draw region) and, for Ju, as the
single illustrated epilogue.

### 5.1 Portrait framing rule

Every character card portrait obeys the same framing contract:

- **Head-and-shoulders** composition; eye line at vertical 40% of the portrait
  region (upper third, not geometric center)
- Face fills ≈55% of the region's width
- Background within the portrait is diegetic (a real place from a real memory)
  not a flat color — this is a card *about* someone in a moment, not a profile
  photo against paper
- Subject's gaze direction: lean **toward** the table centre when the card is
  placed on its authored seed-position (see scene layout). Faces do not stare
  at the player — they stare toward the partner card

### 5.2 Chester (the one who made this)

- **Visual intent**: the hand that made the game. Recognisable *to Ju* in a
  glance; impressionistic to anyone else.
- Palette: warm — the Section 4 primary Ink Warm (#24201B) for outlines,
  skin tones built from Paper Warm (#F4EEDE) warmed with a #C9A882 wash
- Micro-expression cue: slight eyebrow tilt (asymmetric) rather than smile —
  we are going for *attentive*, not *cheerful*
- Props allowed only if emotionally specific: the coffee machine, a specific
  mug, a specific hoodie. Never a generic suit or studio-photo polish.

### 5.3 Ju (the reason)

- **Visual intent**: centre of gravity. Every scene's composition subtly
  pulls toward her card.
- Palette: warm+slightly-cool blend — same Ink Warm outline, skin tones
  slightly cooler than Chester's to create a recognisable pair contrast
  (without tipping into gender stereotype — cool vs. warm, not pink vs. blue)
- Special rule: Ju's card is the only one that uses a **light halo** — a
  faint 2px inner glow in Paper Warm tint around the card border at 20% alpha.
  Not a gameplay marker (status bars do that); a quiet compositional anchor.
- Epilogue illustration: Ju *not looking at the camera* — receiving
  something (the coffee, the moment). This is the only place the game leaves
  the card grid and becomes a full illustration.

### 5.4 Tertiary: "Shared Friend" / "Home" / scene figures

Minor character cards (the `shared-friend` card, the `home` silhouette in
later scenes) follow the same framing rule but get **30% desaturated** so
they read as *background to the two*. They must not steal focus.

### 5.5 What we do NOT draw

- Full body poses, fashion illustrations, costume change sheets
- Character emotion-variation sheets (angry / sad / surprised grid) — the
  game shows the *same* portrait regardless of in-scene state
- Background characters / crowds / extras
- Stylised anime / chibi / super-deformed variants — one register only

---

## Section 6 — Environment Design Language

**Scope**: there is one environment — **the table**. Cards sit on it, scenes
differ only by the *tinting* of that table (see Section 4.2 Per-Scene Palette).
There are no rooms, levels, or skyboxes to design.

### 6.1 Table surface

- Baseline texture: an aged-paper / desk-surface hybrid with ≤5% luminance
  variance. Think "museum display card" — uniform enough to let the cards
  dominate, textured enough to not feel like a CSS background.
- The surface is a single full-viewport Sprite, drawn behind all cards
  (z_index = -10). Changed per scene via a tint multiply.

### 6.2 Edge vignette

A soft vignette (radial falloff, 15% darker at the corners than the centre)
keeps the eye on the card cluster. Constant across scenes; do not animate.

### 6.3 Implied-space rule

If a scene needs to *feel* like a place (e.g., "morning kitchen" for
coffee-intro), the feeling comes from:

1. Tint of the table (Section 4.2)
2. The chosen cards' own portrait backgrounds (Section 5.1 — backgrounds
   within portraits)
3. Optional single ambient card (e.g., a `home` card) acting as set dressing

Never from a new background image, never from a parallax layer, never from
3D geometry. Scenes are composed from *cards*, not from environments.

### 6.4 Off-limits

- Weather, time-of-day simulation, day/night cycles
- Camera movement, parallax, environmental VFX (rain, dust motes)
- Multiple rooms or a map view between scenes
- Architecture / furniture drawn outside of card portraits

---

## Section 7 — UI/HUD Visual Direction

**Scope**: anything *on top of* the table surface that is not a card. Status
bars, hint arc, transitions, menus.

### 7.1 Core rule — "paper on paper"

Every UI element reads as a **paper overlay** on the table. Same stock as
the cards, slightly offset tone, pressed rather than drawn. This preserves
the handmade-diary feel and lets the eye rank UI below card content by
default.

Concretely:
- All UI panels use Paper Warm (#F4EEDE) at 94% opacity over whatever is
  below
- Borders: 1px Ink Warm at 35% opacity (not a sharp line — feels deckled)
- Text: Ink Warm, hand-lettered for titles, neutral sans for small text
  (≥14 px). No TrueType "display" faces.

### 7.2 Status bars (two vertical bars in a left panel)

- Geometry finalised in Section 3.3 — stays there
- Fill colour: **scene-specific accent**, not a fixed UI color, so the bar
  feels part of the memory (coffee-intro = warm brown; home = warmer red)
- Below-threshold state: bar fill desaturates to 60%; above-threshold: full
  saturation. No outline change (see Section 3.6 hierarchy rule).
- Label below each bar: card's `display_name` in sentence case. Not
  "Chester: 60" — just "Chester". Numbers are engineering, this is a memory.

### 7.3 Hint arc

- Geometry in Section 3.4
- Only visible element that uses **motion** as a communication channel
- Color: same scene accent as the status bar it sweeps above
- Never flashes; only rotates at low opacity

### 7.4 Transition overlay (page-turn)

- Cream paper (#F4EEDE) with a single curl-shadow gradient along the leading
  edge
- No text, no spinner, no "loading…" — the transition IS the message
- Epilogue variant uses amber tint (#E8B888 multiply over cream) and
  ≈1.5× the standard timing (per Section 4.2)

### 7.5 Main menu

- **Hand-lettered title PNG** (logo-style, not a typed font). If art isn't
  ready, a Label with the typeface below stands in — but the shipping build
  uses the PNG.
- Single Start button: hand-lettered word "Start" on a slightly-darker paper
  rectangle. No dropshadow, no glow, no hover animation beyond 5% brightness
  rise.
- Background: same table surface from Section 6.1, 15% darker than gameplay

### 7.6 Settings / pause (future)

`SettingsPanelHost` CanvasLayer is declared in ADR-004 but empty in MVP.
When filled: paper-on-paper modal, dismissable by Esc, does not fade the
underlying table (the memory is always visible). Entries: audio volume,
reduced-motion toggle, quit.

### 7.7 Forbidden UI moves

- Neumorphism, glassmorphism, holographic, neon — the game is paper
- Drop-shadows longer than 2px
- Border-radius above 12px (cards are 8px; UI must not out-round cards)
- Icon-only buttons without a label — accessibility rule
- Toast / popup notifications

---

## Section 8 — Asset Standards

**Scope**: concrete production rules. Everything on disk must conform.

### 8.1 File format & colour space

- All raster art: **PNG** (RGBA8), sRGB colour space, no ICC profile embedded
- No JPG, no WebP, no .psd in `assets/` (keep working files elsewhere)
- Godot import: `import/compress_mode = Lossless` for card art; `VRAM Compressed`
  only for backgrounds larger than 512×512

### 8.2 Resolution tiers

| Asset type | Canvas | Draw region | Export size | DPI-scaled? |
|---|---|---|---|---|
| Card portrait | 200×300 | 200×300 | 400×600 @2x | Yes |
| Card badge (optional) | 48×48 | 48×48 | 96×96 @2x | Yes |
| Main menu title | 960×240 | 800×180 | 1920×480 @2x | Yes |
| Main menu button | 360×120 | 280×80 | 720×240 @2x | Yes |
| Epilogue illustration | 1920×1080 | content-dependent | 3840×2160 @2x | Yes |
| Table surface | 1920×1080 | full | 1920×1080 @1x (tiled if needed) | No |
| Status ring | code-drawn | — | — | — |

All `@2x` assets also ship a `@1x` downscale for low-spec hardware. Godot's
`hdpi/allow_hidpi` setting is on — let the engine pick.

### 8.3 Naming & paths

- All filenames lowercase, underscore-separated: `coffee_machine.png`, not
  `CoffeeMachine.png` or `coffee-machine.png` (matches card `id` in cards.tres,
  see `.claude/rules/data-files.md` enum-ish rule)
- Paths by asset type:
  - Card art: `res://assets/cards/[card_id].png`
  - UI art: `res://assets/ui/[purpose]_[variant].png`
  - Menu art: `res://assets/main-menu/[purpose].png`
  - Epilogue: `res://assets/epilogue/illustration.png`
  - Table surface: `res://assets/table/surface_[scene_id].png`

### 8.4 Texture budget

- Total on-disk art budget for the MVP: **≤ 80 MB**
- VRAM ceiling: ≤ 256 MB (per `.claude/docs/technical-preferences.md`)
- Card art per file: ≤ 400 KB
- Epilogue illustration: ≤ 2 MB
- If a file exceeds budget, reduce canvas before compressing — never drop to
  JPG to save KB.

### 8.5 Transparency rule

- Card portraits: **solid rectangular** PNG with the card border baked in.
  The card node does its own border/drop-shadow in code (see CardVisual) —
  the portrait stays opaque.
- UI icons with transparency: PNG alpha, premultiplied disabled (Godot
  handles straight alpha natively)
- Never mix 8-bit and premultiplied alpha in the same scene.

### 8.6 Delivery checklist (per asset)

Before a PNG can land in `assets/`:

1. [ ] Canvas size matches the tier in §8.2
2. [ ] Filename lowercase + underscore
3. [ ] Filename matches the `id` in the referencing `.tres` (card / recipe)
4. [ ] Palette uses only Section 4 primaries + scene-specific accent (no
       rogue colours)
5. [ ] Subject framing passes Section 5.1 portrait rule
6. [ ] Opens in Godot editor without reimport errors
7. [ ] `tres` file updated so the `@export var art` points at the real path
       (not `3_placeholder_art`)
8. [ ] File size within §8.4 budget

### 8.7 What NOT to ship

- "Final" versions with watermarks or visible signature overlays
- Files with layer comps / working paths embedded (flatten before export)
- Assets that depend on fonts not in `assets/fonts/`
- Source `.psd` / `.procreate` / `.clip` files in `assets/` (keep in a
  separate `art-source/` tree — add to `.gitignore` if large)

---

## Section 9 — Reference Direction (expanded)

**Scope**: the specific external visual anchors that Chester / the art
producer will lean on. Kept deliberately short — three strong anchors beat
a mood wall of forty weak ones.

### 9.1 Primary anchors (lean heavily here)

1. **Saul Steinberg — The New Yorker covers (1950s–60s)**
   Why: deckled edges, hand-lettered signage, architecture as personality.
   Borrow: ink line weight, negative space, single-subject composition.
2. **Kitty Crowther — picture book illustration**
   Why: warm portraiture, domestic intimacy, characters in their own space.
   Borrow: palette limits (≤5 colours per scene), how she handles faces at
   small scale.
3. **Vanillaware — 13 Sentinels / Odin Sphere (UI and 2D frames only)**
   Why: rich paper-texture UI, hand-illustrated card frames, painterly
   without being sluggish.
   Borrow: how gameplay UI coexists with illustrated characters without
   either one feeling cheap.

Save three representative images per anchor in `design/art/references/`
before Production begins. Each image captioned with *exactly which element
we are referencing* — don't just post mood dumps.

### 9.2 Secondary anchors (cameo roles)

- **Wes Anderson — Moonrise Kingdom / Grand Budapest**: symmetry, off-centre
  framing, label typography. *Apply to*: transition cards, "scene 1 of 3"
  interstitials (future).
- **Studio Ghibli — still backgrounds (Kiki, Totoro)**: how they paint
  warmth without saturating. *Apply to*: table surface tint variants.
- **The Artful Escape (game)**: how it handles a single illustrated
  centrepiece with no other geometry. *Apply to*: epilogue illustration
  composition.

### 9.3 Explicit rejections

The following styles are **off-limits** for this project. Including them so
future decisions have a clear line to point at:

- Pixel art (any resolution) — not this project's register
- Flat vector / Corporate Memphis / "Alegria" style — too impersonal
- Photorealism / photobashing — breaks the handmade vow
- Anime / manga — wrong emotional register
- Cyberpunk / synthwave / y2k — wrong temperature
- AI-generated imagery **without human repainting** — allowed as base layer
  only if overpainted ≥50% by the final artist (Chester or commissioned)

### 9.4 Reference delivery

One-file moodboard at `design/art/references/moodboard.md`:
- 3 images per Section 9.1 anchor (9 total)
- 1 image per Section 9.2 anchor (3 total)
- 1 "what we are NOT" image per Section 9.3 rejection (6 total)

Total: 18 images. Chester or the commissioned artist reads the moodboard
once before producing any asset in Section 8.

---

## Sign-off

### AD-ART-BIBLE verdict

**Status**: READY (self-signed, Solo mode)
**Signed by**: Chester (solo author)
**Date**: 2026-04-23
**Scope**: Sections 1–9 complete. Sections 1–4 locked during Technical Setup;
Sections 5–9 authored after Vertical Slice prototyping surfaced concrete
asset needs (coffee-intro tutorial: 5 card portraits + 1 main-menu title +
1 epilogue illustration are the MVP commissioning list).

**Open items tracked separately (not blockers)**:
- Shape-language open questions in Section 3 (prototype validation)
- Per-scene palette open questions in Section 4.7
- Reference moodboard files — to be delivered under `design/art/references/`
  before the first production asset is commissioned

This Art Bible unblocks the Pre-Production → Production gate's "Art bible
complete (all 9 sections) and AD-ART-BIBLE sign-off recorded" requirement.
