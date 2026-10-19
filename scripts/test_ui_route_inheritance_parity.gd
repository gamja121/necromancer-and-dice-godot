extends SceneTree
## UI stage3: original patrol boards and simultaneous inheritance card sources.
const MapScene=preload("res://map.tscn")
const PatrolUI=preload("res://systems/exploration_actions.gd")
const InheritanceUI=preload("res://systems/home_inheritance.gd")
const RoutePlan=preload("res://systems/route_plan.gd")
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
	var brand: Dictionary=session.create_item("brand",{})
	session.world.brand_cards.append(brand)
	var inherit=InheritanceUI.new()
	map.add_child(inherit)
	inherit.setup(session)
	await process_frame
	check(inherit.inheritance_frame!=null and inherit.inheritance_frame.texture!=null,"original center inheritance info art displayed")
	check(inherit.status.text.contains("① 재료"),"inheritance starts with the material-selection instruction")
	check(inherit.material_art!=null and inherit.receiver_art!=null,"two original board slots displayed")
	check(inherit.material_art.position.x==38 and inherit.receiver_art.position.x==38,"both cards fit portrait slots")
	check(inherit.unit_hand_scroll!=null and inherit.brand_fan_scroll!=null,"unit and brand sources simultaneously visible")
	check(inherit.unit_options.size()==session.world.roster.size(),"all owned monsters appear without tabs")
	check(inherit.brand_options.size()==1,"owned brand card appears without tabs")
	check(inherit.brand_fan.get_child_count()>=1,"brand fan renders interactive cards")
	inherit.select_brand_card(str(brand.id))
	check(inherit.brand_card_id==str(brand.id),"source brand card select works")
	check(inherit.status.text.contains("② 축복"),"after choosing source, UI asks for recipient")
	inherit.select_unit(str(session.world.roster[0].id))
	check(inherit.receiver_id==str(session.world.roster[0].id),"brand recipient can be chosen from simultaneous unit hand")
	check(inherit.material_id=="" and not inherit.confirm_button.disabled,"brand source enables existing inheritance confirmation")
	check(inherit.status.text.contains("③ 낙인 카드 1장 소모") and inherit.confirm_button.text.contains("확정"),"irreversible source cost appears before confirmation")
	inherit.select_brand_card(str(brand.id))
	check(inherit.brand_card_id.is_empty() and inherit.confirm_button.disabled,"deselecting brand blocks incomplete inheritance")
	inherit.queue_free()
	await process_frame
	map.queue_free()
	await process_frame
	session.save_file_path=former_path
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("UI_STAGE3_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
