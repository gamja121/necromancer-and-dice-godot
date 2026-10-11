extends SceneTree
## Stone shuffle step 1: each of 21 slabs must fall without bouncing,
## changing dimensions beyond 100% or lifting its contact shadow.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_stone_landing.gd

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
		print("PASS stone-landing: ", label)
	else:
		failed += 1
		printerr("FAIL stone-landing: ", label)


func make_texture(color: Color) -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _run() -> void:
	var stage := Control.new()
	stage.size = Vector2(1280.0, 720.0)
	root.add_child(stage)
	var source_face: Texture2D = make_texture(Color(0.5, 0.45, 0.4))
	var tiles: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		var tile := TextureButton.new()
		tile.texture_normal = source_face
		tile.ignore_texture_size = true
		tile.size = Layout.TILE_SIZE
		tile.position = MapState.centers()[i] * Vector2(12.8, 7.2) - tile.size * 0.5
		stage.add_child(tile)
		tiles.append(tile)
	var die := TextureButton.new()
	die.texture_normal = source_face
	die.size = Vector2(76.0, 76.0)
	die.position = Vector2(602.0, 307.6)
	stage.add_child(die)
	var next_faces: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		next_faces.append(source_face if i in Layout.FIXED_INDICES else make_texture(Color(float(i) / 24.0, 0.45, 0.4)))
	var shuffle := Gather.new()
	stage.add_child(shuffle)
	check(shuffle.prepare(tiles), "24-tile board prepared")
	await shuffle.play_gather()
	await shuffle.play_rotation()
	check(shuffle.gathered and shuffle.rotated, "both rings still counter-rotate")

	# A live frame-by-frame check is stronger than a code/string assertion:
	# detect rubber-like overshoot and upward movement while landing.
	var probe: Dictionary = {"frames": 0, "downward_only": true, "no_overshoot": true, "no_elastic_scale": true, "contact_shadow": true, "raised": false}
	var prior_y: Array = []
	for i in range(shuffle.tile_visuals.size()):
		prior_y.append(-1000000.0)
	var monitor: Callable = func() -> void:
		if shuffle.reveal_tween == null or shuffle.tile_visuals.size() != Layout.INNER_COUNT + Layout.OUTER_COUNT:
			return
		probe["frames"] = int(probe["frames"]) + 1
		for i in range(shuffle.tile_visuals.size()):
			var face: TextureRect = shuffle.tile_visuals[i]
			var shadow: TextureRect = shuffle.tile_shadows[i]
			var destination_index: int = int(Layout.SCATTER_DESTINATIONS[i])
			var ground_y: float = tiles[destination_index].position.y
			var current_y: float = face.position.y
			if current_y < ground_y - 0.5:
				probe["raised"] = true
			if current_y < float(prior_y[i]) - 0.20:
				probe["downward_only"] = false
			if current_y > ground_y + 0.20:
				probe["no_overshoot"] = false
			if face.scale.x > 1.005 or face.scale.y > 1.005:
				probe["no_elastic_scale"] = false
			if absf(face.position.y + shadow.position.y - ground_y - Gather.SHADOW_OFFSET.y) > 0.8:
				probe["contact_shadow"] = false
			prior_y[i] = current_y
	process_frame.connect(monitor)
	var finished: bool = await shuffle.play_scatter(next_faces, true)
	process_frame.disconnect(monitor)
	check(finished, "successful saved map fully revealed")
	check(int(probe["frames"]) > 2, "multiple real landing frames sampled")
	check(bool(probe["raised"]), "4-pixel stone drop remains visible")
	check(bool(probe["downward_only"]), "all slabs move downward without rebound")
	check(bool(probe["no_overshoot"]), "all stone slabs stop exactly at board surface")
	check(bool(probe["no_elastic_scale"]), "flip reveal never rubber-stretches beyond 100%")
	check(bool(probe["contact_shadow"]), "stone contact shadow stays grounded")
	check(shuffle.tile_visuals.is_empty() and shuffle.tile_shadows.is_empty(), "temporary slabs and shadows cleaned")
	check(tiles.all(func(t): return t.visible), "all gameplay tiles restored and visible")
	check(die.position == Vector2(602.0, 307.6) and die.texture_normal == source_face, "central die remains untouched")
	stage.queue_free()
	print("MAP_SHUFFLE_STONE_LANDING: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
