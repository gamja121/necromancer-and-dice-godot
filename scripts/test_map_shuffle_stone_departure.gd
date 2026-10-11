extends SceneTree
## Stone shuffle step 2: a sub-pixel tremor followed by a heavy launch.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_stone_departure.gd

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
		print("PASS stone-departure: ", label)
	else:
		failed += 1
		printerr("FAIL stone-departure: ", label)


func make_texture() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.45, 0.4, 0.36))
	return ImageTexture.create_from_image(img)


func _run() -> void:
	var stage := Control.new()
	stage.size = Vector2(1280.0, 720.0)
	root.add_child(stage)
	var face := make_texture()
	var buttons: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		var tile := TextureButton.new()
		tile.texture_normal = face
		tile.ignore_texture_size = true
		tile.size = Layout.TILE_SIZE
		tile.position = MapState.centers()[i] * Vector2(12.8, 7.2) - tile.size * 0.5
		stage.add_child(tile)
		buttons.append(tile)
	var dice := TextureButton.new()
	dice.texture_normal = face
	dice.position = Vector2(602, 307.6)
	dice.size = Vector2(76, 76)
	stage.add_child(dice)
	var shuffle := Gather.new()
	stage.add_child(shuffle)
	check(shuffle.prepare(buttons), "prepare all 24 tile locations")
	check(shuffle.tile_visuals.size() == 21, "21 moving stone slabs prepared")
	check(Gather.PREDEPARTURE_DURATION <= 0.12, "predeparture vibration lasts under 120ms")
	check(Gather.PREDEPARTURE_AMPLITUDE.x <= 1.0 and Gather.PREDEPARTURE_AMPLITUDE.y <= 0.5, "stone movement limited to subpixel vertical tremor")

	# Deterministic probe, not dependent on the display refresh rate.
	shuffle._apply_predeparture(0.25)
	var displaced := 0
	var safe_displacement := true
	for i in range(shuffle.tile_visuals.size()):
		var original: Vector2 = shuffle.tile_sources[i].position
		var actual: Vector2 = shuffle.tile_visuals[i].position
		if actual.distance_to(original) > 0.2:
			displaced += 1
		if absf(actual.x - original.x) > Gather.PREDEPARTURE_AMPLITUDE.x + 0.01:
			safe_displacement = false
		if absf(actual.y - original.y) > Gather.PREDEPARTURE_AMPLITUDE.y + 0.01:
			safe_displacement = false
	check(displaced == 21, "all 21 stone slabs visibly resist the initial pull")
	check(safe_displacement, "tremor stays within the conservative displacement cap")
	shuffle._apply_predeparture(1.0)
	check(shuffle.tile_visuals.all(func(v): return v.position.distance_to(shuffle.tile_sources[shuffle.tile_visuals.find(v)].position) < 0.01), "tremor ends at original exact positions")

	var samples: Dictionary = {"tremor": 0, "tremor_ok": true, "early": false, "late": false, "static_ok": true}
	var initial_positions: Array = []
	for tile in buttons:
		initial_positions.append(tile.position)
	var source_pos: Vector2 = shuffle.tile_sources[0].position
	var first_visual: TextureRect = shuffle.tile_visuals[0]
	var first_target: Vector2 = Layout.orbit_position(shuffle.slots[0], 0.0) - first_visual.size * 0.5
	var full_distance: float = source_pos.distance_to(first_target)
	var monitor: Callable = func() -> void:
		if not is_instance_valid(shuffle):
			return
		if shuffle.predeparture_tween != null and shuffle.predeparture_tween.is_running():
			samples["tremor"] = int(samples["tremor"]) + 1
			for i in range(shuffle.tile_visuals.size()):
				var source: Vector2 = shuffle.tile_sources[i].position
				var delta: Vector2 = shuffle.tile_visuals[i].position - source
				if absf(delta.x) > Gather.PREDEPARTURE_AMPLITUDE.x + 0.02 or absf(delta.y) > Gather.PREDEPARTURE_AMPLITUDE.y + 0.02:
					samples["tremor_ok"] = false
		if shuffle.gathering != null and shuffle.gathering.is_running():
			# During shrinking the first tile is still at full-scale; only
			# observe acceleration once it is at the target ring scale.
			if first_visual.scale.x <= Layout.INNER_SCALE + 0.001 and full_distance > 1.0:
				var normalized_time: float = shuffle.gathering.get_total_elapsed_time() / Gather.TRAVEL_DURATION
				var normalized_distance: float = source_pos.distance_to(first_visual.position) / full_distance
				if normalized_time > 0.14 and normalized_time < 0.40 and normalized_distance < normalized_time - 0.03:
					samples["early"] = true
				if normalized_time > 0.60 and normalized_time < 0.88 and normalized_distance > normalized_time + 0.03:
					samples["late"] = true
		for i in range(buttons.size()):
			if buttons[i].position != initial_positions[i]:
				samples["static_ok"] = false
	process_frame.connect(monitor)
	await shuffle.play_gather()
	process_frame.disconnect(monitor)
	# Very fast headless runs may advance a 90ms tween in a single
	# process frame. Test the tween's actual completion, not frame count.
	check(shuffle.predeparture_tween != null and shuffle.predeparture_tween.get_total_elapsed_time() >= Gather.PREDEPARTURE_DURATION - 0.001, "predeparture resistance tween reaches its full programmed duration")
	check(bool(samples["tremor_ok"]), "animated tremor stays within one-pixel limits")
	check(bool(samples["early"]), "departure accelerates slowly instead of jumping into motion")
	check(bool(samples["late"]), "stone gains momentum before easing into its ring")
	check(bool(samples["static_ok"]), "authoritative gameplay tile positions never move")
	check(shuffle.gathered, "all stone slabs reached both ring positions")
	var exactly_placed := true
	for i in range(shuffle.tile_visuals.size()):
		var visual: TextureRect = shuffle.tile_visuals[i]
		var finish: Vector2 = Layout.orbit_position(shuffle.slots[i], 0.0) - visual.size * 0.5
		if visual.position.distance_to(finish) > 0.1:
			exactly_placed = false
	check(exactly_placed, "21 slabs end at precisely the original orbit slots")
	check(dice.position == Vector2(602, 307.6) and dice.texture_normal == face, "dice still unaffected")
	shuffle.restore_tiles()
	check(shuffle.predeparture_tween == null and shuffle.tile_visuals.is_empty(), "tremor and visual state completely cleaned")
	check(buttons.all(func(tile): return tile.visible), "all original tiles restored")
	stage.queue_free()
	print("MAP_SHUFFLE_STONE_DEPARTURE: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
