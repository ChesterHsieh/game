## RecipeManifest — top-level Resource that holds all RecipeEntry SubResources.
## Loaded once by RecipeDatabase at startup via ResourceLoader.
## No methods. RecipeDatabase owns all querying logic.
##
## Usage example:
##   var manifest: RecipeManifest = ResourceLoader.load(
##       "res://assets/data/recipes.tres") as RecipeManifest
##   for entry: RecipeEntry in manifest.entries:
##       print(entry.id)
class_name RecipeManifest extends Resource

## All recipe definitions in this manifest.
@export var entries: Array[RecipeEntry]
