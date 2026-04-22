# Card Database

> **Status**: Designed
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-23
> **Implements Pillar**: Personal > Polished; Recognition over Reward

## Overview

The Card Database is a read-only data resource containing every card definition
in the game. It is the single source of truth for card identity — name, display
text, art reference, type, and any metadata needed by other systems. No card can
exist at runtime that isn't defined here. For *Moments*, authoring the Card
Database is equivalent to writing the game's content: every memory Chester encodes
for Ju begins here as a card entry.

## Player Fantasy

The player never interacts with the Card Database directly. Its fantasy is
invisible: every card that appears on the table should feel *inevitable* — like
it could only exist in this game, made by this person. The database makes that
possible by separating *what a card is* from *how it behaves*. Chester authors
meaning; the engine delivers it.

## Detailed Design

### Core Rules

1. The Card Database is a **read-only** data resource. No system writes to it at runtime.
2. Every card that can ever appear on the table must have an entry in the database.
3. A card's `id` is its permanent, unique identifier. IDs must never be reused or changed after authoring begins.
4. All runtime systems reference cards exclusively by `id`. Display and visual data are resolved by reading the database at load time.
5. The database is loaded once at game start and held in memory for the session.

### Card Schema

Each card entry contains the following fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique kebab-case identifier (e.g. `rainy-afternoon`). Never changes after authoring. |
| `display_name` | string | Yes | Text shown on the card face. Can be an inside joke, a date, a name — anything Ju will recognize. |
| `flavor_text` | string | No | Optional small text below the display name. A date, a fragment, a note, or empty. |
| `art_path` | string | Yes | Path to the card's image asset (e.g. `res://assets/cards/rainy-afternoon.png`). |
| `type` | enum | Yes | Card category — see Card Types below. |
| `scene_id` | string | Yes | Which scene this card belongs to, or `"global"` if it can appear in multiple scenes. |
| `tags` | string[] | No | Optional labels for authoring convenience (e.g. `["feeling", "home"]`). Not used by gameplay systems. |

### Card Types

| Type | Description | Examples |
|------|-------------|---------|
| `person` | Real people in the relationship | "Chester", "Ju", a shared friend |
| `place` | Physical locations that carry meaning | "Home", "The café", "Kyoto" |
| `feeling` | Emotions and emotional states | "Nervous", "Safe", "3am energy" |
| `object` | Tangible things with meaning | A handmade gift, a song, a specific photo |
| `moment` | Specific dated or described memories | "The first call", "That argument we fixed" |
| `inside_joke` | Shared language only Chester and Ju know | Any reference only she will understand |
| `seed` | Starting cards placed on the table at scene start | Technical type — not content |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Recipe Database** | Reads from DB | Uses `id` to define combination rules. DB has no awareness of recipes. |
| **Card Engine** | Reads from DB | Uses `id` to track card identity at runtime. Engine owns position/physics; DB owns definition. |
| **Card Visual** | Reads from DB | Uses `display_name`, `flavor_text`, `art_path` to render the card face. |
| **Card Spawning System** | Reads from DB | Uses `id` and `type` to instantiate cards. Receives a list of card IDs from Scene Manager. |
| **Save/Progress System** | Reads from DB | Uses `id` to record which cards have been discovered or unlocked. |

All relationships are one-way: systems read from the database. Nothing writes to it at runtime.

## Formulas

None. The Card Database is a read-only data lookup system with no mathematical
operations. Formula logic lives in the systems that consume card data (e.g.,
Scene Goal System, Status Bar System).

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **Card ID not found** | A system requests an ID not in the database (e.g. recipe typo) | Log a clear error naming the missing ID. Do not crash silently. |
| **Duplicate ID** | Two entries share the same `id` | Fail loudly at load time with the conflicting ID named. Never allow silent overwrite. |
| **Missing art asset** | `art_path` points to a nonexistent file | Card Visual renders a fallback placeholder image. Log a warning naming the card ID. |
| **Empty `display_name`** | A card entry has no name | Catch at load time with a validation warning. Do not allow nameless cards in production. |
| **Orphaned `scene_id`** | A card references a scene that doesn't exist | Log a warning at load time. Card is still valid; it simply won't be spawned by any scene. |

## Dependencies

### Upstream (this system depends on)

None. The Card Database is a Foundation-layer system with no runtime dependencies.

### Downstream (systems that depend on this)

| System | What They Need |
|--------|---------------|
| Recipe Database | `id` — to reference cards in combination rules |
| Card Engine | `id` — to track card identity |
| Card Visual | `display_name`, `flavor_text`, `art_path` — to render card faces |
| Card Spawning System | `id`, `type` — to instantiate cards |
| Save/Progress System | `id` — to record discovery state |

## Tuning Knobs

The Card Database has no runtime tuning knobs. All values are authored at design
time. The only "tuning" is content authoring:

| Knob | Description | Current Target |
|------|-------------|----------------|
| Total card count | Total entries across all scenes | ~120–200 |
| Cards per scene | Seed cards + cards unlockable within one scene | ~20–30 |
| Scene count | Total scenes in the game | 5–8 |

## Acceptance Criteria

- [ ] Given a valid card ID, the database returns the correct card entry with all fields
- [ ] Requesting a nonexistent ID logs a clear error and does not crash the game
- [ ] Duplicate IDs are detected and reported at load time
- [ ] A card with a missing art asset shows a fallback placeholder without crashing
- [ ] Empty `display_name` entries are flagged at load time
- [ ] Database loads fully before any card is instantiated (no lazy-load race conditions)
- [ ] All 7 card types (person, place, feeling, object, moment, inside_joke, seed) are representable
- [ ] A card definition can be added or edited in the data file without changing any code

## Open Questions

- **File format**: ✅ **RESOLVED by [ADR-005](../../docs/architecture/adr-0005-data-file-format-convention.md)** — Godot `.tres` Resource files via `ResourceLoader`. Card Database is stored as a single manifest at `res://assets/data/cards.tres` containing an `Array[CardEntry]`. See "File Format and Schema" section below.
- **Art asset format**: PNG assumed — confirm resolution and size constraints with Card Visual system design.
- **Localization**: Not required for this game (single player, personal gift), but the schema supports it if `display_name` ever needs translation.

## File Format and Schema

Per [ADR-005](../../docs/architecture/adr-0005-data-file-format-convention.md):

- **Storage**: single manifest file at `res://assets/data/cards.tres`.
- **Resource class**: `res://src/data/card_entry.gd` declares `class_name CardEntry extends Resource` with typed `@export` fields matching the Card Schema table above.
- **Manifest class**: a thin wrapper Resource with `@export var entries: Array[CardEntry]`.
- **Loader**: `CardDatabase._ready()` calls `ResourceLoader.load("res://assets/data/cards.tres")`, casts via `as CardManifest`, asserts non-null, then runs `_validate_entries()` for id uniqueness, non-empty `display_name`, and enum-valid `type`.
- **No JSON.** Any `FileAccess` + `JSON.parse_string` path for card data is a forbidden pattern per ADR-005 §9.
- **`type` field** is backed by the `CardEntry.CardType` enum declared inside the Resource class; Inspector shows a dropdown rather than a free-text string.
- **`art` field** is a `Texture2D` `@export` (UID-safe across asset moves), not a string path.
