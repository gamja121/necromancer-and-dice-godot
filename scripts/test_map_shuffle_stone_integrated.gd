extends SceneTree
## Full scene home-exit regression: gather 21 stones into two rings,
## rotate one tooth, visibly exchange two disjoint pairs, scatter matching
## persisted faces, and safely rollback on save failure.
const MapScene = preload("res://map.tscn")
const MapState = preload("res://systems/map_state.gd")
const Gear = preload("res://systems/map_gear_shift.gd")
const SAVE_PATH = "user://stone_shuffle_one_notch_integrated.json"
var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed+=1
		print("PASS stone-integrated: ",description)
	else:
		failed+=1
		printerr("FAIL stone-integrated: ",description)

func gear_nodes(map: Control) -> Array:
	var found: Array=[]
	if is_instance_valid(map.stage):
		for child in map.stage.get_children():
			if child is Gear: found.append(child)
	return found

func wait_for_gear(map: Control) -> bool:
	var started: int=Time.get_ticks_msec()
	while map.moving and Time.get_ticks_msec()-started<14000:
		await process_frame
	return not map.moving

func scene_board_matches(map: Control) -> bool:
	if map.buttons.size()!=24: return false
	for i in range(24):
		if not map.buttons[i].visible or map.buttons[i].texture_normal!=map.texture(map.tile_path(i)): return false
	return true

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	check(session!=null,"real autoload session available")
	if session==null: quit(1); return
	var previous_path: String=session.save_file_path
	session.save_file_path=SAVE_PATH
	session.start_new_world()
	session.world.position=MapState.HOME
	session.world.lap_ready=true
	check(session.save_world(),"isolated home-exit run committed")
	var map: Control=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	var initial_serial: int=session.world.map_serial
	var initial_laps: int=session.world.laps
	var face_before: int=session.world.last_face
	var die_pos: Vector2=map.dice.position
	var die_rot: float=map.dice.rotation_degrees
	for lap in range(3):
		session.world.position=MapState.HOME
		session.world.lap_ready=true
		var previous_tiles: Array=session.world.tiles.duplicate()
		var before_serial: int=session.world.map_serial
		var seen: Dictionary={"visuals":0,"progress_monotone":true,"last_progress":0.0,"faces_stable":true,"phases":{},"swap_move":false,"pairs":0,"input_locked":true}
		var observer: Callable=func():
			if not is_instance_valid(map) or not is_instance_valid(map.stage): return
			var gears: Array=gear_nodes(map)
			if gears.is_empty(): return
			var effect: Control=gears[0]
			seen["visuals"]=maxi(int(seen["visuals"]),effect.visuals.size())
			if not map.moving or not map.dice.disabled: seen["input_locked"]=false
			if effect.phase in ["gather","rotate","swap","scatter"]:
				seen["phases"][effect.phase]=true
			seen["pairs"]=maxi(int(seen["pairs"]),effect.swap_pairs.size())
			if effect.phase=="rotate":
				if effect.last_progress<float(seen["last_progress"])-0.0001:
					seen["progress_monotone"]=false
				seen["last_progress"]=effect.last_progress
			if effect.phase=="swap" and not effect.swap_pairs.is_empty():
				var pair: Dictionary=effect.swap_pairs[0]
				var source_idx: int=effect.source_indices.find(int(pair["a"]))
				if source_idx>=0 and effect.visuals[source_idx].position.distance_to(effect.rotated_centers[source_idx]-effect.visuals[source_idx].size*0.5)>0.5:
					seen["swap_move"]=true
			if effect.phase in ["rotate","swap","scatter"]:
				for i in range(effect.visuals.size()):
					var dest: int=int(effect.target_indices[i])
					if effect.visuals[i].texture!=map.texture(map.tile_path(dest)):
						seen["faces_stable"]=false
		process_frame.connect(observer)
		map.exit_home()
		map.exit_home()
		var finished: bool=await wait_for_gear(map)
		process_frame.disconnect(observer)
		check(finished,"lap %d completes one heavy gear notch without double trigger" % (lap+1))
		if not finished: break
		check(session.world.map_serial==before_serial+1 and session.world.laps==initial_laps+lap+1,"lap %d increments world just once" % (lap+1))
		check(session.world.contamination==mini(100,(lap+1)*7),"lap %d respects existing +7 contamination" % (lap+1))
		check(scene_board_matches(map) and map.world==session.world,"lap %d shows exact persisted tile types" % (lap+1))
		check(gear_nodes(map).is_empty() and not map.moving and not map.dice.disabled,"lap %d leaves no ghost tiles and releases input" % (lap+1))
		var four_phases: bool=true
		for name in ["gather","rotate","swap","scatter"]:
			if not seen["phases"].has(name): four_phases=false
		check(int(seen["visuals"])==21 and four_phases,"lap %d visibly gathers, one-notch rotates, swaps and scatters all 21 tiles" % (lap+1))
		check(int(seen["pairs"])==2 and bool(seen["swap_move"]),"lap %d shows two real simultaneous exchanged tile pairs" % (lap+1))
		check(bool(seen["faces_stable"]) and bool(seen["progress_monotone"]) and is_equal_approx(float(seen["last_progress"]),1.0),"lap %d has no post-landing face flip or repeated ring spin" % (lap+1))
		check(bool(seen["input_locked"]),"lap %d blocks input during the moving gear" % (lap+1))
		check(map.dice.position==die_pos and map.dice.rotation_degrees==die_rot and session.world.last_face==face_before,"lap %d does not move or reroll the die" % (lap+1))
		var minimum_changes: int=Gear.changed_count(previous_tiles,session.world.tiles,session.world.map_serial)
		if lap==0: check(minimum_changes==1,"first lap converts only one tile into the required graveyard")
		elif lap==1: check(minimum_changes==0,"second lap keeps all shifted tile identities")
		elif lap==2: check(session.world.tiles[MapState.BOSS_TILE_INDEX]=="boss" and session.world.current_boss_stage()==20 and not session.world.final_dragon_available(),"contamination 21 opens the first stage boss, not the final dragon")
	check(session.world.map_serial==initial_serial+3,"three actual home exits were committed")
	if failed==0:
		session.world.position=MapState.HOME
		session.world.lap_ready=true
		var snap: Dictionary=session.world.snapshot().duplicate(true)
		session.save_file_path="user://missing_gear_shuffle_directory/blocked.json"
		map.exit_home()
		var aborted: bool=await wait_for_gear(map)
		check(aborted,"failed save does not hang behind a transition")
		check(session.world.snapshot()==snap,"failed save fully restores map, RNG, counts, lap and dice")
		check(gear_nodes(map).is_empty(),"failed save creates no deceptive moving tile")
		check(is_instance_valid(map.overlay),"failed save returns to retryable home")
		check(not map.moving and map.dice.disabled,"failed save releases movement lock while retryable home modal still prevents die clicks")
		map.close_overlay()
		check(not map.dice.disabled,"closing failed-save home modal restores clickable die")
	# Drain the new map's asynchronous audio controls before scene teardown.
	for i in range(6): await process_frame
	map.queue_free()
	await process_frame
	session.save_file_path=SAVE_PATH
	session.reload_world()
	check(session.world.laps==initial_laps+3,"disk reload returns committed three laps")
	session.save_file_path=previous_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(SAVE_PATH+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH+suffix))
	print("MAP_SHUFFLE_STONE_INTEGRATED: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
