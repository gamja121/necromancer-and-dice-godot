extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_layout.gd

const Layout = preload("res://systems/map_shuffle_layout.gd")
var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS map-shuffle: ", label)
	else:
		failed += 1
		printerr("FAIL map-shuffle: ", label)


func rings_fit(progress: float, slots: Array[Dictionary]) -> bool:
	var rectangles: Array[Rect2] = []
	var dice_rect := Rect2(Vector2(602.0, 307.6), Vector2(76.0, 76.0))
	for slot in slots:
		var size: Vector2 = Layout.TILE_SIZE * float(slot["scale"])
		var rect := Rect2(Layout.orbit_position(slot, progress) - size * 0.5, size)
		if not Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)).encloses(rect):
			return false
		if rect.intersects(dice_rect):
			return false
		for previous in rectangles:
			if rect.intersects(previous):
				return false
		rectangles.append(rect)
	return true


func _run() -> void:
	var moving: Array[int] = Layout.moving_indices()
	var slots: Array[Dictionary] = Layout.ring_slots()
	check(moving.size() == 21, "21 movable tiles")
	check(slots.size() == 21, "21 distinct orbit slots")
	var unique_indices: Dictionary = {}
	var inner := 0
	var outer := 0
	for slot in slots:
		unique_indices[int(slot["tile_index"])] = true
		if int(slot["ring"]) == 0:
			inner += 1
			check(float(slot["travel_degrees"]) > 0.0, "inner slot turns clockwise")
		else:
			outer += 1
			check(float(slot["travel_degrees"]) < 0.0, "outer slot turns counterclockwise")
	check(inner == 8 and outer == 13, "8 inner and 13 outer")
	check(unique_indices.size() == 21, "each moving tile appears once")
	for fixed_index in Layout.FIXED_INDICES:
		check(not unique_indices.has(fixed_index), "fixed tile %d excluded" % fixed_index)
	var all_clear := true
	for frame in range(241):
		if not rings_fit(float(frame) / 240.0, slots):
			all_clear = false
			break
	check(all_clear, "all 241 rotation samples avoid overlap, dice and screen edges")
	print("MAP_SHUFFLE_LAYOUT: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
