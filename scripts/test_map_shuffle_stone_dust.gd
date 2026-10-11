extends SceneTree
## Stone shuffle stage 4: visually restrained contact dust only after landing
## a successfully saved board. No texture assets, input interception or leaks.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_stone_dust.gd

const Layout = preload("res://systems/map_shuffle_layout.gd")
const Gather = preload("res://systems/map_shuffle_gather.gd")
const StoneDust = preload("res://systems/map_shuffle_stone_dust.gd")
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


func make_texture(color: Color) -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _run() -> void:
	var stage := Control.new()
	stage.size = Vector2(1280, 720)
	root.add_child(stage)
	var old := make_texture(Color(0.4, 0.38, 0.34))
	var buttons: Array = []
	var centers: Array = MapState.centers()
	for i in range(Layout.BOARD_TILE_COUNT):
		var tile := TextureButton.new()
		tile.texture_normal = old
		tile.ignore_texture_size = true
		tile.size = Layout.TILE_SIZE
		tile.position = centers[i] * Vector2(12.8, 7.2) - tile.size * 0.5
		tile.z_index = 4
		stage.add_child(tile)
		buttons.append(tile)
	var die := TextureButton.new()
	die.texture_normal = old
	die.position = Vector2(602, 307.6)
	die.size = Vector2(76, 76)
	die.z_index = 19
	stage.add_child(die)
	var new_faces: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		new_faces.append(old if i in Layout.FIXED_INDICES else make_texture(Color(float(i) / 24.0, 0.5, 0.45)))

	var shuffle := Gather.new()
	stage.add_child(shuffle)
	var dust: StoneDust = shuffle.stone_dust
	check(dust != null and is_instance_valid(dust), "one shared contact dust draw layer exists")
	check(dust.mouse_filter == Control.MOUSE_FILTER_IGNORE, "dust never blocks board input")
	check(dust.get_parent() == shuffle and dust.get_child_count() == 0, "dust uses no new per-tile nodes")
	check(StoneDust.MAX_PUFFS == 21 and StoneDust.MAX_SPECKS <= 3, "dust emission and particle count strictly capped")
	check(StoneDust.PUFF_DURATION <= 0.20, "dust appears for less than 200 milliseconds")
	check(not dust.is_processing() and dust.puffs.is_empty(), "dust is entirely idle before animation")

	# Standalone draw-layer lifecycle and hard limit checks.
	dust.emit_at(Vector2(100, 100), 0)
	check(dust.puffs.size() == 1 and dust.is_processing(), "first impact enables rendering")
	dust._process(StoneDust.PUFF_DURATION + 0.02)
	check(dust.puffs.is_empty() and not dust.is_processing(), "dust expires and disables frame updates")
	dust.clear_puffs()
	for i in range(StoneDust.MAX_PUFFS + 3):
		dust.emit_at(Vector2(200.0 + i, 200), i)
	check(dust.puffs.size() == 21 and dust.total_emitted == 21, "excess puffs are discarded instead of allocating")
	dust.clear_puffs()
	check(dust.puffs.is_empty() and dust.total_emitted == 0 and not dust.is_processing(), "clear resets shared dust layer completely")

	# Failed persistence: no new tile faces or dust may escape.
	check(shuffle.prepare(buttons), "prepare failure-path board")
	await shuffle.play_gather()
	await shuffle.play_rotation()
	check(dust.total_emitted == 0, "no dust appears during gather or ring rotation")
	var refused: bool = await shuffle.play_scatter(new_faces, false)
	check(not refused, "failed save prevents visual reveal")
	check(dust.total_emitted == 0 and dust.puffs.is_empty(), "failed save emits no stone impacts")
	check(not dust.is_processing(), "failure leaves no dust processing overhead")
	check(buttons.all(func(t): return t.visible and t.texture_normal == old), "failed save restores original tiles")

	# Successful persistence: watch every arrival as real tween proceeds.
	check(shuffle.prepare(buttons), "prepare committed-board reveal")
	await shuffle.play_gather()
	await shuffle.play_rotation()
	var sample: Dictionary = {"saw": false, "max_emitted": 0, "max_live": 0, "max_processors": 0, "locations_valid": true}
	var destinations: Dictionary = {}
	for tile_index in Layout.SCATTER_DESTINATIONS:
		var tile: TextureButton = buttons[int(tile_index)]
		var contact: Vector2 = tile.position + Vector2(tile.size.x * 0.5, tile.size.y - 5.0)
		destinations[contact] = true
	var monitor: Callable = func() -> void:
		if not is_instance_valid(shuffle):
			return
		sample["max_emitted"] = maxi(int(sample["max_emitted"]), dust.total_emitted)
		sample["max_live"] = maxi(int(sample["max_live"]), dust.puffs.size())
		if not dust.puffs.is_empty():
			sample["saw"] = true
			if dust.is_processing():
				sample["max_processors"] = 1
		for puff in dust.puffs:
			if not destinations.has(puff["center"]):
				sample["locations_valid"] = false
	process_frame.connect(monitor)
	var ok: bool = await shuffle.play_scatter(new_faces, true)
	process_frame.disconnect(monitor)
	check(ok, "saved map finishes all slab landing effects")
	check(bool(sample["saw"]), "faint contact dust appears during live tween")
	check(int(sample["max_emitted"]) == 21, "each of 21 slabs emits one impact only")
	check(int(sample["max_live"]) <= StoneDust.MAX_PUFFS and int(sample["max_live"]) > 0, "simultaneous dust puffs stay within mobile budget")
	check(int(sample["max_processors"]) == 1, "dust processing is enabled only while visible")
	check(bool(sample["locations_valid"]), "all dust originates at genuine destination tile edges")
	check(dust.puffs.is_empty() and dust.total_emitted == 0 and not dust.is_processing(), "all impact visuals and counters cleaned after reveal")
	check(shuffle.tile_visuals.is_empty() and shuffle.tile_shadows.is_empty(), "no cloned tiles or shadows linger")
	check(buttons.all(func(t): return t.visible), "original gameplay tiles remain visible")
	check(die.texture_normal == old and die.position == Vector2(602, 307.6), "die position and visible result unchanged")

	shuffle.queue_free()
	stage.queue_free()
	print("MAP_SHUFFLE_STONE_DUST: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
