extends SceneTree
## Final stone-slab acceptance: observe the COMPLETE real home-exit
## choreography rather than calling its visual stages in isolation.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_stone_integrated.gd

const MapScene = preload("res://map.tscn")
const MapState = preload("res://systems/map_state.gd")
const Gather = preload("res://systems/map_shuffle_gather.gd")
const Layout = preload("res://systems/map_shuffle_layout.gd")
const SAVE_PATH = "user://stone_shuffle_final_qa.json"

var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS stone-integrated: ", description)
	else:
		failed += 1
		printerr("FAIL stone-integrated: ", description)


func new_observation() -> Dictionary:
	return {
		"predeparture": false, "travel": false, "rotation": false,
		"scatter": false, "reveal": false, "dust": false,
		"aura": false, "locks_ok": true, "die_ok": true,
		"no_dust_during_scatter": true, "max_visuals": 0,
		"max_dust_points": 0, "max_audio": [], "saw_shadows": false,
		"max_players": 0, "frame_count": 0
	}


func sample(map: Control, observation: Dictionary, original_face: int) -> void:
	if not is_instance_valid(map) or not is_instance_valid(map.stage):
		return
	var effect = null
	for child in map.stage.get_children():
		if child.get_script() == Gather:
			effect = child
			break
	if effect == null:
		return
	observation["frame_count"] = int(observation["frame_count"]) + 1
	if not map.moving or not map.dice.disabled:
		observation["locks_ok"] = false
	if map.world.last_face != original_face or map.dice.position != Vector2(602.0, 307.6):
		observation["die_ok"] = false
	observation["max_visuals"] = maxi(int(observation["max_visuals"]), effect.tile_visuals.size())
	if effect.tile_shadows.size() == 21:
		observation["saw_shadows"] = true
	observation["max_players"] = maxi(int(observation["max_players"]), effect.cue_players.size())
	if effect.played_audio_cues.size() > observation["max_audio"].size():
		observation["max_audio"] = effect.played_audio_cues.duplicate()
	if effect.predeparture_tween != null and effect.predeparture_tween.is_running():
		observation["predeparture"] = true
	if effect.gathering != null and effect.gathering.is_running():
		observation["travel"] = true
	if effect.rotation_tween != null and effect.rotation_tween.is_running():
		observation["rotation"] = true
	if effect.scatter_tween != null and effect.scatter_tween.is_running():
		observation["scatter"] = true
		if effect.dust_elapsed >= 0.0:
			observation["no_dust_during_scatter"] = false
	if effect.reveal_tween != null and effect.reveal_tween.is_running():
		observation["reveal"] = true
	if effect.dust_elapsed >= Gather.DUST_IMPACT_OFFSET:
		observation["dust"] = true
	if effect.dust_centers.size() > int(observation["max_dust_points"]):
		observation["max_dust_points"] = effect.dust_centers.size()
	if effect.aura_strength > 0.1:
		observation["aura"] = true


func finish_or_timeout(map: Control) -> bool:
	var started: int = Time.get_ticks_msec()
	while is_instance_valid(map) and map.moving and Time.get_ticks_msec() - started < 20000:
		await process_frame
	await process_frame
	return is_instance_valid(map) and not map.moving


func count_temp_nodes(map: Control) -> int:
	var n := 0
	if is_instance_valid(map.stage):
		for node in map.stage.get_children():
			if node.get_script() == Gather:
				n += 1
	return n


func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	if session == null:
		check(false, "RunSession autoload available")
		quit(1)
		return
	var previous_save_path: String = session.save_file_path
	session.save_file_path = SAVE_PATH
	session.start_new_world()
	session.world.position = MapState.HOME
	session.world.lap_ready = true
	check(session.save_world(), "dedicated integration test save created")
	var start_serial: int = session.world.map_serial
	var start_laps: int = session.world.laps
	var face: int = session.world.last_face
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(count_temp_nodes(map) == 0, "no stone clones on an idle map")

	var bus_sfx: int = AudioServer.get_bus_index("SFX")
	var bus_music: int = AudioServer.get_bus_index("Music")
	var initial_mutes: Array = [AudioServer.is_bus_mute(0), AudioServer.is_bus_mute(bus_music), AudioServer.is_bus_mute(bus_sfx)]
	var latest_success: Dictionary = {}
	for lap in range(2):
		session.world.position = MapState.HOME
		session.world.lap_ready = true
		var seen: Dictionary = new_observation()
		var monitor: Callable = sample.bind(map, seen, face)
		process_frame.connect(monitor)
		map.exit_home()
		map.exit_home()
		var completed: bool = await finish_or_timeout(map)
		process_frame.disconnect(monitor)
		check(completed, "lap %d full stone animation finished" % (lap + 1))
		if not completed:
			break
		latest_success = seen
		check(bool(seen["predeparture"]) and bool(seen["travel"]), "lap %d observes resistance tremor and gathering" % (lap + 1))
		check(bool(seen["rotation"]) and bool(seen["scatter"]), "lap %d observes heavy counterrotation and scatter" % (lap + 1))
		check(bool(seen["reveal"]) and bool(seen["dust"]), "lap %d observes actual slab landing and dust" % (lap + 1))
		check(bool(seen["aura"]) and bool(seen["saw_shadows"]), "lap %d observes magical glow and 21 contact shadows" % (lap + 1))
		check(seen["max_visuals"] == 21 and seen["max_dust_points"] == 21, "lap %d uses precisely 21 temporary stone/dust locations" % (lap + 1))
		check(seen["max_players"] == 3 and seen["max_audio"] == ["gather", "rotate", "land"], "lap %d plays exactly three stage effects, in order" % (lap + 1))
		check(bool(seen["no_dust_during_scatter"]), "lap %d never emits dust during horizontal travel" % (lap + 1))
		check(bool(seen["locks_ok"]) and bool(seen["die_ok"]), "lap %d keeps input locked and die unchanged during shuffle" % (lap + 1))
		check(count_temp_nodes(map) == 0 and not map.dice.disabled, "lap %d cleans visuals, audio, dust and restores input" % (lap + 1))
		check(session.world.map_serial == start_serial + lap + 1 and session.world.laps == start_laps + lap + 1, "lap %d saves one world update despite duplicate taps" % (lap + 1))
		check(AudioServer.is_bus_mute(0) == initial_mutes[0] and AudioServer.is_bus_mute(bus_music) == initial_mutes[1] and AudioServer.is_bus_mute(bus_sfx) == initial_mutes[2], "lap %d preserves all sound bus mute settings" % (lap + 1))

	# Failed writes must not trigger any of the three impact visuals/sounds.
	if failed == 0:
		session.world.position = MapState.HOME
		session.world.lap_ready = true
		var expected: Dictionary = session.world.snapshot().duplicate(true)
		session.save_file_path = "user://nonexistent_stone_shuffle_final_qa/blocked.json"
		var rollback: Dictionary = new_observation()
		var failed_monitor: Callable = sample.bind(map, rollback, face)
		process_frame.connect(failed_monitor)
		map.exit_home()
		var done: bool = await finish_or_timeout(map)
		process_frame.disconnect(failed_monitor)
		check(done, "failed-save transition exits safely")
		check(bool(rollback["predeparture"]) and bool(rollback["rotation"]), "failed-save transition still protects its pre-save stages")
		check(not rollback["scatter"] and not rollback["dust"], "save failure never reveals a false new board or dust")
		check(rollback["max_audio"] == ["gather", "rotate"], "failed save cannot trigger heavy landing audio")
		check(session.world.snapshot() == expected, "save failure restores full authoritative world")
		check(not map.moving and not map.dice.disabled and count_temp_nodes(map) == 0, "save failure releases all input/scene resources")
		check(is_instance_valid(map.overlay), "save failure returns to home so player can retry")

	map.queue_free()
	await process_frame
	session.save_file_path = SAVE_PATH
	session.reload_world()
	check(session.world.map_serial == start_serial + 2 and session.world.laps == start_laps + 2, "last successful stone laps reload from disk")
	check(session.world.tiles.size() == 24 and session.world.last_face == face, "24 board tiles and die result survive reload")
	session.save_file_path = previous_save_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("MAP_SHUFFLE_STONE_INTEGRATED: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
