## CardNode — minimal data container for a card on the table.
## Visual rendering is handled by CardVisual (Sprint 03).
## Position and state are owned by CardEngine.
## instance_id and card_id are set by CardSpawning immediately after instantiation.

extends Node2D

## Unique runtime identifier: "{card_id}_{counter}" e.g. "chester_0"
var instance_id: String = ""

## Base card definition ID — references CardDatabase
var card_id: String = ""
