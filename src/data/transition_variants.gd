## TransitionVariants — per-scene tuning knob overrides for STUI (ADR-005, Story 006).
##
## Loaded at STUI _enter_tree() via:
##   ResourceLoader.load("res://assets/data/ui/transition-variants.tres") as TransitionVariants
##
## The `variants` Dictionary maps scene_id (String) to a knob override Dictionary.
## Recognised per-scene keys (GDD §Tuning Knobs — Per-scene override):
##   "fold_duration_scale" : float  — multiplier on rise/hold/fade nominals (0.6–1.5)
##   "paper_tint"          : Color  — overrides overlay_color_cream for this scene
##   "sfx_variant_id"      : String — selects a specific rustle SFX variant by name
##
## Any unrecognised keys are silently ignored at lookup time.
## A "default" key provides the fallback when a scene_id is not found.
##
## Example content:
##   variants = {
##     "home":    { "fold_duration_scale": 1.0, "paper_tint": Color(0.98, 0.95, 0.88) },
##     "park":    { "fold_duration_scale": 0.9, "paper_tint": Color(0.95, 0.98, 0.90) },
##     "default": { "fold_duration_scale": 1.0, "paper_tint": Color(0.98, 0.95, 0.88) }
##   }
class_name TransitionVariants extends Resource

## Per-scene knob overrides keyed by scene_id.
## Missing key falls back to "default"; missing "default" falls back to hardcoded knobs.
@export var variants: Dictionary = {}
