extends SceneTree
## Boss tile at contamination 20: natural shuffle, mid-lap crossing,
## persistence migration, no duplicates and safe disk rollback.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_boss_threshold.gd

const MapState = preload("res://systems/map_state.gd")
const MapScene = preload("res://map.tscn")
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
	check(MapState.BOSS_CONTAMINATION == 20, "boss unlock exactly at contamination 20")
	check(MapState.BOSS_TILE_INDEX == 23, "canonical boss icon at existing 24th slot")
	check(ResourceLoader.exists("res://assets/map/tiles/boss.png"), "existing boss stone tile art exists")
	for corruption in [0,16,19]:
		state.contamination = corruption
		state.generate()
		check(boss_count(state.tiles) == 0, "no premature boss at contamination %d" % corruption)
		check(state.tiles[23] == "monster" and state.tiles.count("monster") == 5, "future boss slot reserves a normal monster below 20")
		check(state.tiles[0] == "fortune-teller-camp" and state.tiles[8] == "village" and state.tiles[15] == "home", "fixed tile types retained below 20")
	for corruption in [20,21,39,40,79,80,100]:
		state.contamination = corruption
		state.generate()
		check(state.tiles[23] == "boss" and boss_count(state.tiles) == 1, "exactly one boss tile at contamination %d" % corruption)
		check(state.tiles.size() == 24 and state.tiles[0] == "fortune-teller-camp" and state.tiles[8] == "village" and state.tiles[15] == "home", "24-slot geometry unchanged at %d" % corruption)
		check(state.tiles.count("monster") >= 4, "one existing monster slot replaced; no missing tiles at %d" % corruption)
		check(state.tiles.count("monster") + boss_count(state.tiles) == (5 if corruption < 40 else (6 if corruption < 80 else 7)), "only an ordinary monster converts to boss at %d" % corruption)

	# Independent threshold fixture; unlike a live run, clear the previous peak.
	state.boss_peak = 19
	state.contamination = 19
	state.generate()
	state.cleared.append(23)
	state.scout = {"scouted":true,"intel":[{"index":23,"type":state.tiles[23],"count":1,"grade":"normal","legion":"skeleton"}]}
	var unchanged: Array = state.tiles.slice(0,23).duplicate()
	state.contamination = 20
	check(state.reveal_boss_at_threshold(), "crossing threshold reveals boss in current lap")
	check(state.tiles[23] == "boss" and state.tiles.slice(0,23) == unchanged, "midlap conversion preserves every other tile")
	check(not 23 in state.cleared and state.scout.intel.is_empty(), "stale cleared/scout data removed at converted slot")
	check(not state.reveal_boss_at_threshold() and boss_count(state.tiles) == 1, "second threshold check is idempotent")
	var snapshot: Dictionary = state.snapshot().duplicate(true)
	var restored = MapState.new(definitions,999)
	check(restored.restore(snapshot) and restored.tiles[23] == "boss", "boss reveal survives snapshot restore")
	check(restored.rng.state == state.rng.state, "boss conversion does not reroll RNG")

	# Historical boards can have special tiles in the last slot.
	state.boss_peak = 19
	state.contamination = 19
	state.generate()
	state.tiles[23] = "event"
	state.contamination = 20
	var protected_tiles: Array = state.tiles.duplicate()
	var protected_rng: int = state.rng.state
	check(not state.reveal_boss_at_threshold(), "legacy special tile is not overwritten")
	check(state.tiles == protected_tiles and state.rng.state == protected_rng, "deferred reveal preserves every saved position and RNG")

	var session = root.get_node_or_null("RunSession")
	if session == null:
		check(false, "RunSession available")
		quit(1)
		return
	var old_path: String = session.save_file_path
	var test_path := "user://boss_threshold_acceptance.json"
	session.save_file_path = test_path
	session.start_new_world()
	session.world.contamination = 16
	session.world.position = MapState.HOME
	session.world.lap_ready = true
	check(session.save_world(), "dedicated test save prepared")
	var old_serial: int = session.world.map_serial
	var before_laps: int = session.world.laps
	var success: bool = session.leave_home()
	check(success, "home exit commits across contamination 20")
	check(session.world.contamination == 20 and session.world.laps == before_laps + 1, "contamination reaches 20 on expected lap")
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
	check(session.world.contamination == 20 and session.world.tiles[23] == "boss", "boss tile persists across full session reload")

	# Old 80-threshold saves can upgrade a normal monster without reroll.
	session.world.contamination = 24
	session.world.generate()
	session.world.tiles[23] = "monster"
	var last_map: Array = session.world.tiles.slice(0,23).duplicate(true)
	var original_serial: int = session.world.map_serial
	check(session.save_world(), "older monster-slot snapshot stored")
	session.reload_world()
	check(session.world.tiles[23] == "boss" and session.world.tiles.slice(0,23) == last_map, "safe old saves upgrade only the reserved monster slot")
	check(session.world.map_serial == original_serial, "migration does not generate a new board")

	# Protect the position and event state of legacy non-monster slot 24.
	var event_index: int = session.world.tiles.find("event")
	check(event_index >= 0, "legacy fixture contains an event")
	if event_index >= 0:
		session.world.tiles[event_index] = "monster"
		session.world.tiles[23] = "event"
	var legacy_tiles: Array = session.world.tiles.duplicate()
	var legacy_serial: int = session.world.map_serial
	check(session.save_world(), "legacy special-tile save prepared")
	session.reload_world()
	check(session.world.tiles == legacy_tiles and session.world.map_serial == legacy_serial, "reload keeps legacy event and all saved positions")
	session.world.position = MapState.HOME
	session.world.lap_ready = true
	check(session.leave_home(), "next home shuffle is persisted")
	check(session.world.tiles[23] == "boss" and boss_count(session.world.tiles) == 1, "legacy save reveals boss on next shuffle")

	# A failed write must undo contamination AND boss appearance atomically.
	session.world.boss_peak = 19
	session.world.contamination = 19
	session.world.generate()
	var before_failure: Dictionary = session.world.snapshot().duplicate(true)
	session.save_file_path = "user://missing_boss_threshold_directory/cannot_write.json"
	session.world.contamination = 20
	check(not session.persist_change(before_failure), "disk write refusal is reported")
	check(session.world.contamination == 19 and session.world.tiles == before_failure.tiles, "failed write fully rolls back boss appearance and contamination")
	check(session.world.rng.state == int(before_failure.rng_state), "failed write restores randomized map state")
	session.save_file_path = test_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	session.save_file_path = old_path
	print("MAP_SHUFFLE_BOSS_THRESHOLD: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
