extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_event_discovery_arrival_integration.gd
## Verify real map event dispatch: story always precedes discovery; mere
## tile preview, duplicate arrival and save reload cannot award a new card.
const MapScene = preload("res://map.tscn")
const Child = preload("res://systems/story_event_entry.gd")
const State = preload("res://systems/map_state.gd")
const Actions = preload("res://systems/exploration_actions.gd")
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
	var before: Dictionary = world.snapshot().duplicate(true)
	var forest_before: int = world.tiles.count("forest")
	var roads_before: int = world.tiles.count("basic")
	var random_before: int = world.rng.state
	map.show_tile(event_index, true)
	check(session.event_flag_is_set(receipt), "first eligible genuine arrival saves discovery receipt")
	check(session.event_flag_is_set(State.HILL_UNLOCK_FLAG) and session.event_flag_is_set(State.HILL_HOME_NOTICE), "hill unlock and home NEW reminder saved atomically")
	check(world.tiles.count("forest")==forest_before+1 and world.tiles.count("basic")==roads_before-1, "one truly empty road changes into one real hill on the current map")
	check(world.tiles[event_index]=="event" and world.tiles[0]=="fortune-teller-camp" and world.tiles[8]=="village" and world.tiles[15]=="home", "event and fixed place cells untouched")
	check(world.rng.state==random_before and world.map_serial==int(before.map_serial), "conversion neither rerolls the dice RNG nor reshuffles map")
	var new_hill_index: int=-1
	for i in range(24):
		if before.tiles[i]=="basic" and world.tiles[i]=="forest": new_hill_index=i
	check(new_hill_index>=0 and new_hill_index!=event_index and new_hill_index!=23, "forest conversion picks protected safe empty cell")
	var card: Control = map.overlay.get_node_or_null("EventDiscoveryCard") if is_instance_valid(map.overlay) else null
	check(card != null, "first eligible genuine arrival opens actual discovery card")
	if card != null:
		check(card.get_node_or_null("EventDiscoveryTile") is TextureRect, "discovery shows real in-game forest board tile")
		check(card.get_node_or_null("EventDiscoveryClose")==null,"there is no confirm button")
		var click=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=true
		card._gui_input(click)
		await process_frame
		await process_frame
		check(not is_instance_valid(map.overlay),"one click dismisses popup and restores board")
		check(map.buttons.size()==24 and new_hill_index>=0 and map.buttons[new_hill_index].texture_normal==map.texture(map.tile_path(new_hill_index)), "board redraw displays actual new forest art")
	# Unread first house notice and permanent route-editor unlock art.
	map.show_home(true)
	check(is_instance_valid(map.overlay) and map.overlay.find_child("UnlockNewBadge",true,false)!=null,"home interior announces the newly unlocked hill")
	map.close_overlay()
	var home_route=Actions.new()
	map.stage.add_child(home_route)
	home_route.setup(map,State.HOME)
	check(home_route.find_child("HomeUnlockedForestTile",true,false) is TextureRect, "home route editor shows unlocked forest tile artwork")
	check(home_route.find_child("HomeForestUnlockedLabel",true,false) is Label, "home route editor names the unlocked forest")
	home_route.queue_free()
	await process_frame
	check(session.save_world(), "receipt remains durable after popup closes")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.event_flag_is_set(receipt) and session.event_flag_is_set(State.HILL_UNLOCK_FLAG), "reload preserves both discovery and actual tile unlock")
	check(world.tiles.count("forest")==forest_before+1, "converted road survives reload")
	world = session.world
	var second = MapScene.instantiate()
	root.add_child(second)
	await process_frame
	second.show_tile(event_index, true)
	check(not (is_instance_valid(second.overlay) and second.overlay.get_node_or_null("EventDiscoveryCard") != null), "revisited event never duplicates card")
	if is_instance_valid(second.overlay):
		second.close_overlay()
	check(session.world.tiles.count("forest")==forest_before+1, "duplicate arrival grants no further hills")
	# The discovered extra hill is rebuilt on the next generated board, too.
	world.generate()
	check(world.tiles.count("forest")==forest_before+1 and world.tiles.size()==24,"home shuffle preserves discovered extra hill")
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
	check(not session.event_flag_is_set(State.HILL_UNLOCK_FLAG) and world.tiles.count("forest")==forest_before, "main story never mutates a road into a hill")
	story_map.queue_free()
	await process_frame
	# Previously shipped one-shot discovery was visual-only. Loading that
	# exact saved receipt should now grant the missing real tile once.
	session.start_new_world()
	world=session.world
	event_index=world.tiles.find("event")
	world.position=event_index
	world.laps=1
	world.event_flags[receipt]=true
	var old_hill_count: int=world.tiles.count("forest")
	check(session.save_world(),"old visual-only card fixture stored")
	session.world=null
	session.ensure_world()
	world=session.world
	check(session.event_flag_is_set(State.HILL_UNLOCK_FLAG) and session.event_flag_is_set(State.HILL_HOME_NOTICE),"legacy visual-only receipt automatically migrated to HOME unlock")
	check(world.tiles.count("forest")==old_hill_count+1,"legacy card receipt restores one real new hill tile")
	var old_tiles: Array=world.tiles.duplicate()
	session.world=null
	session.ensure_world()
	check(session.world.tiles==old_tiles,"legacy discovery migration is idempotent across second reload")
	# The unlock receipt and transformed road MUST roll back together if the
	# same save cannot be committed; no phantom card/NEW hint is allowed.
	session.start_new_world()
	world=session.world
	event_index=world.tiles.find("event")
	world.position=event_index
	world.laps=1
	var rollback_before: Dictionary=world.snapshot().duplicate(true)
	session.save_file_path="user://missing_discovery_save_dir/forbidden.json"
	var denied: Dictionary=session.discover_hill_on_event(event_index)
	check(not bool(denied.get("ok",false)) and world.snapshot()==rollback_before,"failed save rolls back new hill, receipt and HOME NEW badge atomically")
	session.save_file_path = previous_path
	session.world = null
	cleanup()
	print("DISCOVERY_ARRIVAL_INTEGRATION: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
