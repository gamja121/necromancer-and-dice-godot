extends RefCounted
## Presentation only: one side-view art can face both horizontal directions.
## Travel keeps its direction across intermediate tiles; only the final destination faces front.
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

## Called after each animated tile step. Intermediate stops keep the travelling pose.
static func for_step_arrival(delta: Vector2, final_step: bool) -> Dictionary:
	return for_arrival() if final_step else for_travel(delta)
