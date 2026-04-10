# Recipe Database

> **Status**: Designed
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-23
> **Implements Pillar**: Interaction is Expression; Personal > Polished

## Overview

The Recipe Database is a read-only data resource containing all combination rules
for the game. Each rule maps a pair of card IDs to an interaction template
(Additive, Merge, Animate, or Generator) and defines the result. When the Card
Engine detects two compatible cards snapping together, it queries the Recipe
Database to determine what happens next. No combination can fire that isn't defined
here — incompatible pairs are simply those with no matching rule.

## Player Fantasy

The player never sees the Recipe Database. What she sees is its output: a card
snapping into place, a new card appearing, two cards slowly drifting toward each
other. The database is where Chester makes promises — "when she finds these two
things and puts them together, *this* will happen." Every rule is an act of design
that will play out exactly once, for exactly one person.

## Detailed Design

### Core Rules

1. The Recipe Database is **read-only**. No system writes to it at runtime.
2. A recipe matches on exactly two card IDs. No wildcards, no type-based matching.
3. Combinations are **symmetric**: `card_a + card_b` fires the same rule as `card_b + card_a`. The lookup system normalizes order (e.g., sort IDs alphabetically) so Chester authors each pair once.
4. If no rule exists for a given pair, the cards are incompatible — the Card Engine push-away fires.
5. Each recipe specifies exactly one interaction template. The template determines what happens to the source cards and what (if anything) is produced.
6. A recipe can be scoped to a specific scene (`scene_id`) or available globally. Scene-scoped rules only fire when the player is in that scene.
7. The database is loaded once at game start and held in memory.

### Recipe Schema

Each recipe entry contains:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique kebab-case rule identifier (e.g. `chester-rainy-afternoon`) |
| `card_a` | string | Yes | First card ID — references Card Database |
| `card_b` | string | Yes | Second card ID — references Card Database |
| `template` | enum | Yes | `Additive` \| `Merge` \| `Animate` \| `Generator` |
| `scene_id` | string | Yes | Scene where this rule is active, or `"global"` |
| `config` | object | Yes | Template-specific configuration — see below |

### Template Configurations

Each template type uses a different `config` structure:

**Additive** — both source cards remain; new card(s) appear on the table

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `spawns` | string[] | Yes | IDs of cards to add to the table near the combination point |

**Merge** — both source cards are removed; one new card takes their place

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `result_card` | string | Yes | ID of the card that replaces the two source cards |

**Animate** — source cards begin moving in a defined pattern; no cards produced or consumed

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `motion` | enum | Yes | `drift` \| `orbit` \| `pulse` \| `float` |
| `speed` | float | Yes | Movement speed multiplier (1.0 = default) |
| `target` | enum | Yes | `card_a` \| `card_b` \| `both` — which card(s) animate |
| `duration_sec` | float | No | How long the animation runs; null = loops indefinitely |

**Generator** — one card begins periodically spawning a new card; source cards remain

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `generates` | string | Yes | ID of the card to generate |
| `interval_sec` | float | Yes | Seconds between each generated card |
| `max_count` | int | No | Stop generating after this many cards; null = no limit |
| `generator_card` | enum | Yes | `card_a` \| `card_b` — which source card becomes the generator |

### States and Transitions

The Recipe Database has no state. It is stateless data — the same lookup always
returns the same result. Runtime state (e.g., which generators are active) is
owned by the Interaction Template Framework, not the database.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Card Database** | Reads from | Validates that `card_a`, `card_b`, and result card IDs exist in the Card Database at load time |
| **Interaction Template Framework** | Reads from | Queries by `(card_a_id, card_b_id)` pair; receives the matching recipe (template type + config) or null if no rule exists |

The Recipe Database has no awareness of how the Interaction Template Framework
executes the result. It only returns the rule; execution is the Framework's responsibility.

## Formulas

None. The Recipe Database is a read-only lookup table with no mathematical
operations. All calculations based on recipe results (e.g., generator timing,
animation speed) are executed by the Interaction Template Framework using values
read from this database's config fields.

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **No matching rule** | Card pair has no recipe | Returns null; Card Engine fires push-away. Not an error — this is expected for incompatible pairs. |
| **Duplicate rule** | Two recipes define the same card pair in the same scene | Fail loudly at load time naming the conflicting pair. Never silently pick one. |
| **Rule references unknown card ID** | `card_a`, `card_b`, or a result card doesn't exist in Card Database | Fail loudly at load time naming the missing ID and the recipe it belongs to. |
| **Generator with interval_sec = 0** | Config sets generation interval to zero | Clamp to a minimum of 0.5 seconds. Log a warning. Zero-interval generators would produce infinite cards instantly. |
| **Additive with empty spawns list** | `spawns: []` — no cards defined | Log a warning and treat as a no-op. The snap fires but nothing is produced. |
| **Merge with result_card = source card** | `result_card` is the same ID as `card_a` or `card_b` | Allow it — the card "survives" the merge. Not an error, but flag in authoring tools as unusual. |
| **Same rule exists as both global and scene-scoped** | A pair has a global rule and a scene-specific rule for the same scene | Scene-scoped rule takes precedence over global. |

## Dependencies

### Upstream (this system depends on)

| System | What We Need |
|--------|-------------|
| **Card Database** | All card IDs — used to validate recipe entries at load time. A recipe referencing an unknown card ID should fail at load, not at runtime. |

### Downstream (systems that depend on this)

| System | What They Need |
|--------|---------------|
| **Interaction Template Framework** | Lookup by card pair → recipe (template type + config). The primary consumer. |

## Tuning Knobs

No runtime tuning knobs. All values are authored at design time. Content targets:

| Knob | Description | Current Target |
|------|-------------|----------------|
| Total recipe count | Combination rules across all scenes | ~150–300 (roughly 1–2 recipes per card) |
| Recipes per scene | Discoverable combinations in one scene | ~30–60 |
| Generator interval range | Practical range for `interval_sec` | 2–30 seconds (minimum clamped to 0.5) |
| Additive spawn count | Cards produced per Additive combination | Typically 1–2; more than 3 clutters the table |

## Acceptance Criteria

- [ ] Given a valid card pair, the database returns the correct recipe with template type and config
- [ ] Given a pair with no rule, returns null (no crash, no error log)
- [ ] Combinations are symmetric: lookup(`a`,`b`) == lookup(`b`,`a`)
- [ ] Duplicate rules for the same pair in the same scene are detected at load time
- [ ] Any recipe referencing an unknown card ID fails at load time with the ID named
- [ ] Scene-scoped rules take precedence over global rules for the same pair
- [ ] Generator with `interval_sec < 0.5` is clamped and logged as a warning
- [ ] A recipe can be added or edited in the data file without changing any code
- [ ] Database loads fully before any card combination can be attempted

## Open Questions

- **File format**: Same decision as Card Database — JSON vs Godot `.tres`. Should use the same format for consistency. Resolve when Card Database format is decided.
- **Animate motions**: Are `drift`, `orbit`, `pulse`, `float` the right four? Needs validation when Card Engine and Interaction Template Framework are prototyped.
- **Multi-fire rules**: Can the same pair fire again after being combined once? (e.g., you split a Merge and try again.) Currently undefined — the Interaction Template Framework will need to decide whether combinations are one-time or repeatable. Flag as provisional.
