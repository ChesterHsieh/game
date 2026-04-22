## DebugConfig — typed Resource for development-only overrides.
## Loaded from res://assets/data/debug-config.tres at MUT._ready().
## This file is EXCLUDED from release exports via export_presets.cfg:
##   exclude_filter="*/debug-config.tres,*/debug-config.tres.import"
## If absent (release build), all debug overrides are silently disabled.
##
## force_unlock_all: when true, MUT bulk-marks all recipes as discovered at
##   startup under scene_id "__debug__", without emitting any signals.
##   Used only for development testing of epilogue and carry-forward paths.
##
## Implements: GDD mystery-unlock-tree.md Rule 9; ADR-005 §7 (debug exclusion)
## ADR-005: typed Resource — no methods, only @export fields.
##
## Usage example:
##   var dbg: DebugConfig = ResourceLoader.load(
##       "res://assets/data/debug-config.tres") as DebugConfig
##   if dbg != null and dbg.force_unlock_all:
##       MUT._run_force_unlock_all()
class_name DebugConfig extends Resource

## When true, all recipes are bulk-marked discovered at startup.
## No discovery signals are emitted during the bulk-load.
## This flag has no effect in release builds (file is excluded from export).
@export var force_unlock_all: bool = false
