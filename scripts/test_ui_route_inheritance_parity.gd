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
	check(route.reserve_options.size()==5 and route.current_options.size()==6,"five reserve and six current stones")
	check(route.current_options[0].position.x>900 and route.current_options[5].position.y>route.current_options[0].position.y+240,"current six stones form right vertical strip")
	check(route.reserve_options[0].position.x<route.reserve_options[4].position.x and absf(route.reserve_options[0].position.y-route.reserve_options[4].position.y)<1,"reserve stones form original horizontal five slots")
	check(route.action_button!=null and not route.action_button.disabled,"route confirmation available before visit")
	var before_plan=session.world.patrol_plan.duplicate(true)
	route.choose_route("current",0)
	check(route.selected_current==0,"select current stone")
	route.choose_route("reserve",0)
	check(route.selected_current==-1 and route.selected_reserve==-1,"swap clears both highlights")
	check(route.plan.current[0]==before_plan.reserve[0] and route.plan.reserve[0]==before_plan.current[0],"swap modifies proposed plan without losing tiles")
	check(session.world.patrol_plan==before_plan,"preview swap does not mutate saved plan")
	check(RoutePlan.valid(route.plan),"edited 11-tile inventory remains valid")
	route.confirm_route()
	check(session.world.patrol_plan.current[0]==before_plan.reserve[0],"confirmed plan saved in live world")
	check(session.place_visit_id("patrol",15) in session.world.reward_receipts,"visit receipt prevents duplicate route confirmation")
	session.reload_world()
	check(session.world.patrol_plan.current[0]==before_plan.reserve[0],"route persists on disk reload")
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
	check(inherit.material_art!=null and inherit.receiver_art!=null,"two original board slots displayed")
	check(inherit.material_art.position.x==38 and inherit.receiver_art.position.x==38,"both cards fit portrait slots")
	check(inherit.unit_hand_scroll!=null and inherit.brand_fan_scroll!=null,"unit and brand sources simultaneously visible")
	check(inherit.unit_options.size()==session.world.roster.size(),"all owned monsters appear without tabs")
	check(inherit.brand_options.size()==1,"owned brand card appears without tabs")
	check(inherit.brand_fan.get_child_count()>=1,"brand fan renders interactive cards")
	inherit.select_brand_card(str(brand.id))
	check(inherit.brand_card_id==str(brand.id),"source brand card select works")
	inherit.select_unit(str(session.world.roster[0].id))
	check(inherit.receiver_id==str(session.world.roster[0].id),"brand recipient can be chosen from simultaneous unit hand")
	check(inherit.material_id=="" and not inherit.confirm_button.disabled,"brand source enables existing inheritance confirmation")
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
