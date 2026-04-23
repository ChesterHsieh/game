## TableLayoutSystem — stateless card position calculator.
## Computes where seed cards appear at scene start and where spawned cards land.
## Not an Autoload — instantiated by CardSpawning and Scene Manager as needed.
## Uses seeded RNG so Chester can fix positions permanently once they look right.

extends Node

# ── Table Bounds ──────────────────────────────────────────────────────────────

## Inset from viewport edges — keeps cards fully visible and away from UI panels.
const EDGE_INSET     := 60.0
## Minimum distance between any two card centers.
const MIN_SPACING    := 100.0
## Max scatter attempts before accepting the least-overlapping position.
const MAX_ATTEMPTS   := 8
## Preferred spawn radius around a combination point.
const SPAWN_RADIUS   := 120.0


## Returns the safe table rect in world coordinates.
func get_table_bounds() -> Rect2:
	var vp := get_viewport().get_visible_rect()
	return Rect2(
		vp.position + Vector2(EDGE_INSET, EDGE_INSET),
		vp.size     - Vector2(EDGE_INSET * 2.0, EDGE_INSET * 2.0)
	)


# ── Seed Card Placement ───────────────────────────────────────────────────────

## Returns a Dictionary mapping card_id → Vector2 for each entry in [param seed_cards].
## [param seed_cards] is an Array of Dictionaries with at minimum a "card_id" key.
## Pass [param rng_seed] == -1 to use a random seed (logged to console for authoring).
func get_seed_positions(seed_cards: Array, rng_seed: int = -1) -> Dictionary:
	var rng        := RandomNumberGenerator.new()
	var seed_value := rng_seed if rng_seed >= 0 else randi()
	rng.seed        = seed_value

	if rng_seed < 0:
		print("TableLayout: random seed used for seed cards — fix as: rng_seed=%d" % seed_value)

	var bounds    := get_table_bounds()
	var placed:   Dictionary       = {}    # card_id -> Vector2
	var occupied: Array[Vector2]   = []

	for entry: Dictionary in seed_cards:
		var card_id: String = entry.get("card_id", "")
		if card_id == "":
			push_warning("TableLayout: seed card entry missing card_id — skipping")
			continue

		var pos := _sample_in_rect(bounds, occupied, rng)
		placed[card_id]  = pos
		occupied.append(pos)

	return placed


# ── Spawn Placement ───────────────────────────────────────────────────────────

## Returns a world position for a newly spawned card near [param combination_point].
## [param occupied] is the list of current card positions (to avoid overlap).
## Pass [param rng_seed] == -1 for random placement.
func get_spawn_position(combination_point: Vector2, occupied: Array[Vector2],
		rng_seed: int = -1) -> Vector2:
	var rng  := RandomNumberGenerator.new()
	rng.seed  = rng_seed if rng_seed >= 0 else randi()

	var bounds := get_table_bounds()

	var best_pos      := combination_point
	var best_overlap  := _count_overlaps(combination_point, occupied)

	for _i in MAX_ATTEMPTS:
		var angle := rng.randf() * TAU
		var dist  := rng.randf_range(SPAWN_RADIUS * 0.5, SPAWN_RADIUS)
		var candidate := combination_point + Vector2(cos(angle), sin(angle)) * dist
		candidate = _clamp_to_rect(candidate, bounds)

		var overlaps := _count_overlaps(candidate, occupied)
		if overlaps < best_overlap:
			best_pos     = candidate
			best_overlap = overlaps
			if overlaps == 0:
				break

	return best_pos


# ── Private ───────────────────────────────────────────────────────────────────

func _sample_in_rect(rect: Rect2, occupied: Array[Vector2],
		rng: RandomNumberGenerator) -> Vector2:
	var best_pos     := rect.position + rect.size * 0.5
	var best_overlap := _count_overlaps(best_pos, occupied)

	for _i in MAX_ATTEMPTS:
		var candidate := Vector2(
			rng.randf_range(rect.position.x, rect.position.x + rect.size.x),
			rng.randf_range(rect.position.y, rect.position.y + rect.size.y)
		)
		var overlaps := _count_overlaps(candidate, occupied)
		if overlaps < best_overlap:
			best_pos     = candidate
			best_overlap = overlaps
			if overlaps == 0:
				break

	return best_pos


func _count_overlaps(pos: Vector2, occupied: Array[Vector2]) -> int:
	var count := 0
	for other: Vector2 in occupied:
		if pos.distance_to(other) < MIN_SPACING:
			count += 1
	return count


func _clamp_to_rect(pos: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clamp(pos.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(pos.y, rect.position.y, rect.position.y + rect.size.y)
	)
