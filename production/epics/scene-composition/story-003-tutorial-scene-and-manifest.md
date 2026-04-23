# Story 003: Tutorial scene JSON + manifest registration

> **Epic**: scene-composition
> **Status**: Complete
> **Layer**: Presentation + Content
> **Type**: Config/Data
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-manager.md`, `design/gdd/scene-goal-system.md`
**Requirement**: TR-scene-manager-002 (load scene by id), TR-scene-goal-system-002 (reach_value goal)

**ADR Governing Implementation**: ADR-005: Data File Format Convention
**ADR Decision Summary**: Scene configs live as individual JSON files in
`assets/data/scenes/` (file-per-scene keeps narrative-facing authoring simple);
the ordered playlist lives as `SceneManifest` in `scene-manifest.tres`.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `FileAccess.get_as_text()` + `JSON.parse_string()` is the
existing loader in `src/gameplay/scene_goal_system.gd`. No new code.

**Control Manifest Rules (Content layer)**:
- Required: every seed_cards entry has a `card_id` key matching a CardDatabase id
- Required: bars referenced in goal config appear as bar_effect targets somewhere
- Forbidden: file names with spaces or uppercase letters

---

## Acceptance Criteria

- [ ] File `assets/data/scenes/coffee-intro.json` exists with `scene_id = "coffee-intro"`
- [ ] Seed cards block lists: `chester`, `ju`, `coffee_machine`, `coffee_beans` (in this order)
- [ ] Goal config:
  - `type = "reach_value"`
  - `bars = [{ id: "affection", initial_value: 0, decay_rate_per_sec: 0.0 }]`
  - `max_value = 100.0`
  - `threshold = 100.0`
  - `duration_sec = 0.1` (reach_value fires near-instantly once threshold is hit)
- [ ] `scene-manifest.tres` lists `coffee-intro` as the **first** entry (before any other scenes); `home` may remain as the second entry for later scenes
- [ ] `SceneGoal.load_scene(&"coffee-intro")` transitions to ACTIVE and emits `seed_cards_ready` with exactly 4 cards

---

## Implementation Notes

### coffee-intro.json

Follow the existing shape from `assets/data/scenes/home.json` — same top-level
keys, only the values change. A minimal payload:

```json
{
  "scene_id": "coffee-intro",
  "seed_cards": [
    { "card_id": "chester" },
    { "card_id": "ju" },
    { "card_id": "coffee_machine" },
    { "card_id": "coffee_beans" }
  ],
  "goal": {
    "type": "reach_value",
    "bars": [
      { "id": "affection", "initial_value": 0, "decay_rate_per_sec": 0.0 }
    ],
    "max_value": 100,
    "threshold": 100,
    "duration_sec": 0.1
  }
}
```

### scene-manifest.tres

Update the `scene_ids` array to `PackedStringArray("coffee-intro", "home")` —
SceneManager plays them in declaration order, so this places Coffee Intro as
scene-01. Leave the rest of the file untouched.

---

## Out of Scope

- `gameplay.tscn` composition (Story 004)
- Playtesting and reports (Story 005)
- New bars beyond `affection` — status-bar-system already supports arbitrary
  bar ids via the scene JSON; no code change

---

## QA Test Cases

- **AC-1 (file loads)**:
  - Given: `coffee-intro.json` on disk
  - When: `SceneGoal.load_scene(&"coffee-intro")` is called
  - Then: `SceneGoal.get_goal_config()["type"] == "reach_value"`, `_scene_id == "coffee-intro"`

- **AC-2 (seed cards emitted)**:
  - Given: scene loaded
  - When: `seed_cards_ready` signal fires
  - Then: payload is an Array of 4 entries with the correct card_ids in order

- **AC-3 (manifest lists scene first)**:
  - Given: SceneManager loaded `scene-manifest.tres`
  - When: the internal `_manifest.scene_ids` is inspected
  - Then: index 0 is `"coffee-intro"`

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke-check pass at
`production/qa/smoke-coffee-intro-scene.md`. Manual verification: launch the
game, observe 4 cards seeded on the table.

**Status**: [x] production/qa/smoke-coffee-intro-scene.md — PASS 2026-04-23

---

## Dependencies

- Depends on: Story 001 (card ids), Story 002 (bar-effects bar id "affection")
- Unlocks: Story 004 (gameplay.tscn boot flow triggers SceneManager which loads this scene first)
