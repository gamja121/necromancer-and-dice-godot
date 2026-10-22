extends RefCounted
## Render-space obstacle derived from the actual giant sprite, including its
## authored attack lunge canvas. This consumes no gameplay or visual RNG.
static func exclusion(battle: Control, map_stage: Control) -> Rect2:
	if not is_instance_valid(battle) or not is_instance_valid(map_stage): return Rect2()
	for unit in battle.rules.units:
		if unit.get("team","")!="enemy" or unit.get("slug","")!="dragon": continue
		var geometry: Dictionary = battle.presentation_layout.geometry(unit,battle.surface_size)
		var transform: Transform2D = map_stage.get_global_transform_with_canvas().affine_inverse()*battle.get_global_transform_with_canvas()
		var first: Vector2 = transform*Vector2(geometry.position)
		var last: Vector2 = transform*(Vector2(geometry.position)+Vector2(geometry.size))
		return Rect2(first,last-first).abs().grow(8.0)
	return Rect2()

static func rest_position(position: Vector2, die_size: Vector2, area: Rect2, obstacle: Rect2) -> Vector2:
	if not obstacle.has_area(): return position
	var radius: float = die_size.length()*0.55
	var bounds := obstacle.grow(radius)
	var center := position+die_size*0.5
	if not bounds.has_point(center): return position
	var safe_area := area.grow(-radius)
	var candidates: Array[Vector2] = [
		Vector2(bounds.position.x-1.0,center.y),Vector2(bounds.end.x+1.0,center.y),
		Vector2(center.x,bounds.position.y-1.0),Vector2(center.x,bounds.end.y+1.0),
		safe_area.position,safe_area.end
	]
	var best := center
	var nearest := INF
	for candidate in candidates:
		candidate = candidate.clamp(safe_area.position,safe_area.end)
		if bounds.has_point(candidate): continue
		if center.distance_squared_to(candidate)<nearest:
			best = candidate
			nearest = center.distance_squared_to(candidate)
	return best-die_size*0.5
