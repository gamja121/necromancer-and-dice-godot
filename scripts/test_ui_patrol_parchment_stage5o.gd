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
	check(route.close_button.text=="← 돌아가기" and route.action_button.text=="경로 확정" and route.route_reset_button.text=="기본값","source three action captions retained")
	# PanelEffectsModule offsets all three real buttons by 6px during the
	# 0.20s entrance tween. Compare approved source coordinates only AFTER
	# the entrance settles; do not remove the player's visible animation.
	await create_timer(0.29).timeout
	check(route.close_button.position.distance_to(Vector2(430,561))<0.5 and route.close_button.size==Vector2(128,36),"source close button keeps game-canvas footprint")
	check(route.action_button.position.distance_to(Vector2(614,561))<0.5 and route.action_button.size==Vector2(160,36),"confirm keeps existing board position")
	check(route.route_reset_button.position.distance_to(Vector2(245,561))<0.5 and route.route_reset_button.size==Vector2(148,36),"reset keeps existing board position")
	check(route.route_slot_layout.size()==6 and route.content.get_node_or_null("SelectedPatrolSlot0") is Button,"new patrol shows all six selectable route slots")
	check(route.content.get_node_or_null("PatrolChoice_monster") is Button and route.content.get_node_or_null("PatrolChoice_rest") is Button,
		"monster and gated rest are displayed as actual route choices")
	check((route.content.get_node_or_null("PatrolChoice_rest") as Button).disabled,"first rest location is locked without earned unlock")
	check(route.route_count_labels.is_empty() and route.route_plus_buttons.is_empty(),"obsolete plus/minus controls do not cover the six-slot selector")
	var before: Dictionary=world.patrol_plan.duplicate(true)
	var receipts_before: int=world.reward_receipts.size()
	var random_before: int=world.rng.state
	for slot in range(2):
		var slot_button: Button=route.content.get_node_or_null("SelectedPatrolSlot%d" % slot)
		check(slot_button!=null and not slot_button.disabled,"slot %d is interactive" % slot)
		if slot_button!=null: slot_button.pressed.emit()
		var monster_choice: Button=route.content.get_node_or_null("PatrolChoice_monster")
		check(monster_choice!=null and not monster_choice.disabled,"monster choice is enabled for slot %d" % slot)
		if monster_choice!=null: monster_choice.pressed.emit()
	check(int(route.plan.selection.monster)==2 and int(route.plan.selection.rest)==0 and route.route_slot_kind(0)=="monster" and route.route_slot_kind(1)=="monster",
		"two real slot/button clicks create exactly two monster stones")
	check(RoutePlan.available(route.plan)==4,"slot selection updates remaining six-road budget")
	check(world.patrol_plan==before and world.reward_receipts.size()==receipts_before,"preview edits never consume a patrol visit")
	var second_slot: Button=route.content.get_node_or_null("SelectedPatrolSlot1")
	if second_slot!=null: second_slot.pressed.emit()
	var basic_choice: Button=route.content.get_node_or_null("PatrolChoice_basic")
	if basic_choice!=null: basic_choice.pressed.emit()
	check(int(route.plan.selection.monster)==1 and route.route_slot_kind(1)=="basic","clicking empty road removes exactly one selected monster")
	route.route_reset_button.pressed.emit()
	check(route.plan==RoutePlan.default_plan() and world.patrol_plan==before,"reset clears preview without writing permanent save")
	check(route.route_slot_layout.all(func(tile): return tile=="basic") and RoutePlan.available(route.plan)==6,"reset restores all six empty selectable roads")
	check(is_original(route.route_reset_button,inart),"original parchment reset art survives re-render")
	for slot in range(6):
		var slot_button: Button=route.content.get_node_or_null("SelectedPatrolSlot%d" % slot)
		check(slot_button!=null and not slot_button.disabled,"six-slot route choice %d remains touchable" % slot)
		if slot_button!=null: slot_button.pressed.emit()
		var monster_choice: Button=route.content.get_node_or_null("PatrolChoice_monster")
		if monster_choice!=null: monster_choice.pressed.emit()
	check(int(route.plan.selection.monster)==6 and RoutePlan.available(route.plan)==0,"six optional slots are filled with exactly six monsters")
	check(route.route_slot_layout.size()==6 and route.route_slot_layout.all(func(tile): return tile=="monster"),"all six visual slots match planned monster quantities")
	var inactive_rest: Button=route.content.get_node_or_null("PatrolChoice_rest")
	check(inactive_rest!=null and inactive_rest.disabled,"locked rest cannot be chosen even at full capacity")
	check(RoutePlan.valid(route.plan),"modified patrol plan preserves cap and locked-rest limits")
	var actual_changed: Dictionary=route.plan.duplicate(true)
	route.action_button.pressed.emit()
	check(world.patrol_plan==actual_changed,"confirm persists exactly six selected monster stones")
	check(world.reward_receipts.size()==receipts_before+1,"only explicit confirm consumes one home visit")
	check(world.rng.state==random_before,"patrol selection uses no gameplay RNG")
	route.render_route()
	check(route.action_button.disabled and is_original(route.action_button,inart),"confirmation disables further edits but keeps parchment")
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
	check(is_original(route2.close_button,outart) and is_original(route2.action_button,inart),"reopened patrol parchment art stays original")
	route2.queue_free()
	await process_frame
	check(not session.world.tiles.has("forest"),"new campaign forest remains gated until a real story discovery")
	check(route2.content.get_node_or_null("PatrolChoice_forest")==null,"unearned forest does not appear as a choice on reopened patrol editor")
	map.queue_free()
	await process_frame
	session.save_file_path=prev_save
	if owned: session.queue_free()
	remove_save()
	check(not FileAccess.file_exists(save_path),"disposable patrol save cleaned, original save untouched")
	print("UI_PATROL_PARCHMENT_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
