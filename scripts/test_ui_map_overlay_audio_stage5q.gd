extends SceneTree
## Stage 5Q: the frozen web hides BOTH map sound controls when a tile
## event owns the board. Verify the real map panel and modal lifecycle,
## without muting/saving the user's audio preferences.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const AUDIO = preload("res://systems/audio_settings.gd")
var passed: int = 0
var failed: int = 0
var test_save: String = ""

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-map-overlay-audio: ", message)
	else:
		failed += 1
		printerr("FAIL ui-map-overlay-audio: ", message)

func is_blocked(map: Control) -> bool:
	var audio = map.map_audio
	return is_instance_valid(audio) and audio.modal_blocked and not audio.visible and audio.options_button.disabled and not audio.panel.visible

func is_unblocked(map: Control) -> bool:
	var audio = map.map_audio
	return is_instance_valid(audio) and not audio.modal_blocked and audio.visible and not audio.options_button.disabled and not audio.panel.visible

func cleanup() -> void:
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(test_save + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save + suffix))

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	test_save = "user://ui_map_overlay_audio_stage5q_%d.json" % OS.get_process_id()
	cleanup()
	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var original_save: String = session.save_file_path
	session.save_file_path = test_save
	session.start_new_world()
	var map = MAP.instantiate()
	root.add_child(map)
	await process_frame
	var audio = map.map_audio
	check(is_instance_valid(audio) and audio.options_button.name == "MapOptionsButton", "real map instantiates original sound icon")
	check(is_unblocked(map), "source map starts with clickable icon and a closed options panel")
	var button_art: TextureRect
	for child in audio.options_button.get_children():
		if child is TextureRect and child.texture != null:
			button_art = child
			break
	check(button_art != null and button_art.texture.resource_path == "res://assets/map/ui/map_audio_options.webp", "byte-exact original audio icon remains visible")
	check(audio.options_button.position == Vector2(1053,133) and audio.options_button.size == Vector2(58,58), "source map icon retains the existing footprint")
	var expected_rect = AUDIO.PANEL_RECT
	check(audio.panel.position.distance_to(expected_rect.position) < 1.0 and absf(audio.panel.size.x-expected_rect.size.x)<1.0, "source OPTION popup coordinates remain unchanged")
	audio.options_button.pressed.emit()
	check(audio.panel.visible, "map icon opens original OPTION controls")
	var before_snapshot: Dictionary = session.world.snapshot().duplicate(true)
	var before_rng: int = session.world.rng.state
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var initial_music: bool = AudioServer.is_bus_mute(music_bus)
	var initial_sfx: bool = AudioServer.is_bus_mute(sfx_bus)
	var original_audio_path: String = audio.save_file_path
	var generic = map.modal()
	check(is_instance_valid(generic) and map.overlay == generic, "modal is owned by actual map overlay")
	check(is_blocked(map), "opening generic tile modal instantly closes and hides icon and OPTION popup")
	check(not audio.options_button.is_visible_in_tree() and not audio.panel.is_visible_in_tree(), "hidden sound controls cannot cover or receive input over event art")
	audio.options_button.pressed.emit()
	check(not audio.panel.visible, "old sound icon cannot programmatically reopen popup while blocked")
	audio.toggle_panel()
	check(not audio.panel.visible, "direct options toggle also respects modal lock")
	check(audio.music_toggle.text in ["ON","OFF"] and audio.sfx_toggle.text in ["ON","OFF"], "original sound status text retained while popup is hidden")
	map.close_overlay()
	check(is_unblocked(map), "closing generic modal immediately restores icon, not old OPTION popup")
	audio.options_button.pressed.emit()
	check(audio.panel.visible, "restored icon is still interactive")
	audio.close_button.pressed.emit()
	check(not audio.panel.visible, "close X retains source semantics")
	check(AudioServer.is_bus_mute(music_bus)==initial_music and AudioServer.is_bus_mute(sfx_bus)==initial_sfx, "modal transitions never mute Music or SFX buses")
	check(audio.save_file_path==original_audio_path, "modal transitions never redirect or write audio config")
	var fortune: int = session.world.tiles.find("fortune-teller-camp")
	check(fortune>=0, "fixed map contains original fortune-teller event")
	if fortune>=0:
		audio.options_button.pressed.emit()
		check(audio.panel.visible, "open OPTION before actual location entry")
		map.show_location(fortune)
		check(is_instance_valid(map.overlay) and is_blocked(map), "source fortune-teller location art hides open OPTION panel")
		map.close_overlay()
		check(is_unblocked(map), "leaving fortune-teller art restores audio icon only")
		map.show_place_actions(fortune)
		check(is_instance_valid(map.overlay) and is_blocked(map), "nested prophecy actions also hide map sound controls")
		map.close_overlay()
		check(is_unblocked(map), "leaving prophecy actions restores board sound icon")
	var unknown: int = session.world.tiles.find("unknown")
	check(unknown>=0, "fixed map contains world-tree prayer")
	if unknown>=0:
		map.show_exploration_actions(unknown)
		check(is_instance_valid(map.overlay) and is_blocked(map), "world-tree action screen does not expose overlapping audio UI")
		map.close_overlay()
		check(is_unblocked(map), "world-tree action close restores map icon")
	map.show_home()
	check(is_instance_valid(map.overlay) and is_blocked(map), "home exterior scene hides audio UI like source event art")
	map.close_overlay()
	check(is_unblocked(map), "home exterior close restores map options")
	map.show_inventory("unit")
	check(is_instance_valid(map.overlay) and is_blocked(map), "book inventory overlay cannot be covered by audio button")
	map.close_overlay()
	check(is_unblocked(map), "closing book returns map sound icon")
	var battle_index: int = session.world.tiles.find("monster")
	check(battle_index>=0, "generated board has a combat tile")
	if battle_index>=0:
		map.show_battle_deck(battle_index)
		check(is_instance_valid(map.overlay) and is_blocked(map), "prebattle deck chooser hides high-z-index sound popup")
		check(session.encounter.is_empty(), "visual deck opening does not start combat automatically")
		map.close_overlay()
		check(is_unblocked(map), "canceling deck chooser restores map audio")
	var before_reward: Array = session.world.reward_receipts.duplicate()
	check(session.world.snapshot()==before_snapshot, "displaying and closing overlay sequence did not modify world save fields")
	check(session.world.rng.state==before_rng and session.world.reward_receipts==before_reward, "audio visibility and overlay controls never roll or award rewards")
	map.render()
	check(is_unblocked(map), "map stage rebuild starts with icon visible and OPTION closed")
	map.queue_free()
	await process_frame
	session.save_file_path = original_save
	if created: session.queue_free()
	cleanup()
	check(not FileAccess.file_exists(test_save), "test-only world file cleaned without touching player's saves")
	print("UI_MAP_OVERLAY_AUDIO_PARITY: %d passed, %d failed" % [passed, failed])
	quit(0 if failed==0 else 1)
