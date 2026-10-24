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
	check(ResourceLoader.exists(PatrolUI.ROUTE_RESERVE_ART),"original reserve panel resource imported")
	check(ResourceLoader.exists(PatrolUI.ROUTE_CURRENT_ART),"original vertical current panel resource imported")
	check(route.current_options.is_empty() and route.reserve_options.is_empty(),"old 6-versus-5 swapping puzzle removed")
	check(route.content.get_node_or_null("SelectedPatrolSlot0")!=null and route.content.get_node_or_null("SelectedPatrolSlot5")!=null,"six selectable route preview slots exist")
	check(route.content.get_node_or_null("PatrolChoice_monster")!=null and route.content.get_node_or_null("PatrolChoice_rest")!=null,"contextual monster and rest choices shown")
	check(route.content.get_node_or_null("PatrolChoice_rest").disabled,"rest choice locked before first-lap unlock")
	check(route.action_button!=null and not route.action_button.disabled,"route confirmation available before visit")
	var before_plan: Dictionary=session.world.patrol_plan.duplicate(true)
	route.choose_route_slot(4)
	route.set_route_slot_kind("monster")
	check(route.route_slot_kind(4)=="monster" and route.route_slot_kind(0)=="basic","chosen preview slot changes without shuffling other slots")
	check(int(route.plan.selection.monster)==1 and RoutePlan.available(route.plan)==5,"one tap adds exactly one monster, five slots remain")
	check(session.world.patrol_plan==before_plan,"preview selection does not persist immediately")
	route.choose_route_slot(1)
	route.set_route_slot_kind("monster")
	check(route.route_slot_kind(4)=="monster" and route.route_slot_kind(1)=="monster","independent slot order retained")
	route.set_route_slot_kind("basic")
	check(route.route_slot_kind(1)=="basic" and int(route.plan.selection.monster)==1,"clearing one slot preserves another")
	check(RoutePlan.valid(route.plan),"edited route remains within six selectable slots")
	route.reset_route()
	check(RoutePlan.total_selected(route.plan)==0 and route.route_slot_kind(4)=="basic","reset clears preview and counts")
	route.choose_route_slot(4)
	route.set_route_slot_kind("monster")
	route.confirm_route()
	check(int(session.world.patrol_plan.selection.monster)==1,"confirmed plan stored in live world")
	check(session.place_visit_id("patrol",15) in session.world.reward_receipts,"visit receipt prevents repeated selection")
	session.reload_world()
	check(int(session.world.patrol_plan.selection.monster)==1,"saved selected extra monster persists on disk reload")
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
