extends "res://scripts/test_fortune_direct_flow.gd"
const PRAYER=preload("res://systems/exploration_actions.gd")
func fixture(tag:String,face:int=4) -> int:
	save="user://prayer_direct_%d_%s.json"%[OS.get_process_id(),tag]
	paths.append(save)
	session.save_file_path=save
	session.start_new_world()
	var world=session.world
	var index:int=world.tiles.find("basic")
	world.tiles[index]="unknown"
	world.position=index
	world.contamination=10
	world.dice_visual_position=[450,250]
	world.dice_visual_rotation=17
	world.dice_visual_face=2
	world.last_face=5
	world.previous_map_roll=3
	world.rng.seed=seed_for(face)
	check(session.save_world(),tag+": isolated prayer fixture saves")
	return index
func enter(map:Control,index:int) -> Control:
	map.show_location(index)
	check(map.overlay.get_script()==PRAYER,"ordinary arrival opens direct prayer")
	return map.overlay
func all_faces() -> void:
	for face in range(1,7):
		var index:int=fixture("face%d"%face,face)
		var map:Control=await new_map()
		var before:Dictionary=session.world.snapshot().duplicate(true)
		var bytes:PackedByteArray=FileAccess.get_file_as_bytes(save)
		var panel:Control=enter(map,index)
		check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes,"opening neither saves nor draws")
		check(panel.dice==map.dice and panel.action_button==null and panel.prayer_can_roll(),"one actual die is the only action")
		check(map.dice.position==Vector2(450,250) and is_equal_approx(map.dice.rotation_degrees,17),"opening preserves die pose")
		check(Rect2(panel.prayer_notice_strip.position,panel.prayer_notice_strip.size)==Rect2(340,423,600,150),"full common lower parchment")
		check(Rect2(panel.close_button.position,panel.close_button.size)==map.TILE_EVENT_EXIT_RECT and panel.close_button.text=="맵으로 나가기","common exit slot")
		check(panel.prayer_detail.visible and panel.prayer_detail.text.contains("1~3") and panel.prayer_detail.text.contains("4~5"),"original risks on detail line")
		for child in panel.get_children():
			if child is Label and child.visible and not child.text.is_empty(): check(child.position.y>=423,"no upper title or stray guide")
		var preview:=RandomNumberGenerator.new()
		preview.seed=session.world.rng.seed
		preview.state=session.world.rng.state
		check(preview.randi_range(1,6)==face,"predicted actual next draw")
		map.dice.pressed.emit()
		check(panel.busy and panel.close_button.disabled and map.dice.disabled,"roll locks exit and input")
		var delta:int=-5 if face==6 else (-3 if face>=4 else 1)
		var receipt:String=session.place_visit_id("purify",index)
		check(int(session.world.prayer_result.face)==face and int(session.world.prayer_result.delta)==delta and session.world.contamination==10+delta,"original face-specific prayer rule saved")
		check(session.world.reward_receipts.count(receipt)==1 and session.world.rng.state==preview.state,"exactly one RNG draw and visit receipt")
		var committed:Dictionary=session.world.snapshot().duplicate(true)
		panel.pray()
		map.dice.pressed.emit()
		panel.close_button.pressed.emit()
		check(session.world.snapshot()==committed and map.overlay==panel,"busy duplicates and exit cannot interfere")
		check(await until(func(): return not panel.busy),"actual die and prayer complete")
		check(map.dice.disabled and map.dice.mouse_filter==Control.MOUSE_FILTER_IGNORE and not panel.close_button.disabled,"spent die cannot cover exit")
		check(panel.status.text.contains("오염도") and panel.prayer_detail.text.contains("완료"),"completion remains on common notice")
		check(session.world.position==before.position and session.world.move_serial==before.move_serial and session.world.dice_cards==before.dice_cards and session.world.roster==before.roster and session.world.last_face==before.last_face and session.world.previous_map_roll==before.previous_map_roll,"no movement, card cost or monster changes")
		committed=session.world.snapshot().duplicate(true)
		await close(map,panel)
		panel=enter(map,index)
		panel.pray()
		check(session.world.snapshot()==committed and map.dice.disabled and map.pending_location_papers.is_empty(),"reopen reads saved result without reroll or phantom paper")
		await dispose(map)
		session.reload_world()
		map=await new_map()
		panel=enter(map,index)
		check(map.shared_dice_face()==face and map.dice.texture_normal.resource_path.ends_with("result-%02d.png"%face),"reload restores committed visible face")
		# Legacy prayer JSON restores numeric values as floats; keep that schema.
		var reloaded:Dictionary=session.world.snapshot()
		for key in ["face","delta"]: reloaded.prayer_result[key]=int(reloaded.prayer_result[key])
		check(reloaded==committed and not panel.prayer_can_roll(),"reload keeps outcome and one-use lock")
		await dispose(map)
func cancellation_and_failure() -> void:
	var index:int=fixture("failure",4)
	session.world.event_flags["ui:unlock:unknown:action_pending"]=true
	check(session.save_world(),"pending NEW fixture saves")
	var map:Control=await new_map()
	var panel:Control=enter(map,index)
	var before:Dictionary=session.world.snapshot().duplicate(true)
	panel.close_button.pressed.emit()
	panel.pray()
	map.dice.pressed.emit()
	check(session.world.snapshot()==before,"closing prevents a new prayer")
	check(session.event_flag_is_set("ui:unlock:unknown:action_pending"),"opening and cancelling keep action NEW")
	check(await until(func(): return not is_instance_valid(map.overlay)),"one exit returns to map")
	panel=enter(map,index)
	session.save_file_path="user://missing_prayer_%d/save.json"%OS.get_process_id()
	panel.pray()
	check(not panel.busy and panel.prayer_can_roll() and not panel.close_button.disabled and panel.status.text.contains("저장"),"save failure visibly retryable")
	check(session.world.snapshot()==before and map.pending_location_papers.is_empty(),"save failure restores receipt, contamination and RNG")
	session.save_file_path=save
	panel.pray()
	check(await until(func(): return not panel.busy),"retry completes")
	check(session.world.contamination==7 and session.world.reward_receipts.count(session.place_visit_id("purify",index))==1,"retry commits original result once")
	check(not session.event_flag_is_set("ui:unlock:unknown:action_pending"),"successful actual prayer acknowledges NEW")
	await dispose(map)
func guards_and_legacy() -> void:
	var index:int=fixture("guards")
	var map:Control=await new_map()
	var panel:Control=enter(map,index)
	var before:Dictionary=session.world.snapshot().duplicate(true)
	session.world.position=(index+1)%24
	check(not panel.prayer_can_roll(),"cannot pray from another tile")
	session.world.position=index
	var replacement:Control=map.modal(false)
	panel.pray()
	check(session.world.snapshot()==before and map.overlay==replacement,"stale owner cannot pray")
	panel.queue_free()
	await dispose(map)
	index=fixture("legacy")
	session.world.reward_receipts.append(session.place_visit_id("purify",index))
	session.world.prayer_result={"visit":"other-visit","face":6,"delta":-5}
	check(session.save_world(),"legacy spent fixture saves")
	map=await new_map()
	panel=enter(map,index)
	check(not panel.prayer_can_roll() and panel.status.text.contains("완료") and not panel.status.text.contains("대축복"),"legacy spent record cannot show unrelated outcome or reroll")
	await dispose(map)
	index=fixture("queued_map")
	map=await new_map()
	panel=enter(map,index)
	before=session.world.snapshot().duplicate(true)
	var map_ref:WeakRef=weakref(map)
	map.queue_free()
	panel.pray()
	check(session.world.snapshot()==before,"queued map cannot save a prayer")
	check(await until(func(): return map_ref.get_ref()==null),"queued map finishes deletion")
	check(await until(func(): return LOADS.PendingLoads.active.is_empty()),"queued map loads drain")
func natural_arrival() -> void:
	var index:int=fixture("arrival")
	session.world.position=(index+23)%24
	session.world.rng.seed=seed_for(1)
	check(session.save_world(),"natural one-step fixture saves")
	var map:Control=await new_map()
	await map.roll_move()
	check(session.world.position==index and session.world.pending_move.is_empty() and not map.moving,"real movement reaches world tree")
	check(map.overlay.get_script()==PRAYER and map.overlay.prayer_can_roll() and session.world.prayer_result.is_empty(),"natural arrival opens usable prayer without rolling it")
	await dispose(map)
func run() -> void:
	session=root.get_node("RunSession")
	var original:String=session.save_file_path
	await all_faces()
	await cancellation_and_failure()
	await guards_and_legacy()
	await natural_arrival()
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
	print("WORLD_TREE_DIRECT_FLOW: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
