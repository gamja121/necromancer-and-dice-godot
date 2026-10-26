extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_unlock_notice_badge.gd
const Session = preload("res://systems/run_session.gd")
const MapState = preload("res://systems/map_state.gd")
const MapScene = preload("res://map.tscn")
const ExplorationActions = preload("res://systems/exploration_actions.gd")
const Notice = preload("res://systems/unlock_notice_badge.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS unlock-notice: ", label)
	else:
		failed += 1
		printerr("FAIL unlock-notice: ", label)

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var owned: bool = session == null
	if owned:
		session = Session.new()
		session.name = "RunSession"
		root.add_child(session)
	var prior_path: String = session.save_file_path
	var scratch: String = "user://unlock_notice_%d.json" % OS.get_process_id()
	session.save_file_path = scratch
	session.start_new_world()
	check(not session.event_flag_is_set(Notice.REST_TILE_PENDING) and not session.event_flag_is_set(Notice.REST_ACTION_PENDING), "new expedition shows no fabricated badge")
	# Complete the first patrol to enable the existing real unlock action.
	session.world.position = MapState.HOME
	session.world.laps = 1
	check(session.unlock_rest_tile().ok,"genuine home action grants rest unlock")
	check(session.event_flag_is_set(Notice.REST_TILE_PENDING) and session.event_flag_is_set(Notice.REST_ACTION_PENDING), "unlock creates both pending notifications in save")
	session.reload_world()
	check(session.event_flag_is_set(Notice.REST_TILE_PENDING) and session.event_flag_is_set(Notice.REST_ACTION_PENDING), "unread notifications survive reload")

	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	var panel := ExplorationActions.new()
	root.add_child(panel)
	panel.setup(map,MapState.HOME)
	var rest_choice: Button = panel.route_plus_buttons.get("rest") as Button
	check(rest_choice != null and panel.route_editor.station_badges.rest.visible, "home patrol rest choice shows NEW after legitimate unlock")
	if rest_choice != null:
		var rest_badge: Control = panel.route_editor.station_badges.rest as Control
		check(not rest_choice.disabled and rest_badge != null and rest_badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "unlocked rest choice is interactive and NEW badge does not intercept clicks")
	panel.queue_free()
	await process_frame
	# Place the real unlocked rest terrain on the next board, without a test UI.
	session.world.patrol_plan["selection"]["rest"] = 1
	session.world.generate()
	var rest_index: int = session.world.tiles.find("rest")
	check(rest_index >= 0, "newly unlocked rest is placed on generated board")
	map.queue_free()
	await process_frame
	map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(rest_index >= 0 and map.buttons[rest_index].get_node_or_null("UnlockNewBadge") != null, "actual board tile shows NEW badge")
	check(map.buttons[rest_index].get_node("UnlockNewBadge").mouse_filter == Control.MOUSE_FILTER_IGNORE, "tile badge never intercepts input")
	# First location view acknowledges the tile, not the new action.
	map.show_location(rest_index)
	await process_frame
	var heal: Button = map.overlay.find_child("RestHealAction",true,false)
	check(not session.event_flag_is_set(Notice.REST_TILE_PENDING), "view acknowledges tile exactly once")
	check(session.event_flag_is_set(Notice.REST_ACTION_PENDING), "viewing tile does not consume NEW action")
	check(heal != null and heal.get_node_or_null("UnlockNewBadge") != null, "inside-location heal button shows NEW")
	check(heal.get_node("UnlockNewBadge").mouse_filter == Control.MOUSE_FILTER_IGNORE, "button badge does not intercept clicks")
	check(not map.buttons[rest_index].get_node("UnlockNewBadge").visible, "already-read board label hides without regenerating board")
	# Actual use acknowledges the action atomically with the original heal.
	session.world.roster[0]["current_hp"] = maxi(1,int(session.world.roster[0]["max_hp"])-1)
	check(session.heal_at_rest(rest_index).ok, "original whole-party recovery still works")
	check(not session.event_flag_is_set(Notice.REST_ACTION_PENDING), "successful action acknowledges its NEW badge")
	session.reload_world()
	check(not session.event_flag_is_set(Notice.REST_TILE_PENDING) and not session.event_flag_is_set(Notice.REST_ACTION_PENDING), "both acknowledgements survive restart")
	map.queue_free()
	await process_frame
	# Failure to persist a grant must roll back both badges and the unlock.
	session.start_new_world()
	session.world.laps = 1
	session.world.position = MapState.HOME
	var before: Dictionary = session.world.snapshot().duplicate(true)
	session.save_file_path = "user://missing_unlock_badge_dir/no_write.json"
	var denied: Dictionary = session.unlock_rest_tile()
	check(not bool(denied.get("ok",false)) and session.world.snapshot()==before, "failed save cannot leak unlock or NEW markers")
	session.save_file_path = scratch
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	session.save_file_path = prior_path
	if owned: session.queue_free()
	print("UNLOCK_NOTICE_BADGE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
