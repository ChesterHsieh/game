# Story 005: Generator interval_sec clamp (≥ 0.5 s)

> **Epic**: recipe-database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/recipe-database.md`
**Requirement**: `TR-recipe-database-007` — clamp Generator `interval_sec`
minimum to 0.5 seconds; log warning on values below.

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §6
validation strategy
**ADR Decision Summary**: Semantic validation in `_ready()` via `push_warning`
+ in-place clamp. Unlike duplicate-rule detection (which is an `assert` halt),
interval clamping is a content-authoring warning — the game can still run with
clamped values.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `push_warning()` is stable in 4.3. Clamping a float in
place on a Resource field is safe — the loaded Resource is already in memory
and not written back to disk.

**Control Manifest Rules (Foundation layer)**:
- Required: semantic validation in autoload `_ready()`.
- Forbidden: silently accepting `interval_sec < 0.5` without warning.
- Guardrail: O(n) over generator-template recipes; sub-millisecond.

---

## Acceptance Criteria

*From GDD `design/gdd/recipe-database.md`:*

- [ ] Every recipe with `template == &"generator"` has its
      `config.interval_sec` checked
- [ ] `interval_sec < 0.5` is clamped to `0.5` and a `push_warning` is
      emitted naming the recipe id and the original value
- [ ] `interval_sec >= 0.5` passes through unchanged with no warning
- [ ] `interval_sec == 0.0` (the zero-interval edge case from the GDD)
      is clamped to 0.5 with warning
- [ ] Negative `interval_sec` is clamped to 0.5 with warning
- [ ] Non-generator templates are skipped (no interval check on additive,
      merge, animate)
- [ ] Clamping runs in `_ready()` AFTER Story 003 (card-ref validation)
      and Story 004 (duplicate detection), BEFORE Story 006 (index-build)
- [ ] A fixture with all `interval_sec >= 0.5` produces zero warnings

---

## Implementation Notes

*Derived from ADR-005 §6 and GDD Edge Case "Generator with interval_sec = 0":*

1. Add `_clamp_generator_intervals()` to `_ready()`:
   ```gdscript
   const MIN_INTERVAL_SEC := 0.5

   func _clamp_generator_intervals() -> void:
       for r: RecipeEntry in _entries:
           if r.template != &"generator":
               continue
           var interval: float = r.config.get("interval_sec", MIN_INTERVAL_SEC)
           if interval < MIN_INTERVAL_SEC:
               push_warning(
                   "RecipeDatabase: recipe '%s' generator interval_sec %.3f < %.1f — clamped to %.1f"
                       % [r.id, interval, MIN_INTERVAL_SEC, MIN_INTERVAL_SEC])
               r.config["interval_sec"] = MIN_INTERVAL_SEC
   ```
2. Call `_clamp_generator_intervals()` in `_ready()` AFTER
   `_validate_no_duplicates()` (Story 004) and BEFORE Story 006's
   index-build. The index needs clamped data.
3. Use `push_warning`, NOT `assert` — a below-minimum interval is a
   content-authoring mistake that can be auto-corrected, not a fatal
   inconsistency.
4. The constant `MIN_INTERVAL_SEC` is defined on the autoload class.
   The GDD Tuning Knobs section documents the minimum as 0.5.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: card-ref validation
- Story 004: duplicate-rule detection
- Story 006: lookup API
- Generator `max_count` validation — not specified in GDD as a load-time
  check; null means infinite, which is valid
- Animate `motion` enum validation — belongs to ITF, not RecipeDatabase

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (interval_sec below minimum is clamped)**:
  - Given: a generator recipe with `config.interval_sec = 0.1`,
    recipe `id = &"fast-gen"`
  - When: `_ready()` runs
  - Then: `config["interval_sec"] == 0.5`; a warning was emitted
    containing `fast-gen` and `0.1`
  - Edge cases: `interval_sec = 0.499` → clamped; `interval_sec = 0.5`
    → NOT clamped

- **AC-2 (interval_sec == 0.0 clamped)**:
  - Given: a generator recipe with `config.interval_sec = 0.0`
  - When: `_ready()` runs
  - Then: `config["interval_sec"] == 0.5`; warning emitted

- **AC-3 (negative interval_sec clamped)**:
  - Given: a generator recipe with `config.interval_sec = -2.0`
  - When: `_ready()` runs
  - Then: `config["interval_sec"] == 0.5`; warning emitted

- **AC-4 (interval_sec at minimum: no warning)**:
  - Given: a generator recipe with `config.interval_sec = 0.5`
  - When: `_ready()` runs
  - Then: `config["interval_sec"] == 0.5`; no warning emitted

- **AC-5 (interval_sec above minimum: no change)**:
  - Given: a generator recipe with `config.interval_sec = 5.0`
  - When: `_ready()` runs
  - Then: `config["interval_sec"] == 5.0`; no warning emitted

- **AC-6 (non-generator templates skipped)**:
  - Given: a fixture with additive, merge, and animate recipes
    (no generator recipes)
  - When: `_ready()` runs
  - Then: no interval-related warnings emitted

- **AC-7 (clean fixture: zero warnings)**:
  - Given: a fixture with 2 generator recipes, both
    `config.interval_sec >= 0.5`
  - When: `_ready()` runs
  - Then: zero interval-related warnings

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/recipe_database/generator_clamp_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (autoload), Story 003 (card-ref validation runs
  first), Story 004 (duplicate detection runs first)
- Unlocks: Story 006 (lookup index needs clamped data)
