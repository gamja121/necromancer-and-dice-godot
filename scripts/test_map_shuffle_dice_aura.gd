extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_dice_aura.gd
## Verify dice glow timing, cleanup, save failures and untouched dice data.

const Layout = preload("res://systems/map_shuffle_layout.gd")
const Gather = preload("res://systems/map_shuffle_gather.gd")
const MapState = preload("res://systems/map_state.gd")
var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, name: String) -> void:
	if ok:
		passed += 1
		print("PASS shuffle-aura: ", name)
	else:
		failed += 1
		printerr("FAIL shuffle-aura: ", name)


func make_texture(color: Color) -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _run() -> void:
	var original: Texture2D = make_texture(Color(0.75, 0.70, 0.63))
	var stage := Control.new()
	stage.size = Vector2(1280, 720)
	root.add_child(stage)
	var buttons: Array = []
	var centers: Array = MapState.centers()
	for i in range(Layout.BOARD_TILE_COUNT):
		var tile := TextureButton.new()
		tile.ignore_texture_size = true
		tile.texture_normal = original
		tile.size = Layout.TILE_SIZE
		tile.position = centers[i] * Vector2(12.8, 7.2) - tile.size * 0.5
		tile.z_index = 4
		stage.add_child(tile)
		buttons.append(tile)
	var dice := TextureButton.new()
	dice.texture_normal = original
	dice.position = Vector2(602.0, 307.6)
	dice.size = Vector2(76.0, 76.0)
	dice.z_index = 19
	stage.add_child(dice)
	var dice_original_position: Vector2 = dice.position
	var next_tiles: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		next_tiles.append(original if i in Layout.FIXED_INDICES else make_texture(Color(float(i)/24.0, 0.4, 0.8)))

	var shuffle := Gather.new()
	stage.add_child(shuffle)
	check(shuffle.mouse_filter == Control.MOUSE_FILTER_IGNORE, "aura never catches mouse input")
	check(shuffle.z_index < dice.z_index, "glow stays behind real dice")
	check(shuffle.prepare(buttons), "original map accepted")
	check(is_zero_approx(shuffle.aura_strength), "aura initially invisible")
	await shuffle.play_rotation()
	check(is_zero_approx(shuffle.aura_strength), "rotation cannot start an aura without gathering")
	await shuffle.play_gather()
	check(shuffle.gathered and shuffle.aura_strength > 0.50, "subtle glow fades in while tiles gather")
	check(shuffle.aura_strength <= 1.0, "glow never exceeds opacity limit")
	await shuffle.play_rotation()
	check(shuffle.rotated and shuffle.aura_strength > 0.50, "glow stays visible during counter-rotation")
	check(dice.position == dice_original_position and dice.texture_normal == original, "dice position and face remain unchanged")
	var saved_ok: bool = await shuffle.play_scatter(next_tiles, true)
	check(saved_ok and is_zero_approx(shuffle.aura_strength), "glow fades out when new map lands")
	check(shuffle.tile_visuals.is_empty() and shuffle.tile_shadows.is_empty(), "all temporary tile visuals removed")
	check(buttons.all(func(tile): return tile.visible), "all tiles visible after reveal")

	check(shuffle.prepare(buttons), "new shuffle can start")
	await shuffle.play_gather()
	await shuffle.play_rotation()
	var refused: bool = await shuffle.play_scatter(next_tiles, false)
	check(not refused and is_zero_approx(shuffle.aura_strength), "save failure immediately removes aura")
	check(buttons.all(func(tile): return tile.visible), "failed save does not hide tiles")
	check(dice.position == dice_original_position and dice.texture_normal == original, "dice unchanged after failed save")
	shuffle.queue_free()
	stage.queue_free()
	print("MAP_SHUFFLE_DICE_AURA: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
