extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_rotation.gd

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
		print("PASS map-rotation: ", label)
	else:
		failed += 1
		printerr("FAIL map-rotation: ", label)


## Every tween frame must keep tiles separated from each other and the dice.
func orbit_geometry_safe(slots: Array[Dictionary]) -> bool:
	var board := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	var dice_rect := Rect2(Vector2(602.0, 307.6), Vector2(76.0, 76.0))
	for frame in range(361):
		var progress: float = float(frame) / 360.0
		var rectangles: Array[Rect2] = []
		for slot in slots:
			var extent: Vector2 = Layout.TILE_SIZE * float(slot["scale"])
			var rect := Rect2(Layout.orbit_position(slot, progress) - extent * 0.5, extent)
			if not board.encloses(rect) or rect.intersects(dice_rect):
				return false
			for other in rectangles:
				if rect.intersects(other):
					return false
			rectangles.append(rect)
	return true


func clockwise_on_screen(slot: Dictionary) -> bool:
	var a: Vector2 = Layout.orbit_position(slot, 0.0) - Layout.DICE_CENTER
	var b: Vector2 = Layout.orbit_position(slot, 0.02) - Layout.DICE_CENTER
	return a.cross(b) > 0.0


func _run() -> void:
	var stage := Control.new()
	stage.size = Vector2(1280.0, 720.0)
	root.add_child(stage)
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var buttons: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		var tile := TextureButton.new()
		tile.texture_normal = texture
		tile.ignore_texture_size = true
		tile.size = Layout.TILE_SIZE
		tile.position = MapState.centers()[i] * Vector2(12.8, 7.2) - tile.size * 0.5
		tile.z_index = 4
		stage.add_child(tile)
		buttons.append(tile)
	var dice := TextureButton.new()
	dice.texture_normal = texture
	dice.size = Vector2(76.0, 76.0)
	dice.position = Vector2(602.0, 307.6)
	dice.z_index = 19
	stage.add_child(dice)
	var original_dice_position: Vector2 = dice.position
	var gather := Gather.new()
	stage.add_child(gather)
	check(gather.prepare(buttons), "prepare temporary tiles")
	await gather.play_rotation()
	check(not gather.rotated, "rotation cannot start before gathering")
	await gather.play_gather()
	check(gather.gathered, "gathering has completed")
	check(gather.tile_visuals.size() == 21, "all 21 visuals retained")
	var inner_slot: Dictionary = gather.slots[0]
	var outer_slot: Dictionary = gather.slots[Layout.INNER_COUNT]
	check(clockwise_on_screen(inner_slot), "inner ring rotates clockwise")
	check(not clockwise_on_screen(outer_slot), "outer ring rotates counterclockwise")
	check(orbit_geometry_safe(gather.slots), "361 rotation samples: no overlapping tiles or dice")
	var initial_scale: Array[Vector2] = []
	for visual in gather.tile_visuals:
		initial_scale.append(visual.scale)
	await gather.play_rotation()
	check(gather.rotated, "rotation tween finished")
	var final_positions_ok := true
	var upright_and_scaled := true
	var faces_unchanged := true
	for i in range(gather.tile_visuals.size()):
		var visual: TextureRect = gather.tile_visuals[i]
		var target: Vector2 = Layout.orbit_position(gather.slots[i], 1.0) - visual.size * 0.5
		if visual.position.distance_to(target) > 0.2:
			final_positions_ok = false
		if absf(visual.rotation) > 0.001 or visual.scale.distance_to(initial_scale[i]) > 0.001:
			upright_and_scaled = false
		if visual.texture != texture:
			faces_unchanged = false
	check(final_positions_ok, "all tiles finish at exact rotated ring slots")
	check(upright_and_scaled, "tile faces remain upright and scales remain steady")
	check(faces_unchanged, "rotation does not reveal or change tile images")
	check(dice.position == original_dice_position and dice.visible, "dice stays still and visible")
	var fixed_ok := true
	for index in Layout.FIXED_INDICES:
		if not buttons[index].visible:
			fixed_ok = false
	check(fixed_ok, "home, village, and fortune teller remain visible")
	await gather.play_rotation()
	check(final_positions_ok and gather.rotated, "repeated rotation request is ignored")
	gather.restore_tiles()
	check(buttons.all(func(tile): return tile.visible), "all map tiles restored")
	check(gather.tile_visuals.is_empty() and not gather.rotated and not gather.gathered, "visual and state cleanup")
	print("MAP_SHUFFLE_ROTATION: %d passed, %d failed" % [passed, failed])
	stage.queue_free()
	quit(0 if failed == 0 else 1)
