extends SceneTree
## Shared dialogue art is a decoration only; all actions are still Godot buttons.
const FRAME = "res://assets/map/ui/intro-dialogue-box.webp"
const MAP = preload("res://map.tscn")
const INTRO = preload("res://intro.tscn")
var failed: int = 0
var passed: int = 0

func check(condition: bool, what: String) -> void:
	if condition:
		passed += 1
		print("PASS shared-dialogue: ", what)
	else:
		failed += 1
		printerr("FAIL shared-dialogue: ", what)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var art = load(FRAME) as Texture2D
	check(art != null, "blank parchment is imported as a Godot texture")
	if art == null:
		quit(1)
		return
	check(art.get_width() >= 768 and art.get_height() >= 180, "source art retains sufficient native resolution")
	var raw = FileAccess.get_file_as_bytes(FRAME)
	check(raw.size() > 12000 and raw.slice(0,4) == "RIFF".to_ascii_buffer() and raw.slice(8,12) == "WEBP".to_ascii_buffer(), "original recovered RIFF/WEBP parchment asset is the dialogue source")
	check(art.get_width() == 768 and art.get_height() == 288, "web original dialogue painting keeps its 768×288 intrinsic dimensions")
	var session = root.get_node_or_null("RunSession")
	check(session != null, "RunSession autoload is available")
	if session == null:
		quit(1)
		return
	var old_path: String = session.save_file_path
	var test_path: String = "user://shared_dialogue_%d.json" % OS.get_process_id()
	session.save_file_path = test_path
	session.start_new_world()
	var before = session.world.snapshot().duplicate(true)
	var map = MAP.instantiate()
	root.add_child(map)
	await process_frame
	var panel = map.modal()
	var frame = map.shared_story_frame(panel)
	check(frame is TextureRect and frame.texture == art and frame.texture.resource_path == FRAME, "story uses the shared transparent frame")
	check(frame.mouse_filter == Control.MOUSE_FILTER_IGNORE, "parchment never swallows touch input")
	check(panel.get_children().filter(func(n): return n is Button).is_empty(), "blank art alone creates no extra buttons")
	var clicks = [0]
	var action = map.location_button(panel,"계속",Vector2(651,653),Vector2(194,48),func(): clicks[0]+=1,1)
	check(action is Button, "story action remains a real independent button")
	if action != null:
		action.pressed.emit()
	check(clicks[0] == 1, "shared frame does not suppress action callbacks")
	check(session.world.snapshot() == before, "art and button fixture do not alter saved state")
	var source = FileAccess.get_file_as_string("res://map.gd")
	for fn in ["show_village_rumor_beat","show_knight_commander_beat","show_monster_hunter_beat","show_cultist_rumor_beat","show_monster_king_hunt_beat","show_ritual_portal_beat","show_ritual_portal_aftermath","show_cultist_altar_beat","show_cultist_altar_followup","show_story_battle_result"]:
		var begin = source.find("func " + fn + "(")
		var end = source.find("\nfunc ",begin + 5)
		var body = source.substr(begin,end - begin) if begin >= 0 and end > begin else ""
		check(body.contains("shared_story_frame(panel)"), "shared parchment added to " + fn)
	map.queue_free()
	await process_frame
	var intro = INTRO.instantiate()
	root.add_child(intro)
	await process_frame
	var intro_art_found: bool = false
	for node in intro.dialogue_stage.get_children():
		if node is Control:
			for child in node.get_children():
				if child is TextureRect and child.texture != null and child.texture.resource_path == FRAME:
					intro_art_found = true
	check(intro_art_found, "intro uses exactly the same parchment texture")
	check(intro.advance_button is Button and intro.skip_button is Button, "intro click and skip affordances remain")
	intro.queue_free()
	await process_frame
	session.save_file_path = old_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	print("SHARED_DIALOGUE_UI: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
