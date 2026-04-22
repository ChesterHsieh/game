## MutConfig — typed Resource for MysteryUnlockTree configuration.
## Loaded from res://assets/data/mut-config.tres at MUT._ready().
## If the file is absent, MUT falls back to inline defaults.
##
## milestone_pct: Array of floats (0.0–1.0) representing discovery percentage
##   thresholds at which discovery_milestone_reached is emitted. Defaults to
##   [0.15, 0.50, 0.80] when no config file is present.
## partial_threshold: float (0.0–1.0). Fraction of epilogue-required recipes
##   that must be discovered before epilogue_conditions_met fires mid-session.
##   0.0 suppresses mid-session check entirely (final_memory_ready still fires
##   on epilogue_started). Default: 0.80.
##
## Implements: GDD mystery-unlock-tree.md Rule 6 (Tuning Knobs)
## ADR-005: typed Resource — no methods, only @export fields.
##
## Usage example:
##   var cfg: MutConfig = ResourceLoader.load(
##       "res://assets/data/mut-config.tres") as MutConfig
##   if cfg != null:
##       MysteryUnlockTree._inject_config(cfg)
class_name MutConfig extends Resource

## Discovery percentage thresholds for milestone_reached events.
## Values must be in (0.0, 1.0]. Duplicates are resolved at runtime.
@export var milestone_pct: Array[float] = [0.15, 0.50, 0.80]

## Fraction of epilogue-required recipes that triggers epilogue_conditions_met.
## Set to 0.0 to suppress the mid-session check.
@export_range(0.0, 1.0) var partial_threshold: float = 0.80
