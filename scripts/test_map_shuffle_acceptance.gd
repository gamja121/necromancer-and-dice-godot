extends SceneTree
## Final map-shuffle acceptance: repeated laps, duplicate input, save rollback,
## cleaned visuals/audio and readback of the persisted world.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_acceptance.gd

const MapScene = preload("res://map.tscn")
const MapState = preload("res://systems/map_state.gd")
const Gather = preload("res://systems/map_shuffle_gather.gd")
const ROUNDS = 3
const STATE_KEYS = [
	"tiles", "map_serial", "laps", "contamination", "rng_seed",
	"rng_state", "last_face", "position", "lap_ready", "event_flags",
	"story_events"
]

var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS shuffle-acceptance: ", label)
	else:
		failed += 1
		printerr("FAIL shuffle-acceptance: ", label)


func active_shuffle_count(map: Control) -> int:
	if not is_instance_valid(map.stage):
		return -1
	var count := 0
	for node in map.stage.get_children():
		if node.get_script() == Gather:
			count += 1
	return count


func await_end(map: Control) -> bool:
	var begin: int = Time.get_ticks_msec()
	while map.moving and Time.get_ticks_msec() - begin < 16000:
		await process_frame
	await process_frame
	return not map.moving


func board_matches(map: Control) -> bool:
	if map.buttons.size() != MapState.centers().size():
		return false
	for i in range(map.buttons.size()):
		if not map.buttons[i].visible:
			return false
		if map.buttons[i].texture_normal != map.texture(map.tile_path(i)):
			return false
	return true


func consistent_state(before: Dictionary, after: Dictionary) -> bool:
	for key in STATE_KEYS:
		if before.get(key) != after.get(key):
			return false
	return true


func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	if session == null:
		check(false, "RunSession autoload is accessible")
		quit(1)
		return
	var original_save_path: String = session.save_file_path
	var test_path := "user://map_shuffle_final_acceptance.json"
	# The entire test uses a dedicated file; never touch the player's save.
	session.save_file_path = test_path
	session.start_new_world()
	session.world.position = MapState.HOME
	session.world.lap_ready = true
	check(session.save_world(), "initial test world is persisted")
	var initial_serial: int = session.world.map_serial
	var initial_laps: int = session.world.laps
	var initial_contamination: int = session.world.contamination
	var original_dice_face: int = session.world.last_face
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(active_shuffle_count(map) == 0, "no temporary shuffle before exit")

	for lap in range(ROUNDS):
		session.world.position = MapState.HOME
		session.world.lap_ready = true
		map.exit_home()
		var number := lap + 1
		check(map.moving and map.dice.disabled, "round %d locks input immediately" % number)
		check(active_shuffle_count(map) == 1, "round %d has exactly one live shuffle" % number)
		# A second click must be ignored while the first is still awaiting.
		map.exit_home()
		check(active_shuffle_count(map) == 1, "round %d ignores rapid duplicate click" % number)
		var finished: bool = await await_end(map)
		check(finished, "round %d completes without a stuck transition" % number)
		if not finished:
			break
		check(session.world.map_serial == initial_serial + number, "round %d increments map serial only once" % number)
		check(session.world.laps == initial_laps + number, "round %d counts only one completed lap" % number)
		check(session.world.contamination == mini(100, initial_contamination + 7 * number), "round %d advances contamination once" % number)
		check(not map.moving and not map.dice.disabled, "round %d restores dice input" % number)
		check(not is_instance_valid(map.overlay), "round %d closes the home overlay" % number)
		check(map.world == session.world and board_matches(map), "round %d shows the committed board" % number)
		check(session.world.last_face == original_dice_face, "round %d retains the previous dice result" % number)
		check(active_shuffle_count(map) == 0, "round %d removes cloned tiles, shadows and audio nodes" % number)
		check(map.status.text.begins_with("새 경로"), "round %d displays completion feedback" % number)

	# A failed physical save must not expose a regenerated world or leave the
	# player stuck behind an invisible input lock.
	if failed == 0:
		session.world.position = MapState.HOME
		session.world.lap_ready = true
		var before: Dictionary = session.world.snapshot().duplicate(true)
		session.save_file_path = "user://missing_map_shuffle_final_qa_directory/forbidden.json"
		map.exit_home()
		map.exit_home()
		var failed_save_completed: bool = await await_end(map)
		check(failed_save_completed, "failed-save transition finishes and unlocks the board")
		check(consistent_state(before, session.world.snapshot()), "failed save restores tiles, RNG, laps and dice result")
		check(map.world == session.world and board_matches(map), "failed save keeps old board imagery")
		check(active_shuffle_count(map) == 0, "failed save leaves no temporary visual or sound layers")
		check(not map.moving and not map.dice.disabled, "failed save restores input and dice")
		check(is_instance_valid(map.overlay), "failed save presents home panel for retry")
		check(map.status.text.contains("저장"), "failed save reports the save error")

	# Read back the independently persisted file, not just the in-memory copy.
	map.queue_free()
	await process_frame
	session.save_file_path = test_path
	var expected_serial: int = initial_serial + ROUNDS
	var expected_laps: int = initial_laps + ROUNDS
	session.reload_world()
	check(session.world.map_serial == expected_serial, "reloaded save keeps all committed map changes")
	check(session.world.laps == expected_laps, "reloaded save keeps all committed laps")
	check(session.world.last_face == original_dice_face, "reloaded save keeps original die face")
	check(session.world.tiles.size() == 24, "reloaded save has exactly 24 map tiles")

	session.save_file_path = original_save_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("MAP_SHUFFLE_ACCEPTANCE: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
