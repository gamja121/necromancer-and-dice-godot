extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_hill_unlocked_patrol_choice.gd
## Real discovery -> HOME slot/choice buttons -> next board -> reload.
const MAP = preload("res://map.tscn")
const Session = preload("res://systems/run_session.gd")
const RouteUI = preload("res://systems/exploration_actions.gd")
const Plan = preload("res://systems/route_plan.gd")
const State = preload("res://systems/map_state.gd")
const Discovery = preload("res://systems/location_discoveries.gd")
var pass_count: int = 0
var fail_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, name: String) -> void:
	if condition:
		pass_count += 1
		print("PASS hill-edit: ",name)
	else:
		fail_count += 1
		printerr("FAIL hill-edit: ",name)

func select_kind(route: Control, slot: int, kind: String) -> void:
	var remove: bool=kind=="basic"
	var selected_kind: String=("forest" if slot==0 else "monster") if remove else kind
	var controls: Dictionary=route.route_minus_buttons if remove else route.route_plus_buttons
	var control: Button=controls.get(selected_kind) as Button
	check(control!=null and not control.disabled,selected_kind+" quantity control is enabled")
	if control!=null and not control.disabled: control.pressed.emit()

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var own: bool = session == null
	if own:
		session = Session.new()
		session.name = "RunSession"
		root.add_child(session)
	var old_save: String = session.save_file_path
	var scratch: String = "user://hill_route_choice_%d.json" % OS.get_process_id()
	session.save_file_path = scratch
	session.start_new_world()
	var world = session.world
	check(Plan.CHOICES.has("forest") and Plan.available(world.patrol_plan)==6,"hill uses existing 6 optional slots")
	var fake: Dictionary = world.patrol_plan.duplicate(true)
	fake.selection.forest = 1
	var denied: Dictionary = session.confirm_patrol(fake)
	check(not bool(denied.get("ok",false)),"forged hill not selectable before discovery")
	check(not Discovery.is_unlocked(world,"forest") and world.tiles.count("forest")==0,"new expedition has no unearned forest")
	var map = MAP.instantiate()
	root.add_child(map)
	await process_frame
	var before = RouteUI.new()
	map.stage.add_child(before)
	before.setup(map,State.HOME)
	check(before.route_plus_buttons.has("forest") and before.route_plus_buttons.forest.disabled,"hill station cannot add an unearned place")
	before.queue_free()
	await process_frame

	# Simulate an eligible genuine event landing; call the production award.
	world.laps=1
	var event_index: int=world.tiles.find("event")
	world.position=event_index
	check(session.save_world(),"event approach fixture is saved")
	var result: Dictionary=session.discover_hill_on_event(event_index)
	check(bool(result.get("ok",false)) and Discovery.is_unlocked(world,"forest"),"genuine event discovery unlocks an extra forest")
	check(world.tiles.count("forest")==1,"discovery creates one free hill without optional selection")

	world.position=State.HOME
	check(session.save_world(),"home arrival persisted")
	var route=RouteUI.new()
	map.stage.add_child(route)
	route.setup(map,State.HOME)
	var forest_choice: Button=route.route_plus_buttons.get("forest") as Button
	check(forest_choice!=null and not forest_choice.disabled,"forest choice becomes selectable after discovery")
	check(forest_choice!=null and route.route_editor.station_badges.forest.visible,"new forest choice shows its unread marker")
	check(route.find_child("HomeUnlockedForestTile",true,false)!=null,"existing unlocked tile announcement remains")
	select_kind(route,0,"forest")
	check(int(route.plan.selection.forest)==1 and Plan.available(route.plan)==5,"one forest selection uses one optional slot")
	check(str(route.route_count_labels.forest.text).contains("1"),"hill count updates beside real controls")
	var forest_art: bool=route.find_children("*","TextureRect",true,false).any(func(node):
		return node.texture!=null and node.texture.resource_path.ends_with("forest.png"))
	check(forest_art,"selected slot uses real hill art")
	select_kind(route,0,"basic")
	check(int(route.plan.selection.forest)==0 and Plan.available(route.plan)==6,"choosing empty road removes the optional hill")
	select_kind(route,0,"forest")
	# Six fixed selection slots share the same monster/rest/hill capacity.
	for i in range(1,6): select_kind(route,i,"monster")
	check(Plan.available(route.plan)==0 and Plan.total_selected(route.plan)==6 and route.route_plus_buttons.monster.disabled,"six optional choices cannot exceed capacity")
	select_kind(route,5,"basic")
	check(Plan.available(route.plan)==1,"removing a monster frees one choice")
	var saved_plan: Dictionary=route.plan.duplicate(true)
	route.action_button.pressed.emit()
	check(world.patrol_plan==saved_plan and int(world.patrol_plan.selection.forest)==1,"confirm saves chosen forest to the real world")
	check(not session.event_flag_is_set(Discovery.home_flag("forest")),"confirmation acknowledges forest NEW indicator")
	route.queue_free()
	await process_frame
	session.reload_world()
	world = session.world
	check(int(world.patrol_plan.selection.forest)==1 and Discovery.is_unlocked(world,"forest"),"saved forest choice and permanent unlock survive reload")
	world.lap_ready=true
	world.position=State.HOME
	check(session.leave_home(),"house departure regenerates next map from selected plan")
	check(world.tiles.size()==24 and world.tiles.count("forest")==2,"one discovered hill and one optional hill exist on next board")
	check(world.tiles[0]=="fortune-teller-camp" and world.tiles[8]=="village" and world.tiles[15]=="home","fixed map anchors still present")
	check(world.tiles.count("basic")>=Plan.RESERVED_SWAMP_ROADS-State.required_swamp_count(world.contamination),"protected swamp roads retained")
	session.reload_world()
	check(session.world.tiles.count("forest")==2 and session.world.patrol_plan.selection.forest==1,"real newly generated hill tiles survive reload")

	# Prior 2-key modern plans are valid: migrate to hill=0 rather than crash.
	var previous: Dictionary = {"selection":{"monster":2,"rest":0},"rest_unlocked":false,"rest_discovered":false}
	check(Plan.valid(previous) and Plan.total_selected(previous)==2,"2026-10-14 two-key plan remains readable")
	var old_state = State.new(session.world.definitions,9900,previous)
	var original: Dictionary=old_state.snapshot().duplicate(true)
	var reboot = State.new(session.world.definitions,9988)
	check(reboot.restore(original) and int(reboot.patrol_plan.selection.get("forest",-1))==0,"old two-key save migrates safely to hill=0")
	var grown: Dictionary=Plan.adjust(previous,"forest",1)
	check(Plan.valid(grown) and int(grown.selection.forest)==1 and Plan.available(grown)==3,"legacy plan can gain newly unlocked forest count")

	# First rest was genuinely discovered: reset may never erase its free tile.
	var rest_plan: Dictionary=Plan.default_plan()
	rest_plan.rest_unlocked=true
	rest_plan.rest_discovered=true
	rest_plan.selection.rest=2
	check(Plan.valid(rest_plan) and Plan.deltas(rest_plan).rest==2,"discovered free rest plus optional rest cap remains unchanged")
	var invalid_rest: Dictionary=rest_plan.duplicate(true)
	invalid_rest.selection.rest=3
	check(not Plan.valid(invalid_rest),"fourth rest rejected after discovery")

	map.queue_free()
	await process_frame
	session.save_file_path=old_save
	if own: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("HILL_UNLOCKED_PATROL: %d passed, %d failed" % [pass_count,fail_count])
	quit(0 if fail_count==0 else 1)
