extends SceneTree
## Staged boss tiles at contamination 20/40/60, with story-locked final at 80:
## persistence migration, no duplicates and safe disk rollback.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_boss_threshold.gd

const MapState = preload("res://systems/map_state.gd")
const MapScene = preload("res://map.tscn")
const StoryFixture = preload("res://scripts/boss_story_test_fixture.gd")
var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, name: String) -> void:
	if ok:
		passed += 1
		print("PASS boss-threshold: ", name)
	else:
		failed += 1
		printerr("FAIL boss-threshold: ", name)


func boss_count(tiles: Array) -> int:
	return tiles.count("boss")


func _run() -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var state = MapState.new(definitions,1201)
	check(MapState.BOSS_CONTAMINATION == 80, "boss unlock exactly at contamination 80")
	check(MapState.BOSS_TILE_INDEX == 23, "canonical boss icon at existing 24th slot")
	check(ResourceLoader.exists("res://assets/map/tiles/boss.png"), "existing boss stone tile art exists")
	for corruption in [0,16,19]:
		state.contamination = corruption
		state.generate()
		check(boss_count(state.tiles) == 0, "no premature boss at contamination %d" % corruption)
		check(state.tiles[0] == "fortune-teller-camp" and state.tiles[8] == "village" and state.tiles[15] == "home", "fixed tile types retained below 20")
	for corruption in [20,39,40,59,60,79]:
		state.contamination=corruption
		state.generate()
		check(state.tiles[23]=="boss" and state.boss_available(),"unbeaten stage appears at %d corruption" % corruption)
	for corruption in [80,100]:
		state.contamination=corruption
		state.generate()
		check(state.tiles[23]!="boss" and not state.boss_available(),"even max contamination cannot bypass the final story")
	StoryFixture.seed_completed_final_hunt(state,false)
	state.contamination=80
	state.generate()
	check(state.tiles[23]!="boss","final quest is not enough before last scene Finish")
	state.event_flags["event:monster_king_hunt_trace_01:final_acknowledged"]=true
	for corruption in [80,81,99,100]:
		state.contamination = corruption
		state.generate()
		check(state.tiles[23] == "boss" and boss_count(state.tiles) == 1, "exactly one boss tile at contamination %d" % corruption)
		check(state.tiles.size() == 24 and state.tiles[0] == "fortune-teller-camp" and state.tiles[8] == "village" and state.tiles[15] == "home", "24-slot geometry unchanged at %d" % corruption)
		check(state.tiles.count("monster") >= 4, "one existing monster slot replaced; no missing tiles at %d" % corruption)

	state.mark_boss_defeated(60)
	state.contamination = 79
	state.generate()
	state.cleared.append(23)
	state.scout = {"scouted":true,"intel":[{"index":23,"type":state.tiles[23],"count":1,"grade":"normal","legion":"skeleton"}]}
	var unchanged: Array = state.tiles.slice(0,23).duplicate()
	state.contamination = 80
	check(state.reveal_boss_at_threshold(), "crossing threshold reveals boss in current lap")
	check(state.tiles[23]=="boss" and state.tiles.count("event")==pre_hide.count("event") and state.tiles[0]=="fortune-teller-camp" and state.tiles[8]=="village" and state.tiles[15]=="home","midlap conversion preserves existing event count and fixed tiles even when relocating an event from the new boss slot")
	check(not 23 in state.cleared and state.scout.intel.is_empty(), "stale cleared/scout data removed at converted slot")
	check(not state.reveal_boss_at_threshold() and boss_count(state.tiles) == 1, "second threshold check is idempotent")
	var pre_hide: Array = state.tiles.duplicate(true)
	var saved_rng: int = state.rng.state
	state.contamination = 79
	check(state.conceal_boss_below_threshold(),"purification immediately hides boss under 80")
	check(state.tiles[23]=="monster" and state.tiles.slice(0,23)==pre_hide.slice(0,23),"retirement replaces only boss stone with a monster")
	check(state.rng.state==saved_rng and not state.conceal_boss_below_threshold(),"no reroll or duplicate replacement when retiring")
	state.contamination = 80
	check(state.reveal_boss_at_threshold(),"returning to 80 reveals boss again")
	var snapshot: Dictionary = state.snapshot().duplicate(true)
	var restored = MapState.new(definitions,999)
	check(restored.restore(snapshot) and restored.tiles[23] == "boss", "boss reveal survives snapshot restore")
	check(restored.rng.state == state.rng.state, "boss conversion does not reroll RNG")

	var session = root.get_node_or_null("RunSession")
	if session == null:
		check(false, "RunSession available")
		quit(1)
		return
	var old_path: String = session.save_file_path
	var test_path := "user://boss_threshold_acceptance.json"
	session.save_file_path = test_path
	session.start_new_world()
	StoryFixture.seed_completed_final_hunt(session.world)
	# Lap contamination is +7: start at 73 to cross the boss gate exactly at 80.
	session.world.contamination = 73
	session.world.position = MapState.HOME
	session.world.lap_ready = true
	check(session.save_world(), "dedicated test save prepared")
	var old_serial: int = session.world.map_serial
	var before_laps: int = session.world.laps
	var success: bool = session.leave_home()
	check(success, "home exit commits across contamination 80")
	check(session.world.contamination == 80 and session.world.laps == before_laps + 1, "contamination reaches 80 on expected lap")
	check(session.world.tiles[23] == "boss" and boss_count(session.world.tiles) == 1, "boss appears automatically in newly shuffled layout")
	check(session.world.map_serial == old_serial + 1, "map serial increases just once")
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(map.buttons.size() == 24 and map.buttons[23].texture_normal == map.texture("res://assets/map/tiles/boss.png"), "live Godot map draws correct boss texture")
	check(map.buttons[23].tooltip_text.contains("보스"), "boss tile presents correct readable tooltip")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.contamination == 80 and session.world.tiles[23] == "boss", "boss tile persists across full session reload")

	# Old 20-79 saves may contain a premature boss: remove it without reroll.
	session.world.contamination = 24
	session.world.generate()
	session.world.tiles[23] = "boss"
	session.world.cleared.append(23)
	var last_map: Array = session.world.tiles.slice(0,23).duplicate(true)
	var original_serial: int = session.world.map_serial
	check(session.save_world(), "older pre-threshold snapshot stored")
	session.reload_world()
	check(session.world.tiles[23] == "monster" and session.world.tiles.slice(0,23) == last_map, "old cleared stage-20 boss remains gone after restore")
	check(session.world.map_serial == original_serial, "migration does not generate a new board")

	# A failed write must undo contamination AND boss appearance atomically.
	session.world.contamination = 79
	session.world.generate()
	var before_failure: Dictionary = session.world.snapshot().duplicate(true)
	session.save_file_path = "user://missing_boss_threshold_directory/cannot_write.json"
	session.world.contamination = 80
	check(not session.persist_change(before_failure), "disk write refusal is reported")
	check(session.world.contamination == 79 and session.world.tiles == before_failure.tiles, "failed write fully rolls back boss appearance and contamination")
	check(session.world.rng.state == int(before_failure.rng_state), "failed write restores randomized map state")
	session.save_file_path = test_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	session.save_file_path = old_path
	print("MAP_SHUFFLE_BOSS_THRESHOLD: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
