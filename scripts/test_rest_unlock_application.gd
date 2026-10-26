extends SceneTree
## Complete route: first homecoming -> explicit unlock -> choose 3 rests
## -> confirm -> real next-lap generation -> verify three actual rest tiles.
## The current lap never changes until the committed home exit.
const State = preload("res://systems/map_state.gd")
const Route = preload("res://systems/route_plan.gd")
const RouteUI = preload("res://systems/exploration_actions.gd")
const MapScene = preload("res://map.tscn")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	if ok:
		passed+=1
		print("PASS rest-unlock: ",msg)
	else:
		failed+=1
		printerr("FAIL rest-unlock: ",msg)

func press_route_choice(route, _slot: int, kind: String) -> bool:
	var control: Button=route.route_plus_buttons.get(kind) as Button
	if control==null or control.disabled: return false
	var before: int=int(route.plan.selection.get(kind,0))
	control.pressed.emit()
	return int(route.plan.selection.get(kind,0))==before+1

func rest_choice_button(route: Control) -> Button:
	return route.route_unlock_button as Button

func _run() -> void:
	var session: Node=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload exists")
		quit(1)
		return
	var previous_path: String=session.save_file_path
	var scratch: String="user://rest_unlock_application_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var map: Control=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	var initial: Array=session.world.tiles.duplicate()
	check(initial.count("rest")==0 and initial.count("swamp")==0 and initial.count("monster")==5,"new expedition starts with 5 monsters and no rest/swamp")
	var route=RouteUI.new()
	map.stage.add_child(route)
	route.setup(map,State.HOME)
	await process_frame
	var locked_rest_choice: Button=rest_choice_button(route)
	var monster_choice: Button=route.route_plus_buttons.get("monster") as Button
	check(locked_rest_choice!=null and locked_rest_choice.visible and locked_rest_choice.text=="숙영 해금","rest tile visibly presents the actual unlock choice")
	check(locked_rest_choice!=null and locked_rest_choice.disabled and not session.rest_unlock_allowed().ok,"new expedition locks rest choice until first homecoming")
	check(monster_choice!=null and not monster_choice.disabled,"first expedition permits an added monster slot while rest is locked")
	var blocked: Dictionary=session.unlock_rest_tile()
	check(not blocked.ok and not session.world.patrol_plan.rest_unlocked,"direct unlock call cannot bypass initial first-lap gate")
	# The normal movement system sets lap_ready when the player returns to
	# HOME. Use an isolated fixture here to exercise the unlock action
	# immediately; natural full-lap completion has its own integration test.
	session.world.lap_ready=true
	check(session.save_world(),"completed first homecoming persisted before unlocking")
	route.render_route()
	var earned_unlock: Button=rest_choice_button(route)
	check(earned_unlock!=null and earned_unlock.visible and not earned_unlock.disabled,"first completed lap enables the actual rest unlock choice")
	var seed_before: int=session.world.rng.state
	var count_before: int=session.world.reward_receipts.size()
	check(press_route_choice(route,0,"monster"),"the first current six-slot button selects a monster")
	check(int(route.plan.selection.monster)==1,"pending extra monster survives unlocking the first rest tile")
	earned_unlock=rest_choice_button(route)
	if earned_unlock!=null: earned_unlock.pressed.emit()
	check(session.world.patrol_plan.rest_unlocked and Route.valid(session.world.patrol_plan),"explicit unlock writes legitimate durable rest permission")
	var unlocked_rest_choice: Button=route.route_plus_buttons.get("rest") as Button
	check(unlocked_rest_choice!=null and not unlocked_rest_choice.disabled and not route.route_unlock_button.visible,"after unlock, rest choice becomes usable immediately")
	check(int(route.plan.selection.monster)==1 and bool(route.plan.rest_unlocked),"unlock preserves pending edits and adds the permission")
	check(not session.world.patrol_plan.has("current"),"new route system remains six-slot mode")
	check(session.world.tiles==initial and session.world.rng.state==seed_before,"unlock does NOT regenerate current board or consume random dice")
	check(session.world.reward_receipts.size()==count_before,"unlock does not consume the visit's one route confirmation")
	for slot in [1,2,3]:
		check(press_route_choice(route,slot,"rest"),"actual slot %d selects an unlocked rest" % slot)
	check(int(route.plan.selection.rest)==3 and int(route.plan.selection.monster)==1,"exactly three rest choices visible next to one monster")
	check(not press_route_choice(route,4,"rest") and int(route.plan.selection.rest)==3,"fourth rest is refused at the hard three-tile limit")
	check(int(session.world.patrol_preview(route.plan).remaining)==2 and route.route_plus_buttons.rest.disabled,"actual budget has two remaining while camp plus blocks the fourth tile")
	var before_reset: Dictionary=route.plan.duplicate(true)
	route.route_reset_button.pressed.emit()
	check(bool(session.world.patrol_plan.rest_unlocked) and bool(route.plan.rest_unlocked),"reset never removes permanent rest unlock")
	check(int(route.plan.selection.rest)==0 and Route.available(route.plan)==6,"reset clears optional counts but not unlock")
	for slot in range(3):
		check(press_route_choice(route,slot,"rest"),"real slot %d reselects rest after reset" % slot)
	for slot in range(3,6):
		check(press_route_choice(route,slot,"monster"),"real slot %d reselects monster after reset" % slot)
	check(int(route.plan.selection.rest)==3 and int(route.plan.selection.monster)==3 and Route.available(route.plan)==0,"3 rests + 3 extra monsters fill fixed six slots")
	var plan_to_save: Dictionary=route.plan.duplicate(true)
	route.action_button.pressed.emit()
	check(session.world.patrol_plan==plan_to_save,"confirm persists unlocked three-rest selection")
	check(session.world.tiles==initial,"current map still unchanged after route confirmation")
	check(session.world.reward_receipts.size()==count_before+1,"route confirmation spends one visit, unlock was free")
	route.queue_free()
	await process_frame
	session.reload_world()
	check(bool(session.world.patrol_plan.rest_unlocked) and int(session.world.patrol_plan.selection.rest)==3,"unlock and selection survive restart")
	check(session.world.tiles==initial,"reloading never applies future tiles to current lap prematurely")
	var duplicate: Dictionary=session.unlock_rest_tile()
	check(not bool(duplicate.get("ok",false)),"re-unlocking rest cannot duplicate rewards or mutate state")
	session.world.position=State.HOME
	session.world.lap_ready=true
	check(session.save_world(),"simulate completed lap without modifying original save")
	check(session.leave_home(),"next home exit commits chosen route and next-lap tile arrangement")
	check(session.world.laps==1 and session.world.contamination==7,"home exit keeps exact +7 contamination")
	check(session.world.tiles.count("rest")==3 and session.world.tiles.count("monster")==8,"next lap contains precisely 3 rest and 5+3 monster tiles")
	check(session.world.tiles.count("graveyard")==1 and session.world.tiles.count("event")==2,"mandatory graveyard and two event stones unaffected")
	check(session.world.tiles.count("basic")==4 and session.world.tiles.count("swamp")==0,"two guaranteed events leave four empty roads including two protected; no premature swamp")
	check(session.world.tiles.size()==24 and session.world.tiles[State.HOME]=="home","all 24 tile slots still valid")
	var saved_tiles: Array=session.world.tiles.duplicate()
	session.reload_world()
	check(session.world.tiles==saved_tiles and session.world.patrol_plan==plan_to_save,"applied tiles and unlock are durable across save/reload")
	# Failed unlock must be atomic and leave locked plan untouched.
	session.save_file_path="user://no_parent_rest_unlock_test/blocked.json"
	session.start_new_world()
	session.world.lap_ready=true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	var denied: Dictionary=session.unlock_rest_tile()
	check(not bool(denied.get("ok",false)) and session.world.snapshot()==before,"failed save rolls back unlock and all other state")
	map.queue_free()
	await process_frame
	session.save_file_path=previous_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("REST_UNLOCK_APPLICATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
