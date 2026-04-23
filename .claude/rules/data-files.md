---
paths:
  - "assets/data/**"
---

# Data File Rules

- All JSON files must be valid JSON — broken JSON blocks the entire build pipeline
- File naming: lowercase with underscores only, following `[system]_[name].json` pattern
- Every data file must have a documented schema (either JSON Schema or documented in the corresponding design doc)
- Numeric values must include comments or companion docs explaining what the numbers mean
- Use consistent key naming: camelCase for keys within JSON files
- No orphaned data entries — every entry must be referenced by code or another data file
- Version data files when making breaking schema changes
- Include sensible defaults for all optional fields

## Enum-ish string field rule

When a data-file field takes one of a fixed set of string values (a template
name, a goal type, a card type, a recipe template, an animation motion etc.),
the string MUST be **lowercase_snake_case** in the data file AND the GDScript
`match` statement that dispatches on it MUST use the same lowercase spelling.

Why: Godot's `match` is case-sensitive. A PascalCase matcher against a lowercase
data value produces a silent fall-through to the default arm — usually a
`push_warning` that's easy to miss in a busy log. The Coffee Intro vertical
slice wasted a debugging session on `template = "merge"` (data) vs
`match "Merge":` (code).

How to apply:
- Recipes: `template` field values — `additive`, `merge`, `animate`, `generator`
- Recipes: `config.emote` field values — filename stems from `assets/emotes/`,
  currently: `spark`, `heart`, `ok`, `sweat`, `anger`, `question`, `exclaim`,
  `zzz`. Absent or `none` = no emote.
- Scene goals: `type` field values — `sustain_above`, `reach_value`, `find_key`, `sequence`
- Cards: `type` field values mirror the `CardType` enum — `person`, `place`, `feeling`, `object`, `moment`, `inside_joke`, `seed`
- Any new enum-ish field added to a `.tres` or `.json` — follow the same convention
- If a matcher is added to code, lowercase the arm labels and add a `to_lower()`
  call on the incoming value defensively:
  ```gdscript
  var template := String(recipe["template"]).to_lower()
  match template:
      "merge": ...
  ```
- If a data file must be updated, grep the codebase for `match` on that field
  and update every arm at the same time. Don't leave mixed-case arms.

## Examples

**Correct** naming and structure (`combat_enemies.json`):

```json
{
  "goblin": {
    "baseHealth": 50,
    "baseDamage": 8,
    "moveSpeed": 3.5,
    "lootTable": "loot_goblin_common"
  },
  "goblin_chief": {
    "baseHealth": 150,
    "baseDamage": 20,
    "moveSpeed": 2.8,
    "lootTable": "loot_goblin_rare"
  }
}
```

**Incorrect** (`EnemyData.json`):

```json
{
  "Goblin": { "hp": 50 }
}
```

Violations: uppercase filename, uppercase key, no `[system]_[name]` pattern, missing required fields.
