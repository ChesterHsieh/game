## EpilogueRequirements — typed Resource listing recipes required for the
## final illustrated memory.
## Loaded from res://assets/data/epilogue-requirements.tres at MUT._ready().
## If absent or empty, epilogue_conditions_met and final_memory_ready are
## suppressed and an error is logged.
##
## recipe_ids: explicit list of recipe_id strings that must be discovered
##   (subject to partial_threshold) for the epilogue condition to be satisfied.
##   One file, one place to audit the gift's required memories — the per-recipe
##   epilogue_required flag is NOT used (GDD Rule 7).
##
## Implements: GDD mystery-unlock-tree.md Rule 7 (epilogue requirements file)
## ADR-005: typed Resource — no methods, only @export fields.
##
## Usage example:
##   var req: EpilogueRequirements = ResourceLoader.load(
##       "res://assets/data/epilogue-requirements.tres") as EpilogueRequirements
##   if req == null:
##       push_error("MUT: epilogue-requirements.tres missing")
class_name EpilogueRequirements extends Resource

## Recipe IDs that gate the final illustrated memory.
## Empty array → both epilogue_conditions_met and final_memory_ready are
## suppressed and an error is logged.
@export var recipe_ids: Array[String] = []
