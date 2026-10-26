extends RefCounted
## Presentation only: one side-view art can face both horizontal directions.
## All completed steps restore the front-view token, independent of tile row.
const FRONT := "front"
const SIDE := "side"
const BACK := "back"

static func for_travel(delta: Vector2) -> Dictionary:
	if delta.length_squared() < 0.0001:
		return for_arrival()
	if absf(delta.x) >= absf(delta.y):
		return {"pose": SIDE, "flip_h": delta.x < 0.0}
	return {"pose": BACK if delta.y < 0.0 else FRONT, "flip_h": false}

static func for_arrival() -> Dictionary:
	return {"pose": FRONT, "flip_h": false}
