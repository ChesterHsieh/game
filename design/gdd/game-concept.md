# Game Concept: Moments

*Created: 2026-03-23*
*Status: Draft*

---

## Elevator Pitch

A personal card-discovery game where you drag memories together to see what they
become — built from a real relationship, gifted to the person it's about.

---

## Core Identity

| Aspect | Detail |
|--------|--------|
| **Genre** | Card discovery / interactive scrapbook |
| **Platform** | PC |
| **Target Audience** | One specific person — Ju (Chester's girlfriend) |
| **Player Count** | Single-player |
| **Session Length** | 20–40 min per scene, 5–8 scenes total |
| **Monetization** | None — personal gift |
| **Estimated Scope** | Small-medium (3–6 months) |
| **Comparable Titles** | Stacklands, A Little to the Left, Florence |

---

## Core Fantasy

Rediscovering a shared life through the act of play — finding that dragging
one card onto another makes something appear that only one person in the world
will recognize. The game is a love letter written in mechanics.

---

## Unique Hook

Like Stacklands, AND ALSO every recipe was written by someone who loves you.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
|-----------|----------|-------------------|
| **Narrative** | 1 | Each scene is a chapter; each combination is a sentence in their story |
| **Discovery** | 2 | Hidden goals, unlabelled bars, mystery unlock tree |
| **Sensation** | 3 | Magnetic snap/push-away; card animations; ambient visual cues |
| **Submission** | 4 | No fail states; gentle pacing; safe to explore |
| **Challenge** | N/A | Not a challenge game — friction is discovery friction only |
| **Fellowship** | N/A | Single-player, but the game IS about fellowship |
| **Expression** | N/A | Content is authored, not player-created |
| **Fantasy** | N/A | The world is real — their actual relationship |

### Key Dynamics (Emergent player behaviors)

- Player will try every card on every other card, driven by curiosity
- Player will form hypotheses about what the unlabelled bars represent
- Player will experience recognition moments — "I know exactly what this is"
- Player will slow down near the finale, sensing it's almost over

### Core Mechanics (Systems we build)

1. **Magnetic card system** — compatible cards snap together; incompatible cards
   push away. No UI labels needed. The physics IS the feedback.
2. **Interaction template framework** — each combination has a declared behavior
   type. The template chosen is itself a storytelling choice:
   - *Additive*: both cards stay, a new card spawns (a memory that created something)
   - *Merge*: both cards become one (two things that became inseparable)
   - *Animate*: cards drift, orbit, or move (a feeling that keeps returning)
   - *Generator*: card slowly produces new cards over time (a ritual, a recurring habit)
3. **Hidden scene goals with delayed visual cues** — each of 5–8 scenes has a
   unique goal type (sustain two bars, trigger a sequence, find a key combination).
   No text instructions. After time passes, ambient visual indicators emerge:
   counterclockwise arcs fade in around status bars, rings trace silently. No words.
   The cue appears; she reads it herself.
4. **Mystery unlock tree** — start with 2–3 seed cards. Combinations produce new
   cards. The tree builds across the session toward the scene's breakthrough, and
   across the full game toward the final illustrated memory.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
|------|---------------------------|----------|
| **Autonomy** | She chooses which cards to combine, in any order, at any pace | Supporting |
| **Competence** | Decoding the hidden goal feels like genuine insight, not luck | Core |
| **Relatedness** | Every card, every scene, every combination is about her relationship | Core |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Explorers** — Discovery of combinations and hidden goals is the primary loop
- [x] **Socializers** — Deep emotional connection to the game's subject matter
- [ ] **Achievers** — No collection or completion pressure by design
- [ ] **Killers/Competitors** — No competition, no leaderboard, no fail state

### Flow State Design

- **Onboarding curve**: No tutorial. 2–3 seed cards on a table. Magnetic feedback
  teaches the mechanic in the first 30 seconds through touch, not text.
- **Difficulty scaling**: Discovery friction increases as the card tree grows —
  more options, subtler combinations. Hint system catches anyone who stalls too long.
- **Feedback clarity**: Magnetic snap is unambiguous success. Push-away is clear
  non-match. Status bar movement confirms card-to-goal connection.
- **Recovery from failure**: There is no failure. Wrong combinations push away
  and reset. Every attempt is low-cost.

---

## Core Loop

### Moment-to-Moment (30 seconds)

Drag a card toward another. Compatible: magnetic snap fires, interaction template
executes — a new card appears, or two merge into one, or a card begins to drift.
Incompatible: gentle push-away. The physicality of snap vs. push is intrinsically
satisfying. No reading required.

### Short-Term (5–15 minutes)

Two status bars sit on screen, unlabelled. The player experiments, watching what
moves them. Slowly the shape of the goal comes into focus: "these bars are us."
Some combinations affect one bar; some affect both; some push one down while
raising the other. Finding the balance is the short-term challenge.

Around the 5-minute mark, if the goal is still opaque, ambient visual cues emerge:
counterclockwise arcs fade in silently around each bar. No words. The player reads
the shape herself.

### Session-Level (20–40 minutes)

Each scene is a chapter of their relationship. The player enters with a small hand
of seed cards, no instructions, and a scene-specific goal to discover. As combinations
fire, the card table grows and shifts. Eventually the goal condition is met. The scene
resolves — a card, an image, a message. A new scene unlocks.

### Long-Term Progression

5–8 scenes, each a chapter: how they met, early moments, a hard time, a trip, home,
now. Each scene's cards are drawn from that era. Cards from earlier scenes may carry
forward, enabling cross-era combinations in later scenes. The full game ends with a
single final combination that reveals the special illustrated memory — the emotional
centerpiece authored by Chester for Ju.

### Retention Hooks

- **Curiosity**: What does this card combine with? What does the next scene hold?
- **Investment**: The emotional weight of the story builds — she doesn't want to stop
- **Mastery**: Learning the interaction template language makes later scenes readable

---

## Game Pillars

### Pillar 1: Recognition Over Reward

Every combination should create the feeling "I know exactly what this is." The
win condition is her recognition of the memory, not points, progress, or performance.

*Design test*: "Should this card have a poetic label or the actual inside joke?" →
The actual inside joke. Always. Poetry is for people who don't know the reference.

### Pillar 2: Interaction Is Expression

How two cards behave together reflects the nature of that memory. The interaction
template is not a mechanical choice — it is a storytelling choice. A merge says
something different than an additive. An animate says something different than a
generator.

*Design test*: "Should this combination produce a new card or start animating?" →
Whichever reflects how that memory actually felt when it happened.

### Pillar 3: Discovery Without Explanation

Scene goals are hidden. Status bars are unlabelled. Nothing is announced upfront.
Visual cues emerge only after time passes — counterclockwise arcs, fading rings
around bars — never text instructions. The indicator arrives; she reads it herself.

*Design test*: "Should we add a tutorial popup for this mechanic?" → Never text.
If the mechanic is unclear after 5 minutes, let a visual ambient cue fade in. If
it's still unclear, redesign the mechanic, not the explanation.

### Pillar 4: Personal Over Polished

A handwritten note beats a perfect font. An inside joke beats a beautiful animation.
Time spent writing new combinations is worth more than time spent polishing existing
card art.

*Design test*: "Should we spend a week polishing the card art or writing 10 more
combinations?" → Write 10 more combinations.

### Anti-Pillars (What This Game Is NOT)

- **NOT a challenge game**: No fail states, no health bars, no losing. Difficulty
  exists only as discovery friction — the pleasant resistance of "I haven't figured
  this out yet." Punishment would poison the emotional tone.
- **NOT procedural**: Every card, every combination recipe, every scene goal, every
  interaction template assignment is handcrafted by Chester. Randomness would break
  the guarantee that she finds exactly what he put there.
- **NOT replayable**: This game is designed to be played once, slowly, and felt.
  Replayability would imply the discoveries are generic. They are not.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
|-----------|---------------------|----------------------|----------------|
| Stacklands | Magnetic card drag; snap/push feedback; card-produces-card loop | Content is personal memories, not generic village resources | Proves the core tactile feel works at small scope |
| Florence | Personal relationship as game subject matter; emotional pacing | Card mechanics vs. minigames; longer form | Validates emotional games about real relationships |
| A Little to the Left | Discovery through observation; no text instructions | Our goals are hidden, not puzzle-solved | Proves players enjoy working out rules themselves |

**Non-game inspirations**: Scrapbooks and photo albums — the way physical memory
objects carry emotional weight just by existing. The act of being given something
handmade.

---

## Target Player Profile

| Attribute | Detail |
|-----------|--------|
| **Name** | Ju |
| **Gaming experience** | Casual to mid-core |
| **Familiarity** | Knows Chester; will recognize every reference |
| **Session context** | Playing alone, at home, probably with music on |
| **What she's looking for** | Surprise, recognition, warmth — to feel seen |
| **What would turn her away** | Frustration from being stuck with no way forward |

---

## Technical Considerations

| Consideration | Assessment |
|---------------|-----------|
| **Engine** | Godot 4.6 — free, great 2D support, GDScript is approachable for first game |
| **Key Technical Challenges** | Interaction template framework (data-driven, extensible); magnetic physics feel |
| **Art Style** | 2D, hand-drawn or illustrated — warmth over precision |
| **Art Pipeline Complexity** | Medium — card art per memory, scene backgrounds, one illustrated finale |
| **Audio Needs** | Minimal — ambient music per scene, satisfying card snap SFX |
| **Networking** | None |
| **Content Volume** | 5–8 scenes × ~20–30 cards each = ~120–200 cards total; ~3–5 hrs of play |
| **Procedural Systems** | None — fully handcrafted |

---

## Risks and Open Questions

### Design Risks

- Combination tree must feel rich enough — content creation (the memories) is the
  primary development workload, not code
- Hidden goals require careful calibration: too obscure and she stalls; too obvious
  and the discovery moment is lost

### Technical Risks

- Interaction template framework is the load-bearing system — needs prototyping first
- Magnetic card feel is subtle to tune; too strong feels sticky, too weak feels loose

### Scope Risks

- Art for 5–8 scenes + final illustrated memory — even simple art takes time for a
  solo developer
- Content volume (~150 cards, 5–8 scene goals) may expand as memories are added

### Open Questions

- What does the card snap animation look and feel like at ~60fps in Godot? → Prototype this first
- How does the delayed visual cue (fading arc) trigger gracefully without feeling punishing? → Test with a timer + tween in early build

---

## MVP Definition

**Core hypothesis**: Dragging one memory-card onto another and watching a new card
appear is emotionally satisfying when the content is personal.

**Required for MVP**:
1. Card engine: drag, magnetic snap, push-away
2. One interaction template working (Additive: both stay + new card spawns)
3. One complete scene (Home) with two status bars and one hidden goal type
4. ~15–20 cards with real content (actual memories, real labels)
5. Delayed visual cue system (arc fades in after 5 min)

**Explicitly NOT in MVP**:
- Multiple interaction templates (add after core feel is validated)
- Multiple scenes
- Final illustrated memory
- Polish: sound, music, animations beyond snap/push

### Scope Tiers

| Tier | Content | Features | Notes |
|------|---------|----------|-------|
| **MVP** | 1 scene, ~20 cards | Card engine, 1 template, 1 goal type, hint system | Tests core hypothesis |
| **Vertical Slice** | 2–3 scenes, ~60 cards | All 4 templates, 2–3 goal types | Tests emotional arc |
| **Full Vision** | 5–8 scenes, ~150 cards | All features, final illustrated memory | The gift |

---

## Next Steps

- [ ] Run `/map-systems` to decompose into individual buildable systems
- [ ] Run `/design-system` to author per-system GDDs (card engine, template framework, scene goals, hint system)
- [ ] Prototype the card engine and magnetic feel first (`/prototype card-engine`)
- [ ] Validate core feel with a real test: does snapping a card feel good?
- [ ] Begin writing card content — the memories are the game
