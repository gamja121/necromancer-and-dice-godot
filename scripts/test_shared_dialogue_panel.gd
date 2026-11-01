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
	var intro_art_found: bool = false
	for node in intro.dialogue_stage.get_children():
		if node is Control:
			for child in node.get_children():
				if child is TextureRect and child.texture != null and child.texture.resource_path == FRAME:
					intro_art_found = true
	check(intro_art_found, "intro uses exactly the same parchment texture")
	check(intro.advance_button is Button and intro.skip_button is Button, "intro click and skip affordances remain")
	var intro_box: Control=intro.dialogue_stage.get_node_or_null("IntroDialogueBox")
	check(intro_box!=null and intro_box.size==Vector2(1075.2,216),"intro keeps original cinematic dialogue footprint")
	if intro_box!=null:
		var nameplate: Control=intro_box.get_node_or_null("SpeakerNameplate")
		var inner: Control=intro_box.get_node_or_null("GoldHairline")
		var badge: Control=intro_box.get_node_or_null("DialogueNextBadge")
		check(nameplate is Panel and nameplate.position.y<0,"intro has a raised independent speaker plate")
		check(nameplate!=null and intro.speaker_label.get_parent()==nameplate and intro.speaker_label.name=="IntroSpeakerName",
			"editable speaker text is embedded in the gilt nameplate")
		check(inner is Panel and intro_box.get_node_or_null("BronzeInset") is Panel,
			"intro uses double live gilded inner-frame rules")
		check(badge is Panel and badge.get_node_or_null("IntroContinueArrow") is Label,
			"animated continue indicator sits in its own heraldic medallion")
		check(intro.text_label.get_parent()==intro_box and intro.text_label.name=="IntroDialogueText"
			and intro.text_label.has_theme_font_override("font"),"dialogue type stays live and uses a legible manuscript font")
		var text_bounds: Rect2=Rect2(intro.text_label.position,intro.text_label.size)
		check(text_bounds.position.x>=75 and text_bounds.end.x<badge.position.x
			and text_bounds.position.y>nameplate.position.y+nameplate.size.y
			and text_bounds.end.y<intro_box.size.y-10,
			"spoken text stays clear of the nameplate, advance emblem and lower frame")
		for deco in [intro_box.get_node_or_null("DialogueShadow"),inner,nameplate,badge]:
			check(deco!=null and deco.mouse_filter==Control.MOUSE_FILTER_IGNORE,
				"purely decorative trim never intercepts dialogue tap input")
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
