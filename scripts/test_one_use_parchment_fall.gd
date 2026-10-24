extends SceneTree
## Immediate fallaway is visual-only: receipts must exist BEFORE any animation.
## Test real RunSession + existing location artwork, no gameplay-rule changes.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed+=1
		print("PASS used-paper: ",description)
	else:
		failed+=1
		printerr("FAIL used-paper: ",description)

func _run() -> void:
	var session: Node=root.get_node_or_null("RunSession")
	var owned: bool=session==null
	if owned:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var prior: String=session.save_file_path
	var temp: String="user://one_shot_paper_%d.json" % OS.get_process_id()
	session.save_file_path=temp
	session.start_new_world()
	session.world.lap_ready=true
	session.world.leave_home()
	var cemetery: int=session.world.tiles.find("graveyard")
	check(cemetery>=0,"real graveyard is accessible after lap")
	if cemetery<0: quit(1); return
	session.world.position=cemetery
	check(session.save_world(),"temporary run saved")
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	map.show_exploration_actions(cemetery)
	var screen: Control=map.overlay
	check(screen!=null and screen.type=="graveyard","production cemetery UI is open")
	# Without successful storage, a fallaway must never happen.
	map.animate_used_location_paper(screen,cemetery,"grave-extract")
	await process_frame
	check(screen.get_node_or_null("SpentLocationParchment")==null,"unearned action cannot fall off the screen")
	var outcome: Dictionary=session.dig_graveyard(cemetery)
	check(outcome.get("ok",false) and not outcome.get("overflow",false),"actual graveyard reward persists successfully")
	var saved: Dictionary=session.world.snapshot().duplicate(true)
	map.animate_used_location_paper(screen,cemetery,"grave-extract")
	var paper: Button=screen.get_node_or_null("SpentLocationParchment")
	check(paper!=null,"persisted action displays the SAME source paper at its original position")
	if paper==null: quit(1); return
	check(paper.text=="시체 파헤치기" and paper.position==map.TILE_EVENT_ACTION_RECT.position and paper.size==map.TILE_EVENT_ACTION_RECT.size,"original action label and original painted location geometry remain unchanged")
	var style: StyleBoxTexture=paper.get_theme_stylebox("normal") as StyleBoxTexture
	check(style!=null and style.texture.resource_path=="res://assets/map/ui/parchment_button_variant_04.png","unchanged game bitmap reused instead of new UI")
	check(paper.disabled and paper.mouse_filter==Control.MOUSE_FILTER_IGNORE and paper.get_meta("spent_paper_falling",false),"falling paper never intercepts input or triggers a second action")
	var duplicate: int=screen.get_children().filter(func(c): return c.name=="SpentLocationParchment").size()
	map.animate_used_location_paper(screen,cemetery,"grave-extract")
	check(duplicate==1 and screen.get_children().filter(func(c): return c.name=="SpentLocationParchment").size()==1,"repeated triggers do not spawn extra paper")
	await create_timer(0.28).timeout
	check(is_instance_valid(paper) and paper.rotation_degrees>0.0,"paper shakes and peels after receipt is saved")
	await create_timer(0.53).timeout
	check(not is_instance_valid(paper) or not paper.is_inside_tree(),"paper has fallen away and been freed within one second")
	check(session.world.snapshot()==saved,"visual movement cannot change stored loot, RNG or receipt")
	map.close_overlay()
	map.show_location(cemetery)
	var entrance_button: Button=null
	for child in map.overlay.get_children():
		if child is Button and child.text=="시체 파헤치기": entrance_button=child
	check(entrance_button!=null and entrance_button.disabled,"saved one-use action cannot be triggered again upon return")
	map.close_overlay()
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==saved,"one-use receipt and dice-control card survive reload")
	session.save_file_path=prior
	if owned: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(temp+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(temp+suffix))
	print("ONE_USE_PARCHMENT_FALL: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
