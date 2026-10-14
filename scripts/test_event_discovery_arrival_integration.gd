extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_event_discovery_arrival_integration.gd
## Verify real map event dispatch: story always precedes discovery; mere
## tile preview, duplicate arrival and save reload cannot award a new card.
const MapScene = preload("res://map.tscn")
const Child = preload("res://systems/story_event_entry.gd")
var passed := 0
var failed := 0
var save_path := ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS discovery-arrival: ", title)
	else:
		failed += 1
		printerr("FAIL discovery-arrival: ", title)

func cleanup() -> void:
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	check(session != null, "RunSession autoload available")
	if session == null:
		quit(1)
		return
	var previous_path: String = session.save_file_path
	save_path = "user://test_discovery_arrival_%d.json" % OS.get_process_id()
	cleanup()
	session.save_file_path = save_path
	session.start_new_world()
	var world = session.world
	var event_index: int = world.tiles.find("event")
	check(event_index >= 0, "existing event tile retained on opening board")
	if event_index < 0:
		session.save_file_path = previous_path
		quit(1)
		return
	# A genuine landing calls show_tile(index,true) after the durable move.
	# Use this dispatch with the real event index; never fabricate an unlock flag.
	world.position = event_index
	world.laps = 1
	world.contamination = 0
	check(session.save_world(), "test fixture saved with a completed first patrol")
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	var receipt := "event:discovery:forest:card_shown"
	map.show_tile(event_index)
	check(not session.event_flag_is_set(receipt), "preview never creates a discovery receipt")
	check(not (is_instance_valid(map.overlay) and map.overlay.get_node_or_null("EventDiscoveryCard") != null), "preview never opens discovery card")
	if is_instance_valid(map.overlay):
		map.close_overlay()
	map.show_tile(event_index, true)
	check(session.event_flag_is_set(receipt), "first eligible genuine arrival saves visual receipt")
	var card: Control = map.overlay.get_node_or_null("EventDiscoveryCard") if is_instance_valid(map.overlay) else null
	check(card != null, "first eligible genuine arrival opens actual discovery card")
	if card != null:
		check(card.get_node_or_null("EventDiscoveryTile") is TextureRect, "discovery shows real in-game forest board tile")
		var ok_button = card.get_node_or_null("EventDiscoveryClose")
		if ok_button is Button:
			ok_button.pressed.emit()
			await process_frame
			await process_frame
		check(not is_instance_valid(map.overlay), "confirm dismisses popup and restores board")
	check(session.save_world(), "receipt remains durable after popup closes")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.event_flag_is_set(receipt), "reload preserves discovery receipt")
	world = session.world
	var second = MapScene.instantiate()
	root.add_child(second)
	await process_frame
	second.show_tile(event_index, true)
	check(not (is_instance_valid(second.overlay) and second.overlay.get_node_or_null("EventDiscoveryCard") != null), "revisited event never duplicates card")
	if is_instance_valid(second.overlay):
		second.close_overlay()
	second.queue_free()
	await process_frame
	# Fresh session with contamination 10: the unmodified original child
	# story takes priority and the discovery receipt must remain absent.
	session.start_new_world()
	world = session.world
	event_index = world.tiles.find("event")
	world.position = event_index
	world.laps = 1
	world.contamination = 10
	check(session.save_world(), "story-priority fixture saved")
	var story_map = MapScene.instantiate()
	root.add_child(story_map)
	await process_frame
	story_map.show_tile(event_index, true)
	check(session.get_story_event(Child.EVENT_ID).status == "seen", "eligible main child story still starts first")
	check(not session.event_flag_is_set(receipt), "main story never grants fallback discovery")
	story_map.queue_free()
	await process_frame
	session.save_file_path = previous_path
	session.world = null
	cleanup()
	print("DISCOVERY_ARRIVAL_INTEGRATION: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
