extends SceneTree
## World tree prayer is performed by the one shared map die, with no button.
## Uses a disposable run and a synthetic discovered world-tree tile.
const MapScene = preload("res://map.tscn")
const SessionScript = preload("res://systems/run_session.gd")
var passed: int = 0
var failed: int = 0
var save: String = ""

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS prayer-die: ",description)
	else:
		failed += 1
		printerr("FAIL prayer-die: ",description)

func _initialize() -> void:
	call_deferred("_run")

func cleanup() -> void:
	for extension in ["",".tmp"]:
		if FileAccess.file_exists(save+extension):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save+extension))

func _run() -> void:
	save = "user://ui_world_tree_die_%d.json" % OS.get_process_id()
	cleanup()
	var session = root.get_node_or_null("RunSession")
	var owns: bool = session==null
	if owns:
		session = SessionScript.new()
		session.name = "RunSession"
		root.add_child(session)
	var old_save: String = session.save_file_path
	session.save_file_path = save
	session.start_new_world()
	var world = session.world
	# World-tree discovery does not exist on every first-lap board.
	# Convert an ordinary path only inside this disposable fixture.
	var index: int = world.tiles.find("basic")
	check(index>=0,"disposable board has an unfixed path for a prayer fixture")
	if index<0:
		session.save_file_path = old_save
		if owns: session.queue_free()
		cleanup()
		quit(1)
		return
	world.tiles[index] = "unknown"
	world.position = index
	world.contamination = 30
	var preview = RandomNumberGenerator.new()
	var seeded: bool = false
	for seed in range(1,400):
		preview.seed = seed
		if preview.randi_range(1,6)==6:
			world.rng.seed = seed
			seeded = true
			break
	check(seeded,"deterministic grand-blessing die seed")
	check(session.save_world(),"disposable prayer fixture saved")
	var before_receipts: int = world.reward_receipts.size()
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	map.show_exploration_actions(index)
	var panel = map.overlay
	check(is_instance_valid(panel) and panel.get_script().resource_path.ends_with("exploration_actions.gd"),"live world tree action panel")
	check(panel.dice==map.dice and panel.action_button==null,"no second die or prayer button exists")
	check(panel.status.text.contains("정화 기도를 하려면 주사위를 누르세요."),"guidance points to shared die")
	var redundant: bool = false
	for child in panel.get_children():
		if child is Button and child.text=="기도": redundant=true
	check(not redundant,"no clickable duplicate prayer control")
	check(map.dice.is_visible_in_tree() and not map.dice.disabled,"unused prayer enables visible shared die")
	check(map.dice.mouse_filter==Control.MOUSE_FILTER_STOP and map.dice.z_index>panel.z_index,"prayer die is in front of world-tree painting and receives mouse input")
	check(map.stage.get_child(map.stage.get_child_count()-1)==map.dice,"actual Godot input hit testing puts shared die last")
	map.dice.pressed.emit()
	await process_frame
	check(panel.busy and map.dice.disabled and panel.close_button.disabled,"prayer locks repeated rolls and exit while animating")
	var started: int = Time.get_ticks_msec()
	while panel.busy and Time.get_ticks_msec()-started<11000:
		await process_frame
	check(not panel.busy and not panel.close_button.disabled,"prayer animation releases close control")
	check(int(world.prayer_result.get("face",0))==6 and int(world.prayer_result.get("delta",0))==-5,"real die gave persisted grand blessing")
	check(world.contamination==25,"world tree changed contamination exactly once")
	check(panel.status.text.contains("대축복"),"outcome replaces prayer instruction")
	check(world.reward_receipts.size()==before_receipts+1,"only one prayer receipt recorded")
	check(not session.pray_world_tree(index).get("ok",true),"same-visit prayer cannot repeat")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.contamination==25 and int(session.world.prayer_result.get("face",0))==6,"prayer outcome survives save reload")
	check(session.world.reward_receipts.size()==before_receipts+1,"prayer receipt survives save reload")
	map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	map.show_location(index)
	var visit_button: Button=null
	for child in map.overlay.get_children():
		if child is Button and child.text=="기도": visit_button=child
	check(visit_button!=null and not visit_button.disabled,"used world tree remains accessible to inspect saved prayer results")
	map.close_overlay()
	map.show_exploration_actions(index)
	panel = map.overlay
	check(panel.action_button==null and map.dice.disabled,"reopened spent prayer leaves only a disabled die")
	check(panel.status.text.contains("기도 결과 6"),"reopened prayer shows persisted outcome")
	check(map.stage.get_child(map.stage.get_child_count()-1)==map.dice,"reopened world-tree art does not cover shared die")
	map.queue_free()
	await process_frame
	session.save_file_path = old_save
	if owns: session.queue_free()
	cleanup()
	check(not FileAccess.file_exists(save),"temporary prayer save removed")
	print("WORLD_TREE_SHARED_DIE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
