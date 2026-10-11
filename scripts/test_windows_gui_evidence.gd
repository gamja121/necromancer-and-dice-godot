extends SceneTree
## Optional GitHub-hosted WINDOWS graphical renderer capture, never PC approval.
## Running without --headless attempts actual Godot Windows GUI rendering.
## Output is restricted to the CI runner's temporary artifact directory.

const TITLE = preload("res://title.tscn")
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const STATE = preload("res://systems/map_state.gd")

var shots: int = 0
var failures: int = 0
var outdir: String = ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, note: String) -> void:
	if ok:
		print("PASS windows-gui-preview: ", note)
	else:
		failures += 1
		printerr("FAIL windows-gui-preview: ", note)

func capture_frame(filename: String) -> void:
	# SceneTree root is a real Window. Only the active graphical renderer
	# can return a valid pixel buffer; headless output cannot approve images.
	for i in range(6):
		await process_frame
	var tex: ViewportTexture = root.get_texture()
	if tex == null:
		check(false, filename + ": root viewport has no rendered texture")
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		check(false, filename + ": graphical pixel buffer unavailable")
		return
	var width: int = img.get_width()
	var height: int = img.get_height()
	check(width >= 1024 and height >= 576, filename + ": real window image has usable dimensions %dx%d" % [width, height])
	var sample_colors: Dictionary = {}
	for y in range(15):
		for x in range(25):
			var px: int = mini(width - 1, int((float(x) + 0.5) * width / 25.0))
			var py: int = mini(height - 1, int((float(y) + 0.5) * height / 15.0))
			sample_colors[img.get_pixel(px, py).to_html(false)] = true
	check(sample_colors.size() > 12, filename + ": rendered pixels contain scene variation, not a blank frame")
	var absolute_path: String = outdir.path_join(filename)
	var saved: Error = img.save_png(absolute_path)
	check(saved == OK and FileAccess.file_exists(absolute_path), filename + ": pixel evidence PNG saved")
	if saved == OK and FileAccess.file_exists(absolute_path):
		var bytes: int = FileAccess.get_file_as_bytes(absolute_path).size()
		check(bytes >= 16000, filename + ": nonempty PNG %d bytes" % bytes)
		if bytes >= 16000 and sample_colors.size() > 12:
			shots += 1

## Capture only after the actual Map ink-reveal animation has settled.
## These are render snapshots, not evidence of walking to or clicking a location.
func capture_settled_art(map: Control, expected_path: String, label: String, filename: String) -> void:
	await create_timer(1.1).timeout
	var art: TextureRect = null
	var expected: Texture2D = map.texture(expected_path)
	if is_instance_valid(map.overlay):
		for node in map.overlay.get_children():
			if node is TextureRect and node.texture == expected:
				art = node
				break
	check(art != null, label + ": production Map panel contains the expected art")
	if art != null:
		check(art.visible and art.size.x > 0.0 and art.size.y > 0.0,
			label + ": art is visible with positive dimensions")
		check(art.material == null,
			label + ": ink-reveal finished before the final screenshot")
		check(art.position.x >= 0.0 and art.position.y >= 0.0
			and art.position.x + art.size.x <= 1280.0
			and art.position.y + art.size.y <= 720.0,
			label + ": art bounds remain inside the native 1280x720 window")
	await capture_frame(filename)

func visible_button(panel: Control, label: String) -> bool:
	if not is_instance_valid(panel):
		return false
	for node in panel.get_children():
		if node is Button and node.text == label and node.visible:
			return true
	return false

func _run() -> void:
	outdir = OS.get_environment("WINDOWS_GUI_EVIDENCE_DIR")
	check(OS.get_name() == "Windows", "running a native Windows Godot executable")
	var display_driver: String = DisplayServer.get_name()
	print("WINDOWS_GUI_DISPLAY_DRIVER: ", display_driver)
	check(display_driver.to_lower() == "windows", "real Windows GUI display driver, not headless")
	check(not outdir.is_empty(), "CI provided a dedicated external evidence directory")
	if failures > 0:
		print("WINDOWS_GUI_PREVIEW: %d captured, %d failed; manual review remains required" % [shots, failures])
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(outdir) == OK, "dedicated screenshot artifact folder prepared")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var existing_session: Node = root.get_node_or_null("RunSession")
	var created: bool = existing_session == null
	var session: Node = existing_session
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var old_path: String = session.save_file_path
	var temp_save: String = "user://windows_ci_preview_%d.json" % OS.get_process_id()
	var temp_audio: String = "user://windows_ci_preview_audio_%d.cfg" % OS.get_process_id()
	session.save_file_path = temp_save
	var title: Control = TITLE.instantiate()
	title.set("audio_save_path", temp_audio)
	root.add_child(title)
	current_scene = title
	await capture_frame("01_title_native_windows.png")
	current_scene = null
	root.remove_child(title)
	title.queue_free()
	await process_frame
	session.start_new_world()
	var map: Control = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	check(session.world.tiles[STATE.HOME] == "home" and map.buttons.size() == 24, "real game map and 24 original tiles initialized")
	await capture_frame("02_map_native_windows.png")
	map.show_home(true)
	await capture_frame("03_home_interior_native_windows.png")
	map.close_overlay()
	map.show_location(0)
	# A settled first view is required; a transition frame can hide real art.
	await capture_settled_art(map, "res://assets/map/events/fortune-teller.jpg",
		"fortune-teller location", "04_fortune_teller_native_windows.png")
	map.close_overlay()
	map.show_home(false)
	await capture_settled_art(map, "res://assets/map/events/home.jpg",
		"home exterior", "05_home_exterior_native_windows.png")
	map.close_overlay()
	# These six production panels plus the fortune-teller form the seven
	# location types. Keep the original 24-tile board and player state intact.
	var locations: Array[Dictionary] = [
		{"tile":"village", "filename":"06_village_native_windows.png"},
		{"tile":"graveyard", "filename":"07_graveyard_native_windows.png"},
		{"tile":"altar", "filename":"08_altar_native_windows.png"},
		{"tile":"unknown", "filename":"09_world_tree_native_windows.png"},
		{"tile":"forest", "filename":"10_forest_native_windows.png"},
		{"tile":"rest", "filename":"11_rest_native_windows.png"}
	]
	for entry in locations:
		var tile_type: String = str(entry["tile"])
		var index: int = map.world.tiles.find(tile_type)
		check(index >= 0, tile_type + ": location exists on the original generated board")
		if index < 0:
			continue
		map.show_location(index)
		var art_path: String = "res://assets/map/events/%s.jpg" % str(map.EVENT_IMAGES[tile_type])
		await capture_settled_art(map, art_path, tile_type, str(entry["filename"]))
		map.close_overlay()
	# Test-only preview states use a disposable save. These screenshots are
	# NOT proof of naturally playing the story, defeating enemies, or collecting cards.
	var grave_index: int = session.world.tiles.find("graveyard")
	check(grave_index >= 0, "graveyard story preview: original generated tile found")
	if grave_index >= 0:
		session.world.position = grave_index
		check(session.save_world(), "graveyard story preview: disposable save checkpoint")
		map.show_graveyard_child_beat(grave_index, 0)
		check(visible_button(map.overlay, "계속"), "graveyard first scene: Continue button visible")
		await capture_settled_art(map,
			"res://assets/map/events/graveyard-child-base-v3.webp",
			"graveyard child scene", "12_graveyard_child_story_native_windows.png")
		map.show_graveyard_child_beat(grave_index, 3)
		check(visible_button(map.overlay, "아이를 구한다")
			and visible_button(map.overlay, "지나친다"),
			"graveyard story choice: both original choices visible")
		await capture_frame("13_graveyard_story_choice_native_windows.png")
		map.close_overlay()
	var monster_index: int = session.world.tiles.find("monster")
	check(monster_index >= 0, "battle preview: ordinary monster tile found")
	if monster_index >= 0:
		session.world.position = monster_index
		check(session.save_world(), "battle preview: disposable save checkpoint")
		map.show_battle_deck(monster_index)
		await create_timer(1.0).timeout
		var deck: Control = map.overlay
		var is_deck: bool = (is_instance_valid(deck) and deck.get_script() != null
			and deck.get_script().resource_path.ends_with("battle_deck.gd"))
		check(is_deck, "battle deck: real selection panel opened")
		if is_deck:
			var first_id: String = str(session.world.roster[0].id)
			deck.toggle_unit(first_id)
			check(deck.selected_ids.size() == 1 and not deck.confirm_button.disabled,
				"battle deck: one owned monster selected and start button enabled")
			await capture_frame("14_battle_deck_native_windows.png")
			map.close_overlay()
			var started: bool = session.start_encounter(monster_index, [first_id])
			check(started, "battle preview: original RunSession encounter starts with owned monster")
			if started:
				map.open_embedded_battle(false)
				await create_timer(0.8).timeout
				var battle: Control = map.embedded_battle
				check(is_instance_valid(battle) and battle.rules != null
					and battle.rules.units.size() >= 2,
					"embedded battlefield: original active allies and enemies visible")
				await capture_frame("15_embedded_battle_native_windows.png")
	current_scene = null
	root.remove_child(map)
	map.queue_free()
	await process_frame
	# An entirely new disposable run isolates the chest from the battle.
	session.start_new_world()
	var chest_index: int = session.world.tiles.find("gem")
	check(chest_index >= 0, "reward preview: genuine treasure tile found")
	var sample_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var normal_chest_seed_found: bool = false
	for seed_value in range(1, 250):
		sample_rng.seed = seed_value
		if sample_rng.randf() >= 0.10:
			session.world.rng.seed = seed_value
			normal_chest_seed_found = true
			break
	check(normal_chest_seed_found, "reward preview: reproducible regular chest seed found")
	if chest_index >= 0 and normal_chest_seed_found:
		session.world.position = chest_index
		check(session.save_world(), "reward preview: disposable checkpoint saved")
		var reward_map: Control = MAP.instantiate()
		root.add_child(reward_map)
		current_scene = reward_map
		reward_map.show_treasure(chest_index)
		await create_timer(2.0).timeout
		var reward_panel: Control = reward_map.overlay
		var is_reward: bool = (is_instance_valid(reward_panel) and reward_panel.get_script() != null
			and reward_panel.get_script().resource_path.ends_with("treasure_reward.gd"))
		check(is_reward, "reward preview: original TreasureReward panel opened")
		if is_reward:
			check(session.world.pending_reward.get("kind", "") == "treasure"
				and reward_panel.options.size() == 3 and not reward_panel.busy,
				"reward preview: exactly three selectable reward cards shown")
			await capture_frame("16_treasure_card_choice_native_windows.png")
		current_scene = null
		root.remove_child(reward_map)
		reward_map.queue_free()
		await process_frame
	session.save_file_path = old_path
	if created:
		root.remove_child(session)
		session.queue_free()
	for path in [temp_save, temp_save + ".tmp", temp_audio]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(not FileAccess.file_exists(temp_save), "disposable CI save removed; no player save changed")
	print("WINDOWS_GUI_PREVIEW: %d captured, %d failed; manual review remains required" % [shots, failures])
	quit(0 if shots == 16 and failures == 0 else 1)
