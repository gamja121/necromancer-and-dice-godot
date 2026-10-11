extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_scatter.gd

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
		print("PASS map-scatter: ", label)
	else:
		failed += 1
		printerr("FAIL map-scatter: ", label)


func new_texture(color: Color) -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func make_board(stage: Control, base: Texture2D) -> Array:
	var buttons: Array = []
	var centers: Array = MapState.centers()
	for i in range(Layout.BOARD_TILE_COUNT):
		var tile := TextureButton.new()
		tile.ignore_texture_size = true
		tile.texture_normal = base
		tile.size = Layout.TILE_SIZE
		tile.position = centers[i] * Vector2(12.8, 7.2) - tile.size * 0.5
		tile.z_index = 4
		stage.add_child(tile)
		buttons.append(tile)
	return buttons


func destinations_are_safe() -> bool:
	var slots: Array[Dictionary] = Layout.ring_slots()
	var choices: Array = Layout.SCATTER_DESTINATIONS
	if choices.size() != slots.size():
		return false
	var board: Array = MapState.centers()
	var dice_rect := Rect2(Vector2(602, 307.6), Vector2(76, 76))
	var frame: Rect2 = Rect2(Vector2.ZERO, Vector2(1280, 720))
	for sample in range(401):
		var t: float = float(sample) / 400.0
		var eased: float = 0.5 - cos(PI * t) * 0.5
		var rects: Array[Rect2] = []
		for i in range(slots.size()):
			var start: Vector2 = Layout.orbit_position(slots[i], 1.0)
			var finish: Vector2 = board[int(choices[i])] * Vector2(12.8, 7.2)
			var tile_center: Vector2 = start.lerp(finish, eased)
			var scaled_size: Vector2 = Layout.TILE_SIZE * float(slots[i]["scale"])
			var rect := Rect2(tile_center - scaled_size * 0.5, scaled_size)
			if not frame.encloses(rect) or rect.intersects(dice_rect):
				return false
			for other in rects:
				if rect.intersects(other):
					return false
			rects.append(rect)
	return true


func _run() -> void:
	var old_texture := new_texture(Color(0.2, 0.3, 0.4))
	var next_textures: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		next_textures.append(old_texture if i in Layout.FIXED_INDICES else new_texture(Color(float(i) / 24.0, 0.3, 0.7)))
	var targets: Array = Layout.SCATTER_DESTINATIONS
	var unique: Dictionary = {}
	for index in targets:
		unique[int(index)] = true
	check(targets.size() == 21 and unique.size() == 21, "21 unique scatter destinations")
	var all_movable := true
	for index in MapState.centers().size():
		if (index in Layout.FIXED_INDICES) == unique.has(index):
			all_movable = false
	check(all_movable, "fixed locations excluded, all other board locations covered")
	check(destinations_are_safe(), "401 scatter samples without dice/slot collision")

	var stage := Control.new()
	stage.size = Vector2(1280, 720)
	root.add_child(stage)
	var tiles := make_board(stage, old_texture)
	var dice := TextureButton.new()
	dice.texture_normal = old_texture
	dice.size = Vector2(76, 76)
	dice.position = Vector2(602, 307.6)
	dice.z_index = 19
	stage.add_child(dice)
	var gather := Gather.new()
	stage.add_child(gather)
	check(gather.prepare(tiles), "prepare board for unsuccessful save case")
	await gather.play_gather()
	await gather.play_rotation()
	var failed_save: bool = await gather.play_scatter(next_textures, false)
	check(not failed_save, "save failure refuses to reveal new board")
	check(tiles.all(func(tile): return tile.texture_normal == old_texture and tile.visible), "failed save restores all original tile images")
	check(gather.tile_visuals.is_empty(), "failed save frees temporary visuals")

	check(gather.prepare(tiles), "prepare board again for successful save")
	var premature: bool = await gather.play_scatter(next_textures, true)
	check(not premature, "scatter forbidden before rotation")
	await gather.play_gather()
	await gather.play_rotation()
	var invalid: Array = next_textures.duplicate()
	invalid[8] = new_texture(Color.RED)
	var rejected: bool = await gather.play_scatter(invalid, true)
	check(not rejected, "fixed village texture cannot change")
	check(tiles.all(func(tile): return tile.texture_normal == old_texture and tile.visible), "invalid imagery leaves original board intact")
	check(gather.prepare(tiles), "prepare valid persisted board")
	await gather.play_gather()
	await gather.play_rotation()
	var saved_ok: bool = await gather.play_scatter(next_textures, true)
	check(saved_ok, "successful persistence unlocks scatter and flip")
	var face_ok := true
	for i in range(tiles.size()):
		if tiles[i].texture_normal != next_textures[i] or not tiles[i].visible:
			face_ok = false
	check(face_ok, "all 24 final tiles match saved board and are visible")
	check(gather.tile_visuals.is_empty() and not gather.rotated, "completion restores temporary state")
	check(dice.position == Vector2(602, 307.6) and dice.texture_normal == old_texture, "dice remains completely unchanged")
	print("MAP_SHUFFLE_SCATTER: %d passed, %d failed" % [passed, failed])
	stage.queue_free()
	quit(0 if failed == 0 else 1)
