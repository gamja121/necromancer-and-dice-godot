extends SceneTree
## Stone shuffle step 4: bounded dust and ground-kick at each saved landing.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_stone_dust.gd

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
		print("PASS stone-dust: ", label)
	else:
		failed += 1
		printerr("FAIL stone-dust: ", label)


func make_face(color: Color) -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _run() -> void:
	var face: Texture2D = make_face(Color(0.55, 0.51, 0.45))
	var stage := Control.new()
	stage.size = Vector2(1280, 720)
	root.add_child(stage)
	var buttons: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		var button := TextureButton.new()
		button.ignore_texture_size = true
		button.texture_normal = face
		button.size = Layout.TILE_SIZE
		button.position = MapState.centers()[i] * Vector2(12.8, 7.2) - button.size * 0.5
		button.z_index = 4
		stage.add_child(button)
		buttons.append(button)
	var dice := TextureButton.new()
	dice.texture_normal = face
	dice.size = Vector2(76, 76)
	dice.position = Vector2(602.0, 307.6)
	dice.z_index = 19
	stage.add_child(dice)
	var saved_faces: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		saved_faces.append(face if i in Layout.FIXED_INDICES else make_face(Color(float(i) / 24.0, 0.4, 0.5)))
	var shuffle := Gather.new()
	stage.add_child(shuffle)

	check(Gather.DUST_GRAINS_PER_TILE == 4, "just four lightweight grains per tile")
	check(Gather.DUST_GRAINS_PER_TILE * 21 == 84, "at most 84 simultaneous dust grains")
	check(Gather.DUST_LIFETIME <= 0.20, "each puff vanishes within 200ms")
	check(Gather.DUST_TOTAL_DURATION <= 0.70, "all bursts complete without long input lock")
	check(Gather.DUST_IMPACT_OFFSET >= Gather.FLIP_HALF_DURATION + Gather.LANDING_DURATION - 0.001, "dust begins at full stone contact")
	check(Gather.dust_burst_fraction(Gather.DUST_IMPACT_OFFSET - 0.001, 0) < 0.0, "no dust before the first impact")
	check(is_equal_approx(Gather.dust_burst_fraction(Gather.DUST_IMPACT_OFFSET, 0), 0.0), "first burst starts exactly on impact")
	check(Gather.dust_burst_fraction(Gather.DUST_IMPACT_OFFSET + 0.05, 1) > 0.0, "bursts follow tile index stagger")
	check(Gather.dust_burst_fraction(Gather.DUST_TOTAL_DURATION, 20) < 0.0, "last burst fully disappears")
	check(Gather.dust_burst_fraction(1.0, -1) < 0.0 and Gather.dust_burst_fraction(1.0, 21) < 0.0, "invalid tile indexes emit no dust")
	check(shuffle.dust_elapsed < 0.0 and shuffle.dust_centers.is_empty(), "nothing emits dust before the transition")

	# Test rollback BEFORE a successful run. No stone impact is allowed if
	# the actual RunSession refused to persist a changed map.
	check(shuffle.prepare(buttons), "initial original map prepares")
	await shuffle.play_gather()
	await shuffle.play_rotation()
	var refused: bool = await shuffle.play_scatter(saved_faces, false)
	check(not refused, "unsaved board cannot be revealed")
	check(shuffle.dust_centers.is_empty() and shuffle.dust_elapsed < 0.0 and shuffle.dust_tween == null, "save failure spawns zero dust and cleans state")
	check(buttons.all(func(tile): return tile.visible), "unsaved map keeps old gameplay buttons visible")

	check(shuffle.prepare(buttons), "successful transition reuses same visual controller")
	await shuffle.play_gather()
	await shuffle.play_rotation()
	var probe: Dictionary = {"frames": 0, "started_during_scatter": false, "max_active": 0, "all_bursts": {}, "positions_valid": true, "timing_valid": true}
	var monitor: Callable = func() -> void:
		if shuffle.scatter_tween != null and shuffle.scatter_tween.is_running() and not shuffle.dust_centers.is_empty():
			probe["started_during_scatter"] = true
		if shuffle.dust_elapsed < 0.0:
			return
		probe["frames"] = int(probe["frames"]) + 1
		if shuffle.dust_centers.size() != 21:
			probe["positions_valid"] = false
			return
		var active: int = 0
		for i in range(shuffle.dust_centers.size()):
			var destination_index: int = int(Layout.SCATTER_DESTINATIONS[i])
			var expected: Vector2 = buttons[destination_index].position + Vector2(Layout.TILE_SIZE.x * 0.5, Layout.TILE_SIZE.y)
			if shuffle.dust_centers[i].distance_to(expected) > 0.01:
				probe["positions_valid"] = false
			var fraction: float = Gather.dust_burst_fraction(shuffle.dust_elapsed, i)
			if fraction >= 0.0:
				active += 1
				probe["all_bursts"][i] = true
				if fraction > 1.0 or fraction < 0.0:
					probe["timing_valid"] = false
		probe["max_active"] = maxi(int(probe["max_active"]), active)
	process_frame.connect(monitor)
	var succeeded: bool = await shuffle.play_scatter(saved_faces, true)
	process_frame.disconnect(monitor)
	check(succeeded, "new board safely reveals after a successful save")
	check(not bool(probe["started_during_scatter"]), "no dust during scatter travel")
	check(int(probe["frames"]) >= 5, "multiple actual dust animation frames rendered")
	check(bool(probe["positions_valid"]), "all impact points match real tile destination corners")
	check(bool(probe["timing_valid"]), "every active dust puff has a bounded lifetime")
	check(probe["all_bursts"].size() == 21, "every one of 21 landing tiles emitted a staggered puff")
	check(int(probe["max_active"]) > 0 and int(probe["max_active"]) <= 21, "particle work stays within maximum 21 simultaneous puffs")
	check(shuffle.dust_centers.is_empty() and shuffle.dust_elapsed < 0.0 and shuffle.dust_tween == null, "dust timer and event data are cleared at end")
	check(shuffle.tile_visuals.is_empty() and shuffle.tile_shadows.is_empty(), "stone art and shadows are cleaned")
	check(buttons.all(func(tile): return tile.visible), "all authoritative tile buttons restored")
	check(dice.position == Vector2(602.0, 307.6) and dice.texture_normal == face, "die position and face remain unchanged")
	stage.queue_free()
	print("MAP_SHUFFLE_STONE_DUST: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
