extends SceneTree
## Type-on, first tap reveal-all, second tap commit; no saved story changes.
const MAP = preload("res://map.tscn")
const INTRO = preload("res://intro.tscn")

var passed: int = 0
var failed: int = 0

func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("PASS story-typewriter: ",what)
	else:
		failed += 1
		printerr("FAIL story-typewriter: ",what)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	check(session != null,"RunSession autoload")
	if session == null:
		quit(1)
		return
	var old_save: String = session.save_file_path
	var save: String = "user://story_typewriter_%d.json" % OS.get_process_id()
	session.save_file_path = save
	session.start_new_world()
	var map = MAP.instantiate()
	root.add_child(map)
	for i in range(3): await process_frame
	var snapshot: Dictionary = session.world.snapshot().duplicate(true)
	var panel = map.story_modal()
	map.shared_story_frame(panel)
	var narrative = map.label_at(panel,"달빛 아래 깊은 숲속에서 오래된 성역의 그림자가 천천히 고개를 들었다.",Vector2(285,535),Vector2(710,66),17)
	var speech = map.label_at(panel,"기사단장: 돌아가라. 여기에는 네가 알아서는 안 될 비밀이 잠들어 있다.",Vector2(285,605),Vector2(710,50),16)
	var calls: Array[int] = [0]
	var action = map.location_button(panel,"계속",Vector2(463,653),Vector2(171,48),func():calls[0]+=1,1)
	var typewriter = panel.get_node_or_null("StoryTypewriter")
	check(typewriter != null,"typewriter attached once to shared story panel")
	check(narrative.visible_characters == 0 and speech.visible_characters == 0,"narration and dialogue start concealed")
	check(narrative.text.contains("달빛") and speech.text.contains("기사단장"),"original full copy stays intact")
	check(panel.get_node("StorySplitSpeechFrame") is TextureRect,"speech stays in separate lower frame")
	check(narrative.mouse_filter == Control.MOUSE_FILTER_IGNORE and speech.mouse_filter == Control.MOUSE_FILTER_IGNORE,"copy never blocks touch on story panel")
	var backdrops = panel.get_children().filter(func(n):return n is ColorRect and n.get_meta("ui_backdrop",false))
	check(backdrops.size() == 1 and backdrops[0].mouse_filter == Control.MOUSE_FILTER_PASS,"story backdrop bubbles taps for reveal")
	await create_timer(0.16).timeout
	check(narrative.visible_characters > 0 and narrative.visible_characters < narrative.get_total_character_count(),"narration reveals progressively over time")
	check(speech.visible_characters == 0,"dialogue waits until narration is finished")
	action.pressed.emit()
	check(calls[0] == 0 and narrative.visible_characters == -1 and speech.visible_characters == -1,"first action press reveals both copies without advancing")
	check(not typewriter.is_revealing(),"skip stops typewriter without restarting")
	action.pressed.emit()
	check(calls[0] == 1,"second action press executes original action exactly once")
	check(session.world.snapshot() == snapshot,"typewriter and reveal do not touch save, RNG, or event flags")
	map.close_overlay()
	var silent_panel = map.story_modal()
	map.shared_story_frame(silent_panel)
	var silent = map.label_at(silent_panel,"하나의 이야기만 있는 사건이다.",Vector2(285,535),Vector2(710,66),17)
	check(silent.visible_characters == 0,"silent event also types narration")
	check(silent_panel.get_node_or_null("StorySplitSpeechFrame") == null,"silent event never fabricates a speech frame")
	check(map._reveal_story_text(silent_panel) and silent.visible_characters == -1,"direct story tap instantly reveals silent narration")
	check(not map._reveal_story_text(silent_panel),"repeated tap does not trigger a second skip")
	map.close_overlay()
	map.queue_free()
	await process_frame
	var intro = INTRO.instantiate()
	root.add_child(intro)
	await process_frame
	check(intro.line_index == -1,"intro starts before the first line")
	intro.advance()
	check(intro.line_index == 0 and intro.text_label.visible_characters == 0,"first intro line starts typing")
	intro.advance()
	check(intro.line_index == 0 and intro.text_label.visible_characters == -1,"second intro tap only reveals full sentence")
	intro.advance()
	check(intro.line_index == 1 and intro.text_label.visible_characters == 0,"third intro tap advances to the next sentence")
	intro.queue_free()
	await process_frame
	session.save_file_path = old_save
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))
	print("STORY_TYPEWRITER: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
