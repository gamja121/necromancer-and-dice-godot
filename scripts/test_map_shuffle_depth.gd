extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_depth.gd

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
		print("PASS shuffle-depth: ", label)
	else:
		failed += 1
		printerr("FAIL shuffle-depth: ", label)


func texture_for(color: Color) -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _run() -> void:
	var stage := Control.new()
	stage.size = Vector2(1280.0, 720.0)
	root.add_child(stage)
	var old_face := texture_for(Color.BEIGE)
	var buttons: Array = []
	var centers: Array = MapState.centers()
	for i in range(24):
		var node := TextureButton.new()
		node.ignore_texture_size = true
		node.texture_normal = old_face
		node.size = Layout.TILE_SIZE
		node.position = centers[i] * Vector2(12.8, 7.2) - node.size * 0.5
		stage.add_child(node)
		buttons.append(node)
	var dice := TextureButton.new()
	dice.texture_normal = old_face
	dice.position = Vector2(602, 307.6)
	dice.size = Vector2(76, 76)
	stage.add_child(dice)
	var shuffle := Gather.new()
	stage.add_child(shuffle)
	check(shuffle.prepare(buttons), "prepare existing 24 tile board")
	check(shuffle.tile_visuals.size() == 21 and shuffle.tile_shadows.size() == 21, "21 shadow silhouettes track 21 moving tile faces")
	var safe_shadows := true
	for i in range(shuffle.tile_visuals.size()):
		var shadow: TextureRect = shuffle.tile_shadows[i]
		var face: TextureRect = shuffle.tile_visuals[i]
		if shadow.get_parent() != face or not shadow.show_behind_parent:
			safe_shadows = false
		if shadow.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			safe_shadows = false
		if shadow.texture != old_face or shadow.position != Gather.SHADOW_OFFSET:
			safe_shadows = false
		if shadow.modulate.a <= 0.0 or shadow.modulate.a >= 0.5:
			safe_shadows = false
	check(safe_shadows, "silhouette shadows sit behind each tile, stay subtle and ignore input")
	await shuffle.play_gather()
	await shuffle.play_rotation()
	check(shuffle.rotated, "counter-rotation unaffected by depth layer")
	check(dice.position == Vector2(602, 307.6), "dice remains completely static")
	var fresh: Array = []
	for i in range(24):
		fresh.append(old_face if i in Layout.FIXED_INDICES else texture_for(Color(float(i) / 24.0, 0.5, 0.6)))
	# Observe the middle of the coroutine using a timer signal while
	# awaiting play_scatter normally (Godot 4 requires explicit await).
	var sample: Dictionary = {"ran":false, "faded":false, "synchronized":true, "anchored":true, "lifting":false}
	var probe_timer := create_timer(Gather.SCATTER_DURATION + Gather.FLIP_HALF_DURATION + 0.075)
	probe_timer.timeout.connect(func():
		sample["ran"] = true
		for i in range(shuffle.tile_shadows.size()):
			var shadow: TextureRect = shuffle.tile_shadows[i]
			var face: TextureRect = shuffle.tile_visuals[i]
			if shadow.modulate.a < Gather.SHADOW_TINT.a:
				sample["faded"] = true
			if face.texture != shadow.texture:
				sample["synchronized"] = false
			var target_index: int = int(Layout.SCATTER_DESTINATIONS[i])
			var board_y: float = buttons[target_index].position.y
			# Local offsets cancel the lift, so contact shadows do not
			# jump upward even while cards rebound in place.
			var contact_y: float = face.position.y + shadow.position.y
			if absf(contact_y - (board_y + Gather.SHADOW_OFFSET.y)) > 0.5:
				sample["anchored"] = false
			if face.position.y < board_y - 0.5:
				sample["lifting"] = true
	)
	var saved_ok: bool = await shuffle.play_scatter(fresh, true)
	check(bool(sample["ran"]), "landing motion sampled while active")
	check(bool(sample["faded"]), "contact shadow fades during landing")
	check(bool(sample["synchronized"]), "reveal texture and shadow silhouette stay in sync")
	check(bool(sample["anchored"]), "all contact shadows stay anchored during lift and bounce")
	check(bool(sample["lifting"]), "landing bounce produces visible upward displacement")
	check(saved_ok, "scatter and landing complete")
	check(shuffle.tile_shadows.is_empty() and shuffle.tile_visuals.is_empty(), "all temporary faces and shadows cleaned up")
	check(buttons.all(func(tile): return tile.visible), "all gameplay tile buttons visible")
	check(dice.texture_normal == old_face, "dice texture remains unchanged")
	stage.queue_free()
	print("MAP_SHUFFLE_DEPTH: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
