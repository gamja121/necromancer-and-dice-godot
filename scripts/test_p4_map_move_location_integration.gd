extends SceneTree
## P4-01B: real Map.roll_move() -> saved movement -> arrival -> location UI.
## Exercise genuine movement, not synthetic direct calls to show_tile().
## Run: godot --headless --path . --script res://scripts/test_p4_map_move_location_integration.gd

const MapScene = preload("res://map.tscn")
const MapState = preload("res://systems/map_state.gd")
const SessionScript = preload("res://systems/run_session.gd")

var passed: int = 0
var failed: int = 0
var save_paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-map-location: ",label)
	else:
		failed += 1
		printerr("FAIL p4-map-location: ",label)

func clear_path(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

## Preview the real map die without consuming the canonical RNG.
## Swap two ordinary board tiles rather than breaking the board's tile counts.
func install_deterministic_landing(session: Node, tile_type: String) -> Dictionary:
	var world = session.world
	var preview = RandomNumberGenerator.new()
	preview.state = world.rng.state
	var face: int = preview.randi_range(1,6)
	var landing: int = (MapState.HOME+face)%24
	var original_type: String = str(world.tiles[landing])
	if original_type != tile_type:
		var source: int = -1
		for i in range(world.tiles.size()):
			if i not in [0,8,MapState.HOME,landing] and world.tiles[i] == tile_type:
				source = i
				break
		if source < 0 and tile_type in ["altar","unknown"]:
			# This disposable UI-only fixture still exercises the artwork and
			# buttons of locations removed from the real opening board.
			# A spare road becomes one test-only advanced tile; production
			# map generation and real player saves remain untouched.
			for i in range(world.tiles.size()):
				if i not in [0,8,MapState.HOME,landing] and world.tiles[i]=="basic":
					source=i
					world.tiles[source]=tile_type
					break
		if source < 0:
			return {}
		world.tiles[landing] = tile_type
		world.tiles[source] = original_type
	return {"face":face,"landing":landing,"kind":tile_type}

func location_art_visible(map: Control, location_type: String) -> bool:
	if not is_instance_valid(map.overlay): return false
	var name: String = str(map.EVENT_IMAGES.get(location_type,""))
	var path: String = "res://assets/map/events/%s.jpg" % name
	var expected: Texture2D = map.texture(path)
	for node in map.overlay.get_children():
		if node is TextureRect and node.texture == expected and node.visible:
			return true
	return false

func has_panel_button(map: Control, label: String) -> bool:
	if not is_instance_valid(map.overlay): return false
	for node in map.overlay.get_children():
		if node is Button and node.text == label and node.visible:
			return true
	return false

func check_scenario(session: Node, label: String, location_type: String, is_swamp: bool = false) -> void:
	var path: String = "user://p4_map_location_%d_%s.json" % [OS.get_process_id(),label]
	save_paths.append(path)
	clear_path(path)
	session.save_file_path = path
	session.start_new_world()
	var world = session.world
	var fixture: Dictionary = install_deterministic_landing(session,location_type)
	check(not fixture.is_empty(),label+": preserved-tile-count board fixture generated")
	if fixture.is_empty(): return
	if is_swamp:
		world.roster[0].current_hp = 2
		world.roster[1].current_hp = 1
	check(session.save_world(),label+": fixture saved outside player's file")
	var before_map_serial: int = world.map_serial
	var before_move_serial: int = world.move_serial
	var original_rewards: Array = world.reward_receipts.duplicate()
	var map: Control = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(map.buttons.size()==24 and map.dice!=null,label+": real Map scene has 24 tiles and die")
	check(not is_instance_valid(map.overlay),label+": no location panel before arrival")
	# Do NOT invoke session.prepare_map_roll or map.show_tile directly here.
	# The user-facing map method runs its full die and moving hero effects.
	await map.roll_move()
	check(not map.moving and map.dice.is_visible_in_tree() and map.dice.disabled==is_instance_valid(map.overlay),
		label+": die remains visible but only unlocks when its arrival modal closes")
	check(world.position==int(fixture.landing),label+": real die followed %d steps and landed correctly" % int(fixture.face))
	check(world.move_serial==before_move_serial+1 and world.map_serial==before_map_serial,label+": one committed move, no map regeneration")
	check(world.pending_move.is_empty(),label+": movement transaction finalized")
	check(map.selected==world.position and map.hero.position.distance_to(map.hero_position(world.position))<0.5,label+": hero and tile highlight match landing")
	check(map.dice.texture_normal==map.texture("res://assets/battle/dice/result-%02d.png" % int(fixture.face)),label+": final die face matches saved movement")
	check(world.reward_receipts==original_rewards and world.pending_reward.is_empty() and session.encounter.is_empty(),label+": no phantom rewards or battles on entry")
	if location_type in ["rest","forest","altar","unknown"]:
		check(is_instance_valid(map.overlay),label+": location panel automatically opens on landing")
		check(location_art_visible(map,location_type),label+": correct original location background rendered")
		check(has_panel_button(map,"나가기"),label+": location has exit control")
		var names: Dictionary = {"rest":"전체 회복","forest":"이동 위치 선택","altar":"의식","unknown":"기도"}
		check(has_panel_button(map,str(names[location_type])),label+": correct location action is present")
	elif location_type=="monster":
		check(is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("battle_deck.gd"),label+": monster landing opens real pre-battle deck selection")
		check(session.encounter.is_empty(),label+": battle does not begin before choosing deck")
	else:
		check(not is_instance_valid(map.overlay),label+": non-interactive tile creates no location panel")
	if is_swamp:
		check(world.roster[0].current_hp==1 and world.roster[1].current_hp==1,label+": swamp damage applies once and respects 1HP floor")
	# Scene is removed before serializing restoration to prevent UI-held stale world.
	map.queue_free()
	await process_frame
	var committed: Dictionary = session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==committed,label+": saved move/arrival survives a new load without data loss")
	check(session.world.pending_move.is_empty() and session.world.position==int(fixture.landing),label+": reload does not replay already completed move")
	check(session.world.reward_receipts==original_rewards,label+": reload does not duplicate rewards")
	if is_swamp:
		check(session.world.roster[0].current_hp==1 and session.world.roster[1].current_hp==1,label+": swamp HP loss persists once after restart")

## Reopen a save after the movement has been committed but animation has
## not finished; the actual map auto-resumes the pending entry.
func check_interrupted_move(session: Node) -> void:
	var label: String = "resumed"
	var path: String = "user://p4_map_location_%d_%s.json" % [OS.get_process_id(),label]
	save_paths.append(path)
	clear_path(path)
	session.save_file_path = path
	session.start_new_world()
	var world = session.world
	var fixture: Dictionary = install_deterministic_landing(session,"rest")
	check(not fixture.is_empty(),"interrupted: deterministic rest landing present")
	if fixture.is_empty(): return
	check(session.save_world(),"interrupted: initial world saved")
	var prepared: Dictionary = session.prepare_map_roll()
	check(prepared.get("ok",false),"interrupted: pending move persisted before animation")
	if not prepared.get("ok",false): return
	check(not world.pending_move.is_empty(),"interrupted: one pending move exists")
	var serial: int = world.move_serial
	session.reload_world()
	check(not session.world.pending_move.is_empty(),"interrupted: pending move restored after process-style reload")
	var map: Control = MapScene.instantiate()
	root.add_child(map)
	var started: int = Time.get_ticks_msec()
	while map.moving or not session.world.pending_move.is_empty():
		if Time.get_ticks_msec()-started>10000: break
		await process_frame
	# Ensure deferred _ready -> resume_map_move has had a chance to start.
	for i in range(3): await process_frame
	check(session.world.pending_move.is_empty(),"interrupted: actual Map scene finalizes pending move")
	check(session.world.move_serial==serial and session.world.position==int(fixture.landing),"interrupted: move not rolled twice during restart")
	check(is_instance_valid(map.overlay) and location_art_visible(map,"rest"),"interrupted: destination rest panel appears after resume")
	check(not map.moving and map.dice.is_visible_in_tree() and map.dice.disabled==is_instance_valid(map.overlay),
		"interrupted: shared die persists but the location modal prevents accidental map rolls")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.pending_move.is_empty() and session.world.move_serial==serial,"interrupted: completed move not repeated on second reload")

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var created: bool = session==null
	if created:
		session = SessionScript.new()
		session.name = "RunSession"
		root.add_child(session)
	var original_path: String = session.save_file_path
	for entry in [
		{"label":"rest","type":"rest"},
		{"label":"forest","type":"forest"},
		{"label":"altar","type":"altar"},
		{"label":"unknown","type":"unknown"},
		{"label":"swamp","type":"swamp"},
		{"label":"basic","type":"basic"},
		{"label":"monster","type":"monster"}
	]:
		await check_scenario(session,str(entry.label),str(entry.type),entry.type=="swamp")
	await check_interrupted_move(session)
	session.save_file_path = original_path
	if created: session.queue_free()
	for path in save_paths: clear_path(path)
	check(save_paths.all(func(path): return not FileAccess.file_exists(path)), "temporary move saves removed; original save untouched")
	print("P4_MAP_LOCATION_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
