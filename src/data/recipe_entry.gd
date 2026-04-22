## RecipeEntry — typed Resource representing a single recipe definition.
## One RecipeEntry SubResource per recipe. Lives inside a RecipeManifest .tres file.
## No methods beyond engine-generated getters. Validation is RecipeDatabase's job.
##
## Usage example:
##   var manifest: RecipeManifest = ResourceLoader.load(
##       "res://assets/data/recipes.tres") as RecipeManifest
##   var entry: RecipeEntry = manifest.entries[0]
class_name RecipeEntry extends Resource

## Unique identifier used for lookups. Must be unique across the manifest.
@export var id: StringName
## ID of the first card in the combination (order-insensitive per GDD).
@export var card_a: StringName
## ID of the second card in the combination (order-insensitive per GDD).
@export var card_b: StringName
## Template type string. Valid values: "additive" | "merge" | "animate" | "generator".
## Stored as StringName for extensibility (ADR-005 §2). No enum — validation
## of allowed values is RecipeDatabase's responsibility (Story 002+).
@export var template: StringName
## Which scene this recipe belongs to. Defaults to "global" (all scenes).
@export var scene_id: StringName = &"global"
## Template-specific configuration payload. Shape is owned by the Interaction
## Template Framework (ADR-005 §8 Dictionary exception — schema varies per template).
## Expected keys by template:
##   additive:  { "spawns": Array[StringName] }
##   merge:     { "result_card": StringName }
##   animate:   { "motion": StringName, "speed": float, "target": StringName, "duration_sec": float }
##   generator: { "generates": StringName, "interval_sec": float, "max_count": int, "generator_card": StringName }
@export var config: Dictionary
