extends SceneTree
## Real direct cemetery -> saved reveal -> explicit collect -> playable map.
const MAP=preload("res://map.tscn")
const SESSION=preload("res://systems/run_session.gd")
const DIG_UI=preload("res://systems/exploration_actions.gd")
var passed:int=0
var failed:int=0

func _initialize() -> void: call_deferred("_run")

func check(ok:bool,message:String) -> void:
	if ok: passed+=1; print("PASS graveyard-exit: ",message)
	else: failed+=1; printerr("FAIL graveyard-exit: ",message)

func wait_for(predicate:Callable,limit:int=5000) -> bool:
	var deadline:int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())

func _run() -> void:
	var session:Node=root.get_node_or_null("RunSession")
	var created:bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var previous_path:String=session.save_file_path
	var path:String="user://graveyard_exit_%d.json"%OS.get_process_id()
	session.save_file_path=path
	session.start_new_world()
	session.world.lap_ready=true
	session.world.leave_home()
	var grave:int=session.world.tiles.find("graveyard")
	check(grave>=0,"graveyard available after first lap")
	if grave<0: quit(1); return
	session.world.position=grave
	session.world.graveyard_corpses=[]
	check(session.save_world(),"corpse-free cemetery position saved")
	var map:Control=MAP.instantiate()
	root.add_child(map)
	for frame in range(3): await process_frame
	map.show_location(grave)
	var panel:Control=map.overlay
	check(is_instance_valid(panel) and panel.get_script()==DIG_UI,"cemetery opens digging directly without a redundant entrance click")
	if not is_instance_valid(panel) or panel.get_script()!=DIG_UI: quit(1); return
	check(panel.action_button!=null and not panel.action_button.disabled,"digging is enabled without an allied corpse")
	var exit_button:Button=panel.graveyard_exit_button
	check(is_instance_valid(exit_button) and not exit_button.disabled and exit_button.visible,"ordinary map exit is available before digging")
	check(exit_button.position==map.TILE_EVENT_EXIT_RECT.position and exit_button.size==map.TILE_EVENT_EXIT_RECT.size,"map exit matches the other ordinary tile buttons")
	check(exit_button.z_index>panel.content.z_index,"exit remains above reward content")
	exit_button.pressed.emit()
	check(await wait_for(func(): return not is_instance_valid(map.overlay)),"unused digging screen exits directly to playable map")
	map.show_location(grave)
	panel=map.overlay
	check(panel.get_script()==DIG_UI and panel.action_button!=null and not panel.action_button.disabled,"unspent digging is still accessible after reopening")
	var prior:int=session.world.dice_cards.size()
	panel.action_button.pressed.emit()
	check(session.world.dice_cards.size()==prior+1 and session.world.graveyard_corpses.is_empty(),"digging commits a dice card immediately without consuming an allied corpse")
	check(panel.busy and panel.graveyard_phase=="revealing" and panel.graveyard_exit_button.disabled,"reveal locks exit until the saved card has been shown")
	check(await wait_for(func(): return not panel.busy and panel.graveyard_phase=="ready"),"soil and card reveal finish before the collection choice")
	check(is_instance_valid(map.overlay) and panel.action_button!=null and panel.action_button.text=="챙기고 나가기" and not panel.action_button.disabled,"revealed card waits for explicit collect-and-leave")
	var committed:Dictionary=session.world.snapshot().duplicate(true)
	panel.action_button.pressed.emit()
	check(panel.busy and panel.graveyard_phase=="delivering","collect starts the card flight instead of an immediate exit")
	check(await wait_for(func(): return not is_instance_valid(map.overlay)),"collection flight finishes before returning to map")
	check(map.dice.visible and not map.dice.disabled,"shared map die reactivates after delivery")
	check(session.world.snapshot()==committed,"collection animation never grants a second reward")
	session.reload_world()
	check(session.world.snapshot()==committed,"card and receipt survive restart")
	map.show_location(grave)
	panel=map.overlay
	check(panel.get_script()==DIG_UI and panel.action_button!=null and panel.action_button.disabled,"spent visit cannot dig again")
	check(is_instance_valid(panel.graveyard_exit_button) and not panel.graveyard_exit_button.disabled,"spent visit still permits departure")
	panel.graveyard_exit_button.pressed.emit()
	check(await wait_for(func(): return not is_instance_valid(map.overlay)),"spent screen exits without another reveal or reward")
	var audio:Node=root.get_node_or_null("GameAudio")
	check(await wait_for(func(): return audio==null or audio.voices.is_empty()),"location audio finishes before scene teardown")
	map.queue_free()
	await process_frame
	var loads=preload("res://systems/battle_resources.gd")
	check(await wait_for(func(): return loads.PendingLoads.active.is_empty()),"exited map resource loads drain before shutdown")
	if audio!=null: audio.queue_free()
	await create_timer(0.10).timeout
	session.save_file_path=previous_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	if created: session.queue_free()
	print("GRAVEYARD_EXTRACTION_EXIT: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
