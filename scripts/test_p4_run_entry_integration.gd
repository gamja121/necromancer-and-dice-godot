extends SceneTree
## P4-01 step 1: actual Title -> New Run -> full Intro -> Map scene transition.
## Run: godot --headless --path . --script res://scripts/test_p4_run_entry_integration.gd
## All save writes target a unique disposable user:// file.
const TITLE_SCENE = preload("res://title.tscn")
const SessionScript = preload("res://systems/run_session.gd")
const MapState = preload("res://systems/map_state.gd")

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-entry: ",label)
	else:
		failed += 1
		printerr("FAIL p4-entry: ",label)

func wait_for_scene(scene_name: String, timeout_ms: int = 8000) -> Node:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < timeout_ms:
		if current_scene != null and current_scene.name == scene_name:
			return current_scene
		await process_frame
	return null

func clear_test_path(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func _run() -> void:
	var save_path: String = "user://p4_entry_%d.json" % OS.get_process_id()
	var audio_path: String = "user://p4_entry_audio_%d.cfg" % OS.get_process_id()
	clear_test_path(save_path)
	clear_test_path(audio_path)
	# Standalone Godot --script has no autoload node. Use the exact production
	# absolute path without changing the user's real RunSession or real save.
	var created_session: bool = not root.has_node("RunSession")
	var session = root.get_node_or_null("RunSession")
	if created_session:
		session = SessionScript.new()
		session.name = "RunSession"
		root.add_child(session)
	var previous_path: String = session.save_file_path
	session.save_file_path = save_path
	check(not session.has_save(),"disposable run starts without a prior save")
	var title: Control = TITLE_SCENE.instantiate()
	title.set("audio_save_path",audio_path)
	root.add_child(title)
	current_scene = title
	await process_frame
	var new_run: Button = title.get_node_or_null("TitleUI/MenuPanel/Menu/NewRun")
	var continue_run: Button = title.get_node_or_null("TitleUI/MenuPanel/Menu/Continue")
	check(new_run != null and not new_run.disabled,"actual title New Run button enabled")
	check(continue_run != null and continue_run.disabled,"Continue correctly disabled before first save")
	if new_run == null:
		failed += 1
		_cleanup(session,created_session,previous_path,save_path,audio_path)
		return
	# Invoke the exact production button signal, not a mocked run initializer.
	new_run.pressed.emit()
	check(session.world != null and session.has_save(),"New Run creates and persists the real world")
	if session.world != null:
		check(session.world.position == MapState.HOME,"new player spawns at home tile")
		check(session.world.tiles.size() == 24,"new world has 24 playable tiles")
		check(session.world.roster.size() == 2,"original two owned monsters available")
		check(session.world.laps == 0 and session.world.contamination == 0,"new run has no prior lap or contamination")
	var intro: Node = await wait_for_scene("Intro")
	check(intro != null,"Title's New Run loads the actual Intro scene")
	if intro == null:
		_cleanup(session,created_session,previous_path,save_path,audio_path)
		return
	var script_lines: Array = intro.get("lines")
	var advance: Button = intro.get("advance_button")
	var speaker: Label = intro.get("speaker_label")
	var dialogue: Label = intro.get("text_label")
	check(script_lines.size() == 12,"Intro loads all 12 original dialogue lines")
	check(advance != null and speaker != null and dialogue != null,"intro dialogue controls are actually constructed")
	if advance == null:
		_cleanup(session,created_session,previous_path,save_path,audio_path)
		return
	var text_correct: bool = true
	for i in range(script_lines.size()):
		advance.pressed.emit()
		if intro.get("line_index") != i or speaker.text != str(script_lines[i].speaker) or dialogue.text != str(script_lines[i].text):
			text_correct = false
	check(text_correct,"all 12 dialogue beats advance in original order without skipping")
	check(not intro.get("leaving"),"intro does not switch scenes before last dialogue is dismissed")
	intro.set("ending_duration",0.10)
	advance.pressed.emit()
	check(intro.get("leaving"),"final dialogue click starts actual fade-to-map")
	var map_scene: Node = await wait_for_scene("Map")
	check(map_scene != null,"intro completes fade and opens the actual Map scene")
	if map_scene != null:
		check(map_scene.get("world") == session.world,"map is bound to the newly persisted run")
		var buttons: Array = map_scene.get("buttons")
		check(buttons.size() == 24 and buttons.all(func(b): return b.texture_normal != null),"24 map tiles have loaded art")
		var dice: TextureButton = map_scene.get("dice")
		check(dice != null and not dice.disabled,"first map's dice input is ready")
		var hero: TextureRect = map_scene.get("hero")
		check(hero != null and hero.texture != null,"player marker is rendered on the map")
		var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		check(saved is Dictionary and saved.get("position",-1) == MapState.HOME,"map scene preserves the new run on disk")
		if saved is Dictionary:
			check(saved.get("roster",[]).size() == 2 and saved.get("tiles",[]).size() == 24,"first map does not lose starter units or tile data")
		map_scene.queue_free()
		await process_frame
		current_scene = null
		session.reload_world()
		check(session.world != null and session.world.position == MapState.HOME,"fresh load returns to the saved first map position")
		if session.world != null:
			check(session.world.roster.size() == 2 and session.world.laps == 0,"reload preserves starter party and zero completed laps")
	_cleanup(session,created_session,previous_path,save_path,audio_path)

func _cleanup(session: Node, created_session: bool, previous_path: String, save_path: String, audio_path: String) -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null
	session.set("save_file_path",previous_path)
	if created_session: session.queue_free()
	clear_test_path(save_path)
	clear_test_path(audio_path)
	check(not FileAccess.file_exists(save_path),"disposable run save removed; production path was not touched")
	print("P4_RUN_ENTRY_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
