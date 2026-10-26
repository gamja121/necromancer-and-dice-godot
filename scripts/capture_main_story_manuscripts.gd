extends SceneTree
## Optional native visual QA for the seven approved manuscript replacements.
## Disposable high-contamination/road fixtures shorten travel only. Screenshots
## are production render evidence, not natural gameplay or balance approval.
## Usage: --script res://scripts/capture_main_story_manuscripts.gd -- --screenshots=<absolute directory>
const MAP = preload("res://map.tscn")
const BOOK = preload("res://systems/main_story_book.gd")
const CHILD = preload("res://systems/story_event_entry.gd")
const RUMOR = preload("res://systems/village_rumor_entry.gd")
const RUMOR_BEATS = preload("res://systems/village_rumor_beats.gd")
const COMMANDER = preload("res://systems/knight_commander_entry.gd")
const COMMANDER_BEATS = preload("res://systems/knight_commander_beats.gd")
const HUNTER = preload("res://systems/monster_hunter_entry.gd")
const HUNTER_BEATS = preload("res://systems/monster_hunter_beats.gd")
const CULTIST = preload("res://systems/cultist_rumor_entry.gd")
const CULTIST_BEATS = preload("res://systems/cultist_rumor_beats.gd")
const ALTAR = preload("res://systems/cultist_altar_entry.gd")
const ALTAR_BEATS = preload("res://systems/cultist_altar_beats.gd")
const PORTAL = preload("res://systems/ritual_portal_entry.gd")
const PORTAL_BEATS = preload("res://systems/ritual_portal_beats.gd")
const HUNT = preload("res://systems/monster_king_hunt_entry.gd")
const HUNT_BEATS = preload("res://systems/monster_king_hunt_beats.gd")

class Victory:
	extends RefCounted
	var units: Array = []
	func winner() -> String: return "ally"
	func find_id(_id: String) -> Dictionary: return {}

var passed: int = 0
var failed: int = 0
var captured: int = 0
var output: String = ""
var scratch: String = ""
var records: Array[Dictionary] = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			output = argument.trim_prefix("--screenshots=")
	call_deferred("_run")

func check(ok: bool, note: String) -> bool:
	if ok:
		passed += 1
		print("PASS manuscript-capture: ", note)
	else:
		failed += 1
		printerr("FAIL manuscript-capture: ", note)
	return ok

func remove_scratch() -> void:
	if scratch.is_empty(): return
	for suffix in ["", ".tmp"]:
		var target: String = scratch + suffix
		if FileAccess.file_exists(target):
			check(DirAccess.remove_absolute(ProjectSettings.globalize_path(target)) == OK,
				"temporary capture save removed: " + target.get_file())

func has_texture(panel: Control, expected: String) -> bool:
	for node in panel.find_children("*", "TextureRect", true, false):
		if node is TextureRect and node.texture != null and node.texture.resource_path == expected:
			return node.visible and node.size.x > 0.0 and node.size.y > 0.0
	return false

func capture_story(map: Control, label: String, method: String, arguments: Array,
		expected: Array[String], absent: Array[String] = []) -> void:
	var session: Node = root.get_node("RunSession")
	var before: Dictionary = session.world.snapshot().duplicate(true)
	var save_before: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	map.callv(method, arguments)
	if not check(is_instance_valid(map.overlay) and map.overlay is BOOK, label + ": production book overlay exists"):
		return
	var panel: Control = map.overlay
	panel.skip_opening()
	panel.typewriter.reveal_all()
	await create_timer(0.85).timeout
	if not check(is_instance_valid(panel) and map.overlay == panel, label + ": overlay remains stable while art settles"):
		return
	panel.typewriter.reveal_all()
	await RenderingServer.frame_post_draw
	check(panel.art.size == Vector2(360, 202.5) and panel.art.clip_contents,
		label + ": approved clipped 16:9 picture bounds")
	check(panel.position == BOOK.DISPLAY_POSITION and panel.scale == BOOK.DISPLAY_SCALE,
		label + ": approved fixed book transform")
	var texture_paths: Array[String] = []
	for path in expected:
		check(path.get_file().begins_with("manuscript_"), label + ": expected resource is approved manuscript art: " + path.get_file())
		check(has_texture(panel, path), label + ": actual visible texture " + path.get_file())
		texture_paths.append(path)
	for name in absent:
		check(panel.find_child(name, true, false) == null, label + ": no premature layer " + name)
	var unchanged: bool = session.world.snapshot() == before
	var file_unchanged: bool = FileAccess.get_file_as_bytes(scratch) == save_before
	check(unchanged, label + ": rendering does not change progress, RNG, roster or receipts")
	check(file_unchanged, label + ": rendering does not write the temporary save")
	var rendered: Image = root.get_texture().get_image()
	if not check(rendered != null and not rendered.is_empty(), label + ": actual renderer pixels available"):
		return
	check(rendered.get_size() == Vector2i(1280, 720), label + ": native 1280x720 pixel buffer")
	var colors: Dictionary = {}
	for y in range(9):
		for x in range(15):
			var px: int = int((float(x) + 0.5) * rendered.get_width() / 15.0)
			var py: int = int((float(y) + 0.5) * rendered.get_height() / 9.0)
			colors[rendered.get_pixel(px, py).to_html(false)] = true
	check(colors.size() > 12, label + ": nonblank rendered color variation")
	var filename: String = label + ".png"
	if check(rendered.save_png(output.path_join(filename)) == OK, label + ": PNG saved"):
		captured += 1
		records.append({"file":filename, "textures":texture_paths, "world_unchanged":unchanged,
			"temporary_save_unchanged":file_unchanged, "size":[rendered.get_width(), rendered.get_height()]})
	map.close_overlay()
	await process_frame

func _run() -> void:
	print("MANUSCRIPT_CAPTURE_SCOPE: isolated production render gallery; not natural play or balance verification")
	if not check(DisplayServer.get_name() != "headless", "actual graphical display driver"):
		quit(1)
		return
	if not check(not output.is_empty() and output.is_absolute_path(), "explicit absolute screenshot directory supplied"):
		quit(1)
		return
	if not check(DirAccess.make_dir_recursive_absolute(output) == OK, "screenshot directory prepared"):
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var session: Node = root.get_node("RunSession")
	var language: Node = root.get_node("GameLanguage")
	var previous_save: String = session.save_file_path
	var previous_language: String = language.locale
	for locale in ["ko", "en"]:
		check(language.set_language(locale, false), "temporary language selected without settings write: " + locale)
		await capture_route(session, locale)
		remove_scratch()
	session.save_file_path = previous_save
	check(language.set_language(previous_language, false), "original in-memory language restored without settings write")
	check(captured == 28, "fourteen production views captured in each of Korean and English")
	var manifest: Dictionary = {"scope":"isolated production render gallery; not natural gameplay or balance approval",
		"display_driver":DisplayServer.get_name(), "captured":captured, "passed":passed,
		"failed":failed, "screenshots":records}
	var file: FileAccess = FileAccess.open(output.path_join("capture_manifest.json"), FileAccess.WRITE)
	if check(file != null, "capture manifest opened"):
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	print("MAIN_STORY_MANUSCRIPT_CAPTURE: %d captured, %d passed, %d failed" % [captured, passed, failed])
	quit(0 if failed == 0 and captured == 28 else 1)

func capture_route(session: Node, locale: String) -> void:
	scratch = "user://manuscript_capture_%d_%s.json" % [OS.get_process_id(), locale]
	session.save_file_path = scratch
	session.start_new_world()
	# Visual-only travel fixture. Preserve all real story prerequisite APIs.
	session.world.contamination = 100
	session.world.reveal_boss_at_threshold()
	session.world.reveal_swamps_for_contamination()
	for place in ["graveyard", "unknown", "altar", "forest"]:
		if not session.world.tiles.has(place):
			var road: int = session.world.tiles.find("basic")
			if not check(road >= 0, locale + ": fixture can place required location " + place): return
			session.world.tiles[road] = place
	if not check(session.save_world(), locale + ": isolated visual fixture saved"): return
	var grave: int = session.world.tiles.find("graveyard")
	var village: int = session.world.tiles.find("village")
	var tree: int = session.world.tiles.find("unknown")
	var altar: int = session.world.tiles.find("altar")
	var forest: int = session.world.tiles.find("forest")
	if not check(mini(mini(grave, village), mini(tree, mini(altar, forest))) >= 0, locale + ": required story destinations exist"): return
	var map: Control = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	for i in range(4): await process_frame
	map.close_overlay()
	await process_frame
	await traverse_route(session, map, locale, grave, village, tree, altar, forest)
	current_scene = null
	map.queue_free()
	await process_frame

func traverse_route(session: Node, map: Control, locale: String, grave: int,
		village: int, tree: int, altar: int, forest: int) -> void:
	# Fixture victories exercise real RunSession result/acknowledgement APIs.
	# They are not evidence of winning normal-difficulty combat.
	session.world.position = grave
	if not check(CHILD.begin(session, grave), locale + ": real child event begins"): return
	if not check(CHILD.choose(session, grave, "protect_child"), locale + ": child rescue choice persisted"): return
	if not check(session.start_story_encounter(CHILD.EVENT_ID, grave, [session.world.roster[0].id]), locale + ": real rescue encounter begins"): return
	if not check(session.finish_encounter(Victory.new()), locale + ": fixture rescue result recorded"): return
	if not check(session.acknowledge_graveyard_battle_result(), locale + ": rescue result acknowledged"): return
	session.world.position = village
	if not check(RUMOR.begin(session, village) == RUMOR.RESCUED_ID, locale + ": rescued-child rumor starts"): return
	for beat in range(RUMOR_BEATS.count(RUMOR.RESCUED_ID)):
		if beat == 3:
			await capture_story(map, locale + "_01_village_noticed", "show_village_rumor_beat", [village, RUMOR.RESCUED_ID],
				[RUMOR.SCENE_ART, RUMOR_BEATS.TURN, RUMOR_BEATS.NECROMANCER])
		if not check(RUMOR.advance(session, village, RUMOR.RESCUED_ID, beat), locale + ": rumor advance %d" % beat): return
	if not check(COMMANDER.begin(session, village), locale + ": commander begins"): return
	for beat in range(COMMANDER_BEATS.count()):
		if beat == 0:
			await capture_story(map, locale + "_02_commander_arrival", "show_knight_commander_beat", [village],
				[COMMANDER.ART, COMMANDER_BEATS.COMMANDER], ["PlayerStoryPortrait"])
		elif beat == 2:
			await capture_story(map, locale + "_03_commander_player_reply", "show_knight_commander_beat", [village],
				[COMMANDER.ART, COMMANDER_BEATS.PLAYER], ["CommanderStoryPortrait"])
		if not check(COMMANDER.advance(session, village, beat), locale + ": commander advance %d" % beat): return
	session.world.position = tree
	if not check(HUNTER.begin(session, tree), locale + ": hunter begins"): return
	for beat in range(HUNTER_BEATS.count()):
		if beat == 1:
			await capture_story(map, locale + "_04_hunter_scene", "show_monster_hunter_beat", [tree],
				[HUNTER.BASE_ART, HUNTER_BEATS.SCENE], ["HunterPortrait", "HunterPlayerPortrait"])
		elif beat == 3:
			await capture_story(map, locale + "_05_hunter_portrait", "show_monster_hunter_beat", [tree],
				[HUNTER.BASE_ART, HUNTER_BEATS.HUNTER], ["HunterSceneLayer", "HunterPlayerPortrait"])
		if not check(HUNTER.advance(session, tree, beat), locale + ": hunter advance %d" % beat): return
	session.world.position = village
	if not check(CULTIST.begin(session, village), locale + ": cultist rumor begins"): return
	for beat in range(CULTIST_BEATS.count()):
		if beat == 1:
			await capture_story(map, locale + "_06_cultist_procession", "show_cultist_rumor_beat", [village],
				[CULTIST.BASE_ART, CULTIST_BEATS.PROCESSION])
		if not check(CULTIST.advance(session, village, beat), locale + ": cultist advance %d" % beat): return
	session.world.position = altar
	if not check(ALTAR.begin(session, altar), locale + ": altar begins"): return
	if not check(ALTAR.advance(session, altar, 0), locale + ": altar reveal persisted"): return
	await capture_story(map, locale + "_07_altar_ritual", "show_cultist_altar_beat", [altar],
		[ALTAR.BASE_ART, ALTAR_BEATS.RITUAL], ["CultistSummonLayer"])
	if not check(ALTAR.advance(session, altar, 1), locale + ": altar choice persisted"): return
	if not check(ALTAR.choose(session, altar, 2, "fight"), locale + ": explicit altar fight intent"): return
	await capture_story(map, locale + "_08_altar_summon", "show_cultist_altar_beat", [altar],
		[ALTAR.BASE_ART, ALTAR_BEATS.SUMMON], ["CultistRitualLayer"])
	if not check(ALTAR.reconsider(session, altar), locale + ": explicit altar reconsider"): return
	if not check(ALTAR.choose(session, altar, 2, "pass"), locale + ": explicit altar pass choice"): return
	if not check(ALTAR.finish(session, altar), locale + ": altar completion persisted"): return
	session.world.position = forest
	if not check(PORTAL.begin(session, forest), locale + ": portal begins"): return
	var portal_labels: Array[String] = ["09_portal_arrival", "10_portal_energy", "11_portal_cultists", "12_portal_omen"]
	for beat in range(4):
		var expected: Array[String] = []
		expected.append(PORTAL.BASE_ART)
		var absent: Array[String] = []
		if beat == 0:
			absent.append("PortalEnergyLayer")
			absent.append("PortalCultistsLayer")
			absent.append("PortalOmenLayer")
		if beat > 0: expected.append(PORTAL_BEATS.layer_for(str(PORTAL_BEATS.beat(beat).visual)))
		await capture_story(map, locale + "_" + portal_labels[beat], "show_ritual_portal_beat", [forest], expected, absent)
		if not check(PORTAL.advance(session, forest, beat), locale + ": portal advance %d" % beat): return
	if not check(PORTAL.choose_intervention(session, forest, 4), locale + ": intervention intent persisted"): return
	if not check(session.start_story_encounter(PORTAL.EVENT_ID, forest, [session.world.roster[0].id]), locale + ": real portal encounter starts"): return
	if not check(session.finish_encounter(Victory.new()), locale + ": fixture portal result recorded"): return
	if not check(session.acknowledge_story_battle_result(PORTAL.EVENT_ID), locale + ": portal result acknowledged"): return
	if not check(PORTAL.finish(session, forest), locale + ": portal completion unlocks hunt"): return
	session.world.position = tree
	if not check(HUNT.begin(session, tree), locale + ": king hunt begins after real story APIs"): return
	if not check(HUNT.advance(session, tree, 0), locale + ": hunt trace persisted"): return
	await capture_story(map, locale + "_13_hunt_trace", "show_monster_king_hunt_beat", [tree],
		[HUNT.BASE_ART, HUNT_BEATS.SCENE_ART], ["KingHuntPortrait"])
	if not check(HUNT.advance(session, tree, 1), locale + ": hunt portrait persisted"): return
	await capture_story(map, locale + "_14_hunt_portrait", "show_monster_king_hunt_beat", [tree],
		[HUNT.BASE_ART, HUNT_BEATS.PORTRAIT_ART], ["KingHuntSceneLayer"])
