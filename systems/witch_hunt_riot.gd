extends RefCounted
## The plan and the position are saved separately so a reload repeats the view
## of a committed roll without drawing another number.

static func active(world) -> bool:
	return world != null and world.riot.get("state", "") == "active"


static func start(world) -> bool:
	if world == null or not world.riot.is_empty(): return false
	var village: int = world.tiles.find("village")
	var home: int = world.tiles.find("home")
	if village < 0 or village >= home: return false
	world.riot = {"state":"active", "index":village, "face":0, "pending":{}}
	prepare_turn(world, [], true, true)
	return true


static func prepare_turn(world, player_path: Array, roll: bool = true, opening: bool = false) -> void:
	if not active(world) or not world.riot.pending.is_empty(): return
	var index: int = int(world.riot.index)
	var home: int = world.tiles.find("home")
	if world.position == home or (not opening and (player_path.has(index) or world.position == index)):
		world.riot.pending = {"face":0, "path":[], "state":"stopped"}
		return
	if not roll: return

	var face: int = world.rng.randi_range(1, 3)
	var path: Array[int] = []
	var finish := mini(index + face, home)
	for tile in range(index + 1, finish + 1):
		path.append(tile)
	world.riot.pending = {"face":face, "path":path, "state":"burned" if finish == home else "active"}


static func commit_turn(world) -> bool:
	if not active(world) or world.riot.pending.is_empty(): return false
	var plan: Dictionary = world.riot.pending
	if not plan.path.is_empty():
		world.riot.index = plan.path.back()
		world.riot.face = plan.face
	world.riot.state = plan.state
	world.riot.pending = {}
	return true


static func valid(saved: Variant, village: int, home: int) -> bool:
	if not saved is Dictionary: return false
	if saved.is_empty(): return true
	var state: Variant = saved.get("state")
	if state not in ["active", "stopped", "burned"]: return false
	if not _integer_between(saved.get("index"), village, home): return false
	if not _integer_between(saved.get("face"), 0, 3): return false
	var index: int = int(saved.index)
	var plan: Variant = saved.get("pending")
	if not plan is Dictionary: return false
	if state == "burned": return index == home and plan.is_empty()
	if index == home: return false
	if state == "stopped" or plan.is_empty(): return plan.is_empty()
	if not _integer_between(plan.get("face"), 0, 3) or not plan.get("path") is Array: return false
	var face: int = int(plan.face)
	var finish := mini(index + face, home)
	if plan.path.size() != finish - index: return false
	for step in range(plan.path.size()):
		var expected := index + step + 1
		if not _integer_between(plan.path[step], expected, expected): return false
	var expected_state := "stopped" if face == 0 else ("burned" if finish == home else "active")
	return plan.get("state") == expected_state


static func normalized(saved: Dictionary) -> Dictionary:
	var result := saved.duplicate(true)
	if result.is_empty(): return result
	result.index = int(result.index)
	result.face = int(result.face)
	if not result.pending.is_empty():
		result.pending.face = int(result.pending.face)
		result.pending.path = result.pending.path.map(func(tile): return int(tile))
	return result


static func _integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and value >= minimum and value <= maximum and value == floorf(value)
