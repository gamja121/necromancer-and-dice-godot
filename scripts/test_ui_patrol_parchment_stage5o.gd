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
	var inart=load(RouteUI.PATROL_ENTER_PARCHMENT) as Texture2D
	var outart=load(RouteUI.PATROL_EXIT_PARCHMENT) as Texture2D
	check(inart!=null and outart!=null,"source enter and exit parchment textures both load")
	if inart==null or outart==null:
		session.save_file_path=prev_save
		if owned:session.queue_free()
		remove_save()
		print("UI_PATROL_PARCHMENT_PARITY: %d passed, %d failed" % [passed,failed])
		quit(1)
		return
	check(inart.resource_path!=outart.resource_path,"enter and exit actions have distinct original art")
	check(inart.get_width()>80 and outart.get_width()>80,"both original parchment images are decodable")
	world.position=home
	check(session.save_world(),"test only home landing persisted")
	var map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	var route=RouteUI.new()
	map.stage.add_child(route)
	route.setup(map,home)
	await process_frame
	check(route.type=="home" and route.action_button!=null,"real map/ExplorationActions opens home patrol editor")
	check(route.close_button.name=="PatrolRouteClose" and route.action_button.name=="PatrolRouteConfirm" and route.route_reset_button.name=="PatrolRouteReset","source three route action buttons named and visible")
	check(is_original(route.route_reset_button,inart),"reset uses authentic enter parchment in all button states")
	check(is_original(route.action_button,inart),"confirm uses authentic enter parchment in all button states")
	check(is_original(route.close_button,outart),"close uses authentic exit parchment in all button states")
	check(route.close_button.text=="닫기" and route.action_button.text=="경로 확정" and route.route_reset_button.text=="기본값","source three action captions retained")
	check(route.close_button.position==Vector2(430,561) and route.close_button.size==Vector2(128,36),"source close button keeps game-canvas footprint")
	check(route.action_button.position==Vector2(614,561) and route.action_button.size==Vector2(160,36),"confirm keeps existing board position")
	check(route.route_reset_button.position==Vector2(245,561) and route.route_reset_button.size==Vector2(148,36),"reset keeps existing board position")
	check(route.reserve_options.size()==5 and route.current_options.size()==6,"original 11 selectable stone slots remain")
	var before: Dictionary=world.patrol_plan.duplicate(true)
	var receipts_before: int=world.reward_receipts.size()
	var random_before: int=world.rng.state
	route.current_options[0].pressed.emit()
	route.reserve_options[0].pressed.emit()
	check(route.plan.current[0]==before.reserve[0] and route.plan.reserve[0]==before.current[0],"original current/reserve tile swap remains functional")
	check(world.patrol_plan==before and world.reward_receipts.size()==receipts_before,"preview swap alone changes no durable state or receipt")
	route.route_reset_button.pressed.emit()
	check(route.plan==RoutePlan.default_plan() and world.patrol_plan==before,"real reset button restores source plan without saving")
	check(route.selected_current<0 and route.selected_reserve<0,"reset clears existing tile selection highlights")
	check(is_original(route.route_reset_button,inart),"original reset artwork survives dynamic card rerender")
	route.current_options[0].pressed.emit()
	route.reserve_options[0].pressed.emit()
	check(RoutePlan.valid(route.plan),"modified route remains valid canonical tile inventory")
	var actual_changed=route.plan.duplicate(true)
	route.action_button.pressed.emit()
	check(world.patrol_plan==actual_changed,"real confirm button saves selected route exactly once")
	check(world.reward_receipts.size()==receipts_before+1,"one patrol receipt issued on explicit confirmation")
	check(world.rng.state==random_before,"parchment style and route callbacks consume no RNG")
	route.render_route()
	check(route.action_button.disabled and is_original(route.action_button,inart),"already-confirmed route disables confirm but still displays parchment")
	var recheck=session.confirm_patrol(actual_changed)
	check(not bool(recheck.get("ok",false)),"direct duplicate patrol confirmation rejected after receipt")
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
	check(is_original(route2.close_button,outart) and is_original(route2.action_button,inart),"reopened patrol parchment art stays original")
	route2.queue_free()
	await process_frame
	var forest: int=session.world.tiles.find("forest")
	check(forest>=0,"board contains unrelated forest location")
	if forest>=0:
		var other=RouteUI.new()
		map.stage.add_child(other)
		other.setup(map,forest)
		check(other.action_button!=null and other.route_reset_button==null,"patrol reset only exists on the home screen")
		check(not is_original(other.close_button,outart),"forest close button not incorrectly changed to patrol parchment")
		other.queue_free()
		await process_frame
	map.queue_free()
	await process_frame
	session.save_file_path=prev_save
	if owned: session.queue_free()
	remove_save()
	check(not FileAccess.file_exists(save_path),"disposable patrol save cleaned, original save untouched")
	print("UI_PATROL_PARCHMENT_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
