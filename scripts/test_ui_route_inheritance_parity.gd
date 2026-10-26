extends SceneTree
## UI stage3: original patrol boards and simultaneous inheritance card sources.
const MapScene=preload("res://map.tscn")
const PatrolUI=preload("res://systems/exploration_actions.gd")
const InheritanceUI=preload("res://systems/home_inheritance.gd")
const RoutePlan=preload("res://systems/route_plan.gd")
const InheritRules=preload("res://systems/brand_inheritance.gd")
var passed=0
var failed=0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, name: String) -> void:
	if ok:
		passed+=1
		print("PASS ui-stage3: ",name)
	else:
		failed+=1
		printerr("FAIL ui-stage3: ",name)
func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload")
		quit(1)
		return
	var former_path: String=session.save_file_path
	var path="user://ui_stage3_%d.json" % OS.get_process_id()
	session.save_file_path=path
	session.start_new_world()
	var map: Control=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	var route=PatrolUI.new()
	map.add_child(route)
	route.setup(map,15)
	await process_frame
	check(route.find_child("PatrolRouteEditor",true,false)!=null,"approved single planning board opens")
	check(ResourceLoader.exists("res://assets/map/ui/patrol_planning_board_v1.png"),"blank planning board resource exists")
	check(route.find_child("SelectedPatrolSlot0",true,false)==null,"obsolete numbered slots are absent")
	check(route.route_plus_buttons.size()==3 and route.route_minus_buttons.size()==3 and route.route_count_labels.size()==3,"three stations expose real quantity controls")
	check(route.route_plus_buttons.rest.disabled and route.route_plus_buttons.forest.disabled,"unearned camp and hill are gated")
	check(route.action_button!=null and not route.action_button.disabled,"confirmation is initially available")
	var before_plan: Dictionary=session.world.patrol_plan.duplicate(true)
	var plus: Button=route.route_plus_buttons.monster
	var minus: Button=route.route_minus_buttons.monster
	plus.pressed.emit()
	check(int(route.plan.selection.monster)==1 and int(session.world.patrol_preview(route.plan).remaining)==5,"plus adds exactly one monster and updates actual capacity")
	check(route.route_plus_buttons.monster==plus and route.route_minus_buttons.monster==minus,"adjustment keeps focusable controls")
	check(session.world.patrol_plan==before_plan,"draft edits are not saved")
	plus.pressed.emit()
	check(int(route.plan.selection.monster)==2,"second plus adds exactly one more")
	minus.pressed.emit()
	check(int(route.plan.selection.monster)==1,"minus removes exactly one")
	check(RoutePlan.valid(route.plan) and bool(session.world.patrol_preview(route.plan).valid),"draft obeys schema and actual budget")
	route.route_reset_button.pressed.emit()
	check(RoutePlan.total_selected(route.plan)==0 and route.route_minus_buttons.monster.disabled,"default clears draft and prevents negative count")
	route.route_plus_buttons.monster.pressed.emit()
	route.action_button.pressed.emit()
	check(int(session.world.patrol_plan.selection.monster)==1,"confirmed quantity stored")
	check(session.place_visit_id("patrol",15) in session.world.reward_receipts,"confirmation consumes one visit")
	session.reload_world()
	check(int(session.world.patrol_plan.selection.monster)==1,"confirmed quantity survives reload")
	route.queue_free()
	await process_frame
	session.start_new_world()
	var inherit=InheritanceUI.new()
	map.add_child(inherit)
	inherit.setup(session)
	await process_frame
	check(inherit.inheritance_frame!=null and inherit.inheritance_frame.texture!=null,"original center inheritance art remains")
	check(inherit.material_art!=null and inherit.receiver_art!=null,"monster donor/receiver board slots remain")
	check(inherit.material_art.position.x==38 and inherit.receiver_art.position.x==38,"cards fit portrait slots")
	check(inherit.unit_hand_scroll!=null,"monster-only source row exists")
	check(inherit.unit_options.size()==session.world.roster.size(),"all owned monsters available as materials")
	check(not FileAccess.get_file_as_string("res://systems/home_inheritance.gd").contains("brand_card_id"),"independent brand-card UI state removed")
	var donor_id: String=str(session.world.roster[0].id)
	var receiver_id: String=str(session.world.roster[1].id)
	inherit.select_unit(donor_id)
	check(inherit.material_id==donor_id and inherit.status.text=="② 받을 마물 선택","first monster becomes donor with one compact next-action hint")
	inherit.select_unit(receiver_id)
	check(inherit.receiver_id==receiver_id and not inherit.confirm_button.disabled,"second monster becomes recipient")
	var donor_has_curse: bool=false
	for brand in InheritRules.normalize(session.owned_unit(donor_id),session.world.definitions):
		if not brand.curse.is_empty():
			donor_has_curse=true
			break
	var expected_progress: String="축복만 무작위 계승" if donor_has_curse else "낙인 1개 무작위 계승"
	check(inherit.sacrifice_warning.text=="재료 마물 영구 소멸" and inherit.status.text==expected_progress and inherit.confirm_button.text=="계승 확정","single permanent-sacrifice warning and accurate blessing-only random inheritance note")
	inherit.select_unit(donor_id)
	check(inherit.material_id.is_empty() and inherit.confirm_button.disabled,"deselecting donor blocks incomplete inheritance")
	inherit.queue_free()
	await process_frame
	map.queue_free()
	await process_frame
	session.save_file_path=former_path
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("UI_STAGE3_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
