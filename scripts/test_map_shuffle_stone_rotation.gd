extends SceneTree
## Stone shuffle stage 3: inertia and heavy braking without changing rings.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_stone_rotation.gd

const Layout = preload("res://systems/map_shuffle_layout.gd")
const Gather = preload("res://systems/map_shuffle_gather.gd")
const MapState = preload("res://systems/map_state.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS stone-rotation: ", label)
	else:
		failed += 1
		printerr("FAIL stone-rotation: ", label)


func velocity_between(a: float, b: float) -> float:
	return (Gather.stone_rotation_progress(b) - Gather.stone_rotation_progress(a)) / (b - a)


func _run() -> void:
	check(is_equal_approx(Gather.stone_rotation_progress(0.0), 0.0), "rotation begins at zero")
	check(is_equal_approx(Gather.stone_rotation_progress(1.0), 1.0), "rotation reaches full angle")
	check(is_equal_approx(Gather.stone_rotation_progress(-1.0), 0.0) and is_equal_approx(Gather.stone_rotation_progress(2.0), 1.0), "elapsed time clamps safely")
	check(Gather.ROTATION_BRAKE_FRACTION > Gather.ROTATION_ACCEL_FRACTION, "braking window is longer than startup")
	check(is_equal_approx(Gather.ROTATE_DURATION, 0.85), "total ring rotation duration unchanged")

	var monotonic := true
	var within_bounds := true
	var previous := 0.0
	for step in range(1, 1001):
		var fraction: float = float(step) / 1000.0
		var progress: float = Gather.stone_rotation_progress(fraction)
		if progress < previous - 0.00001:
			monotonic = false
		if progress < -0.00001 or progress > 1.00001:
			within_bounds = false
		previous = progress
	check(monotonic, "all 1000 sampled positions advance without reversing")
	check(within_bounds, "integrated inertia has no overshoot")
	var starting_speed := velocity_between(0.00, 0.03)
	var building_speed := velocity_between(0.10, 0.15)
	var middle_speed := velocity_between(0.43, 0.48)
	var braking_speed := velocity_between(0.80, 0.85)
	var ending_speed := velocity_between(0.97, 1.00)
	check(starting_speed < building_speed and building_speed < middle_speed, "stone accelerates smoothly from rest")
	check(ending_speed < braking_speed and braking_speed < middle_speed, "stone brakes gradually until stationary")
	check(starting_speed < middle_speed * 0.12 and ending_speed < middle_speed * 0.12, "both endpoints have strong weight and near-zero velocity")
	check(Gather.stone_rotation_progress(0.5) > 0.5 and Gather.stone_rotation_progress(0.7) < 0.85, "midcourse angular progress follows a steady flywheel")

	# Cosine ramps join the cruise at continuous speed: no jerky
	# sudden acceleration discontinuity at 20% or 70% of duration.
	var joins_smooth := true
	for join in [Gather.ROTATION_ACCEL_FRACTION, 1.0 - Gather.ROTATION_BRAKE_FRACTION]:
		var before: float = velocity_between(join - 0.006, join)
		var after: float = velocity_between(join, join + 0.006)
		if absf(before - after) > 0.05:
			joins_smooth = false
	check(joins_smooth, "both acceleration and braking joins are smooth")

	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.40, 0.37, 0.34))
	var face := ImageTexture.create_from_image(img)
	var stage := Control.new()
	stage.size = Vector2(1280.0, 720.0)
	root.add_child(stage)
	var tiles: Array = []
	var centers: Array = MapState.centers()
	for i in range(Layout.BOARD_TILE_COUNT):
		var tile := TextureButton.new()
		tile.texture_normal = face
		tile.ignore_texture_size = true
		tile.size = Layout.TILE_SIZE
		tile.position = centers[i] * Vector2(12.8, 7.2) - tile.size * 0.5
		tile.z_index = 4
		stage.add_child(tile)
		tiles.append(tile)
	var die := TextureButton.new()
	die.texture_normal = face
	die.size = Vector2(76, 76)
	die.position = Vector2(602.0, 307.6)
	die.z_index = 19
	stage.add_child(die)
	var gather := Gather.new()
	stage.add_child(gather)
	check(gather.prepare(tiles), "original map accepted")
	await gather.play_gather()
	check(gather.gathered, "21 stone slabs reach the two rings")

	var orbit_start: Vector2 = gather.tile_visuals[0].position
	var observed: Dictionary = {"frames": 0, "moved": false, "faces_upright": true, "unchanged_sources": true}
	var source_positions: Array = []
	for tile in tiles:
		source_positions.append(tile.position)
	var monitor: Callable = func() -> void:
		if gather.rotation_tween == null or gather.tile_visuals.is_empty():
			return
		observed["frames"] = int(observed["frames"]) + 1
		if gather.tile_visuals[0].position.distance_to(orbit_start) > 5.0:
			observed["moved"] = true
		for visual in gather.tile_visuals:
			if absf(visual.rotation) > 0.0001:
				observed["faces_upright"] = false
		for i in range(tiles.size()):
			if tiles[i].position != source_positions[i]:
				observed["unchanged_sources"] = false
	process_frame.connect(monitor)
	await gather.play_rotation()
	process_frame.disconnect(monitor)
	check(int(observed["frames"]) > 2 and bool(observed["moved"]), "real rotation tween animates moving tiles")
	check(bool(observed["faces_upright"]) and bool(observed["unchanged_sources"]), "tile art remains upright and original map positions never move")
	check(gather.rotated, "rotation reaches final state")
	var exact_positions := true
	for i in range(gather.tile_visuals.size()):
		var tile: TextureRect = gather.tile_visuals[i]
		var destination: Vector2 = Layout.orbit_position(gather.slots[i], 1.0) - tile.size * 0.5
		if tile.position.distance_to(destination) > 0.12:
			exact_positions = false
	check(exact_positions, "all 21 tiles end at original specified ring angles and slots")
	check(Layout.INNER_ROTATION_DEGREES == 210.0 and Layout.OUTER_ROTATION_DEGREES == -250.0, "inner clockwise and outer counterclockwise rotations unchanged")
	check(die.position == Vector2(602.0, 307.6) and die.texture_normal == face, "central die unchanged")
	gather.restore_tiles()
	check(gather.tile_visuals.is_empty() and gather.tile_shadows.is_empty() and not gather.rotated, "temporary visuals and state cleaned")
	check(tiles.all(func(tile): return tile.visible), "original gameplay tiles restored")
	stage.queue_free()
	print("MAP_SHUFFLE_STONE_ROTATION: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
