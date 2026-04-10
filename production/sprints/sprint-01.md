# Sprint 01 — Foundation Layer

**Start**: 2026-03-27
**End**: 2026-03-27
**Status**: COMPLETE

**Goal**: All three foundation systems implemented, tested, and integrated.
         The game can load card definitions and recipe definitions from data files,
         and mouse input is routed through the Input System.

---

## Systems in Scope

| System | GDD | Layer | Status |
|--------|-----|-------|--------|
| Card Database | design/gdd/card-database.md | Foundation | ✓ Done |
| Recipe Database | design/gdd/recipe-database.md | Foundation | ✓ Done |
| Input System | design/gdd/input-system.md | Foundation | ✓ Done |

---

## Tasks

### Card Database
- [x] Create `assets/data/cards/` directory
- [x] Author seed card data files: `chester.json`, `ju.json`, `home.json`
- [x] Author result card data files: `morning-together.json`, `coffee.json`, `comfort.json`
- [x] Implement `src/core/card_database.gd` as Autoload singleton
- [x] Register `CardDatabase` as Autoload in project.godot
- [x] Verified: loads 6 cards at startup, zero errors

### Recipe Database
- [x] Create `assets/data/recipes/` directory
- [x] Author seed recipe data files: `chester-ju.json`, `chester-home.json`, `ju-home.json`
- [x] Implement `src/core/recipe_database.gd` as Autoload singleton
- [x] Register `RecipeDatabase` as Autoload in project.godot
- [x] Verified: loads 3 recipes at startup, zero errors, card ID validation passes

### Input System
- [x] Implement `src/core/input_system.gd` as Autoload singleton
  - 5 signals: `drag_started`, `drag_moved`, `drag_released`, `proximity_entered`, `proximity_exited`
  - `register_card` / `unregister_card` / `cancel_drag`
  - Hit-test by z-index, proximity check each frame
- [x] Register `InputSystem` as Autoload in project.godot
- [x] Verified: loads without errors

---

## Definition of Done

- [x] All three Autoloads registered and load without errors on project start
- [x] `CardDatabase` loads 6 cards from JSON — no hardcoded data
- [x] `RecipeDatabase` loads 3 recipes, validates all card ID references against CardDatabase
- [x] `InputSystem` registered; signals ready for Card Engine to connect
- [x] No hardcoded card or recipe data in any `.gd` file

---

## Delivered Files

```
src/core/card_database.gd
src/core/recipe_database.gd
src/core/input_system.gd

assets/data/cards/chester.json
assets/data/cards/ju.json
assets/data/cards/home.json
assets/data/cards/morning-together.json
assets/data/cards/coffee.json
assets/data/cards/comfort.json

assets/data/recipes/chester-ju.json
assets/data/recipes/chester-home.json
assets/data/recipes/ju-home.json
```
