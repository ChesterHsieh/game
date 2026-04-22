## CardManifest — top-level Resource that holds all CardEntry SubResources.
## Loaded once by CardDatabase at startup via ResourceLoader.
## No methods. CardDatabase owns all querying logic.
##
## Usage example:
##   var manifest: CardManifest = ResourceLoader.load(
##       "res://assets/data/cards.tres") as CardManifest
##   for entry: CardEntry in manifest.entries:
##       print(entry.id)
class_name CardManifest extends Resource

## All card definitions in this manifest.
@export var entries: Array[CardEntry]
