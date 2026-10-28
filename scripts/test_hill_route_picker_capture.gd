extends SceneTree
## GPU proof of the actual production hill UI, with isolated valid saves.
const MAP=preload("res://map.tscn")
const STATE=preload("res://systems/map_state.gd")
const KINDS=["basic","monster","event","graveyard","rest","gem"]
var out:String
var passed:int=0
var failed:int=0
var session:Node
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("PASS hill-capture: ",label)
	else: failed+=1; printerr("FAIL hill-capture: ",label)
func capture(name:String) -> void:
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(1280,720),"actual 1280x720 viewport "+name)
	check(image.save_png(out.path_join("hill_route_%s.png"%name))==OK,"native screenshot saved "+name)
func set_tile(index:int,kind:String,protected:Array) -> void:
	var world=session.world
	if world.tiles[index]==kind: return
	var other:int=-1
	for candidate in range(24):
		if candidate not in protected and world.tiles[candidate]==kind:
			other=candidate
			break
	if other>=0:
		world.tiles[other]=world.tiles[index]
	else:
		if world.tiles[index]!="basic":
			for road in range(24):
				if road not in protected and world.tiles[road]=="basic":
					world.tiles[road]=world.tiles[index]
					break
	world.tiles[index]=kind
func open(index:int,sample:bool=false) -> Control:
	session.start_new_world()
	var protected:Array=[0,8,STATE.HOME,23,index]
	for step in range(1,7): protected.append((index+step)%24)
	set_tile(index,"forest",protected)
	if sample:
		for i in range(6): set_tile((index+i+1)%24,KINDS[i],protected)
	session.world.position=index
	check(session.save_world(),"isolated actual hill state saved")
	var restored=STATE.new(session.world.definitions,1)
	check(restored.restore(session.world.snapshot()),"capture fixture preserves the canonical save schema")
	var map:Control=MAP.instantiate()
	root.add_child(map)
	for frame in range(3): await process_frame
	map.show_location(index)
	check(map.overlay.get_script()==preload("res://systems/exploration_actions.gd"),"actual location opens the approved direct picker")
	await create_timer(0.35).timeout
	return map
func dispose(map:Control) -> void:
	map.queue_free()
	var deadline:int=Time.get_ticks_msec()+10000
	# Queued deletion happens after process_frame. Drain only once _exit_tree
	# has transferred the scene's unfinished requests to PendingLoads.
	while is_instance_valid(map) and Time.get_ticks_msec()<deadline: await process_frame
	check(not is_instance_valid(map),"captured scene finishes queued deletion")
	while not preload("res://systems/battle_resources.gd").PendingLoads.active.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(preload("res://systems/battle_resources.gd").PendingLoads.active.is_empty(),"captured scene drains all background resource requests")
	await process_frame
func run() -> void:
	root.size=Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	out=OS.get_environment("HILL_CAPTURE_DIR")
	if out.is_empty(): out=ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(out)
	session=root.get_node("RunSession")
	var old_path:String=session.save_file_path
	var isolated:String="user://hill_capture_%d.json"%OS.get_process_id()
	session.save_file_path=isolated
	var map:Control=await open(16,true)
	var panel:Control=map.overlay
	var snapshot:Dictionary=session.world.snapshot().duplicate(true)
	var saved:PackedByteArray=FileAccess.get_file_as_bytes(isolated)
	await capture("01_choose")
	check(panel.action_button.disabled and not panel.hill_picker.flag.visible,"initial production screen waits for a choice")
	panel.hill_choice_buttons[3].pressed.emit()
	await capture("02_selected")
	check(panel.hill_selected_steps==4 and panel.hill_picker.flag.visible and not panel.action_button.disabled,"actual tile selection enlarges the destination and enables travel")
	check(session.world.snapshot()==snapshot and FileAccess.get_file_as_bytes(isolated)==saved,"native screen selection changes no gameplay, save or RNG")
	await dispose(map)
	map=await open((STATE.HOME-2+24)%24)
	panel=map.overlay
	panel.hill_choice_buttons[1].pressed.emit()
	await capture("03_home_limit")
	check(panel.hill_selected_steps==2 and panel.hill_notice.text.contains("우리집"),"actual HOME itself remains selectable")
	check(panel.hill_choice_buttons.slice(2).all(func(control): return control.disabled),"all destinations after HOME stay locked")
	await dispose(map)
	var audio:Node=root.get_node_or_null("GameAudio")
	var deadline:int=Time.get_ticks_msec()+5000
	while audio!=null and not audio.voices.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	if audio!=null: audio.queue_free()
	while is_instance_valid(audio) and Time.get_ticks_msec()<deadline: await process_frame
	check(not is_instance_valid(audio),"capture audio cleanup finishes before shutdown")
	await process_frame
	session.world=null
	session.save_file_path=old_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(isolated+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated+suffix))
	print("HILL_ROUTE_CAPTURE: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
