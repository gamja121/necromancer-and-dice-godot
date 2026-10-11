extends RefCounted
## Geometry-only layout for the home-exit map shuffle.
## The visual transition will use these slots; this file does not change map rules.

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


static func moving_indices() -> Array[int]:
	var result: Array[int] = []
	for tile_index in range(BOARD_TILE_COUNT):
		if tile_index not in FIXED_INDICES:
			result.append(tile_index)
	return result


## A stable 8+13-slot arrangement. Slots never overlap at nominal scale
## during the counter-rotation, including while the two rings pass each other.
static func ring_slots() -> Array[Dictionary]:
	var indices: Array[int] = moving_indices()
	var slots: Array[Dictionary] = []
	for order in range(indices.size()):
		var inner: bool = order < INNER_COUNT
		var ring_index: int = order if inner else order - INNER_COUNT
		var ring_size: int = INNER_COUNT if inner else OUTER_COUNT
		var angle: float = -PI * 0.5 + TAU * float(ring_index) / float(ring_size)
		slots.append({
			"tile_index": indices[order],
			"ring": 0 if inner else 1,
			"slot_index": ring_index,
			"start_angle": angle,
			"travel_degrees": INNER_ROTATION_DEGREES if inner else OUTER_ROTATION_DEGREES,
			"scale": INNER_SCALE if inner else OUTER_SCALE
		})
	return slots


## progress ranges from 0 (gathered) to 1 (rotation complete).
## The displayed tile face stays upright; only its orbit position changes.
static func orbit_position(slot: Dictionary, progress: float) -> Vector2:
	var radius: Vector2 = INNER_RADIUS if int(slot["ring"]) == 0 else OUTER_RADIUS
	var angle: float = float(slot["start_angle"]) + deg_to_rad(float(slot["travel_degrees"])) * clampf(progress, 0.0, 1.0)
	return DICE_CENTER + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
