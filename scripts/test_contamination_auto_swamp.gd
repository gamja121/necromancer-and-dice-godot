extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_contamination_auto_swamp.gd
## Covers 40/80 generation, in-lap pollution change, v1 save upgrade,
## old 2-swamp route plans, save rollback and actual board-tile image.
const State = preload("res://systems/map_state.gd")
const Plan = preload("res://systems/route_plan.gd")
const Session = preload("res://systems/run_session.gd")
const MapScene = preload("res://map.tscn")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, name: String) -> void:
	if ok:
		passed += 1
		print("PASS auto-swamp: ", name)
	else:
		failed += 1
		printerr("FAIL auto-swamp: ", name)

func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	check(State.FIRST_SWAMP_CONTAMINATION == 40 and State.SECOND_SWAMP_CONTAMINATION == 80, "existing contamination stages 40 and 80")
	check(ResourceLoader.exists("res://assets/map/tiles/swamp.png"), "real swamp board art exists")
	var full: Dictionary = Plan.default_plan()
	full.selection["monster"] = Plan.OPTIONAL_CAPACITY
	for level in [0, 39, 40, 60, 79, 80, 100]:
		for configuration in [Plan.default_plan(), full]:
			var world = State.new(data, 12345 + level, configuration)
			world.laps = 2
			world.contamination = level
			world.generate()
			var expected: int = State.required_swamp_count(level)
			check(world.tiles.size() == 24 and world.tiles.count("swamp") == expected,
				"24 board slots, %d swamps at contamination %d" % [expected, level])
			check(world.tiles[0] == "fortune-teller-camp" and world.tiles[8] == "village" and world.tiles[15] == "home",
				"permanent anchors preserved at contamination %d" % level)
			check(world.tiles[23] == ("boss" if level >= State.BOSS_CONTAMINATION else world.tiles[23]),
				"existing boss slot preserved at contamination %d" % level)
			check(world.tiles.count("monster") >= (4 if level >= 20 else 5), "existing automatic monsters survive")
			check(world.tiles.count("event") == 1 and world.tiles.count("warp") == 2,
				"story event and warp tiles unaffected")
	var old_plan: Dictionary = {"current": Plan.CURRENT.duplicate(), "reserve": Plan.RESERVE.duplicate()}
	var legacy = State.new(data, 3456, old_plan)
	legacy.contamination = 100
	legacy.generate()
	check(legacy.tiles.count("swamp") == 2, "legacy inventory already owning two swamp tiles is not duplicated")

	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = Session.new()
		session.name = "RunSession"
		root.add_child(session)
	var original_path: String = session.save_file_path
	var scratch: String = "user://contamination_auto_swamp_%d.json" % OS.get_process_id()
	session.save_file_path = scratch
	session.start_new_world()
	var world = session.world

	# A world-tree prayer can raise contamination mid-lap. This must change
	# only existing ordinary roads; no map reroll or random-state advance.
	world.contamination = 39
	world.position = State.HOME
	world.generate()
	var before: Dictionary = world.snapshot().duplicate(true)
	var old_tiles: Array = world.tiles.duplicate()
	var old_serial: int = world.map_serial
	var old_rng: int = world.rng.state
	world.contamination = 40
	check(session.persist_change(before), "crossing 40 persists atomically")
	check(world.tiles.count("swamp") == 1, "first swamp appears on current board at 40")
	check(world.tiles.size() == 24 and world.map_serial == old_serial, "mid-lap reveal does not regenerate board")
	check(world.rng.state == old_rng, "no RNG consumed to spawn swamp")
	var swamp_index: int = world.tiles.find("swamp")
	check(swamp_index != State.HOME and old_tiles[swamp_index] == "basic", "only a vacant, unoccupied road was converted")
	check(not world.reveal_swamps_for_contamination() > 0 and world.tiles.count("swamp") == 1,
		"repeating the same threshold is idempotent")
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(map.buttons.size() == 24 and map.buttons[swamp_index].texture_normal == map.texture("res://assets/map/tiles/swamp.png"),
		"real Godot board paints the existing swamp tile texture")
	map.queue_free()
	await process_frame
	session.reload_world()
	world = session.world
	check(world.contamination == 40 and world.tiles.count("swamp") == 1, "first swamp survives file reload")

	# Upgrade to 80 in the SAME lap. A second swamp appears immediately.
	world.contamination = 79
	before = world.snapshot().duplicate(true)
	world.contamination = 80
	check(session.persist_change(before), "crossing 80 saves second swamp")
	check(world.tiles.count("swamp") == 2 and world.map_serial == old_serial, "second swamp appears without rerolling the board")
	session.reload_world()
	world = session.world
	check(world.tiles.count("swamp") == 2, "both swamps survive reload")

	# Old saved runs at 80 had two protected basic roads but no swamps.
	world.contamination = 39
	world.generate()
	world.contamination = 80
	check(world.tiles.count("swamp") == 0 and session.save_world(), "older high-contamination board fixture stored")
	var preserved_serial: int = world.map_serial
	var prior: Array = world.tiles.duplicate()
	session.reload_world()
	world = session.world
	check(world.contamination == 80 and world.tiles.count("swamp") == 2 and world.map_serial == preserved_serial,
		"old high-contamination save upgraded in place")
	var untouched: bool = true
	for i in range(24):
		if world.tiles[i] != prior[i] and (prior[i] != "basic" or world.tiles[i] != "swamp"):
			untouched = false
	check(untouched, "migration only converts basic to swamp and preserves story/route tiles")
	
	# If the disk save fails, the contamination and tile changes rollback.
	world.contamination = 39
	world.generate()
	before = world.snapshot().duplicate(true)
	session.save_file_path = "user://missing_auto_swamp_dir/cannot_write.json"
	world.contamination = 40
	check(not session.persist_change(before), "failed save refused at contamination threshold")
	check(world.snapshot() == before, "failed write rolls back new swamps and contamination")
	session.save_file_path = scratch
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(scratch + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch + suffix))
	session.save_file_path = original_path
	if created: session.queue_free()
	print("AUTO_SWAMP_CONTAMINATION: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
