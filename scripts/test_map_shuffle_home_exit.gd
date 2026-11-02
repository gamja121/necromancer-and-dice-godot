extends SceneTree
## Full home-exit smoke: real Map scene, actual RunSession save, and failure rollback.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_home_exit.gd

const MapScene = preload("res://map.tscn")
const MapState = preload("res://systems/map_state.gd")
const RoutePlan = preload("res://systems/route_plan.gd")
const Discovery = preload("res://systems/location_discoveries.gd")
var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS shuffle-home: ", label)
	else:
		failed += 1
		printerr("FAIL shuffle-home: ", label)


func wait_for_shuffle(map: Control, timeout_msec: int = 12000) -> bool:
	var start: int = Time.get_ticks_msec()
	while map.moving and Time.get_ticks_msec() - start < timeout_msec:
		await process_frame
	return not map.moving


func panel_button(map: Control, title: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for child in map.overlay.get_children():
		if child is Button and child.text==title: return child
	return null

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	if session == null:
		check(false, "RunSession autoload exists")
		quit(1)
		return
	var initial_save_path: String = session.save_file_path
	var test_save_path := "user://map_shuffle_exit_regression.json"
	session.save_file_path = test_save_path
	session.start_new_world()
	session.world.position = MapState.HOME
	session.world.lap_ready = true
	check(session.save_world(), "starting state persisted")
	var prior_serial: int = session.world.map_serial
	var prior_laps: int = session.world.laps
	var prior_dice_face: int = session.world.last_face
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(map.buttons.size() == 24, "24 live map buttons available")
	check(map.dice != null and not map.dice.disabled, "map dice initially interactive")
	print("HOME_SHUFFLE_TEST: start successful home exit")
	map.exit_home()
	var first_completed: bool = await wait_for_shuffle(map)
	check(first_completed, "successful home exit animation completes")
	if not first_completed:
		print("MAP_SHUFFLE_HOME_EXIT: %d passed, %d failed" % [passed, failed])
		quit(1)
		return
	check(session.world.map_serial == prior_serial + 1, "leaving home generated one new map")
	check(session.world.laps == prior_laps + 1, "completed lap counted once")
	check(map.world == session.world, "view is bound to committed world")
	check(not map.moving and not map.dice.disabled, "map input unlocked after reveal")
	check(map.buttons.size() == 24, "all 24 live map buttons rebuilt")
	var imagery_correct := true
	for i in range(map.buttons.size()):
		if not map.buttons[i].visible or map.buttons[i].texture_normal != map.texture(map.tile_path(i)):
			imagery_correct = false
	check(imagery_correct, "every tile matches current saved board after reveal")
	check(int(session.world.last_face) == prior_dice_face and map.dice.texture_normal == map.texture("res://assets/battle/dice/result-%02d.png" % prior_dice_face), "dice face unchanged")
	check(not is_instance_valid(map.overlay), "no location panel remains after success")
	check(map.status.text.begins_with("새 경로"), "new-map success message shown")

	# Saving to a non-existent directory must fail and roll back the map state.
	var before: Dictionary = session.world.snapshot().duplicate(true)
	var before_image: Array = []
	for tile in map.buttons:
		before_image.append(tile.texture_normal)
	session.save_file_path = "user://missing_shuffle_home_exit_directory/invalid.json"
	print("HOME_SHUFFLE_TEST: start failed-save home exit")
	map.exit_home()
	var second_completed: bool = await wait_for_shuffle(map)
	check(second_completed, "failed-save home exit animation completes")
	if not second_completed:
		print("MAP_SHUFFLE_HOME_EXIT: %d passed, %d failed" % [passed, failed])
		quit(1)
		return
	check(session.world.map_serial == before.map_serial and session.world.tiles == before.tiles, "failed disk save restores original map data")
	check(map.buttons.size() == 24 and map.buttons.all(func(tile): return tile.visible), "all 24 original tiles visible after failure")
	var unchanged_images := true
	for i in range(before_image.size()):
		if map.buttons[i].texture_normal != before_image[i]:
			unchanged_images = false
	check(unchanged_images, "failed save does not expose any new tile face")
	check(not map.moving and map.dice.disabled, "failed save releases motion lock but home retry modal blocks die input")
	check(is_instance_valid(map.overlay), "failed save restores home window for retry")
	check(map.status.text.contains("저장"), "failed save shows a storage error")
	var saving_warning: Control=map.overlay.get_node_or_null("HomeDepartureFeedback")
	check(saving_warning!=null and saving_warning.get_node("HomeDepartureReason").text.contains("저장"),
		"save rejection is visible directly inside the home painting")
	map.close_overlay()
	check(not map.dice.disabled, "closing retry modal returns map die input")

	# A saved six-stone patrol can become over capacity when earned places and
	# swamp reservations appear. The player must see WHY exit is blocked and
	# enter the route editor directly, without changing or resetting the save.
	session.save_file_path=test_save_path
	var world = session.world
	world.position=MapState.HOME
	world.lap_ready=true
	world.contamination=30
	world.patrol_plan=RoutePlan.default_plan()
	world.patrol_plan.selection.monster=6
	for kind in ["forest","unknown","altar"]:
		world.event_flags[Discovery.unlock_flag(kind)]=true
	var invalid_preview: Dictionary=world.patrol_preview(world.patrol_plan)
	check(not bool(invalid_preview.valid) and int(invalid_preview.selected)>int(invalid_preview.capacity),
		"earned locations reduce usable optional capacity below an older six-stone plan")
	var invalid_before: Dictionary=world.snapshot().duplicate(true)
	map.show_home()
	var depart: Button=panel_button(map,"다음 바퀴 출발")
	check(depart!=null and not depart.disabled,"blocked route still shows a clickable departure button")
	if depart!=null:
		depart.pressed.emit()
		check(is_instance_valid(map.overlay) and not map.moving,
			"invalid departure keeps the house open and does not lock input")
		var warning: Control=map.overlay.get_node_or_null("HomeDepartureFeedback")
		check(warning!=null and warning.get_node("HomeDepartureReason").text.contains(str(invalid_preview.reason)),
			"patrol rejection reason is readable above the home actions")
		var repair: Button=panel_button(map,"순찰경로 수정")
		check(repair!=null and not repair.disabled,"home provides direct repair for an invalid patrol")
		check(world.snapshot()==invalid_before,"invalid departure preserves map, RNG and all saved game state")
		if repair!=null:
			repair.pressed.emit()
			check(is_instance_valid(map.overlay) and map.overlay.get_script()!=null
				and map.overlay.get_script().resource_path.ends_with("exploration_actions.gd"),
				"repair button enters the actual home route editor")
			map.close_overlay()
	map.queue_free()
	session.save_file_path = initial_save_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	print("MAP_SHUFFLE_HOME_EXIT: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
