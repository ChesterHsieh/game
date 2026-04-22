# Mystery Unlock Tree

> **Status**: In Review (2nd revision — re-review applied 2026-04-18)
> **Author**: Chester + Claude Code agents
> **Last Updated**: 2026-04-18
> **Implements Pillar**: Discovery Without Explanation

## Overview

The Mystery Unlock Tree is a Feature-layer runtime data structure that tracks which card combinations the player has discovered across the full game session. It listens to the Interaction Template Framework's `combination_executed` signal (via EventBus, ADR-003) and records each unique recipe as a discovery. Within a scene, the MUT determines which cards are *available but not yet on the table* — enabling a tree-like unfolding where early combinations produce cards that unlock later combinations. Across scenes, it accumulates a persistent discovery set that gates scene-to-scene progression: a scene's breakthrough condition may require a minimum number of discoveries, or a specific key recipe, before the next chapter opens. At the game level, it tracks progress toward the final illustrated memory — the emotional centerpiece that requires the full discovery journey to reach. The player never sees or manipulates the tree directly. She combines cards, and the world responds: new cards appear, a scene resolves, a door opens. The MUT is the invisible ledger that makes that curated unfolding possible — without it, all cards would be available from the start and the game would lose its discovery arc.

## Player Fantasy

The Mystery Unlock Tree mirrors associative memory — one thing leads to another, not because someone explained the order, but because that's how remembering actually works. She drags the coffee shop card onto the rain card and suddenly new cards appear: the umbrella, the song, the walk home. The player fantasy is *my mind is doing this* — the game responds the way her own memory does when a smell or a song pulls an entire evening back into focus.

The anchor moment is the cascade: she combines two cards and the result isn't one unlock but a small flood, and she exhales and thinks "oh — I forgot about that, but of course that's what happened next." The tree never feels like a puzzle to solve. It feels like a drawer she's opening that she didn't know was still full.

Underneath, unnamed, is a second layer: the *shape* of what she remembers quietly reveals that someone who was there built this path for her. The specific leap from one card-pair to its result is so precisely Chester — so exactly the connection he would make — that the system stops feeling like a system and starts feeling like a letter. She doesn't need to notice this. But in the third scene, when a combination result makes her look up from the screen, the authorship is felt even if it's never said.

The design test: if she drags two cards together and the result makes her say "oh my god, I haven't thought about that in years" — the tree is working. If she says "oh cool, I unlocked something" — it isn't.

## Detailed Design

### Core Rules

**1. MUT is an autoload singleton** (registered as `MysteryUnlockTree` in project autoloads). It is a pure observer during gameplay — it listens to signals, records discoveries, and answers queries. It never spawns cards, modifies recipes, or gates recipe execution.

**2. Discovery tracking.** MUT maintains a primary dictionary of discovered recipes:

```
_discovered_recipes: Dictionary
  Key: recipe_id (String)
  Value: {
    card_id_a:       String,    # from the enriched signal
    card_id_b:       String,    # from the enriched signal
    scene_id:        String,    # _active_scene_id at time of discovery
    discovery_order: int,       # 1-indexed global counter
    template:        String     # "additive" | "merge" | "animate" | "generator"
  }
```

Two secondary indices are maintained alongside for efficient queries:

```
_scene_discoveries: Dictionary
  Key: scene_id (String)
  Value: Array[String]  # recipe_ids in discovery order

_cards_in_discoveries: Dictionary
  Key: card_id (String)
  Value: String  # scene_id of first discovery involving this card
```

All three dictionaries are included in save state for simplicity, though the secondary indices could be rebuilt from `_discovered_recipes` + Recipe Database.

**3. Discovery processing.** On `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)`:
   1. Guard: only process in `Active` state. All other states silently discard.
   2. If `recipe_id` is already in `_discovered_recipes`: return. Not a new discovery.
   3. Increment `_discovery_order_counter`.
   4. Store discovery record in `_discovered_recipes[recipe_id]`.
   5. Append `recipe_id` to `_scene_discoveries[_active_scene_id]`.
   6. For each card_id (a and b): if not in `_cards_in_discoveries`, add with current `_active_scene_id`. **First-writer-wins** — later discoveries that reference the same card_id do not overwrite the recorded scene_id.
   7. Emit `EventBus.recipe_discovered(recipe_id, card_id_a, card_id_b, _active_scene_id)`.
   8. If `_suppress_signals == false`: evaluate milestone thresholds (Rule 8).
   9. If `_suppress_signals == false` AND `_epilogue_conditions_emitted == false` AND `partial_threshold > 0.0`: evaluate epilogue conditions. On first emission set `_epilogue_conditions_emitted = true`.

**Intra-handler ordering contract.** Within a single discovery call, Step 8 (milestones) emits before Step 9 (epilogue). Downstream systems listening to both can rely on this order.

**Internal flags.**
- `_suppress_signals: bool` — default `false`. Flipped to `true` only inside the `force_unlock_all` bulk-load bypass (see Rule 9); restored immediately after the bulk assignment completes. Production gameplay never flips this flag.
- `_epilogue_conditions_emitted: bool` — default `false`. Set to `true` the first (and only) time `epilogue_conditions_met()` is emitted. **Persisted in save state** (`get_save_state` / `load_save_state`) so that the one-time contract survives across sessions. Guarded in Rule 3 Step 9 AND checked during `load_save_state` when restoring state into an already-met configuration.

**4. ITF signal enrichment (cross-system change).** `combination_executed` gains two parameters: `card_id_a: String` and `card_id_b: String`. ITF already derives card_ids from instance_ids — this is a one-line addition to the emit call. Existing consumers (Status Bar System) ignore the new parameters. This resolves the ITF GDD open question.

**5. Within-scene role.** MUT does not control which recipes are available or which cards can appear. The recipe graph is the tree: when ITF fires Recipe A (Additive), it spawns Card C via Card Spawning System. Card C being on the table enables Recipe B if the player drags the right pair. MUT records what happened — it does not decide what can happen.

**6. Cross-scene carry-forward.** Scene JSON files may include a `carry_forward` array:

```json
{
  "scene_id": "park",
  "seed_cards": ["bench", "pigeons"],
  "carry_forward": [
    { "card_id": "old-photo", "requires_recipes": ["home-chester-photo"] },
    { "card_id": "umbrella", "requires_recipes": ["home-rain-walk", "home-coffee-rain"] }
  ]
}
```

A carry-forward card is included if **all** `requires_recipes` have been discovered in any prior scene. MUT exposes `get_carry_forward_cards(carry_forward_spec: Array) -> Array[String]`. Scene Goal System calls this during `load_scene()` and appends the result to `seed_cards` before emitting `seed_cards_ready`. This creates a soft dependency: SGS → MUT (read-only query). If MUT returns empty or is unavailable, the scene loads with base seed cards only.

**7. Final illustrated memory condition.** The set of epilogue-required recipes is declared in a dedicated file `res://assets/data/epilogue-requirements.tres` as an explicit array of recipe_ids. At `_ready()`, MUT loads this list into `_epilogue_required_ids`. The per-recipe `epilogue_required` flag on `recipes.tres` is NOT used — one file, one place to audit the gift's required memories. On `epilogue_started()`, MUT evaluates completion using `partial_threshold` (see Formulas):
   - If `R_found >= ceil(R_total * partial_threshold)`: emit `EventBus.final_memory_ready()`. Set `_final_memory_earned = true`.
   - Otherwise: do not emit. Final Epilogue Screen can call `MUT.get_epilogue_state()` for partial data.
   - Degenerate case: if `R_total == 0` (empty or missing `epilogue-requirements.tres`), neither `epilogue_conditions_met()` nor `final_memory_ready()` is ever emitted — the vacuous-truth cliff is explicitly guarded. An error is logged at `_ready()`.

MUT also checks after every new discovery whether the epilogue condition is newly satisfied, and emits `EventBus.epilogue_conditions_met()` at that moment — mid-session, before the epilogue begins. This is a **one-time** signal: once emitted, it does not re-fire for the remainder of the session, and the fact that it fired is persisted via `_epilogue_conditions_emitted` across save/load cycles.

> **Degenerate `partial_threshold == 0.0` guard.** When `partial_threshold == 0.0` and `_epilogue_required_ids` is non-empty, the condition `R_found >= ceil(R_total * 0.0) = 0` is trivially true from the start of the session. To avoid firing `epilogue_conditions_met()` on the first discovery (or arbitrary timing tick), **the mid-session check is suppressed entirely when `partial_threshold == 0.0`** — see Rule 3 Step 9 guard. `final_memory_ready()` is still evaluated on `epilogue_started()` and will fire per its own rule. This makes `0.0` safe as a dev-only "fire the epilogue immediately" test value without polluting mid-session state.

> **Player-visibility constraint (Pillar 3, anti-celebration):** `epilogue_conditions_met` is a preparation signal for engine-side systems only (e.g., Final Epilogue Screen pre-loading assets, silent narrative state updates). Downstream systems MUST NOT produce player-visible feedback (no audio sting, no UI flair, no screen change) in response. Ju must not be told she has "completed" anything mid-session — she learns the shape of the ending by playing into it.

> **Consumer (resolved 2026-04-20 / 2026-04-21).** The Final Epilogue Screen GDD (`design/gdd/final-epilogue-screen.md`) is now authored. Per ADR-004 §2, FES is pre-instanced in `gameplay.tscn` at layer 20; it subscribes to `epilogue_cover_ready` (from STUI) as its reveal gate, not to `epilogue_conditions_met`. `epilogue_conditions_met()` is used by `gameplay_root.gd` and/or Scene Manager's asset preloader as a silent engine-prep hook to begin texture preload for the illustrated memory ahead of STUI's amber cover. No player-visible feedback.

**8. Discovery milestones.** MUT holds a configurable array of `_milestone_pct` (float percentages in (0.0, 1.0], e.g. `[0.15, 0.50, 0.80]`). At `_ready()`, percentages are resolved to absolute counts against `R_authored` (total recipes in Recipe Database): `_milestone_thresholds[i] = max(1, ceil(_milestone_pct[i] * R_authored))`.

**Post-resolution dedup.** Distinct authored percentages can collapse to the same integer threshold when `R_authored` is small (e.g., `_milestone_pct = [0.01, 0.02]` with `R_authored = 10` both resolve to `T = 1`). After resolution, MUT deduplicates `_milestone_thresholds` while preserving the **lowest-index** entry for each unique value, logs a warning naming the dropped entries, and keeps the surviving thresholds strictly ascending.

**`milestone_id` derivation.** The `milestone_id: String` parameter emitted on `discovery_milestone_reached` is derived as `"milestone_" + str(i)` where `i` is the **0-indexed position in the final deduplicated `_milestone_thresholds` array**. Example: `_milestone_pct = [0.15, 0.50, 0.80]` yields milestone_ids `"milestone_0"`, `"milestone_1"`, `"milestone_2"`. This keeps the contract simple and deterministic; no authoring of custom names is supported in v1 (revisit if narrative beats need evocative names — Alpha).

After each new discovery, if `_discovery_order_counter` matches a resolved threshold and `_suppress_signals == false`, emit `EventBus.discovery_milestone_reached(milestone_id, discovery_count)`. Each threshold fires at most once per session.

> **Player-visibility constraint (Pillar 3, anti-celebration):** `discovery_milestone_reached` is for silent narrative beats only (e.g., unlocking a specific carry-forward entry, switching ambient audio bed quietly). Permitted downstream responses: silent gameplay state changes. Forbidden: audio stings, UI flair, visual celebrations, on-screen messages, any response that reads as "you hit a milestone." If the player notices the milestone firing, the tree has failed.

**9. `force_unlock_all` bulk-load bypass (DEV ONLY).** When `debug-config.tres` exists and contains `force_unlock_all: true`, MUT runs a **dedicated bulk-load path** inside `_ready()` (AFTER RecipeDB is queried, BEFORE any scene signal could arrive). The bulk path does NOT call the Rule 3 handler in a loop. Instead:
   1. Set `_suppress_signals = true`.
   2. Iterate every recipe in Recipe Database. For each recipe, write directly into `_discovered_recipes`, `_scene_discoveries["__debug__"]`, and `_cards_in_discoveries` — bypassing the Rule 3 processing pipeline (no `recipe_discovered` emission).
   3. Set `_discovery_order_counter = R_authored`.
   4. Set `_epilogue_conditions_emitted = true` (so that later signal-guards correctly treat the condition as "already met").
   5. Set `_final_memory_earned = true`.
   6. Restore `_suppress_signals = false`.
   7. Log a single warning naming the dev-only override and the number of recipes bulk-marked.

No `recipe_discovered`, `discovery_milestone_reached`, or `epilogue_conditions_met` signals are emitted during this path — verified by AC-047. Queries (`is_final_memory_earned()`, `get_epilogue_state()`) subsequently return the "fully unlocked" state.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `Inactive` | `_ready()` default | `scene_started(scene_id)` or `epilogue_started()` received | Ignores `combination_executed`. No scene context set. |
| `Active` | `scene_started(scene_id)` received | `scene_completed(scene_id)` received | Processes `combination_executed`. Records first-time discoveries. Emits `recipe_discovered`, milestone, and epilogue signals. Answers carry-forward queries. |
| `Transitioning` | `scene_completed(scene_id)` received | `scene_started(next_scene_id)` or `epilogue_started()` received | Ignores `combination_executed`. ITF is also Suspended during this window (dual guard). Answers carry-forward queries for the upcoming scene. |
| `Epilogue` | `epilogue_started()` received | N/A (terminal) | Evaluates final memory condition. Emits `final_memory_ready()` if satisfied. No further discoveries accepted. |

**Transitions:**
- `Inactive → Active`: on `scene_started(scene_id)`. Sets `_active_scene_id`.
- `Inactive → Epilogue`: on `epilogue_started()` (degenerate case — empty manifest in Scene Manager). Evaluates final memory condition with empty discovery set (R_found = 0); if `partial_threshold == 0.0` emit `final_memory_ready()`, otherwise do not. Log a warning. Terminal state.
- `Active → Transitioning`: on `scene_completed(scene_id)` where `scene_id` matches `_active_scene_id`.
- `Active → Epilogue`: on `epilogue_started()` (Scene Manager contract violation — no preceding `scene_completed`). Log a warning. Evaluate final memory condition. Terminal state.
- `Transitioning → Active`: on `scene_started(next_scene_id)`. Updates `_active_scene_id`.
- `Transitioning → Epilogue`: on `epilogue_started()`. Evaluates final memory condition. Terminal state.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **EventBus** (ADR-003) | MUT listens | `combination_executed(recipe_id: String, template: String, instance_id_a: String, instance_id_b: String, card_id_a: String, card_id_b: String)` — primary discovery input |
| **EventBus** | MUT listens | `scene_started(scene_id: String)` — transitions to Active, sets `_active_scene_id` |
| **EventBus** | MUT listens | `scene_completed(scene_id: String)` — transitions to Transitioning |
| **EventBus** | MUT listens | `epilogue_started()` — transitions to Epilogue, evaluates final memory |
| **EventBus** | MUT emits | `recipe_discovered(recipe_id: String, card_id_a: String, card_id_b: String, scene_id: String)` — first-time discovery only. Permitted downstream responses include player-visible feedback (this IS the authored moment of discovery). |
| **EventBus** | MUT emits | `discovery_milestone_reached(milestone_id: String, discovery_count: int)` — silent narrative beat threshold crossed. **Constraint**: downstream systems must NOT produce player-visible feedback (no audio sting, no UI flair). Permitted uses: silent carry-forward unlocks, quiet ambient bed switches. |
| **EventBus** | MUT emits | `epilogue_conditions_met()` — all required epilogue recipes discovered (fires **at most once per save slot**; `_epilogue_conditions_emitted` flag in save state prevents re-fire across sessions). Suppressed entirely when `partial_threshold == 0.0`. **Constraint**: engine-preparation signal only. Consumer: `gameplay_root.gd` / Scene Manager preloader per ADR-004 §2 — triggers silent texture preload for the final illustrated memory. No player-visible feedback. |
| **EventBus** | MUT emits | `final_memory_ready()` — emitted on `epilogue_started()` if `R_found >= R_total * partial_threshold`. This signal IS the cue for the Final Epilogue Screen to begin the authored reveal. |
| **Epilogue Requirements File** | MUT reads at startup | Loads explicit recipe_id array from `res://assets/data/epilogue-requirements.tres` into `_epilogue_required_ids`. |
| **Recipe Database** | MUT reads at startup | Queries `R_authored` (total recipe count) to resolve `_milestone_pct` into absolute thresholds. Validates that every id in `epilogue-requirements.tres` exists in Recipe Database — logs an error on any unknown id. |
| **Scene Goal System** | SGS reads from MUT | `MUT.get_carry_forward_cards(carry_forward_spec: Array) -> Array[String]` — called during `load_scene()` to resolve conditional carry-forward cards |
| **Save/Progress System** | Pulls from MUT | `MUT.get_save_state() -> Dictionary` and `MUT.load_save_state(data: Dictionary)` for persistence |
| **Final Epilogue Screen** | Reads from MUT / listens | `MUT.get_epilogue_state() -> Dictionary` query + listens to `final_memory_ready()` on EventBus |

**Query API (read-only methods, no state mutation):**

| Method | Signature | Description |
|---|---|---|
| `is_recipe_discovered` | `(recipe_id: String) -> bool` | Has this recipe been discovered in the session? |
| `get_discovery_count` | `() -> int` | Total unique recipes discovered |
| `get_scene_discoveries` | `(scene_id: String) -> Array[String]` | Recipe IDs discovered in a specific scene, in order |
| `get_scene_discovery_count` | `(scene_id: String) -> int` | Number of discoveries in a specific scene |
| `get_discovery_record` | `(recipe_id: String) -> Dictionary` | Full record for a recipe (empty dict if undiscovered) |
| `is_card_in_discovery` | `(card_id: String) -> bool` | Has this card appeared in any discovered recipe? |
| `get_carry_forward_cards` | `(carry_forward_spec: Array) -> Array[String]` | Evaluates carry-forward conditions, returns qualifying card IDs |
| `get_epilogue_state` | `() -> Dictionary` | Returns `{ required_count, discovered_count, is_complete, missing_ids }` |
| `is_final_memory_earned` | `() -> bool` | True if all epilogue-required recipes are discovered |
| `get_save_state` | `() -> Dictionary` | Serializable snapshot of full discovery state |
| `load_save_state` | `(data: Dictionary) -> void` | Restores discovery state from saved snapshot |
| `_inject_config` *(test-only)* | `(config: Dictionary) -> void` | Test seam: overrides `mut-config.tres` load with an in-memory Dictionary (keys `milestone_pct`, `partial_threshold`). Used by unit tests to set malformed / edge-case configs without touching the filesystem. Must be called before `_ready()` runs, or (in tests) replaces the file-load step entirely. |
| `_inject_debug_config` *(test-only)* | `(config: Variant) -> void` | Test seam: overrides `debug-config.tres` load. Pass a Dictionary to simulate presence, `null` to simulate absent file. |

**Threading caveat.** All MUT state, dictionaries, and API methods assume **single-threaded access via Godot's main thread**. No mutex is used. Do not call query methods from `Thread` or `WorkerThreadPool` worker threads. If future work introduces threaded access (e.g., background carry-forward precomputation), add a `Mutex` and update this caveat.

## Formulas

### Milestone Hit Check

Determines whether the current discovery count has crossed a configured milestone threshold, triggering `discovery_milestone_reached`. Thresholds are authored as percentages and resolved to absolute counts at `_ready()` against `R_authored` — robust to content-count changes during authoring.

**Resolution at `_ready()`:**

`T_i = max(1, ceil(P_i * R_authored))` for each P_i in `_milestone_pct`

**Hit check at runtime:**

`milestone_hit = (D == T_i) for any T_i in M`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Discovery order counter | D | int | 1–∞ | Global 1-indexed count of unique recipes discovered this session |
| Authored percentage | P_i | float | (0.0, 1.0] | One entry in the configured `_milestone_pct` array |
| Resolved threshold | T_i | int | 1–R_authored | Absolute count resolved from P_i at startup; never 0 (floor clamped to 1) |
| Threshold array | M | Array[int] | length ≥ 0 | Full set of resolved thresholds; each fires at most once per session |
| Total authored recipes | R_authored | int | 1–∞ | Recipe count in Recipe Database at session start |

**Output Range:** Boolean. Each threshold fires exactly once; once fired, that T_i is excluded from future checks.

**Post-resolution dedup:** if two authored percentages resolve to the same integer threshold (e.g. `_milestone_pct = [0.01, 0.02]` with `R_authored = 10` both resolve to `T = 1`), the later entry is dropped with a warning. This guarantees each surviving `T_i` fires exactly once and each `milestone_id` is unique.

**Example:** `_milestone_pct = [0.15, 0.50, 0.80]`, `R_authored = 150` → `M = [23, 75, 120]`. At `D = 75` → milestone_hit true → emit `discovery_milestone_reached("milestone_1", 75)` (index 1 of the 0-indexed deduplicated array).

### Carry-Forward Eligibility

For each entry in `carry_forward_spec`, determines whether all required recipes have been discovered.

```
eligible(E) = ∀ r ∈ E.requires_recipes : r ∈ _discovered_recipes
result = { E.card_id | eligible(E) == true }
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Carry-forward entry | E | Dictionary | — | One element of scene JSON `carry_forward` array; has `card_id` and `requires_recipes` |
| Required recipe | r | String | — | One recipe_id from `E.requires_recipes` being tested |
| Discovered recipes | _discovered_recipes | Dictionary | keys: 0–∞ | Runtime dictionary keyed by recipe_id |

**Output Range:** Array[String] with length 0 to `|carry_forward_spec|`. Empty array means no carry-forward cards qualify.

**Example:** `carry_forward = [{ card_id: "old-photo", requires_recipes: ["home-chester-photo"] }, { card_id: "umbrella", requires_recipes: ["home-rain-walk", "home-coffee-rain"] }]`. Discovered: `{"home-chester-photo", "home-rain-walk"}`. Result: `["old-photo"]` — umbrella fails because "home-coffee-rain" is missing.

### Epilogue Condition Check

Determines whether enough epilogue-required recipes have been discovered to fire the final memory. Uses `partial_threshold` so Chester can soften the gate for the N=1 audience without re-architecting.

```
R_found = |_epilogue_required_ids ∩ keys(_discovered_recipes)|
epilogue_complete = (R_found >= ceil(R_total * partial_threshold))
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Epilogue-required recipes | _epilogue_required_ids | Set[String] | size ≥ 1 | Recipe IDs declared in `epilogue-requirements.tres`; loaded at startup |
| Total required | R_total | int | 1–∞ | `|_epilogue_required_ids|`; fixed at startup |
| Found required | R_found | int | 0–R_total | How many required recipes have been discovered |
| Partial threshold | partial_threshold | float | [0.0, 1.0] | Tuning knob; 1.0 = strict completion, 0.80 = recommended softened gate |

**Output Range:** Boolean. Once true, emits `epilogue_conditions_met()` exactly once mid-session (engine-prep signal — see Section 7 constraint). Same check runs again on `epilogue_started()` to emit `final_memory_ready()`.

**Example:** `_epilogue_required_ids` has 30 entries, `partial_threshold = 0.80` → `ceil(30 * 0.80) = 24`. After discovering the 24th required recipe: `R_found = 24 >= 24` → true → emit `epilogue_conditions_met()`.

### Discovery Percentage

Fraction of all authored recipes discovered. Reporting only — not used for gating logic.

```
if R_authored == 0:
    log_error("Recipe Database empty at discovery_pct query")
    return 0.0
P_discovery = D / R_authored
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Discovered count | D | int | 0–R_authored | Total unique recipes discovered this session |
| Total authored recipes | R_authored | int | 0–∞ | Total recipe count in Recipe Database at session start; a load failure can produce 0 |

**Output Range:** Float in [0.0, 1.0]. D cannot exceed R_authored by construction. Returned by `get_epilogue_state()` under key `"discovery_pct"`. Guarded against `R_authored == 0` (Recipe Database load failure): returns 0.0 and logs an error rather than dividing by zero.

**Example:** D = 14, R_authored = 35 → P_discovery = 0.40 (40% discovered). Degenerate case: D = 0, R_authored = 0 → P_discovery = 0.0 (guarded, error logged).

## Edge Cases

### State Machine Guards

- **If `scene_started` is received while already in Active state** (no preceding `scene_completed`): Log a warning. Treat as implicit completion of the current scene — transition through Transitioning and into Active for the new scene. The snapshot of `_active_scene_id` taken *before* the transition remains the scene_id for discoveries recorded so far; `_active_scene_id` is then overwritten with the new scene_id before any further `combination_executed` is processed. Discoveries already recorded for the previous scene remain valid and continue to appear under the *old* scene_id in `_scene_discoveries`.

- **If `scene_completed` arrives with a `scene_id` that doesn't match `_active_scene_id`**: Ignore silently. Consistent with Scene Manager's own mismatch guard.

- **If `combination_executed` fires while not in Active state** (Inactive, Transitioning, or Epilogue): Discard silently. ITF is also Suspended during transitions (dual guard), so this should not occur in practice.

- **If `epilogue_started()` fires while in Active state** (no preceding `scene_completed`): Accept gracefully — transition directly to Epilogue. Log a warning that **names the `_active_scene_id` at time of the violation** so Chester can identify which scene's manifest is misconfigured. This is a Scene Manager contract violation but MUT should not crash.

- **If `epilogue_started()` fires while in Inactive state** (degenerate path — Scene Manager loaded an empty scene manifest, or a test harness skipped scenes): Transition directly to Epilogue. `_discovered_recipes` is empty so `R_found = 0`. `final_memory_ready()` fires only if `partial_threshold == 0.0`. Log a warning naming the degenerate condition. Terminal state.

### Signal Timing

- **If `combination_executed` fires before the first `scene_started`**: MUT is in Inactive state — discards silently. The discovery is lost. ITF should not fire combinations before scene load completes (it is Suspended until scene load). If this invariant is violated, the discovery cannot be recovered.

- **If duplicate `scene_completed` signals arrive**: First one transitions Active → Transitioning. Second one is discarded (state guard: only process `scene_completed` in Active state).

### Data Validation

- **If `combination_executed` arrives with a `recipe_id` not in Recipe Database**: Log a warning with the recipe_id. Do not record as a discovery. Do not increment the counter or emit `recipe_discovered`.

- **If `combination_executed` arrives with empty `card_id_a` or `card_id_b`**: Record the discovery (recipe_id is valid), but skip the `_cards_in_discoveries` update for the empty card_id. Log a warning.

### Carry-Forward

- **If `get_carry_forward_cards()` is called while MUT is in Inactive state**: `_discovered_recipes` is empty. All carry-forward conditions fail. Returns empty array — scene loads with base seed cards only. First scene's carry-forward spec should always be empty by design.

- **If a carry-forward entry has empty `requires_recipes: []`**: Vacuously true — the card qualifies unconditionally. This is allowed as an "always include" shorthand. Authors should use it intentionally; MUT does not warn.

- **If a carry-forward `requires_recipes` references a `recipe_id` that doesn't exist in Recipe Database**: The condition can never be satisfied. On `_ready()`, MUT validates all scene JSON carry-forward specs against Recipe Database and logs warnings for unknown recipe_ids.

### Epilogue

- **If `_epilogue_required_ids` is empty at startup** (no recipes flagged `epilogue_required`): Log an error at `_ready()`. `epilogue_conditions_met()` would fire immediately on first discovery. This is an authoring error — at least one recipe should be marked required.

- **If a required epilogue recipe can only be discovered in the epilogue scene itself**: MUT is in Epilogue state and discards `combination_executed`. The recipe is never recorded. Authors must ensure all epilogue-required recipes are achievable before the final scene completes.

- **If `epilogue_conditions_met()` fires mid-session but a downstream system initializes later and misses the signal**: Signals are fire-and-forget. Systems that need epilogue state after initialization must poll via `MUT.is_final_memory_earned()` or `MUT.get_epilogue_state()`, not rely solely on the signal.

### Save/Load

- **If `load_save_state()` is called while MUT is not in Inactive state**: Reset MUT to Inactive state first — clear `_active_scene_id`, reset state machine. Then restore discovery data. Caller must ensure this is called before the next `scene_started`.

- **If a recipe in the saved data no longer exists in Recipe Database** (content updated between sessions): On load, cross-check `_discovered_recipes` against current Recipe Database. Prune entries for removed recipes and log a warning. Recalculate `_discovery_order_counter` to match surviving entries.

- **If milestone or `epilogue_conditions_met` signals were already emitted before the save**: After `load_save_state()`, these signals do not re-fire. Downstream systems must query MUT's API on initialization rather than relying on signals. Signals represent events; state is queried via API after load. The `_epilogue_conditions_emitted` flag is persisted in save state (see `get_save_state` schema) so that even a *new* post-load discovery does not re-trigger `epilogue_conditions_met()` — the guard in Rule 3 Step 9 reads the restored flag.

- **If two authored `milestone_pct` entries resolve to the same integer threshold** (e.g., `[0.01, 0.02]` with `R_authored = 10` both resolve to `T = 1`): MUT deduplicates the resolved `_milestone_thresholds` array at `_ready()`, preserving the lowest-index occurrence and dropping the later duplicate. A warning names the dropped entries. Result: each `milestone_id` in the emitted signal stream is unique for the session.

### Startup

- **If MUT's `_ready()` fires before Recipe Database is initialized**: `_epilogue_required_ids` loads as empty, triggering the "empty epilogue set" error. Required autoload order: RecipeDatabase must be declared before MysteryUnlockTree in `project.godot`.

- **If Recipe Database load fails and `R_authored == 0` at startup**: Milestone threshold resolution produces `max(1, ceil(P_i * 0)) = 1` for every entry — every milestone would fire on the very first discovery. To avoid silent nonsense, MUT skips milestone resolution entirely when `R_authored == 0`, logs an error, and sets `_milestone_thresholds = []` so `discovery_milestone_reached` never fires this session. Epilogue logic is already guarded (empty `_epilogue_required_ids` path). `Discovery Percentage` is also guarded (see Formulas).

### Godot 4.3 Signal Compatibility

- **ITF signal parameter expansion (4 → 6 params) is NOT silently backward-compatible.** Godot 4.3 dispatches signal arguments at **emit time**, not at connect time — a signature mismatch raises a runtime dispatch error the first time the signal fires against a handler whose parameter list does not match the declared signal signature. There is no connect-time validation that will catch the mismatch ahead of play. Adding `card_id_a`/`card_id_b` to `combination_executed` is therefore a **breaking change** — every existing consumer (Status Bar System and any other listener) must update its handler signature **in the same commit that lands the ITF change**, or the first combination played will error. See OQ-7 for the cross-GDD edit plan.

- **Consumer update path (only one correct option).** For any consumer that does NOT need the new `card_id_a`/`card_id_b` args, the handler must still **declare all 6 parameters in its signature and ignore the unused two**: `func _on_combo(recipe_id, template, id_a, id_b, _card_a, _card_b):`. This is what Status Bar System will use.

- **Why `.bind()` does NOT help.** `Callable.bind()` **prepends** fixed arguments to a callable — it cannot absorb trailing args the signal passes. A 3-arg handler bound with 2 extra args is a 5-arg callable; a 6-arg signal dispatching to it still fails with a parameter-count error. Do not attempt to use `.bind()` as a compatibility shim for this migration.

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|---|---|---|
| **Interaction Template Framework** | `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)` signal via EventBus — primary discovery input | Hard — MUT cannot record discoveries without this signal |
| **Scene Manager** | `scene_started(scene_id)`, `scene_completed(scene_id)`, `epilogue_started()` signals via EventBus — state machine transitions | Hard — MUT cannot track scene context or trigger epilogue evaluation without these |
| **Recipe Database** | Queried at `_ready()` for `R_authored` (total recipe count, used to resolve `milestone_pct` into absolute thresholds). Also used for `get_recipe(recipe_id)` reverse lookup to validate every id in `epilogue-requirements.tres`. No per-recipe flag scan. | Hard at startup — MUT must resolve milestone thresholds and validate the epilogue set before gameplay begins |
| **Epilogue Requirements File** | `res://assets/data/epilogue-requirements.tres` — explicit Array[String] of recipe_ids; loaded at `_ready()` into `_epilogue_required_ids` | Hard — without this file, the final illustrated memory cannot fire |
| **EventBus** (ADR-003) | Signal bus for all inter-system communication | Hard — no signals flow without it |

### Downstream (systems that depend on this)

| System | What They Need | Hardness |
|---|---|---|
| **Scene Goal System** | `MUT.get_carry_forward_cards(carry_forward_spec)` — called during `load_scene()` to resolve conditional carry-forward cards added to seed cards | Soft — scene loads with base seed cards if MUT is unavailable |
| **Final Epilogue Screen** | `final_memory_ready()` signal + `MUT.get_epilogue_state()` query — determines whether full or partial illustrated memory reveal plays | Hard for game completion — without it, epilogue has no discovery data |
| **Save/Progress System** | `MUT.get_save_state()` and `MUT.load_save_state(data)` — full discovery state for persistence | Soft at Vertical Slice — not needed until Alpha |

### Signals Emitted

| Signal | Parameters | Fired When |
|---|---|---|
| `recipe_discovered` | `recipe_id: String, card_id_a: String, card_id_b: String, scene_id: String` | First-time recipe execution only (not on cooldown re-fires) |
| `discovery_milestone_reached` | `milestone_id: String, discovery_count: int` | Discovery count crosses a configured threshold |
| `epilogue_conditions_met` | *(none)* | All epilogue-required recipes discovered (fires once, mid-session) |
| `final_memory_ready` | *(none)* | On `epilogue_started()` if all epilogue conditions are already met |

### Signals Listened To

| Signal | Source | Handled When |
|---|---|---|
| `combination_executed` | ITF via EventBus | Active state only — records first-time discoveries |
| `scene_started` | Scene Manager via EventBus | Inactive or Transitioning — transitions to Active |
| `scene_completed` | Scene Manager via EventBus | Active state only — transitions to Transitioning |
| `epilogue_started` | Scene Manager via EventBus | Transitioning — transitions to Epilogue |

### External Data

All files in this section are Godot `.tres` Resource files loaded via `ResourceLoader`, per [ADR-005](../../docs/architecture/adr-0005-data-file-format-convention.md). `FileAccess` + `JSON.parse_string` is forbidden for MUT data loads.

| Asset | Path | Description |
|---|---|---|
| MUT config | `res://assets/data/mut-config.tres` | `milestone_pct` array and `partial_threshold` float; loaded at `_ready()` |
| Epilogue requirements | `res://assets/data/epilogue-requirements.tres` | Explicit array of recipe_ids required for the final illustrated memory; single source of truth for the gift's required memory set |
| Debug config (dev only) | `res://assets/data/debug-config.tres` | `force_unlock_all` boolean; **excluded from release exports** via `project.godot` export filter |
| Scene data (carry-forward) | `res://assets/data/scenes/[scene_id].tres` | `carry_forward` array read by SGS, conditions evaluated by MUT |
| Recipe Database | `res://assets/data/recipes.tres` | Queried for `R_authored` at startup and for `get_recipe(recipe_id)` validation. **No per-recipe `epilogue_required` flag is read** — `epilogue-requirements.tres` is the authoritative list. |

### Required Autoload Order

EventBus → RecipeDatabase → MysteryUnlockTree (must be after RecipeDatabase for `R_authored` and recipe validation)

**Scene Manager startup coupling:** Scene Manager defers its first `scene_started` emission by one frame (`call_deferred` pattern) to allow autoloads — including MUT — to finish `_ready()` before any signal fires. MUT relies on this: if Scene Manager were to emit `scene_started` synchronously during its own `_ready()`, the signal could arrive before MUT's signal connections are established. If the Scene Manager's deferred-emit behavior changes, MUT must switch to connecting signals in `_enter_tree()` (earlier than `_ready()`). **Why `_enter_tree()` is safe for this fallback:** EventBus signals are declared on the EventBus class body (not inside `_ready()`), so the signal objects exist from autoload instantiation. Connecting to them from MUT's `_enter_tree()` — which fires before any autoload's `_ready()` — is valid because the connect call only needs the signal object to exist, not EventBus's `_ready()` to have run.

**RecipeDatabase synchronous-load requirement (HARD).** MUT queries `R_authored` and validates `epilogue-requirements.tres` against RecipeDB during its own `_ready()`. This is safe **only if RecipeDB's own `_ready()` performs a synchronous load of `recipes.tres` that completes before returning**. RecipeDB MUST NOT use threaded loading, deferred parsing, or `ResourceLoader.load_threaded_request` for its primary recipe data. If RecipeDB ever moves to an async load path, MUT will silently read `R_authored = 0` at startup and the entire session will run in the degraded R_authored=0 mode (all discoveries discarded as unknown). Document this as a one-line contract in Recipe Database GDD's Dependencies section.

**Typed-array write discipline.** `_scene_discoveries` is `Dictionary` with values typed as `Array[String]`. Godot 4.3 does not support typed dictionaries (arrives in 4.4), so dictionary value retrieval returns `Variant`. **Every write to `_scene_discoveries[scene_id]` must assign a typed `Array[String]`** (not a plain `Array`) — otherwise subsequent retrieval into a typed local variable raises a type-coercion error. In practice: initialize with `_scene_discoveries[scene_id] = [] as Array[String]` (or declare the initial empty value as typed at the call site).

**Cross-reference note:** ITF GDD lists MUT as a downstream listener of `combination_executed` — consistent, but ITF must update its emit signature from 4 params to 6 (OQ-7). Scene Manager GDD lists MUT as a soft downstream dependency listening to `scene_started`, `scene_completed`, and `epilogue_started` — consistent. Scene Goal System GDD does not yet document the soft dependency on `MUT.get_carry_forward_cards()` — update pending (OQ-8).

## Tuning Knobs

### Knob Inventory

| Knob | Owner | Default | Safe Range | What It Affects |
|---|---|---|---|---|
| `milestone_pct` | `mut-config.tres` (Array[float]) | `[0.15, 0.50, 0.80]` | Each entry in (0.0, 1.0]; array strictly ascending and unique | Silent narrative beats only — permitted uses: quiet ambient bed switches, silent carry-forward unlocks. Pillar 3 forbids audio stings, UI flair, on-screen messages. Resolved to absolute counts at `_ready()` against `R_authored`. |
| `partial_threshold` | `mut-config.tres` (float) | `1.0` | [0.0, 1.0]; 1.0 = strict full completion (default); lower only on OQ-2 unreachability findings | Fraction of epilogue-required recipes Ju must discover for `final_memory_ready()` to fire. **Default stays at `1.0` for this N=1 gift** — every authored memory matters, and a softened gate dilutes the letter. Lower to `0.80` *only* if the OQ-2 reachability walker identifies a structurally unreachable recipe and recovery is the goal. `0.0` is a dev-only test value that fires `final_memory_ready()` immediately on `epilogue_started()`; mid-session `epilogue_conditions_met()` is suppressed when the threshold is `0.0`. |
| `epilogue-requirements.tres` | `res://assets/data/epilogue-requirements.tres` (Array[String]) | *(authored per-gift; expect 20–40 entries)* | Length ≥ 1; each entry must exist in Recipe Database | Explicit list of recipe_ids required for the final illustrated memory. Single source of truth — per-recipe `epilogue_required` flags are NOT used. |
| `carry_forward` (per scene) | `scenes/[scene_id].tres` per-scene array | `[]` for first scene; varied per later scene | 0 ≤ entries ≤ ~10 per scene; `requires_recipes` length 0–3 typical | Which prior-scene cards appear as additional seed cards; shapes scene-to-scene continuity |
| `force_unlock_all` (DEV ONLY) | `res://assets/data/debug-config.tres` (boolean) | `false` | `true` only in dev builds; **must** be excluded from release exports | When `true`, MUT marks every recipe as discovered at `_ready()`; allows jumping to late scenes for testing. Lives in a file that the export preset filters out entirely. |

### Safe Ranges & Failure Modes

**`milestone_pct`**
- **Too dense** (e.g., `[0.05, 0.10, 0.15, 0.20]`): frequent silent state changes can accumulate into noise even if each is individually quiet. Keep to 3–4 beats max across the full arc.
- **Above 1.0 or ≤ 0.0**: MUT clamps to (0.0, 1.0] and logs a warning. Entries outside the range are dropped.
- **Empty array `[]`**: MUT never emits `discovery_milestone_reached`. Valid configuration — choose this if no downstream narrative beat is wired yet.
- **Non-ascending or duplicate authored values**: MUT logs a warning at `_ready()` and falls back to `_milestone_pct = []` (no milestones this session).
- **Resolution edge case**: `P_i * R_authored` can round to 0 for very small percentages when `R_authored` is tiny (e.g., `0.05 * 10 = 0.5 → ceil = 1`, but `max(1, ...)` prevents 0). Minimum resolved threshold is always 1.
- **Post-resolution collision** (distinct authored floats collapsing to the same integer, e.g. `[0.01, 0.02]` with `R_authored = 10` both → `T = 1`): the later duplicate is dropped and a warning names the dropped entries. Each surviving threshold produces a unique `milestone_id`.

**`partial_threshold`**
- **`1.0`** (**DEFAULT** — keep this unless OQ-2 finds a structurally unreachable recipe): strict completion. Ju must discover every entry in `epilogue-requirements.tres` for the final memory. For an N=1 gift, this is the correct default: Chester has already chosen which memories matter, and letting any be skipped dilutes the letter.
- **`0.80`**: fallback value for a specific recovery scenario — *use only after* OQ-2 reachability analysis shows a required recipe cannot be reached on any valid play path and you choose not to rewrite the recipe/scene graph. Not a general softening dial.
- **Below `1/R_total`** (e.g. `partial_threshold = 0.20` with `R_total = 5` resolves to `ceil = 1`): final memory triggers on the very first required discovery. Almost certainly a footgun — flagged at `_ready()` with a warning.
- **`< 0.50`** (and above `1/R_total`): final memory feels unearned; risks triggering on a shallow playthrough and undercutting the emotional weight of the discovery arc.
- **`0.0`**: `final_memory_ready()` fires immediately on any `epilogue_started()` regardless of discovery state. **Mid-session `epilogue_conditions_met()` is suppressed entirely when the threshold is `0.0`** (guard in Rule 3 Step 9 and Rule 7). Only for dev testing of the final epilogue screen in isolation.
- **Above `1.0` or negative**: MUT clamps to [0.0, 1.0] and logs a warning.

**`epilogue-requirements.tres`**
- **Missing file**: MUT logs an error at `_ready()`, treats `_epilogue_required_ids` as empty (see degenerate case).
- **Empty array `[]`**: `R_total = 0`; `R_found >= ceil(0 * partial_threshold)` always evaluates to `true` (0 >= 0). `epilogue_conditions_met()` would fire on *any* state tick. MUT logs an error and skips emission of both `epilogue_conditions_met` and `final_memory_ready` when `R_total == 0` — explicit guard against vacuous truth.
- **Contains unknown recipe_ids**: MUT logs an error naming each unknown id at `_ready()`. Unknown ids remain in `_epilogue_required_ids` (cannot be silently dropped — a typo could lock Ju out of the final memory forever). Author must fix the file.
- **All recipes in Recipe Database listed**: equivalent to 100% completion requirement. Risk: carry-forward chains must be perfectly survivable. Pair with `partial_threshold = 0.80` to soften.
- **Required recipe only reachable in epilogue scene itself**: unreachable by design — Epilogue state discards `combination_executed`. Acceptance criteria must verify reachability before scene completion (see OQ-2).
- **Recommended authored size**: 20–40 recipes (the core memories Chester wants Ju to find). Everything else is bonus content that enriches but does not gate.

**`carry_forward` (per-scene array)**
- **Empty `requires_recipes: []`**: card is included unconditionally. Allowed as an "always carry" shorthand.
- **`requires_recipes` includes a recipe_id not in Recipe Database**: condition can never be satisfied. MUT validates at `_ready()` and logs a warning.
- **Carry-forward chains too long** (>3 required recipes per card): card almost never appears, scene effectively loses that content. Authors should keep chains shallow unless intentionally hiding content.
- **Carry-forward references a recipe from a *later* scene**: condition can never be satisfied during the carrying scene's load. No engine-side check — authors must order scenes correctly.

**`force_unlock_all`**
- **Lives in a dev-only file**: `res://assets/data/debug-config.tres` is excluded from release exports via the exclude filter in `export_presets.cfg`. Release builds cannot load the file — MUT defaults to `false` if the file is missing. This makes "accidentally shipped with true" structurally impossible rather than relying on a checklist.
- **Per-preset verification required**: the exclude filter is declared **per preset** in `export_presets.cfg`. If multiple platform presets exist (e.g., desktop + web), each must independently declare the exclusion. There is no global exclude. Release-manager checklist must verify this for every preset.
- **`true` in dev**: takes the Rule 9 bulk-load bypass. Milestones and `epilogue_conditions_met` do not fire because `_suppress_signals` is held `true` throughout the bulk-mark.
- **Release verification**: AC confirms `debug-config.tres` is absent from packaged release archives.

### Knob Interactions

- **`milestone_pct` × Recipe Database size**: thresholds are percentages, not absolute counts — robust to content-count changes during authoring. No re-tuning needed when new recipes are added mid-development.
- **`epilogue-requirements.tres` size × `carry_forward` graph**: a required recipe in scene 3 that depends on a carry-forward card from scene 1 forms a hidden dependency chain. If the scene 1 carry-forward condition fails, Ju cannot complete the epilogue. Acceptance criteria must verify every required recipe is reachable from every valid play path (OQ-2 reachability tool).
- **`milestone_pct` × `partial_threshold`**: if a milestone percentage happens to coincide with the resolved partial-completion point (e.g., `milestone_pct = [0.80]` and `partial_threshold = 0.80`), the milestone signal and `epilogue_conditions_met` may fire close together. Both are silent signals — no player-visible overlap — but downstream listeners (quiet bed-switch + Final Epilogue pre-load) should handle simultaneous firing idempotently.
- **`force_unlock_all` × everything**: when true, Rule 9's dedicated bulk-load bypass runs instead of the per-discovery pipeline. `_suppress_signals` is held `true` during the bulk assignment, so no `recipe_discovered`, `discovery_milestone_reached`, or `epilogue_conditions_met` signals are emitted. `_epilogue_conditions_emitted` and `_final_memory_earned` are set to `true` directly. Ju (or a debug build of Ju) jumps straight to a "ready" state queryable via `is_final_memory_earned() == true`. Document this behavior in the debug-config file's comment header.

- **`requires_recipes: []` authoring guidance** (for carry-forward vacuous-truth shorthand): reserve this for cards that are **scene-setting prerequisites** (context cards that need to be present regardless of discovery history — e.g., a "door" or "table" card that anchors the scene). Do not use it for content that should feel discovered, or the associative-memory fantasy is undermined at that card's appearance. MUT does not validate this — it is an authoring discipline.

### Knobs MUT Does NOT Own

| Knob | Lives In | Why Not Here |
|---|---|---|
| Recipe definitions, costs, effects | `recipes.tres` (Recipe Database) | MUT is read-only on recipes |
| Card definitions | `cards.tres` (Card Database) | MUT only references card IDs |
| Scene seed cards (base set) | `scenes/[scene_id].tres` (Scene Manager) | MUT only resolves *carry-forward* additions, not base seeds |
| Bar values, goal thresholds | `scenes/[scene_id].tres` (Scene Goal System) | MUT does not gate scenes by score, only by discovery state |
| Hint timing | `hint-config.tres` (Hint System) | Independent system; MUT does not feed hints |

## Visual/Audio Requirements

**N/A — invisible system.** MUT is a pure data-tracking autoload with no scene tree presence, no rendering surface, and no sound output of its own. All visual and audio responses to MUT events (cascade VFX on `recipe_discovered`, audio sting on `discovery_milestone_reached`, illustrated reveal on `final_memory_ready`) are owned by downstream systems (Card Visual, Status Bar UI, Audio Manager, Final Epilogue Screen) and are specified in those GDDs. MUT only emits the signals; it never decides what they look or sound like.

## UI Requirements

**N/A — invisible system.** MUT exposes no UI of its own. Player-visible representations of discovery state (e.g., "memories collected" counter on the main menu, illustrated grid on the epilogue screen) live in `main-menu.md` and `final-epilogue-screen.md` respectively and consume MUT's read-only query API. There is no MUT-owned screen, HUD element, or interactive widget.

## Acceptance Criteria

### Story Type Classification

Per `.claude/docs/coding-standards.md`, each criterion below carries a story type tag:
- **[Logic]** = BLOCKING automated unit test required
- **[Integration]** = BLOCKING integration test OR documented playtest
- **[Config]** = ADVISORY smoke check / config file inspection

### Discovery Recording (Rules 2, 3)

**AC-001 [Logic] — First-time discovery records all five fields.**
GIVEN MUT is in Active state with `_active_scene_id == "home"`, WHEN `combination_executed("home-rain-walk", "additive", "inst-a", "inst-b", "rain", "walk")` fires, THEN `_discovered_recipes["home-rain-walk"]` contains `{ card_id_a: "rain", card_id_b: "walk", scene_id: "home", discovery_order: 1, template: "additive" }`.

**AC-002 [Logic] — Secondary indices populated on the same call.**
GIVEN AC-001's preconditions, WHEN the same signal fires, THEN `_scene_discoveries["home"]` contains `["home-rain-walk"]` AND `_cards_in_discoveries["rain"] == "home"` AND `_cards_in_discoveries["walk"] == "home"`.

**AC-003 [Logic] — Duplicate recipe not re-recorded.**
GIVEN `_discovered_recipes` already contains "home-rain-walk", WHEN `combination_executed("home-rain-walk", ...)` fires again, THEN `_discovery_order_counter` is unchanged AND `recipe_discovered` is NOT emitted.

**AC-004 [Logic] — Discovery counter is 1-indexed and monotonic.**
GIVEN zero prior discoveries, WHEN N distinct recipes are discovered in sequence, THEN `get_discovery_count() == N` AND the Nth record's `discovery_order` field equals N.

**AC-005 [Logic] — Counter ↔ dictionary size invariant.**
GIVEN any sequence of discovery operations including duplicates, WHEN any operation completes, THEN `_discovery_order_counter == _discovered_recipes.size()`.

**AC-006 [Logic] — Cross-index aggregate consistency.**
GIVEN any multi-scene play sequence, WHEN any operation completes, THEN the sum of all `_scene_discoveries[scene_id].size()` values equals `_discovered_recipes.size()`.

### Signal Emission (Rules 7, 8; Formulas 1, 3)

**AC-007 [Logic] — `recipe_discovered` emitted on first discovery only.**
GIVEN MUT is Active, WHEN a first-time `combination_executed` is processed, THEN `recipe_discovered(recipe_id, card_id_a, card_id_b, scene_id)` is emitted exactly once with the values from the input signal.

**AC-008 [Logic] — Milestone fires on exact resolved threshold crossing with derived `milestone_id`.**
GIVEN `_milestone_pct = [0.50]` AND R_authored = 10 (so resolved `_milestone_thresholds = [5]`), WHEN the 5th distinct recipe is discovered, THEN `discovery_milestone_reached("milestone_0", 5)` is emitted exactly once. The `milestone_id` value `"milestone_0"` is derived per Rule 8 as `"milestone_" + str(0)` (index 0 of the deduplicated `_milestone_thresholds` array).

**AC-009 [Logic] — Milestone does not re-fire after resolved threshold passed.**
GIVEN the milestone at resolved threshold 5 has already fired, WHEN the 6th and 7th discoveries are recorded, THEN `discovery_milestone_reached` is NOT emitted for either.

**AC-010 [Logic] — Resolved threshold is floor-clamped to 1.**
GIVEN `_milestone_pct = [0.01]` AND R_authored = 10, WHEN MUT's `_ready()` runs, THEN `_milestone_thresholds == [1]` (not 0, per `max(1, ceil(...))`) AND the milestone fires on the very first discovery. *(This is intended — small percentages with tiny content counts collapse to "first discovery" rather than "never fire".)*

**AC-011 [Logic] — `epilogue_conditions_met` fires on the discovery that completes the required set.**
GIVEN `_epilogue_required_ids` size == 3 AND 2 of them are already discovered, WHEN the 3rd required recipe's `combination_executed` fires, THEN `epilogue_conditions_met()` is emitted exactly once.

**AC-012 [Logic] — `epilogue_conditions_met` does not re-fire on subsequent discoveries.**
GIVEN `epilogue_conditions_met()` has already been emitted, WHEN any further `combination_executed` is processed, THEN `epilogue_conditions_met()` is NOT emitted again.

**AC-013 [Logic] — `final_memory_ready` emitted on `epilogue_started` only when condition met.**
GIVEN all 3 required recipes are discovered, WHEN `epilogue_started()` fires, THEN `final_memory_ready()` is emitted exactly once. GIVEN at least one required recipe is missing, WHEN `epilogue_started()` fires, THEN `final_memory_ready()` is NOT emitted.

**AC-014 [Logic] — Simultaneous milestone + epilogue emission, ordered milestone-before-epilogue.**
GIVEN the next discovery would both cross threshold T AND complete the epilogue condition, WHEN `combination_executed` fires once (synchronously, no `await` between), THEN both `discovery_milestone_reached` AND `epilogue_conditions_met` appear in the test harness's signal spy log, AND `discovery_milestone_reached` appears before `epilogue_conditions_met` in emission order (per Rule 3 Step 8 before Step 9).

### State Machine (Transitions 1–4; SMG-1, SMG-2, ST-2)

**AC-015 [Logic] — Inactive → Active sets `_active_scene_id`.**
GIVEN MUT is in Inactive state, WHEN `scene_started("home")` fires, THEN MUT is in Active state AND `_active_scene_id == "home"`.

**AC-016 [Logic] — Active discards `combination_executed` after `scene_completed`.**
GIVEN MUT is Active with `_active_scene_id == "home"`, WHEN `scene_completed("home")` fires followed by `combination_executed(...)`, THEN `get_discovery_count()` is unchanged AND `recipe_discovered` is NOT emitted.

**AC-017 [Logic] — Mismatched `scene_completed` ignored.**
GIVEN MUT is Active with `_active_scene_id == "home"`, WHEN `scene_completed("park")` fires, THEN MUT remains in Active state AND `_active_scene_id == "home"`.

**AC-018 [Logic] — Transitioning → Active updates scene context.**
GIVEN MUT is in Transitioning state after `scene_completed("home")`, WHEN `scene_started("park")` fires, THEN MUT is in Active state AND `_active_scene_id == "park"`.

**AC-019 [Logic] — Epilogue is terminal.**
GIVEN MUT is in Epilogue state, WHEN `scene_started("any")` OR `epilogue_started()` fires, THEN MUT remains in Epilogue state.

**AC-020 [Logic] — Double `scene_started` preserves prior discoveries.**
GIVEN MUT is Active with 3 discoveries in scene "home", WHEN `scene_started("park")` fires without intervening `scene_completed`, THEN `get_scene_discoveries("home")` still returns the original 3 recipe_ids AND `_active_scene_id == "park"` AND a warning is logged.

**AC-021 [Logic] — `epilogue_started` from Active does not crash and warning names the violating scene.**
GIVEN MUT is in Active state with `_active_scene_id == "park"` and no preceding `scene_completed`, WHEN `epilogue_started()` fires, THEN MUT transitions to Epilogue state AND a warning is logged containing the string `"park"` (the `_active_scene_id` at violation time, so Chester can diagnose the misconfigured scene manifest) AND no exception is thrown.

**AC-022 [Logic] — Duplicate `scene_completed` discarded.**
GIVEN MUT has already transitioned Active → Transitioning, WHEN a second identical `scene_completed` fires, THEN MUT remains in Transitioning (no further transition triggered).

### Carry-Forward (Rule 6; Formula 2; CF-1, CF-2)

**AC-023 [Logic] — All required recipes must be discovered (universal quantifier).**
GIVEN `carry_forward = [{ card_id: "umbrella", requires_recipes: ["R1", "R2"] }]` AND only R1 is in `_discovered_recipes`, WHEN `get_carry_forward_cards(carry_forward)` is called, THEN the result is `[]`.

**AC-024 [Logic] — Empty `requires_recipes` is vacuously true.**
GIVEN `carry_forward = [{ card_id: "always", requires_recipes: [] }]`, WHEN `get_carry_forward_cards(carry_forward)` is called from any state with any discovery set, THEN the result is `["always"]`.

**AC-025 [Logic] — Cross-scene satisfaction.**
GIVEN R1 was discovered in scene "home" AND R2 was discovered in scene "park", WHEN `get_carry_forward_cards([{card_id: "X", requires_recipes: ["R1", "R2"]}])` is called for scene "cafe", THEN the result is `["X"]`.

**AC-026 [Logic] — Inactive state returns empty carry-forward.**
GIVEN MUT is in Inactive state with empty `_discovered_recipes`, WHEN `get_carry_forward_cards([{card_id: "X", requires_recipes: ["R1"]}])` is called, THEN the result is `[]`.

**AC-027 [Config] — Unknown recipe in `requires_recipes` validated at startup.**
GIVEN a scene JSON contains `requires_recipes: ["recipe-does-not-exist"]`, WHEN MUT's `_ready()` runs, THEN a warning naming the unknown recipe_id is logged.

### Query API (Rule 5; Section C Query API)

**AC-028 [Logic] — `get_discovery_record` for unknown recipe returns empty Dictionary.**
GIVEN recipe_id "unknown" has never been discovered, WHEN `get_discovery_record("unknown")` is called, THEN the return value is `{}` (empty Dictionary, not `null`).

**AC-029 [Logic] — `get_epilogue_state` returns all five documented keys.**
GIVEN R_total == 3 AND 1 required recipe discovered AND R_authored == 10, WHEN `get_epilogue_state()` is called, THEN result contains keys `required_count == 3`, `discovered_count == 1`, `is_complete == false`, `missing_ids` (array of length 2), `discovery_pct == 0.1`.

**AC-030 [Logic] — `is_final_memory_earned` reflects mid-session epilogue completion.**
GIVEN `epilogue_conditions_met()` has been emitted but `epilogue_started()` has not yet fired, WHEN `is_final_memory_earned()` is called, THEN it returns `true`.

**AC-031 [Logic] — Query API has no side effects.**
GIVEN any MUT state, WHEN any query method (`is_recipe_discovered`, `get_discovery_count`, `get_scene_discoveries`, `get_discovery_record`, `is_card_in_discovery`, `get_carry_forward_cards`, `get_epilogue_state`, `is_final_memory_earned`) is called, THEN no signals are emitted AND no internal dictionaries are mutated.

### Save / Load (SL-1, SL-2, SL-3)

**AC-032 [Logic] — Round-trip fidelity across every persisted field.**
GIVEN MUT has 7 discoveries across 2 scenes with mixed templates (at least one per template type represented), WHEN `get_save_state()` output is serialized and loaded into a fresh MUT instance via `load_save_state()`, THEN:
- `get_discovery_count() == 7`
- `get_scene_discoveries(scene_id)` returns identical arrays for each scene
- For every recipe_id, `get_discovery_record(recipe_id)` returns identical `{card_id_a, card_id_b, scene_id, discovery_order, template}` to the pre-save snapshot
- For every card_id from the 7 discoveries, `is_card_in_discovery(card_id) == true` AND the recorded scene_id in `_cards_in_discoveries` matches the pre-save value
- `_epilogue_conditions_emitted` restored to its pre-save value (see AC-053)

**AC-033 [Logic] — `load_save_state` from non-Inactive resets state first.**
GIVEN MUT is Active with `_active_scene_id == "home"`, WHEN `load_save_state(valid_data)` is called, THEN MUT is in Inactive state post-load AND `_active_scene_id == ""` AND discovery data matches `valid_data`.

**AC-034 [Logic] — Stale recipe pruned on load.**
GIVEN save data contains recipe_id "old-recipe" which is not in current Recipe Database, WHEN `load_save_state()` is called, THEN `is_recipe_discovered("old-recipe") == false` AND `_discovery_order_counter` equals the count of surviving entries AND a warning is logged.

**AC-035 [Logic] — Signals do not re-fire after load.**
GIVEN save data represents a state where `epilogue_conditions_met()` had previously been emitted, WHEN `load_save_state()` is called, THEN `epilogue_conditions_met()` is NOT emitted AND `discovery_milestone_reached` is NOT emitted for any already-crossed thresholds AND `get_epilogue_state()["is_complete"] == true`.

### Cross-System Integration (Section C Interactions Table)

**AC-036 [Integration] — All EventBus signals connected to MUT at startup (callable-agnostic).**
*Note: [Integration] because the assertion requires MUT to be running as the actual autoload singleton; a manually-instantiated test node is a different object and will fail the `c.object == MysteryUnlockTree` check.*
GIVEN EventBus exposes `combination_executed`, `scene_started`, `scene_completed`, and `epilogue_started`, WHEN MUT's `_ready()` completes, THEN all four assertions pass (handler-method-name agnostic):
- `EventBus.combination_executed.get_connections().any(func(c): return c.callable.get_object() == MysteryUnlockTree) == true`
- `EventBus.scene_started.get_connections().any(func(c): return c.callable.get_object() == MysteryUnlockTree) == true`
- `EventBus.scene_completed.get_connections().any(func(c): return c.callable.get_object() == MysteryUnlockTree) == true`
- `EventBus.epilogue_started.get_connections().any(func(c): return c.callable.get_object() == MysteryUnlockTree) == true`

**AC-037a [Integration] — ITF emits enriched signal payload.** *(BLOCKED on OQ-7 until ITF GDD is updated.)*
GIVEN ITF executes any recipe, WHEN `combination_executed` is emitted, THEN the signal argument count is exactly 6 AND the positional order is `(recipe_id: String, template: String, instance_id_a: String, instance_id_b: String, card_id_a: String, card_id_b: String)` AND `card_id_a` / `card_id_b` match the card_ids that ITF resolved from the instance_ids.

**AC-037b [Integration] — Existing consumers updated in lockstep with signal expansion.** *(BLOCKED on OQ-7.)*
GIVEN the ITF emits the 6-parameter signal, WHEN Status Bar System and any other pre-existing consumer of `combination_executed` receives the signal, THEN its handler signature accepts 6 parameters (or uses a `.bind()` wrapper) AND no parameter-count error is raised by Godot 4.3's typed signal dispatch. Handlers that don't need the new `card_id_a`/`card_id_b` simply declare and ignore them.

**AC-038 [Integration] — SGS degrades gracefully when carry-forward returns empty.**
GIVEN MUT returns `[]` from `get_carry_forward_cards()`, WHEN Scene Goal System calls it during `load_scene("park")`, THEN the scene initializes with base seed_cards only AND `seed_cards_ready` is emitted AND no error is logged.

### Edge Cases & Validation (DV-1, DV-2, ST-1, EP-1, SU-1)

**AC-039 [Logic] — Unknown recipe_id discarded with warning.**
GIVEN recipe_id "phantom" is not in Recipe Database, WHEN `combination_executed("phantom", ...)` fires in Active state, THEN `is_recipe_discovered("phantom") == false` AND `_discovery_order_counter` is unchanged AND a warning naming "phantom" is logged.

**AC-040 [Logic] — Empty card_id skipped from `_cards_in_discoveries`.**
GIVEN `combination_executed("R1", "additive", "inst-a", "inst-b", "rain", "")` fires, WHEN MUT processes it, THEN `is_recipe_discovered("R1") == true` AND `is_card_in_discovery("rain") == true` AND `is_card_in_discovery("") == false`.

**AC-041 [Logic] — `combination_executed` before any `scene_started` is discarded.**
GIVEN MUT is in Inactive state, WHEN `combination_executed(...)` fires, THEN `get_discovery_count() == 0` AND no signals are emitted.

**AC-042 [Logic] — Empty `_epilogue_required_ids` suppresses epilogue signals.**
GIVEN `epilogue-requirements.tres` is missing OR contains an empty array, WHEN MUT's `_ready()` completes AND subsequent `combination_executed` events fire AND `epilogue_started()` eventually fires, THEN an error is logged at `_ready()` naming the empty epilogue requirement set AND `epilogue_conditions_met()` is NEVER emitted during the session AND `final_memory_ready()` is NEVER emitted on `epilogue_started()` AND `get_epilogue_state()["required_count"] == 0` AND `get_epilogue_state()["is_complete"] == false`.

**AC-043 [Config] — Autoload order verified in `project.godot`.**
GIVEN `project.godot` is inspected, WHEN the autoload section is parsed, THEN `EventBus` appears before `RecipeDatabase` AND `RecipeDatabase` appears before `MysteryUnlockTree` in declaration order.

**AC-044 [Logic] — Malformed `milestone_pct` falls back to empty array.**
GIVEN MUT is initialized via `_inject_config({ "milestone_pct": [0.50, 0.15], "partial_threshold": 1.0 })` (non-ascending) AND R_authored = 20, WHEN MUT's `_ready()` runs THEN `_milestone_thresholds == []` AND a warning is logged. WHEN subsequently 20 distinct recipes are discovered in sequence, THEN `discovery_milestone_reached` is NOT emitted for any discovery (observed via signal spy) AND `get_discovery_count() == 20`.

**AC-045 [Logic] — Out-of-range `milestone_pct` entries dropped.**
GIVEN MUT is initialized via `_inject_config({ "milestone_pct": [0.25, 1.50, 0.75], "partial_threshold": 1.0 })`, WHEN MUT's `_ready()` runs, THEN a warning is logged naming the out-of-range entry (`1.50`) AND `_milestone_pct` becomes `[0.25, 0.75]` AND `_milestone_thresholds` is resolved from only the retained entries.

**AC-046 [Logic] — `force_unlock_all` disabled when debug-config is absent.**
GIVEN MUT is initialized via `_inject_debug_config(null)` (simulates release build where export filter excluded the file), WHEN MUT's `_ready()` runs, THEN `_force_unlock_all == false` AND MUT does not bulk-mark any recipes as discovered AND `get_discovery_count() == 0` AND no warning is logged (absent file is normal in release). *(Note: `debug-config.tres` exclusion from release exports is enforced via `export_presets.cfg` per-preset and verified by the release-manager's export checklist, not by this AC.)*

**AC-047 [Logic] — `force_unlock_all == true` bulk-marks via Rule 9 bypass without firing milestone or epilogue_conditions_met signals.**
GIVEN MUT is initialized via `_inject_debug_config({ "force_unlock_all": true })` AND Recipe Database has R_authored = 35 recipes AND `_epilogue_required_ids` has 10 entries AND `_milestone_pct = [0.50]`, WHEN MUT's `_ready()` runs, THEN Rule 9's bulk-load bypass executes AND `get_discovery_count() == 35` AND `_discovery_order_counter == 35` AND `recipe_discovered` was NOT emitted during `_ready()` (observed via signal spy — signal spy log contains zero `recipe_discovered` entries from the bulk path) AND `discovery_milestone_reached` was NOT emitted AND `epilogue_conditions_met()` was NOT emitted AND `_epilogue_conditions_emitted == true` AND `is_final_memory_earned() == true` AND `get_epilogue_state()["is_complete"] == true` AND a warning is logged naming the dev-only override.

**AC-048 [Logic] — Discovery Percentage guarded against R_authored == 0.**
GIVEN Recipe Database load fails and R_authored == 0, WHEN `get_epilogue_state()` is called, THEN the return value's `discovery_pct == 0.0` AND no division-by-zero exception is thrown AND an error is logged naming the empty Recipe Database condition.

**AC-049a [Logic] — Inactive → Epilogue with strict threshold does not fire.**
GIVEN MUT is in Inactive state with empty `_discovered_recipes` AND `partial_threshold == 1.0` AND `_epilogue_required_ids` has 3 entries, WHEN `epilogue_started()` fires, THEN MUT is in Epilogue state AND `final_memory_ready()` is NOT emitted AND a warning is logged naming the degenerate (no-scene) path AND `get_epilogue_state()["is_complete"] == false`.

**AC-049b [Logic] — Inactive → Epilogue with `partial_threshold == 0.0` fires.**
GIVEN MUT is in Inactive state with empty `_discovered_recipes` AND `partial_threshold == 0.0` AND `_epilogue_required_ids` has 3 entries, WHEN `epilogue_started()` fires, THEN `final_memory_ready()` IS emitted exactly once.

**AC-050 — Deferred to Alpha.** *(Body moved to OQ-2.)* A reachability walker verifying every `epilogue-requirements.tres` entry is reachable from scene 1's seed cards will become an AC when OQ-2 lands. Until then, this is tracked only as an Open Question — do not treat its absence as a Vertical Slice gap.

**AC-051 [Logic] — Partial threshold gate example.**
GIVEN `_epilogue_required_ids` has 10 entries AND `partial_threshold == 0.80` AND exactly 8 required recipes are discovered, WHEN `epilogue_started()` fires, THEN `final_memory_ready()` is emitted exactly once (8 >= ceil(10 * 0.80) = 8). GIVEN only 7 required recipes are discovered, WHEN `epilogue_started()` fires, THEN `final_memory_ready()` is NOT emitted.

**AC-052 [Logic] — Milestone post-resolution dedup preserves uniqueness.**
GIVEN MUT is initialized via `_inject_config({ "milestone_pct": [0.01, 0.02], "partial_threshold": 1.0 })` AND R_authored = 10 (so both authored entries resolve to `T = 1`), WHEN MUT's `_ready()` runs, THEN `_milestone_thresholds == [1]` (the duplicate dropped) AND a warning is logged naming the dropped entry. WHEN the 1st discovery is recorded, THEN `discovery_milestone_reached("milestone_0", 1)` is emitted exactly once (not twice with different milestone_ids).

**AC-053 [Logic] — `_epilogue_conditions_emitted` persists across save/load; post-load discoveries do not re-fire the signal.**
GIVEN MUT has discovered all required epilogue recipes (so `epilogue_conditions_met()` was emitted once and `_epilogue_conditions_emitted == true`) AND `get_save_state()` is captured AND serialized, WHEN the state is loaded into a fresh MUT instance via `load_save_state()` AND a subsequent `combination_executed` fires for a new (non-required) recipe in Active state, THEN `epilogue_conditions_met()` is NOT re-emitted (observed via signal spy) AND `_epilogue_conditions_emitted` remains `true`.

**AC-054 [Logic] — Mid-session `epilogue_conditions_met` suppressed when `partial_threshold == 0.0`.**
GIVEN MUT is initialized via `_inject_config({ "milestone_pct": [], "partial_threshold": 0.0 })` AND `_epilogue_required_ids` has 3 entries AND MUT is in Active state, WHEN any `combination_executed` fires (including the first discovery), THEN `epilogue_conditions_met()` is NOT emitted during the session (observed via signal spy). `final_memory_ready()` still fires on `epilogue_started()` per its own rule.

**AC-055 [Integration/Playtest] — Player Fantasy recognition, not mechanical success.** *(Advisory — documented playtest.)*
GIVEN a representative slice of Chester's authored content is loaded (at least 5 recipes chained into one cascade: one combination producing a card that unlocks another recipe), WHEN a playtest observer silently watches a naive player reach the first cascade, THEN the player expresses spontaneous recognition or memory-surfacing reaction ("oh, I remember...", "oh my god...", a visible pause) rather than mechanical pattern-recognition language ("I unlocked something", "I got another one"). If the observed reaction is mechanical, the *authored content* needs revision, not the system. This AC fails the system only if the tree's signal/state behavior actively disrupts the authored moment (e.g., emitting a player-visible signal from a Pillar-3-constrained hook).

## Open Questions

| # | Question | Owner | Target Resolution |
|---|---|---|---|
| OQ-1 | **Performance budget for `combination_executed` processing.** Section D and E do not specify a frame-time budget for the discovery handler. Linear scans over `_epilogue_required_ids` and `_milestone_thresholds` happen on every combination. If recipe count grows to 200+, this could become measurable. | systems-designer + performance-analyst | Before Vertical Slice exit (set numeric ms budget, add to AC) |
| OQ-2 | **Reachability validation tool + deferred AC-050.** Every entry in `epilogue-requirements.tres` must be reachable via some valid play path (seed_cards + carry_forward traversal). No static tool exists. Tool must walk the recipe + scene graph from scene 1's base seed_cards and verify every required recipe_id is produced on some path before `epilogue_started`. Its output becomes AC-050 once it exists. Risk: late-content addition silently breaks epilogue reachability. | tools-programmer | Alpha (when content count makes manual verification impractical) |
| OQ-3 | **Scene-graph static checker for carry-forward anomalies.** Currently only author discipline prevents three distinct failure classes: (a) `carry_forward` referencing a recipe from a *later* scene (forward reference — unsatisfiable during the carrying scene's load), (b) **mutual carry-forward cycles** between two scenes (each requires a recipe from the other — both silently produce zero carry-forward cards), and (c) unreachable chains of carry-forward requirements. A single static checker reading the scene manifest should catch all three. | tools-programmer | Alpha (same risk window as OQ-2) |
| OQ-4 | **Session reset API for "New Game".** When the player starts a new save slot or wipes progress, MUT needs to clear all dictionaries and reset to Inactive without going through `load_save_state({})`. Should this be a new method `clear_state()` or repurpose `load_save_state` with a sentinel value? | game-designer + Save/Progress System author | Designed alongside Save/Progress System (Alpha) |
| OQ-5 | **Hot-reload deferred.** This GDD chose load-once at `_ready()` for simplicity. If playtest tuning of `milestone_thresholds` becomes painful, revisit hot-reload via a debug signal. | systems-designer | Reactive — only if playtest cycle reveals friction |
| OQ-6 | **Discovery analytics hook.** No telemetry is specified. If the team wants to measure which recipes get discovered most/least to inform content prioritization, a `recipe_discovered` listener could log to disk. Design intent or post-launch concern? | analytics-engineer + creative-director | Decide before Alpha (analytics scope decision) |
| OQ-7 | **Provisional ITF signal expansion + consumer lockstep.** This GDD specifies a 6-parameter `combination_executed` signal but the ITF GDD currently emits 4 parameters. Godot 4.3 dispatches signal arguments at **emit time** (not at connect time) — a mismatch raises a runtime dispatch error on the first combination played. Adding parameters is a **breaking change**. Every pre-existing consumer must update its handler signature in the same commit that lands the ITF change; the **only** valid migration path is "declare all 6 params in the handler, ignore unused" (`.bind()` cannot absorb trailing args — see Godot 4.3 Signal Compatibility edge-case block). Cross-GDD edits required: (1) ITF GDD emits 6-param signal, (2) Status Bar System GDD handler accepts 6 params (ignores new two), (3) any other consumer of `combination_executed` updated. AC-037a and AC-037b are blocked until this lands. | itf author (revisit) + statusbar author | Before MUT implementation begins — single-commit lockstep |
| OQ-8 | **Provisional Scene Goal System dependency.** SGS GDD does not yet mention the soft dependency on `MUT.get_carry_forward_cards()`. SGS GDD must be updated to document this call site in `load_scene()`. | sgs author (revisit) | Before SGS implementation enters Vertical Slice |
| OQ-9 | **Per-memory display names for Final Epilogue Screen.** `epilogue-requirements.tres` currently holds only recipe_ids. The Final Epilogue Screen will likely want a human-readable title per entry (e.g., "The night we walked home in the rain"). Should this be a parallel `display_name` field in the same file, sourced from Recipe Database's `name` field, or authored separately in the epilogue screen's own data? Affects authoring workflow for Chester. | game-designer + narrative-director | Before Final Epilogue Screen GDD is authored (Alpha) |
| OQ-10 | ~~**Combined autoload manifest.**~~ **RESOLVED 2026-04-21** by `docs/architecture/ADR-004-runtime-scene-composition.md` §1 (canonical 12-autoload order). MUT is position 10; RecipeDatabase is position 3 (before MUT ✓); Scene Manager is position 11 (after MUT ✓). Individual GDDs should cite ADR-004 instead of restating order. | technical-director | Closed |
| OQ-11 | ~~**`epilogue_conditions_met()` consumer decision.**~~ **RESOLVED 2026-04-20 / 2026-04-21** per FES GDD + ADR-004 §2. Consumer: `gameplay_root.gd` and/or Scene Manager's preloader subsystem — both silent, engine-prep only. The signal is kept (not deleted) because pre-loading the illustrated-memory texture ahead of STUI's amber cover prevents a visible frame-drop during the reveal. | game-designer + FES GDD author | Closed |
