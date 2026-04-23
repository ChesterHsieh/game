# Asset Specs — system: card-database (Coffee Intro MVP)

> **Source**: `design/gdd/card-database.md`, `design/art/art-bible.md`, `production/epics/scene-composition/EPIC.md`
> **Art Bible**: design/art/art-bible.md
> **Generated**: 2026-04-23
> **Status**: 5 assets specced / 0 approved / 0 in production / 0 done
> **Mode**: solo (no agent spawning — derived from Art Bible + author references)

---

## Style Anchors

Two distinct sub-styles within the same project, separated by subject type.

### Style A — Person cards (chester, ju)

Reference: Chester's portrait card and Ju's portrait card (author-supplied).
- **Technique**: soft painterly illustration, visible brush texture, rounded
  silhouettes (see Art Bible §3.2 — "simplified silhouettes, 3–5 macro shapes
  per figure")
- **Subject**: head-to-toe single figure (Ju's ref shows full body in context;
  Chester's ref shows full body on paper). Per Art Bible §5.1 the portrait
  region is 200×300 — the figure fills ≈70% of vertical space.
- **Background**: diegetic — a place from a real memory. Ju's reference shows
  a street-front with flags (Vietnamese heritage); Chester's reference shows
  empty cream paper (his home / studio). The contrast is intentional per §5.3
  (Ju = "centre of gravity", gets ambient context).
- **Card border**: soft rounded rectangle, 1-2px grey, rendered INSIDE the
  PNG (not drawn by code). Double-line deckle effect like the refs.
- **Color register**: muted, warm, ≤5 saturated colors per card

### Style B — Object cards (coffee_machine, coffee_beans, coffee)

Reference: the creature-on-cream image (author-supplied).
- **Technique**: thick ink line drawing, rough-brush outline (not clean
  vector), ink-wash stain around the silhouette for weight
- **Subject**: single object, centred, facing roughly forward
- **Background**: none — Paper Warm `#F4EEDE` flat fill. Per author's
  anti-pattern rule.
- **Card border**: same soft deckle rectangle as Style A (so the two styles
  sit on the table as one family)
- **Color register**: ink black + paper cream only (no internal color), or
  at most one warm accent per card

### Shared rules (both styles)

- Portrait canvas: 200×300 px (logical) → exported 400×600 @2x per Art Bible §8.2
- Background padding: 12px paper border around the subject silhouette before
  any deckle / card edge
- Subject gaze: toward table centre (when placed at authored seed-position —
  see Art Bible §5.1 portrait framing rule)
- No text overlays on the portrait (display_name is drawn by CardVisual code,
  below the portrait region)
- No drop shadows baked into the PNG (CardVisual renders shadow dynamically)

---

## Master nano-banana prompt templates

Two templates — one per style. Keep these in sync with this spec file; when
running `mcp__nano-banana__generate_image`, compose
`{base_style_prompt} + {subject_clause} + {shared_constraints}`.

### Template A — Person card (chester, ju)

```
Soft painterly illustration of {SUBJECT}, gouache / digital-watercolour
texture, rounded brushwork, minimalist cartoon — reference Stackland card
style adapted for personal portraits. Muted warm palette of cream paper
(#F4EEDE), warm ink (#24201B), one or two gentle saturated accents. Figure
centred on a tall portrait card with a soft rounded rectangle border (thin
grey double-line deckle). Character has friendly open posture, gentle smile,
simple black dot eyes, cartoon-abstracted features (no detailed anatomy).
{BACKGROUND_CLAUSE}. Overall feeling: handmade, intimate, a quiet page from
a personal diary made as a gift.

--ar 2:3 --style paintery --stylize 250
NEGATIVE: photoreal, anime, manga, 3D render, pixel art, sharp contrast,
cyberpunk, neon, vector flat, corporate illustration, text, signature,
watermark, drop shadow, frame decoration, ornate border
```

Where `{BACKGROUND_CLAUSE}` is:
- **Chester**: `"plain cream paper background — no scene, figure sits on
  blank paper texture"`
- **Ju**: `"soft painted diegetic background showing a specific memory place
  (e.g. a vibrant street-front with small colourful flags, warm Vietnamese
  morning), rendered in the same muted painterly style as the figure —
  background is 40% desaturated relative to the subject so the figure still
  dominates"`

### Template B — Object card (coffee machine / beans / coffee)

```
Minimalist ink-line cartoon of a single {SUBJECT}, thick rough-brush black
outline (approx 6–10px at 400×600), light ink wash inside the silhouette
for weight, no internal colour fill beyond the wash, background is flat
warm cream paper (#F4EEDE) — no scene, no gradient, no props. Style
reference: Stackland card iconography meets hand-brush ink sketching.
Shape is rounded, friendly, slightly chunky / huggable. Single object
centred in the frame with 12% padding around the silhouette. Soft rounded
rectangle card border in thin grey double-line deckle.

--ar 2:3 --style illustrated --stylize 150
NEGATIVE: photoreal, 3D render, colour fills, gradients, background
elements, steam/particles around the subject, text, signature, multiple
objects, small detail clutter, sharp vector edges, perspective, shadow
```

---

## ASSET-001 — Chester Portrait

| Field | Value |
|-------|-------|
| Category | Sprite / Card Portrait |
| Dimensions | 400×600 px (2:3, @2x of the 200×300 logical size) |
| Format | PNG, RGBA8, sRGB |
| Naming | `chester.png` |
| Path | `res://assets/cards/chester.png` |
| Texture Res | Tier 1 — Card portrait (Art Bible §8.2) |
| File size budget | ≤ 400 KB |

**Visual Description:**
Full-figure painterly portrait of Chester — a young man in a blue hoodie and
jeans, a grey messenger bag crossing his chest, hands in pockets, relaxed
slight smile, simple black dot eyes, hair tied up in a small top bun. Figure
rendered in soft watercolour / gouache technique with rounded brushwork.
Stands on a plain cream paper background (no scene) — Chester is the "hand
that made this", seen against the blank page he's drawing on.

**Art Bible Anchors:**
- §5.2 Chester — warm palette, attentive micro-expression (asymmetric
  eyebrow / slight smile, not cheerful)
- §5.1 Portrait framing — eye line ≈40% from top, gaze leans toward table
  centre (mirror-flip if author prefers)
- §4.1 Primary Palette — Ink Warm outline, Paper Warm background
- §7.1 Paper-on-paper — card border consistent with UI register
- §8.2 Resolution tier 1
- §9.3 — no photoreal / no anime

**Generation Prompt (nano-banana):**
Template A with:
- `{SUBJECT}` = `"Chester — a young man in his late 20s, casual blue hoodie
   over white T-shirt, light blue jeans, white sneakers, grey over-shoulder
   messenger bag, hair in a small top bun, warm light skin, gentle attentive
   expression with a small smile, hands relaxed in pockets, full standing
   figure"`
- `{BACKGROUND_CLAUSE}` = the Chester plain-paper clause (Template A)

**Status:** Needed

---

## ASSET-002 — Ju Portrait

| Field | Value |
|-------|-------|
| Category | Sprite / Card Portrait |
| Dimensions | 400×600 px |
| Format | PNG, RGBA8, sRGB |
| Naming | `ju.png` |
| Path | `res://assets/cards/ju.png` |
| Texture Res | Tier 1 |
| File size budget | ≤ 400 KB |

**Visual Description:**
Full-figure painterly portrait of Ju — a young woman in a light
traditional-patterned ao dai (or equivalent culturally specific dress),
walking with gentle posture, carrying a small shoulder bag, warm smile,
simple black dot eyes, hair pulled back. Background is a muted diegetic
scene: a Vietnamese street corner with a small clock tower / pennant flags
in pastel colours, rendered in the same painterly style as the figure but
40% desaturated so Ju dominates. A faint light halo surrounds Ju's silhouette
(Art Bible §5.3 special rule).

**Art Bible Anchors:**
- §5.3 Ju — centre of gravity, cool-warm palette blend, light halo
- §5.1 Portrait framing rule
- §5.3 Special rule — diegetic background *allowed* and *encouraged* for Ju
- §4.1 Primary Palette
- §9.3 — no anime, must stay painterly

**Generation Prompt (nano-banana):**
Template A with:
- `{SUBJECT}` = `"Ju — a young Vietnamese-Taiwanese woman in her late 20s,
   wearing a flowing light ao dai with a small floral print in pastel pink
   and green, white loose trousers, small dark sandals, carrying a small
   patterned shoulder bag, hair pulled back into a low bun, warm smile,
   gentle painterly rosy cheeks, walking stride frozen mid-step, full figure"`
- `{BACKGROUND_CLAUSE}` = the Ju diegetic-memory clause (Template A)

**Status:** Needed

---

## ASSET-003 — Coffee Machine

| Field | Value |
|-------|-------|
| Category | Sprite / Card Portrait (object class) |
| Dimensions | 400×600 px |
| Format | PNG, RGBA8, sRGB |
| Naming | `coffee_machine.png` |
| Path | `res://assets/cards/coffee_machine.png` |
| Texture Res | Tier 1 |
| File size budget | ≤ 400 KB |

**Visual Description:**
Ink-line cartoon of a small stove-top moka pot (or domestic espresso
machine) — chunky silhouette, friendly rounded proportions, spout slightly
exaggerated. Drawn with a thick rough-brush black outline, no colour fill
inside the silhouette (just a soft ink wash for weight). Flat cream paper
background. No steam, no cup, no table — just the object.

**Art Bible Anchors:**
- §6.4 Off-limits — no scene / environment elements
- §3.6 Shape hierarchy — single chunky silhouette
- §4.1 Palette — Ink Warm + Paper Warm only
- §5.5 — object is "furniture", must not steal focus from character cards

**Generation Prompt (nano-banana):**
Template B with:
- `{SUBJECT}` = `"a small stove-top moka espresso pot, classic octagonal
   aluminium body with a curved handle, a rounded chunky silhouette,
   slightly cartoonified proportions, friendly soft curves"`

**Status:** Needed

---

## ASSET-004 — Coffee Beans

| Field | Value |
|-------|-------|
| Category | Sprite / Card Portrait (object class) |
| Dimensions | 400×600 px |
| Format | PNG, RGBA8, sRGB |
| Naming | `coffee_beans.png` |
| Path | `res://assets/cards/coffee_beans.png` |
| Texture Res | Tier 1 |
| File size budget | ≤ 400 KB |

**Visual Description:**
Ink-line cartoon of a small cluster of coffee beans — three to four beans
arranged loosely, each with the characteristic centre seam, drawn with a
thick rough-brush black outline. Soft ink wash inside each bean for weight.
Flat cream paper background. Not a bag of beans, not a scoop — just 3–4
loose beans, like ingredients set on the table.

**Art Bible Anchors:**
- Same as ASSET-003
- §3.2 Simplified silhouette — ≤4 macro shapes (each bean = one shape)

**Generation Prompt (nano-banana):**
Template B with:
- `{SUBJECT}` = `"a small loose cluster of three coffee beans, each bean
   oval with a single central seam, arranged informally (not a pile, not in
   a bag), chunky rounded cartoonified proportions"`

**Status:** Needed

---

## ASSET-005 — Coffee (Brewed)

| Field | Value |
|-------|-------|
| Category | Sprite / Card Portrait (object class) |
| Dimensions | 400×600 px |
| Format | PNG, RGBA8, sRGB |
| Naming | `coffee.png` |
| Path | `res://assets/cards/coffee.png` |
| Texture Res | Tier 1 |
| File size budget | ≤ 400 KB |

**Visual Description:**
Ink-line cartoon of a small ceramic coffee cup (with saucer) viewed from a
slight three-quarter angle — chunky rounded silhouette, friendly
proportions, small curl indicating brewed coffee inside (line only, no
colour). Thick rough-brush outline, ink wash for weight. Flat cream paper
background. No steam squiggles (anti-pattern: environmental VFX within
portrait).

**Art Bible Anchors:**
- Same as ASSET-003 / ASSET-004
- §6.4 — no ambient VFX (no steam particles)

**Generation Prompt (nano-banana):**
Template B with:
- `{SUBJECT}` = `"a small ceramic coffee cup on a matching saucer, viewed
   from a gentle three-quarter angle, brewed coffee visible at the rim as a
   single curved ink line (no colour fill inside), chunky rounded
   cartoonified proportions, gentle handle curve"`

**Status:** Needed

---

## Production Notes

### Batch order recommendation

1. Generate **Chester** first (ASSET-001) — simplest background, establishes
   the painterly style for person cards
2. Generate **Ju** (ASSET-002) using Chester's output as a style reference —
   matching the painterly register is more important than matching Ju's
   photo 1:1
3. Generate the **3 object cards** in parallel (ASSET-003/004/005) —
   Template B is self-contained, they should be visually cohesive out of the
   box

### Style-consistency spot-check

After each generation, eye-check against:
- Does it sit on `#F4EEDE` paper? (Sample 5 pixels from the background —
  should be within 10 units of that RGB)
- Does the subject occupy ≈70% of vertical space (person) or ≈60% (object)?
- Is the card border the thin grey deckle? (If nano-banana didn't include
  one, we may add it post-hoc via a Godot shader or overlay sprite)
- If painterly (Style A): are brush strokes visible when zoomed to 200%?
  (If it looks vector/flat, reject and regen with higher stylize weight)

### After approval

1. Save approved PNG to `assets/cards/[card_id].png`
2. Open Godot editor → let it import
3. Open `assets/data/cards.tres` → change `art = ExtResource("3_placeholder_art")`
   to `art = ExtResource("N_chester")` (define a new ExtResource line at the
   top of the .tres pointing to the real PNG path)
4. Run the game → the card should show the new portrait in the Coffee Intro
   scene
