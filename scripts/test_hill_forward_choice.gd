extends SceneTree
## Actual hill UI + durable 1..6 forward choice, home boundary, warp/swamp,
## rollback, reload and no new scouting. Runs with isolated user:// data.
const MapScene = preload("res://map.tscn")
const MapState = preload("res://systems/map_state.gd")
var passed:int=0
var failed:int=0
var all_paths:Array[String]=[]

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, reason: String) -> void:
	if ok:
		passed+=1
		print("PASS hill-forward: ",reason)
	else:
		failed+=1
		printerr("FAIL hill-forward: ",reason)

func start_case(session: Node, name: String, tile_index: int = 3, target_index: int = -1, target_type: String = "") -> void:
	var path: String="user://hill_forward_%d_%s.json" % [OS.get_process_id(),name]
	all_paths.append(path)
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	session.save_file_path=path
	session.start_new_world()
	var world=session.world
	var old_hill:int=world.tiles.find("forest")
	if old_hill != tile_index:
		var previous: String=world.tiles[tile_index]
		world.tiles[tile_index]="forest"
		world.tiles[old_hill]=previous
	if target_index>=0 and target_type!="":
		var original_type:String=world.tiles[target_index]
		if original_type != target_type:
			var other:int=-1
			for i in range(world.tiles.size()):
				if i not in [0,8,MapState.HOME,tile_index,target_index] and world.tiles[i]==target_type:
					other=i
					break
			if other>=0:
				world.tiles[target_index]=target_type
				world.tiles[other]=original_type
	world.position=tile_index
	check(session.save_world(),name+": fixture saved using isolated user data")

func find_btn(parent: Node, caption: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text==caption: return child
	return null

func test_hill_ui(session: Node) -> void:
	start_case(session,"ui",3,7,"basic")
	var world=session.world
	world.last_face=5
	world.previous_map_roll=2
	check(session.save_world(),"UI: original die history persisted")
	var old_rng:int=world.rng.state
	var old_rewards:int=world.reward_receipts.size()
	var map:Control=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(not is_instance_valid(map.overlay),"UI: no modal until hill entered")
	map.show_location(3)
	var entry:Button=find_btn(map.overlay,"이동 위치 선택")
	check(entry!=null,"UI: hill offers movement, not scouting")
	check(find_btn(map.overlay,"정찰")==null,"UI: old monster intel control is gone")
	if entry!=null:
		entry.pressed.emit()
		await process_frame
	var hill_panel=map.overlay
	var choice4:Button=hill_panel.find_child("HillStep4",true,false) as Button
	var choose:Button=find_btn(hill_panel,"이동 확정")
	check(choice4!=null and choose!=null,"UI: six destination steps and confirmation are displayed")
	check(choose!=null and choose.disabled,"UI: cannot move before selecting a distance")
	var prior_dice:Texture2D=map.dice.texture_normal
	if choice4!=null: choice4.pressed.emit()
	check(map.selected==7,"UI: preview highlights tile 8 (four ahead)")
	check(choose!=null and not choose.disabled,"UI: an explicit selection enables confirmation")
	if choose!=null: choose.pressed.emit()
	var began:int=Time.get_ticks_msec()
	while (map.moving or not session.world.pending_move.is_empty()) and Time.get_ticks_msec()-began<9000:
		await process_frame
	check(not map.moving and session.world.pending_move.is_empty(),"UI: saved movement animation finishes once")
	check(world.position==7 and map.selected==7,"UI: hero really arrives at selected tile 8")
	check(map.dice.texture_normal==prior_dice and world.last_face==5 and world.previous_map_roll==2,"UI: original die image and prior roll history unchanged")
	check(world.rng.state==old_rng,"UI: choice does not consume RNG")
	check(world.reward_receipts.size()==old_rewards+1,"UI: exactly one hill use receipt created")
	check(world.scout.scouted==false and world.scout.intel.is_empty(),"UI: no monster scouting intel created")
	map.queue_free()
	await process_frame
	var expected:Dictionary=world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==expected,"UI: committed choice survives disk reload")

func test_home_rule(session: Node) -> void:
	start_case(session,"home",13)
	var before:Dictionary=session.world.snapshot().duplicate(true)
	var denied:Dictionary=session.prepare_hill_move(13,3)
	check(not denied.get("ok",false) and session.world.snapshot()==before,"HOME: 3 steps cannot skip the home at distance 2")
	var wrong:Dictionary=session.prepare_hill_move(13,0)
	check(not wrong.get("ok",false) and session.world.snapshot()==before,"HOME: zero distance rejected without writes")
	wrong=session.prepare_hill_move(13,7)
	check(not wrong.get("ok",false) and session.world.snapshot()==before,"HOME: seven steps rejected without writes")
	var accepted:Dictionary=session.prepare_hill_move(13,2)
	check(accepted.get("ok",false) and session.world.position==MapState.HOME,"HOME: two forward steps reach actual home")
	check(session.world.lap_ready and session.world.pending_move.path.size()==2,"HOME: original lap-ready and movement path preserved")
	check(session.complete_map_move() and session.world.pending_move.is_empty(),"HOME: route committed once")
	var receipts:int=session.world.reward_receipts.size()
	var state:Dictionary=session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==state and session.world.reward_receipts.size()==receipts,"HOME: no extra lap or receipt after reload")

func test_pending_recovery(session: Node) -> void:
	start_case(session,"recovery",3,5,"basic")
	var world=session.world
	var old_card_count:int=world.dice_cards.size()
	var old_face:int=world.last_face
	var old_rng:int=world.rng.state
	var started:Dictionary=session.prepare_hill_move(3,2)
	check(started.get("ok",false) and started.get("source","")=="hill","RESTART: pending selected route stored before any animation")
	check(world.move_serial==1 and world.pending_move.path==[4,5],"RESTART: exact two visited tile indices recorded")
	session.reload_world()
	check(session.world.pending_move.get("source","")=="hill" and session.world.position==5,"RESTART: pending destination recovered from JSON")
	var map:Control=MapScene.instantiate()
	root.add_child(map)
	var began:int=Time.get_ticks_msec()
	while (map.moving or not session.world.pending_move.is_empty()) and Time.get_ticks_msec()-began<10000:
		await process_frame
	await process_frame
	check(session.world.pending_move.is_empty() and session.world.position==5,"RESTART: map resumes and finalizes selection once")
	check(session.world.move_serial==1 and session.world.reward_receipts.size()==1,"RESTART: no extra movement/receipt")
	check(session.world.last_face==old_face and session.world.rng.state==old_rng and session.world.dice_cards.size()==old_card_count,"RESTART: choice does not consume a die or owned card")
	map.queue_free()
	await process_frame

func test_warp_swamp(session: Node) -> void:
	start_case(session,"swamp",3,4,"swamp")
	session.world.roster[0].current_hp=2
	var res:Dictionary=session.prepare_hill_move(3,1)
	check(res.get("ok",false) and session.world.position==4,"SWAMP: one-step choice lands naturally on swamp")
	check(session.world.roster[0].current_hp==1 and session.world.pending_move.landed==4,"SWAMP: canonical one-time HP penalty stored")
	check(session.complete_map_move(),"SWAMP: completes transaction")
	session.reload_world()
	check(session.world.roster[0].current_hp==1,"SWAMP: restart does not repeat damage")
	start_case(session,"warp",3,4,"warp")
	res=session.prepare_hill_move(3,1)
	var landed:int=int(res.get("landed",-1))
	check(res.get("ok",false) and landed==4,"WARP: chosen path first lands on real warp")
	check(session.world.position!=landed and session.world.tiles[session.world.position]=="warp","WARP: canonical warp pair destination applied")
	check(session.complete_map_move(),"WARP: one-time warp commit")

func test_fail_and_replay(session: Node) -> void:
	start_case(session,"rollback",3,7,"basic")
	var before:Dictionary=session.world.snapshot().duplicate(true)
	var preserved_path:String=session.save_file_path
	session.save_file_path="user://missing_hill_forward_%d/cannot_write.json" % OS.get_process_id()
	var outcome:Dictionary=session.prepare_hill_move(3,4)
	check(not outcome.get("ok",false),"ROLLBACK: real disk write failure reported")
	check(session.world.snapshot()==before,"ROLLBACK: refused save undoes location RNG dice and receipt")
	session.save_file_path=preserved_path
	outcome=session.prepare_hill_move(3,4)
	check(outcome.get("ok",false),"ROLLBACK: same choice can retry successfully")
	var repeat:Dictionary=session.prepare_hill_move(3,4)
	check(not repeat.get("ok",false),"REPLAY: cannot issue a second hill choice during pending move")
	check(session.complete_map_move(),"REPLAY: pending move resolves")
	session.world.position=3
	# Same committed visit can no longer be replayed; the normal die creates
	# a different move serial for a genuine later hill revisit.
	session.world.move_serial-=1
	check(not session.prepare_hill_move(3,4).get("ok",false),"REPLAY: persisted receipt rejects duplicated visit")
	check(session.world.pending_move.is_empty(),"REPLAY: repeated click cannot create pending move")

func _run() -> void:
	var session:Node=root.get_node_or_null("RunSession")
	check(session!=null,"RunSession available")
	if session==null:
		print("HILL_FORWARD_CHOICE: %d passed, %d failed"%[passed,failed])
		quit(1)
		return
	var original_save:String=session.save_file_path
	await test_hill_ui(session)
	test_home_rule(session)
	await test_pending_recovery(session)
	test_warp_swamp(session)
	test_fail_and_replay(session)
	session.save_file_path=original_save
	for path in all_paths:
		for suffix in ["",".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("HILL_FORWARD_CHOICE: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
