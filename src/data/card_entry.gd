## CardEntry — typed Resource representing a single card definition.
## One CardEntry SubResource per card. Lives inside a CardManifest .tres file.
## No methods beyond engine-generated getters. Validation is CardDatabase's job.
##
## Usage example:
##   var e: CardEntry = ResourceLoader.load("res://assets/data/cards.tres") \
##       .entries[0] as CardEntry
class_name CardEntry extends Resource

## All supported card categories. Exactly 7 values per TR-card-database-004.
enum CardType {
	PERSON,
	PLACE,
	FEELING,
	OBJECT,
	MOMENT,
	INSIDE_JOKE,
	SEED,
}

## Unique identifier used for lookups. Must be unique across the manifest.
@export var id: StringName
## Human-readable card title shown in the UI.
@export var display_name: String
## Optional flavour text shown on the card face.
@export var flavor_text: String = ""
## Card illustration. UID-safe reference — drag from the FileSystem dock.
@export var art: Texture2D
## Which category this card belongs to.
@export var type: CardType
## Which scene this card appears in, or "global" for all scenes.
@export var scene_id: StringName
## Optional search/filter tags.
@export var tags: PackedStringArray
## Optional top-bar badge text (e.g. "OFFLINE"). Empty = no badge bar drawn.
## Rendered by CardVisual as a small black bar at the top of the card face.
@export var badge: String = ""
