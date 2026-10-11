extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_gather.gd

const Layout = preload("res://systems/map_shuffle_layout.gd")
const Gather = preload("res://systems/map_shuffle_gather.gd")
var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS map-gather: ", label)
	else:
		failed += 1
		printerr("FAIL map-gather: ", label)


func _run() -> void:
	var stage := Control.new()
	stage.size = Vector2(1280, 720)
	root.add_child(stage)
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var buttons: Array = []
	var centers: Array = preload("res://systems/map_state.gd").centers()
	for i in range(Layout.BOARD_TILE_COUNT):
		var button := TextureButton.new()
		button.ignore_texture_size = true
		button.texture_normal = texture
		button.size = Layout.TILE_SIZE
		button.position = centers[i] * Vector2(12.8, 7.2) - button.size * 0.5
		button.z_index = 4
		stage.add_child(button)
		buttons.append(button)
	var dice := TextureButton.new()
	dice.texture_normal = texture
	dice.position = Vector2(602.0, 307.6)
	dice.size = Vector2(76.0, 76.0)
	dice.z_index = 19
	stage.add_child(dice)
	var gather := Gather.new()
	stage.add_child(gather)
	check(not gather.prepare(buttons.slice(0, 23)), "reject incomplete board without modifications")
	check(buttons.all(func(button): return button.visible), "invalid prepare keeps original tiles visible")
	check(gather.prepare(buttons), "prepare complete board")
	check(gather.tile_visuals.size() == 21, "create 21 distinct temporary visuals")
	check(gather.z_index < dice.z_index, "dice remains above gathered tile visuals")
	for fixed_index in Layout.FIXED_INDICES:
		check(buttons[fixed_index].visible, "fixed index %d remains visible" % fixed_index)
	var moving_hidden := true
	for tile_index in Layout.moving_indices():
		if buttons[tile_index].visible:
			moving_hidden = false
	check(moving_hidden, "original moving tiles hidden during animation")
	await gather.play_gather()
	var positions_ok := true
	var sizes_ok := true
	for i in range(gather.tile_visuals.size()):
		var visual: TextureRect = gather.tile_visuals[i]
		var slot: Dictionary = gather.slots[i]
		var target: Vector2 = Layout.orbit_position(slot, 0.0) - visual.size * 0.5
		if visual.position.distance_to(target) > 0.2:
			positions_ok = false
		if visual.scale.distance_to(Vector2.ONE * float(slot["scale"])) > 0.01:
			sizes_ok = false
	check(positions_ok, "all 21 gathered at designated nonoverlapping slots")
	check(sizes_ok, "all 21 gather to intended ring scales")
	check(dice.position == Vector2(602.0, 307.6), "dice position never changes")
	check(dice.visible, "dice remains visible")
	gather.restore_tiles()
	check(gather.tile_visuals.is_empty(), "temporary visual references released")
	check(buttons.all(func(button): return button.visible), "all original tiles restored")
	print("MAP_SHUFFLE_GATHER: %d passed, %d failed" % [passed, failed])
	stage.queue_free()
	quit(0 if failed == 0 else 1)
