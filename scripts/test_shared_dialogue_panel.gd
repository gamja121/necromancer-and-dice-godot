extends SceneTree
## Shared dialogue art is a decoration only; all actions are still Godot buttons.
const FRAME = "res://assets/map/ui/shared_dialogue_panel.svg"
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
	check(art.get_width() >= 800 and art.get_height() >= 180, "source art retains sufficient native resolution")
	var raw = FileAccess.get_file_as_string(FRAME)
	check(not raw.contains("계속") and not raw.contains("나가기") and not raw.contains("nameplate"), "art has no baked text, buttons or nameplate")
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
	var intro_box: Control=intro.dialogue_stage.get_node_or_null("IntroDialogueBox")
	check(intro_box!=null and intro_box.size.distance_to(Vector2(1075.2,216))<0.1,
		"intro retains its approved in-game footprint")
	check(intro.advance_button is Button and intro.skip_button is Button,
		"intro touch, Continue and Skip buttons are preserved")
	if intro_box!=null:
		var original: NinePatchRect=intro_box.get_node_or_null("IntroOriginalDialogueFrame") as NinePatchRect
		check(original!=null and original.texture!=null
			and original.texture.resource_path=="res://assets/intro/dialogue_frame.webp",
			"intro uses its original hand-painted dialogue_frame.webp asset")
		check(original!=null and original.patch_margin_left==32 and original.patch_margin_right==32
			and original.patch_margin_top==28 and original.patch_margin_bottom==28,
			"hand-painted corners are protected by nine-slice margins")
		check(original!=null and original.mouse_filter==Control.MOUSE_FILTER_IGNORE,
			"original image never captures dialogue taps")
		check(intro_box.get_node_or_null("SpeakerNameplate")==null
			and intro_box.get_node_or_null("BronzeInset")==null
			and intro_box.get_node_or_null("DialogueNextBadge")==null,
			"old synthetic brass decorations are removed")
		check(intro.speaker_label.get_parent()==intro_box and intro.speaker_label.name=="IntroSpeakerName"
			and intro.text_label.get_parent()==intro_box and intro.text_label.name=="IntroDialogueText",
			"speaker and manuscript copy stay as live localized game labels")
		var bounds: Rect2=Rect2(intro.text_label.position,intro.text_label.size)
		check(bounds.position.x>55 and bounds.end.x<980
			and bounds.position.y>intro.speaker_label.position.y+intro.speaker_label.size.y
			and bounds.end.y<200,"original art's inner writing area clears borders and name")
		check(intro_box.get_node_or_null("IntroContinueArrow") is Label,
			"live animated continuation cue remains accessible")
		check(intro_box.get_children().filter(func(n):return n is TextureRect).is_empty(),
			"original intro frame uses NinePatchRect instead of distorting a TextureRect")
	var unchanged = session.world.snapshot().duplicate(true)
		intro.advance()
		check(intro.line_index==0 and intro.dialogue_stage.visible
			and intro.speaker_label.text==str(intro.lines[0].speaker)
			and intro.text_label.text==str(intro.lines[0].text),
			"real intro click reveals the first unchanged script line")
		check(intro.dialogue_typewriter.is_revealing(),
			"updated intro text still starts its normal character-by-character reveal")
		intro.advance()
		check(intro.line_index==0 and not intro.dialogue_typewriter.is_revealing(),
			"second click reveals the current sentence without advancing the story")
		check(session.world.snapshot()==unchanged,
			"live dialogue trim and tap-to-reveal do not modify the player's saved run")
	intro.queue_free()
	await process_frame
	session.save_file_path = old_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	print("SHARED_DIALOGUE_UI: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
