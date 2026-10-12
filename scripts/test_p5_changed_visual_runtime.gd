extends SceneTree
## P5-03B-1: four changed web->Godot illustrations must decode and reach their
## real Map UI callers. This deliberately cannot approve their visual quality.
## Run: godot --headless --path . --script res://scripts/test_p5_changed_visual_runtime.gd
const MAP_SCENE = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const GRAVE = preload("res://systems/story_event_entry.gd")
const RUMOR = preload("res://systems/village_rumor_entry.gd")
const RUMOR_BEATS = preload("res://systems/village_rumor_beats.gd")
const COMMANDER = preload("res://systems/knight_commander_entry.gd")
const BEATS = preload("res://systems/knight_commander_beats.gd")

const CHANGED = [
	"res://assets/map/events/fortune-teller.jpg",
	"res://assets/map/events/home-interior.jpg",
	"res://assets/map/events/knight-commander-upperbody-hd.webp",
	"res://assets/map/events/necromancer-upperbody-hd.webp"
]
const COMMANDER_ART = "res://assets/map/events/knight-commander-village-day.webp"

class Victory:
	extends RefCounted
	var outcome: String = "ally"
	var units: Array = []
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS p5-changed-visual: ", message)
	else:
		failures += 1
		printerr("FAIL p5-changed-visual: ", message)

func clean(path: String) -> void:
	for extension in ["", ".tmp"]:
		if FileAccess.file_exists(path + extension):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + extension))

func ui_texture(panel: Control, tex: Texture2D) -> TextureRect:
	if not is_instance_valid(panel) or tex == null:
		return null
	for child in panel.get_children():
		if child is TextureRect and child.texture == tex:
			return child
	return null

func check_art_ui(map: Control, art_path: String, tag: String) -> void:
	var tex: Texture2D = map.texture(art_path)
	var art: TextureRect = ui_texture(map.overlay, tex)
	check(art != null, tag + ": actual Map modal contains intended texture")
	if art == null: return
	check(art.size.x > 0.0 and art.size.y > 0.0, tag + ": has nonzero drawn area")
	check(art.position.x >= 0.0 and art.position.y >= 0.0
		and art.position.x + art.size.x <= 1280.0
		and art.position.y + art.size.y <= 720.0,
		tag + ": TextureRect lies inside the 1280x720 viewport")
	check(art.visible and art.texture.get_width() > 0 and art.texture.get_height() > 0,
		tag + ": visible with decoded texture")
	if art.name == "LocationSceneImage":
		check(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			tag + ": ordinary location uses battle-sized aspect-covered art")
		check(art.position.distance_to(map.LOCATION_EVENT_SCENE_RECT.position) < 0.2 and art.size.distance_to(map.LOCATION_EVENT_SCENE_RECT.size) < 0.2,
			tag + ": ordinary location art occupies the exact embedded battle viewport")
	else:
		check(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
			tag + ": existing story composition retains centered aspect")

func _run() -> void:
	# Actual bytes, decoding and Godot imported Texture2D are both checked.
	for art_path in CHANGED:
		check(ResourceLoader.exists(art_path), art_path + ": resource exists")
		var tex: Texture2D = load(art_path) as Texture2D
		check(tex != null, art_path + ": Godot imports image")
		if tex == null: continue
		check(tex.get_width() >= 16 and tex.get_height() >= 16,
			art_path + ": usable positive source dimensions")
		var pixels: Image = tex.get_image()
		check(pixels != null and not pixels.is_empty(), art_path + ": pixel image decodes")

	var save_path: String = "user://p5_changed_art_%d.json" % OS.get_process_id()
	clean(save_path)
	# --script keeps configured production autoloads in /root on some runners.
	# Never spawn a second RunSession: the production Map reads /root/RunSession.
	var s = root.get_node_or_null("RunSession")
	var created_session: bool = s == null
	if created_session:
		s = SESSION.new()
		s.name = "RunSession"
		root.add_child(s)
	var previous_path: String = s.save_file_path
	s.save_file_path = save_path
	s.start_new_world()
	var map: Control = MAP_SCENE.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame

	# The real house interior and fortune-teller tile go through production
	# Map functions rather than synthetic resource-only texture instances.
	map.show_home(true)
	check_art_ui(map, CHANGED[1], "home interior")
	map.close_overlay()
	var fortune_idx: int = s.world.tiles.find("fortune-teller-camp")
	check(fortune_idx >= 0, "frozen map contains fortune-teller tile")
	if fortune_idx >= 0:
		map.show_location(fortune_idx)
		check_art_ui(map, CHANGED[0], "fortune-teller location")
		map.close_overlay()

	# Reach the *real saved story* gate without inventing its flags:
	# rescue child, win story combat, acknowledge, finish saved village rumor.
	var grave_idx: int = s.world.tiles.find("graveyard")
	var village_idx: int = s.world.tiles.find("village")
	check(grave_idx >= 0 and village_idx >= 0, "story target tiles exist")
	if grave_idx >= 0 and village_idx >= 0:
		s.world.position = grave_idx
		check(GRAVE.begin(s, grave_idx), "real graveyard child story discovery")
		check(GRAVE.choose(s, grave_idx, "protect_child"), "real rescue choice saved")
		check(s.start_story_encounter(GRAVE.EVENT_ID, grave_idx, [s.world.roster[0].id]),
			"real story battle starts")
		check(s.finish_encounter(Victory.new()), "real story battle victory recorded")
		check(s.acknowledge_graveyard_battle_result(), "real rescue acknowledged")
		s.world.position = village_idx
		check(RUMOR.begin(s, village_idx) == RUMOR.RESCUED_ID,
			"saved rescue rumor begins in village")
		for beat_idx in range(RUMOR_BEATS.count(RUMOR.RESCUED_ID)):
			check(RUMOR.advance(s, village_idx, RUMOR.RESCUED_ID, beat_idx),
				"village rumor beat %d persisted" % beat_idx)
		check(COMMANDER.begin(s, village_idx), "commander encounter unlocked and saved")
		check(map.session == s, "real Map refers to same event RunSession")
		check(COMMANDER.can_enter(s, village_idx), "commander gate remains open after first saved beat")
		check(COMMANDER.current_beat(s) == 0, "commander first beat restored at zero")
		for beat_idx in range(BEATS.count()):
			check(COMMANDER.can_enter(s, village_idx), "commander gate open before beat %d" % beat_idx)
			check(COMMANDER.current_beat(s) == beat_idx, "saved beat matches visible event beat %d" % beat_idx)
			var beat: Dictionary = BEATS.beat(beat_idx)
			map.show_knight_commander_beat(village_idx)
			check(is_instance_valid(map.overlay), "commander UI opens for beat %d" % beat_idx)
			if is_instance_valid(map.overlay):
				check_art_ui(map, str(beat.portrait), "commander beat %d portrait" % beat_idx)
				var art: TextureRect = ui_texture(map.overlay, map.texture(COMMANDER_ART))
				check(art != null, "commander beat %d real scene background" % beat_idx)
			map.close_overlay()
			if beat_idx < BEATS.count() - 1:
				check(COMMANDER.advance(s, village_idx, beat_idx),
					"commander beat %d persisted" % beat_idx)
		check(str(BEATS.beat(2).portrait) == CHANGED[3],
			"player reply uses changed necromancer portrait")
		check(str(BEATS.beat(0).portrait) == CHANGED[2],
			"commander arrival uses changed commander portrait")

	map.close_overlay()
	current_scene = null
	root.remove_child(map)
	map.queue_free()
	s.save_file_path = previous_path
	if created_session:
		root.remove_child(s)
		s.queue_free()
	clean(save_path)
	print("P5_03B_VISUAL_RUNTIME: %d passed, %d failed, 4 changed illustrations checked; PC/user visual approval remains REQUIRED" % [passed, failures])
	if failures > 0:
		quit(1)
	else:
		quit(0)
