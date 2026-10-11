extends SceneTree
## Real boss-threshold shuffle acceptance: 16 -> 20, saved board, failed save.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_boss_integration.gd

const MapScene = preload("res://map.tscn")
const MapState = preload("res://systems/map_state.gd")
var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS boss-shuffle-integrated: ", label)
	else:
		failed += 1
		printerr("FAIL boss-shuffle-integrated: ", label)


func wait_for_shuffle(map: Control, timeout_msec: int = 18000) -> bool:
	var started: int = Time.get_ticks_msec()
	while map.moving and Time.get_ticks_msec() - started < timeout_msec:
		await process_frame
	return not map.moving


func board_matches_world(map: Control) -> bool:
	if map.buttons.size() != 24:
		return false
	for i in range(24):
		if not map.buttons[i].visible or map.buttons[i].texture_normal != map.texture(map.tile_path(i)):
			return false
	return true


func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	if session == null:
		check(false, "RunSession is available")
		quit(1)
		return
	var old_path: String = session.save_file_path
	var test_path := "user://boss_shuffle_integration.json"
	session.save_file_path = test_path
	session.start_new_world()
	session.world.contamination = 16
	session.world.position = MapState.HOME
	session.world.lap_ready = true
	check(session.save_world(), "contamination-16 fixture stored on disk")
	var before: Dictionary = session.world.snapshot().duplicate(true)
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(session.world.tiles[23] == "monster" and map.buttons[23].texture_normal == map.texture("res://assets/map/tiles/monster.png"), "future boss slot starts with ordinary monster")
	map.exit_home()
	check(map.moving and map.dice.disabled, "input is immediately locked during threshold shuffle")
	map.exit_home()
	var finished: bool = await wait_for_shuffle(map)
	check(finished, "threshold shuffle and scatter finish without deadlock")
	if not finished:
		session.save_file_path = old_path
		print("MAP_SHUFFLE_BOSS_INTEGRATION: %d passed, %d failed" % [passed,failed])
		quit(1)
		return
	check(session.world.contamination == 20 and session.world.laps == int(before.laps) + 1, "16 to 20 crosses exactly once")
	check(session.world.map_serial == int(before.map_serial) + 1, "duplicate exit did not reroll map")
	check(session.world.tiles.size() == 24 and session.world.tiles.count("boss") == 1 and session.world.tiles[23] == "boss", "one boss in reserved 24th slot")
	check(session.world.tiles[0] == "fortune-teller-camp" and session.world.tiles[8] == "village" and session.world.tiles[15] == "home", "three fixed landmarks unchanged")
	check(map.world == session.world and board_matches_world(map), "every revealed tile matches committed gameplay board")
	check(map.buttons[23].texture_normal == map.texture("res://assets/map/tiles/boss.png") and map.buttons[23].tooltip_text.contains("보스"), "boss texture and label become visible after stone flip")
	check(map.status.text.contains("보스 타일 출현"), "threshold appearance message is shown")
	check(not map.moving and not map.dice.disabled and not is_instance_valid(map.overlay), "control and overlay recover after success")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.contamination == 20 and session.world.tiles[23] == "boss" and session.world.map_serial == int(before.map_serial) + 1, "boss and layout survive full disk reload")

	# Retry the same 16 -> 20 transition with a failing physical save.
	# Rewind peak only for this synthetic failure fixture, not in live play.
	session.world.boss_peak = 16
	session.world.contamination = 16
	session.world.generate()
	session.world.position = MapState.HOME
	session.world.lap_ready = true
	check(session.save_world(), "new failure fixture stored on disk")
	var rollback_before: Dictionary = session.world.snapshot().duplicate(true)
	var failure_map = MapScene.instantiate()
	root.add_child(failure_map)
	await process_frame
	check(failure_map.buttons[23].texture_normal == failure_map.texture("res://assets/map/tiles/monster.png"), "failure fixture has no premature boss")
	session.save_file_path = "user://missing_boss_shuffle_integration_dir/not_writable.json"
	failure_map.exit_home()
	var rollback_finished: bool = await wait_for_shuffle(failure_map)
	check(rollback_finished, "save failure exits animation cleanly")
	if not rollback_finished:
		session.save_file_path = old_path
		print("MAP_SHUFFLE_BOSS_INTEGRATION: %d passed, %d failed" % [passed,failed])
		quit(1)
		return
	var rolled: Dictionary = session.world.snapshot().duplicate(true)
	check(rolled == rollback_before, "failed transaction restores tiles, contamination, RNG, lap and progress")
	check(session.world.tiles[23] == "monster" and session.world.tiles.count("boss") == 0, "failed save never exposes new boss in gameplay")
	check(board_matches_world(failure_map) and failure_map.buttons[23].texture_normal == failure_map.texture("res://assets/map/tiles/monster.png"), "failed save keeps original 24 stone faces on screen")
	check(not failure_map.moving and not failure_map.dice.disabled and is_instance_valid(failure_map.overlay), "failure restores input and home retry panel")
	check(failure_map.status.text.contains("저장"), "failure is reported to the player")
	failure_map.queue_free()
	await process_frame
	session.save_file_path = test_path
	session.reload_world()
	check(session.world.snapshot() == rollback_before, "disk still holds previous valid world without boss")
	session.save_file_path = old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("MAP_SHUFFLE_BOSS_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
