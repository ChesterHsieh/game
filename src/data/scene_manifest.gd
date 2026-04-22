## SceneManifest — top-level Resource that holds the ordered list of scene IDs
## to play through. Loaded once by SceneManager at startup via ResourceLoader.
## No methods. SceneManager owns all sequencing logic.
##
## Implements: design/gdd/scene-manager.md (ADR-005)
##
## Usage example:
##   var manifest: SceneManifest = ResourceLoader.load(
##       "res://assets/data/scene-manifest.tres") as SceneManifest
##   for scene_id: String in manifest.scene_ids:
##       print(scene_id)
class_name SceneManifest extends Resource

## Ordered list of scene IDs to play through in sequence.
## Scene IDs map to JSON files under assets/data/scenes/{id}.json.
@export var scene_ids: PackedStringArray = []
