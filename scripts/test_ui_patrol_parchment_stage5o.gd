extends SceneTree
## 5O: real source parchment buttons on the home patrol route.
const MapScene=preload("res://map.tscn")
const RouteUI=preload("res://systems/exploration_actions.gd")
const RoutePlan=preload("res://systems/route_plan.gd")
const SessionScript=preload("res://systems/run_session.gd")
const MapState=preload("res://systems/map_state.gd")
var passed: int=0
var failed: int=0
var save_path: String=""
func check(ok: bool, caption: String) -> void:
	if ok:
		passed+=1
		print("PASS ui-patrol-parchment: ",caption)
	else:
		failed+=1
		printerr("FAIL ui-patrol-parchment: ",caption)

func remove_save() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))

func is_original(button: Button, png: Texture2D) -> bool:
	if button==null: return false
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style=button.get_theme_stylebox(state)
		if not style is StyleBoxTexture: return false
		if style.texture!=png: return false
	return true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	save_path="user://ui_patrol_parchment_stage5o_%d.json" % OS.get_process_id()
	remove_save()
	var session=root.get_node_or_null("RunSession")
	var owned: bool=session==null
	if owned:
		session=SessionScript.new()
		session.name="RunSession"
		root.add_child(session)
	var prev_save: String=session.save_file_path
	session.save_file_path=save_path
	session.start_new_world()
	var world=session.world
	var home: int=MapState.HOME
	check(world.tiles[home]=="home","fixed home tile is the real patrol location")
	world.position=home
	check(session.save_world(),"test only home landing persisted")
	var map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	var route=RouteUI.new()
	map.stage.add_child(route)
	route.setup(map,home)
	await process_frame
	check(route.type=="home" and route.find_child("PatrolRouteEditor",true,false)!=null,"real HOME opens the approved planning board")
	check(ResourceLoader.exists("res://assets/map/ui/patrol_planning_board_v1.png"),"text-free board asset exists")
	check(route.close_button.name=="PatrolRouteClose" and route.action_button.name=="PatrolRouteConfirm" and route.route_reset_button.name=="PatrolRouteReset","stable footer actions retained")
	await create_timer(0.29).timeout
	for control in [route.close_button,route.action_button,route.route_reset_button]:
		check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(control.get_global_rect()),str(control.name)+" fits game viewport")
		for state in ["normal","hover","pressed","focus","disabled"]:
			check(control.has_theme_stylebox_override(state),str(control.name)+" defines "+state)
	check(not route.close_button.get_global_rect().intersects(route.action_button.get_global_rect()) and not route.route_reset_button.get_global_rect().intersects(route.action_button.get_global_rect()),"footer controls do not overlap")
	check(route.find_child("SelectedPatrolSlot0",true,false)==null,"old numbered slots removed")
	check(route.route_plus_buttons.size()==3 and route.route_minus_buttons.size()==3 and route.route_count_labels.size()==3,"three live quantity stations")
	check(route.route_plus_buttons.rest.disabled and route.route_plus_buttons.forest.disabled,"unearned camp and hill cannot be added")
	check(route.route_unlock_button!=null and route.route_unlock_button.visible and route.route_unlock_button.disabled,"initial camp unlock is visible and gated")
	var before: Dictionary=world.patrol_plan.duplicate(true)
	var receipts_before: int=world.reward_receipts.size()
	var random_before: int=world.rng.state
	var plus: Button=route.route_plus_buttons.monster
	var minus: Button=route.route_minus_buttons.monster
	check(minus.disabled,"zero cannot become negative")
	for i in range(2): plus.pressed.emit()
	check(int(route.plan.selection.monster)==2 and int(route.plan.selection.rest)==0,"two plus clicks add precisely two monsters")
	check(int(world.patrol_preview(route.plan).remaining)==4,"real capacity decreases by two")
	check(world.patrol_plan==before and world.reward_receipts.size()==receipts_before,"draft changes consume no permanent save/receipt")
	check(route.route_plus_buttons.monster==plus and route.route_minus_buttons.monster==minus,"edits preserve control identity")
	minus.pressed.emit()
	check(int(route.plan.selection.monster)==1,"minus removes exactly one monster")
	route.route_reset_button.pressed.emit()
	check(route.plan==RoutePlan.default_plan() and world.patrol_plan==before,"default resets draft only")
	check(route.route_minus_buttons.monster.disabled and int(world.patrol_preview(route.plan).remaining)==6,"default restores zero and safe fresh capacity")
	for i in range(6): route.route_plus_buttons.monster.pressed.emit()
	check(int(route.plan.selection.monster)==6 and int(world.patrol_preview(route.plan).remaining)==0,"fresh board still permits all six safe optional monsters")
	check(route.route_plus_buttons.monster.disabled and route.route_plus_buttons.rest.disabled,"full budget and locked camp prevent additions")
	check(RoutePlan.valid(route.plan) and bool(world.patrol_preview(route.plan).valid),"full plan respects schema and actual capacity")
	var actual_changed: Dictionary=route.plan.duplicate(true)
	route.action_button.pressed.emit()
	check(world.patrol_plan==actual_changed,"confirm persists exactly six selected monster stones")
	check(world.reward_receipts.size()==receipts_before+1,"only explicit confirm consumes one home visit")
	check(world.rng.state==random_before,"patrol selection uses no gameplay RNG")
	route.render_route()
	check(route.action_button.disabled and route.route_plus_buttons.monster.disabled and route.route_minus_buttons.monster.disabled,"confirmed visit locks all editing")
	var duplicate=session.confirm_patrol(actual_changed)
	check(not duplicate.ok,"duplicate route confirmation prohibited")
	route.queue_free()
	await process_frame
	var snapshot: Dictionary=world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world!=null and session.notice.is_empty(),"new scene reads saved patrol route from JSON")
	check(session.world.patrol_plan==actual_changed and session.world.reward_receipts.size()==receipts_before+1,"selected route and single receipt survive process-style reload")
	var route2=RouteUI.new()
	map.stage.add_child(route2)
	route2.setup(map,home)
	check(route2.plan==actual_changed and route2.action_button.disabled,"reopened saved patrol editor restores edited route and lock")
	check(route2.find_child("PatrolRouteEditor",true,false)!=null,"reopened editor keeps the approved board")
	check(not session.world.tiles.has("forest"),"new campaign forest remains gated until a real story discovery")
	check(route2.route_plus_buttons.forest.disabled,"unearned hill stays locked after reopening")
	route2.queue_free()
	await process_frame
	map.queue_free()
	await process_frame
	session.save_file_path=prev_save
	if owned: session.queue_free()
	remove_save()
	check(not FileAccess.file_exists(save_path),"disposable patrol save cleaned, original save untouched")
	print("UI_PATROL_PARCHMENT_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
