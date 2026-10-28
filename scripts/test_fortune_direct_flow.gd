extends SceneTree
## Actual shared-die transactions, readable completion and interruption safety.
const MAP=preload("res://map.tscn")
const ACTIONS=preload("res://systems/place_actions.gd")
const STATE=preload("res://systems/map_state.gd")
const LOADS=preload("res://systems/battle_resources.gd")
var passed:int=0
var failed:int=0
var session:Node
var paths:Array[String]=[]
var save:String
func _initialize() -> void: call_deferred("run")
func check(ok:bool,message:String) -> void:
	if ok: passed+=1; print("PASS fortune-direct: ",message)
	else: failed+=1; printerr("FAIL fortune-direct: ",message)
func until(predicate:Callable,limit:int=12000) -> bool:
	var deadline:int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func seed_for(face:int) -> int:
	var rng:=RandomNumberGenerator.new()
	for seed in range(1,1000):
		rng.seed=seed
		if rng.randi_range(1,6)==face: return seed
	return 1
func fixture(tag:String,face:int=4) -> int:
	save="user://fortune_direct_%d_%s.json"%[OS.get_process_id(),tag]
	paths.append(save)
	session.save_file_path=save
	session.start_new_world()
	var world=session.world
	var camp:int=world.tiles.find("fortune-teller-camp")
	world.position=camp
	world.dice_visual_position=[450,250]
	world.dice_visual_rotation=17
	world.dice_visual_face=2
	world.last_face=5
	world.previous_map_roll=3
	if face==2:
		world.roster[0].current_hp=maxi(1,int(world.roster[0].max_hp)-1)
		world.event_flags["discovery:ever_injured"]=true
	world.rng.seed=seed_for(face)
	check(session.save_world(),tag+": isolated fixture saves")
	var restored=STATE.new(world.definitions,1)
	check(restored.restore(world.snapshot()),tag+": canonical save schema valid")
	return camp
func new_map() -> Control:
	var map:Control=MAP.instantiate()
	root.add_child(map)
	map.map_music.stop()
	map.map_music.stream=null
	# Headless state checks do not exercise audio output. Retire no decoder
	# at the exact shutdown boundary; native capture keeps its actual cues.
	if DisplayServer.get_name()=="headless": AudioServer.set_bus_mute(0,true)
	for frame in range(3): await process_frame
	return map
func enter(map:Control,camp:int) -> Control:
	map.show_location(camp)
	check(map.overlay.get_script()==ACTIONS,"actual location opens direct prophecy screen")
	return map.overlay
func dispose(map:Control) -> void:
	var ref:WeakRef=weakref(map)
	map.queue_free()
	check(await until(func(): return ref.get_ref()==null),"scene deletion finishes")
	check(await until(func(): return LOADS.PendingLoads.active.is_empty()),"scene background loads drain")
func close(map:Control,panel:Control) -> void:
	panel.close_button.pressed.emit()
	check(await until(func(): return not is_instance_valid(map.overlay)),"one common exit returns to map")
func all_faces() -> void:
	var tones:Array=[]
	for face in range(1,7):
		var camp:int=fixture("face%d"%face,face)
		var map:Control=await new_map()
		var before:Dictionary=session.world.snapshot().duplicate(true)
		var bytes:PackedByteArray=FileAccess.get_file_as_bytes(save)
		var panel:Control=enter(map,camp)
		check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes,"opening does not save or consume RNG")
		check(map.dice.position==Vector2(450,250) and is_equal_approx(map.dice.rotation_degrees,17.0),"opening preserves the real die stopping pose")
		check(panel.dice==map.dice and panel.confirm_button==null and panel.fortune_can_roll(),"one shared die is the only action")
		check(Rect2(panel.close_button.position,panel.close_button.size)==map.TILE_EVENT_EXIT_RECT and panel.close_button.text=="맵으로 나가기","common exit stays in original slot")
		check(panel.fortune_hint.text.contains("이동 없음") and panel.fortune_hint.text.contains("방문당 1회") and panel.fortune_hint.text.contains("1 저주"),"idle guidance explains movement limit and curse risk")
		var preview:=RandomNumberGenerator.new()
		preview.seed=session.world.rng.seed
		preview.state=session.world.rng.state
		check(preview.randi_range(1,6)==face,"fixture predicts actual next gameplay draw")
		map.dice.pressed.emit()
		check(panel.busy and panel.close_button.disabled and map.dice.disabled,"roll immediately locks input")
		var receipt:String=session.place_visit_id("prophecy",camp)
		check(int(session.world.last_prophecy.face)==face and session.world.reward_receipts.count(receipt)==1 and session.world.rng.state==preview.state,"one actual outcome commits before animation")
		var atomic:Dictionary=session.world.snapshot().duplicate(true)
		panel.roll_prophecy()
		map.dice.pressed.emit()
		check(session.world.snapshot()==atomic,"duplicate during roll cannot draw or grant again")
		check(await until(func(): return panel.fortune_effect.active),"actual result enters temporary ink reveal")
		check(panel.busy and int(panel.fortune_effect.face)==face,"ink keeps input locked for actual saved face")
		tones.append(panel.fortune_effect.tone)
		check(await until(func(): return not panel.busy),"ink and result finish")
		check(map.dice.disabled and map.dice.mouse_filter==Control.MOUSE_FILTER_IGNORE and not panel.close_button.disabled,"completed die cannot block the enabled common exit")
		check(panel.fortune_hint.text.contains("이번 방문 완료") and panel.fortune_result.text.begins_with("다음 전투 합계: "),"completion distinguishes result from next battle total")
		var world=session.world
		check(world.position==before.position and world.move_serial==before.move_serial and world.last_face==before.last_face and world.previous_map_roll==before.previous_map_roll and world.dice_cards==before.dice_cards,"prophecy causes no movement or card cost")
		check(int(world.prophecy.get("enemy_attack",0))==(1 if face==1 else 0) and int(world.prophecy.get("ally_speed",0))==(1 if face==3 else 0) and int(world.prophecy.get("ally_hp",0))==(2 if face in [4,6] else 0) and int(world.prophecy.get("ally_attack",0))==(1 if face in [5,6] else 0),"all original face-specific battle effects preserved")
		if face==2: check(world.roster.all(func(unit): return unit.current_hp==unit.max_hp) and world.prophecy.rolls.is_empty(),"healing is immediate and adds no combat roll stack")
		else: check(world.roster==before.roster and world.prophecy.rolls==[face],"battle buffs do not alter permanent monsters")
		var complete:Dictionary=world.snapshot().duplicate(true)
		bytes=FileAccess.get_file_as_bytes(save)
		await close(map,panel)
		panel=enter(map,camp)
		panel.roll_prophecy()
		check(map.dice.disabled and not panel.fortune_effect.active and panel.fortune_hint.text.contains("이번 방문 완료"),"normal reopening reads completion without replaying")
		check(session.world.snapshot()==complete and FileAccess.get_file_as_bytes(save)==bytes and map.pending_location_papers.is_empty(),"reopening neither grants nor saves nor queues removed paper")
		await dispose(map)
	check(tones[0]!=tones[2] and tones[1]!=tones[2] and tones[5]!=tones[2],"curse healing blessing and grand blessing are visually distinct")
func natural_arrival() -> void:
	var camp:int=fixture("arrival")
	session.world.position=23
	session.world.rng.seed=seed_for(1)
	check(camp==0 and session.save_world(),"natural arrival preserves fixed map anchors")
	var map:Control=await new_map()
	var previous_receipts:Array=session.world.reward_receipts.duplicate()
	await map.roll_move()
	check(session.world.position==camp and session.world.pending_move.is_empty() and not map.moving,"actual one-step map travel reaches camp and finishes")
	check(is_instance_valid(map.overlay) and map.overlay.get_script()==ACTIONS and map.overlay.fortune_can_roll() and not map.dice.disabled,"natural arrival directly exposes usable prophecy")
	check(session.world.last_prophecy.is_empty() and session.world.reward_receipts==previous_receipts,"arrival alone grants no prophecy or use receipt")
	await dispose(map)

func cancellation_and_failure() -> void:
	var camp:int=fixture("cancel")
	var map:Control=await new_map()
	var panel:Control=enter(map,camp)
	var before:Dictionary=session.world.snapshot().duplicate(true)
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(save)
	panel.close_button.pressed.emit()
	map.dice.pressed.emit()
	panel.roll_prophecy()
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes,"exit then immediate die activation cannot start a prophecy")
	check(await until(func(): return not is_instance_valid(map.overlay)),"cancel closes to map")
	check(map.dice.get_node_or_null("FortuneDieCue")==null and not map.dice.disabled,"cancel removes cue and restores map input")
	panel=enter(map,camp)
	session.save_file_path="user://missing_fortune_%d/file.json"%OS.get_process_id()
	panel.roll_prophecy()
	check(not panel.busy and panel.fortune_can_roll() and not panel.close_button.disabled and panel.status.text.contains("저장"),"failed save keeps same screen visibly retryable")
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes and not panel.fortune_effect.active,"save failure rolls back outcome receipt and RNG")
	session.save_file_path=save
	panel.roll_prophecy()
	check(await until(func(): return not panel.busy),"retry finishes")
	check(int(session.world.last_prophecy.face)==4 and session.world.reward_receipts.count(session.place_visit_id("prophecy",camp))==1,"retry uses original RNG and commits once")
	await dispose(map)
func guards_and_legacy() -> void:
	var camp:int=fixture("guards")
	var map:Control=await new_map()
	session.world.position=STATE.HOME
	var panel:Control=enter(map,camp)
	check(not panel.fortune_can_roll() and map.dice.disabled and not panel.close_button.disabled,"remote preview cannot roll and can exit")
	map.close_overlay()
	session.world.position=camp
	panel=enter(map,camp)
	for kind in ["reward","move","encounter","busy","moving","shared","ended"]:
		match kind:
			"reward": session.world.pending_reward={"kind":"test"}
			"move": session.world.pending_move={"kind":"test"}
			"encounter": session.encounter={"id":"test"}
			"busy": panel.busy=true
			"moving": map.moving=true
			"shared": map.shared_die_busy=true
			"ended": session.world.run_result={"reason":"test"}
		var before:Dictionary=session.world.snapshot().duplicate(true)
		map.refresh_shared_die_input()
		panel.roll_prophecy()
		check(map.dice.disabled and session.world.snapshot()==before,kind+": guarded input cannot call transaction")
		match kind:
			"reward": session.world.pending_reward={}
			"move": session.world.pending_move={}
			"encounter": session.encounter={}
			"busy": panel.busy=false
			"moving": map.moving=false
			"shared": map.shared_die_busy=false
			"ended": session.world.run_result={}
	map.close_overlay()
	var visit:String=session.place_visit_id("prophecy",camp)
	session.world.reward_receipts.append(visit)
	for saved in [{},{"visit":"other","face":6,"detail":"STALE"}]:
		session.world.last_prophecy=saved
		panel=enter(map,camp)
		check(map.dice.disabled and panel.status.text.contains("완료") and not panel.status.text.contains("STALE"),"legacy completed receipt never offers fresh or stale result")
		check(map.shared_dice_face()==session.world.dice_visual_face,"stale last result cannot override displayed face")
		map.close_overlay()
	await dispose(map)
func interruption_and_total() -> void:
	var camp:int=fixture("interrupted",6)
	var map:Control=await new_map()
	enter(map,camp)
	map.dice.pressed.emit()
	var committed:Dictionary=session.world.snapshot().duplicate(true)
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(save)
	check(committed.last_prophecy.face==6 and committed.dice_visual_face!=6,"catch atomic result before visual face saves")
	await dispose(map)
	session.reload_world()
	check(session.world.snapshot()==committed and FileAccess.get_file_as_bytes(save)==bytes,"interrupted committed prophecy survives unchanged")
	map=await new_map()
	var panel:Control=enter(map,camp)
	check(map.shared_dice_face()==6 and map.dice.texture_normal.resource_path.ends_with("result-06.png") and map.dice.disabled,"restart displays committed face without reroll")
	check(session.world.snapshot()==committed and map.dice.position==Vector2(450,250) and is_equal_approx(map.dice.rotation_degrees,17.0),"restored display changes no saved fields or pose")
	await close(map,panel)
	check(map.dice.texture_normal.resource_path.ends_with("result-06.png") and FileAccess.get_file_as_bytes(save)==bytes,"board exit retains committed displayed face without saving")
	panel=enter(map,camp)
	session.world.prophecy={"rolls":[1,3,4,5],"ally_attack":9999,"ally_hp":9999,"ally_speed":9999,"enemy_attack":9999}
	panel.show_fortune_result()
	for frame in range(3): await process_frame
	var font:Font=panel.fortune_result.get_theme_font("font")
	var font_size:int=panel.fortune_result.get_theme_font_size("font_size")
	check(font.get_string_size(panel.fortune_result.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=494 and panel.fortune_result.get_line_count()==1,"four long totals fit unchanged shared detail line")
	await dispose(map)
func replacement_owner() -> void:
	var camp:int=fixture("replacement",5)
	var map:Control=await new_map()
	var panel:Control=enter(map,camp)
	panel.roll_prophecy()
	var ref:WeakRef=weakref(panel)
	panel.queue_free()
	var replacement:Control=map.modal(false)
	replacement.name="ReplacementOwner"
	check(await until(func(): return ref.get_ref()==null),"old rolling panel deleted")
	check(await until(func(): return not map.shared_die_busy),"map-owned die settles after old panel deletion")
	check(map.overlay==replacement and map.dice.disabled and map.dice.get_node_or_null("FortuneDieCue")==null,"old callback cannot dismiss or unlock replacement owner")
	check(session.world.reward_receipts.count(session.place_visit_id("prophecy",camp))==1 and map.pending_location_papers.is_empty(),"replacement creates no duplicate outcome or paper")
	await dispose(map)
func ink_owner_replacement() -> void:
	var camp:int=fixture("ink_replacement",4)
	var map:Control=await new_map()
	var panel:Control=enter(map,camp)
	panel.roll_prophecy()
	check(await until(func(): return panel.fortune_effect.active),"ink detach fixture reaches actual reveal")
	var committed:Dictionary=session.world.snapshot().duplicate(true)
	var ref:WeakRef=weakref(panel)
	panel.queue_free()
	var replacement:Control=map.modal(false)
	check(await until(func(): return ref.get_ref()==null),"ink owner deletion completes")
	for frame in range(4): await process_frame
	check(map.overlay==replacement and map.dice.disabled and map.dice.get_node_or_null("FortuneDieCue")==null,"ink cancellation preserves newer owner and removes cue")
	check(session.world.snapshot()==committed,"cancelled ink cannot change committed result or RNG")
	await dispose(map)

func run() -> void:
	session=root.get_node("RunSession")
	var original:String=session.save_file_path
	await all_faces()
	await natural_arrival()
	await cancellation_and_failure()
	await guards_and_legacy()
	await interruption_and_total()
	await replacement_owner()
	await ink_owner_replacement()
	var audio:Node=root.get_node_or_null("GameAudio")
	await until(func(): return audio==null or audio.voices.is_empty())
	if audio!=null: audio.queue_free()
	var deadline:int=Time.get_ticks_msec()+5000
	while is_instance_valid(audio) and Time.get_ticks_msec()<deadline: await process_frame
	await process_frame
	session.world=null
	session.save_file_path=original
	for path in paths:
		for suffix in ["",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("FORTUNE_DIRECT_FLOW: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
