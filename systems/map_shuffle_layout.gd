extends RefCounted
## Two-ring, collision-conscious shuffle geometry for the 24-tile map.
## Fixed map nodes and all game rules remain unchanged.

const BOARD_TILE_COUNT = 24
const FIXED_INDICES = [0, 8, 15] # Fortune teller, village, home.
const TILE_SIZE = Vector2(120.0, 90.0)
const DICE_CENTER = Vector2(640.0, 345.6)

const INNER_COUNT = 8
const OUTER_COUNT = 13
const INNER_RADIUS = Vector2(135.0, 110.0)
const OUTER_RADIUS = Vector2(255.0, 205.0)
const INNER_SCALE = 0.50
const OUTER_SCALE = 0.48
const INNER_ROTATION_DEGREES = 210.0
const OUTER_ROTATION_DEGREES = -250.0

# Board positions are fixed in MapState.centers(); assign the nearer eight
# cells to the inner orbit. Within each ring, slots follow perimeter order.
# Offsets reduce intersections on the approach to the two orbits.
const INNER_ORIGIN_ORDER = [1, 2, 3, 4, 13, 14, 16, 17]
const OUTER_ORIGIN_ORDER = [21, 22, 23, 5, 6, 7, 9, 10, 11, 12, 18, 19, 20]
const INNER_OFFSET = 7
const OUTER_OFFSET = 10


static func moving_indices() -> Array[int]:
	var result: Array[int] = []
	for tile_index in range(BOARD_TILE_COUNT):
		if tile_index not in FIXED_INDICES:
			result.append(tile_index)
	return result


static func ring_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for ring in range(2):
		var group: Array = INNER_ORIGIN_ORDER if ring == 0 else OUTER_ORIGIN_ORDER
		var offset: int = INNER_OFFSET if ring == 0 else OUTER_OFFSET
		var ring_size: int = group.size()
		for i in range(ring_size):
			var angle: float = -PI * 0.5 + TAU * float((i + offset) % ring_size) / float(ring_size)
			slots.append({
				"tile_index": int(group[i]),
				"ring": ring,
				"slot_index": i,
				"start_angle": angle,
				"travel_degrees": INNER_ROTATION_DEGREES if ring == 0 else OUTER_ROTATION_DEGREES,
				"scale": INNER_SCALE if ring == 0 else OUTER_SCALE
			})
	return slots


## progress ranges from 0 (gathered) to 1 (rotation complete).
## Faces stay upright; the tiles move along the orbits.
static func orbit_position(slot: Dictionary, progress: float) -> Vector2:
	var radius: Vector2 = INNER_RADIUS if int(slot["ring"]) == 0 else OUTER_RADIUS
	var angle: float = float(slot["start_angle"]) + deg_to_rad(float(slot["travel_degrees"])) * clampf(progress, 0.0, 1.0)
	return DICE_CENTER + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
