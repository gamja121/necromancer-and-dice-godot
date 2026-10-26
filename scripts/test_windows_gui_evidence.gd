extends SceneTree
## Optional GitHub-hosted WINDOWS graphical renderer capture, never PC approval.
## Running without --headless attempts actual Godot Windows GUI rendering.
## Output is restricted to the CI runner's temporary artifact directory.

const TITLE = preload("res://title.tscn")
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const STATE = preload("res://systems/map_state.gd")
const COMMANDER = preload("res://systems/knight_commander_entry.gd")
const COMMANDER_BEATS = preload("res://systems/knight_commander_beats.gd")
const HUNTER = preload("res://systems/monster_hunter_entry.gd")
const HUNTER_BEATS = preload("res://systems/monster_hunter_beats.gd")
const CULTIST = preload("res://systems/cultist_rumor_entry.gd")
const CULTIST_BEATS = preload("res://systems/cultist_rumor_beats.gd")
const ALTAR = preload("res://systems/cultist_altar_entry.gd")
const PORTAL = preload("res://systems/ritual_portal_entry.gd")

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
	check(width == 1280 and height == 720, filename + ": native image is exactly 1280x720, got %dx%d" % [width, height])
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
	if is_instance_valid(map.overlay) and map.overlay.get_script()==map.StoryBook:
		await create_timer(1.7).timeout
		map.overlay.typewriter.reveal_all()
	await create_timer(1.1).timeout
	var art: TextureRect = null
	var expected: Texture2D = map.texture(expected_path)
	if is_instance_valid(map.overlay):
		for node in map.overlay.find_children("*","TextureRect",true,false):
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
	# The first production board deliberately hides graveyard, altar,
	# world-tree and rest until later unlocks. A screenshot fixture may place
	# their existing scenes on ordinary road tiles in THIS disposable save only.
	# Never change MapState generation, user saves or the actual unlock rules.
	for missing_place in ["graveyard","altar","unknown","forest","rest"]:
		if not session.world.tiles.has(missing_place):
			var ordinary: int = session.world.tiles.find("basic")
			check(ordinary >= 0, "visual-only board has a spare road for " + missing_place)
			if ordinary >= 0:
				session.world.tiles[ordinary] = missing_place
	check(session.save_world(), "16-shot visual gallery board saved into disposable CI path")
	# These six production panels plus the fortune-teller form the seven
	# location types. Newly gated tiles are only present in the CI preview.
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
			preload("res://systems/graveyard_story_beats.gd").BASE_ART,
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
	# Dedicated layer gallery for end-user art/composition acceptance.
	# Build a temporary *internally consistent* mid-story save and render the
	# real show_* scene functions. These aren't claims of natural gameplay.
	session.start_new_world()
	for missing_place in ["graveyard","altar","unknown"]:
		if not session.world.tiles.has(missing_place):
			var ordinary: int = session.world.tiles.find("basic")
			check(ordinary >= 0, "story gallery can place " + missing_place)
			if ordinary >= 0:
				session.world.tiles[ordinary] = missing_place
	session.world.contamination = 100
	session.world.reveal_boss_at_threshold()
	session.world.reveal_swamps_for_contamination()
	# The fixed boss slot might have replaced this run's only forest.
	# A CI gallery needs its portal location regardless of shuffled art slots.
	if not session.world.tiles.has("forest"):
		var spare_road: int = session.world.tiles.find("basic")
		check(spare_road >= 0,"story gallery can restore the forest scene")
		if spare_road >= 0: session.world.tiles[spare_road] = "forest"
	# This visual gallery starts AFTER a separately completed child rescue and
	# rescued-child rumor. Only this test save has the setup state.
	session.world.story_events["graveyard_child_ambush_01"] = {"status":"complete","choice":"protect_child","battle_result":"won"}
	session.world.event_flags["event:graveyard_child_ambush_01:complete"] = true
	session.world.event_flags["event:graveyard_child_ambush_01:rescued"] = true
	session.world.story_events["rumor_saved_child_01"] = {"status":"complete","choice":"","battle_result":""}
	session.world.event_flags["event:rumor_saved_child_01:seen"] = true
	session.world.event_flags["event:rumor_saved_child_01:complete"] = true
	var village_index: int = session.world.tiles.find("village")
	var tree_index: int = session.world.tiles.find("unknown")
	var altar_index: int = session.world.tiles.find("altar")
	var forest_index: int = session.world.tiles.find("forest")
	check(village_index >= 0 and tree_index >= 0 and altar_index >= 0 and forest_index >= 0,
		"test-only story gallery contains all four canonical story locations")
	session.world.position = village_index
	check(session.save_world(), "layered-story preview prerequisites saved only to CI")
	var gallery_map: Control = MAP.instantiate()
	root.add_child(gallery_map)
	current_scene = gallery_map
	check(COMMANDER.begin(session,village_index), "actual commander event opens with consistent visual fixture flags")
	gallery_map.show_knight_commander_beat(village_index)
	await capture_settled_art(gallery_map, COMMANDER.ART, "commander figure",
		"17_commander_layer_native_windows.png")
	for i in range(2):
		check(COMMANDER.advance(session,village_index,i), "commander visual advance %d" % i)
	gallery_map.show_knight_commander_beat(village_index)
	check(is_instance_valid(gallery_map.overlay)
		and gallery_map.overlay.find_child("PlayerStoryPortrait",true,false) is TextureRect,
		"commander player reply uses actual left portrait")
	await capture_settled_art(gallery_map, COMMANDER.ART, "commander player reply",
		"18_commander_reply_layer_native_windows.png")
	for i in range(2,COMMANDER_BEATS.count()):
		check(COMMANDER.advance(session,village_index,i), "commander source completion %d" % i)
	session.world.position = tree_index
	check(HUNTER.begin(session,tree_index), "actual hunter encounter eligible after commander completion")
	check(HUNTER.advance(session,tree_index,0), "hunter revealed-scene beat selected")
	gallery_map.show_monster_hunter_beat(tree_index)
	check(is_instance_valid(gallery_map.overlay)
		and gallery_map.overlay.find_child("HunterSceneLayer",true,false) is TextureRect,
		"hunter beast layer exists in real live overlay")
	await capture_settled_art(gallery_map, HUNTER.BASE_ART, "hunter beast scene",
		"19_hunter_beast_layer_native_windows.png")
	for i in range(1,3):
		check(HUNTER.advance(session,tree_index,i), "hunter portrait preparation %d" % i)
	gallery_map.show_monster_hunter_beat(tree_index)
	check(is_instance_valid(gallery_map.overlay)
		and gallery_map.overlay.find_child("HunterPortrait",true,false) is TextureRect,
		"hunter human portrait uses real overlay layer")
	await capture_settled_art(gallery_map, HUNTER.BASE_ART, "hunter portrait scene",
		"20_hunter_portrait_layer_native_windows.png")
	for i in range(3,HUNTER_BEATS.count()):
		check(HUNTER.advance(session,tree_index,i), "hunter source completion %d" % i)
	session.world.position = village_index
	check(CULTIST.begin(session,village_index), "cultist rumor eligible after finished hunter story")
	check(CULTIST.advance(session,village_index,0), "cultist procession beat selected")
	gallery_map.show_cultist_rumor_beat(village_index)
	check(is_instance_valid(gallery_map.overlay)
		and gallery_map.overlay.find_child("CultistProcessionLayer",true,false) is TextureRect,
		"cultist procession layer exists in real UI")
	await capture_settled_art(gallery_map, CULTIST.BASE_ART, "cultist procession",
		"21_cultist_procession_layer_native_windows.png")
	for i in range(1,CULTIST_BEATS.count()):
		check(CULTIST.advance(session,village_index,i), "cultist rumor completion %d" % i)
	session.world.position = altar_index
	check(ALTAR.begin(session,altar_index), "cultist altar eligible after finished rumor")
	check(ALTAR.advance(session,altar_index,0), "altar ritual reveal beat selected")
	gallery_map.show_cultist_altar_beat(altar_index)
	check(is_instance_valid(gallery_map.overlay)
		and gallery_map.overlay.find_child("CultistRitualLayer",true,false) is TextureRect,
		"altar ritual layer exists in real UI")
	await capture_settled_art(gallery_map, ALTAR.BASE_ART, "altar ritual layer",
		"22_altar_ritual_layer_native_windows.png")
	check(ALTAR.advance(session,altar_index,1), "altar final choice reached explicitly")
	check(ALTAR.choose(session,altar_index,2,"pass"), "gallery chooses canonical peaceful altar path")
	check(ALTAR.finish(session,altar_index), "test-only altar quest advances to ritual tracking")
	session.world.position = forest_index
	check(PORTAL.begin(session,forest_index), "real portal event eligible after finished altar")
	check(PORTAL.advance(session,forest_index,0), "portal energy beat selected")
	gallery_map.show_ritual_portal_beat(forest_index)
	check(is_instance_valid(gallery_map.overlay)
		and gallery_map.overlay.find_child("PortalEnergyLayer",true,false) is TextureRect,
		"portal energy artwork uses live layered panel")
	await capture_settled_art(gallery_map, PORTAL.BASE_ART, "portal energy layer",
		"23_portal_energy_layer_native_windows.png")
	for i in range(1,3):
		check(PORTAL.advance(session,forest_index,i), "portal omen preparation %d" % i)
	gallery_map.show_ritual_portal_beat(forest_index)
	check(is_instance_valid(gallery_map.overlay)
		and gallery_map.overlay.find_child("PortalOmenLayer",true,false) is TextureRect,
		"portal omen artwork uses live layered panel")
	await capture_settled_art(gallery_map, PORTAL.BASE_ART, "portal omen layer",
		"24_portal_omen_layer_native_windows.png")
	current_scene = null
	root.remove_child(gallery_map)
	gallery_map.queue_free()
	await process_frame
	# No story preview can modify the user save: the only writable path has
	# been a process-local throwaway file since the start of this script.
	session.save_file_path = old_path
	if created:
		root.remove_child(session)
		session.queue_free()
	for path in [temp_save, temp_save + ".tmp", temp_audio]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(not FileAccess.file_exists(temp_save), "disposable CI save removed; no player save changed")
	print("WINDOWS_GUI_PREVIEW: %d captured, %d failed; manual review remains required" % [shots, failures])
	quit(0 if shots == 24 and failures == 0 else 1)
