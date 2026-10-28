extends "res://scripts/test_fortune_direct_flow.gd"
## Shared location layout and the original atomic rest recovery transaction.
func location_fixture(kind:String,injured:bool=false) -> int:
	var index:int=fixture("shared_"+kind,6)
	if kind=="graveyard":
		session.world.lap_ready=true
		session.world.leave_home()
		index=session.world.tiles.find(kind)
	elif kind!="fortune-teller-camp":
		index=session.world.tiles.find(kind)
		if index<0:
			index=session.world.tiles.find("basic")
			session.world.tiles[index]=kind
	session.world.position=index
	if injured:
		for unit in session.world.roster: unit.current_hp=maxi(1,int(unit.max_hp)-1)
		session.world.event_flags["discovery:ever_injured"]=true
	check(session.save_world(),kind+": actual layout fixture saves")
	var restored=STATE.new(session.world.definitions,1)
	check(restored.restore(session.world.snapshot()),kind+": canonical schema preserved")
	return index
func pieces(panel:Control,kind:String) -> Array:
	var names:Array
	match kind:
		"graveyard": names=["GraveyardNoticeStrip","GraveyardNoticeText","GraveyardNoticeDetail"]
		"forest": names=["HillNoticeStrip","HillNoticeText","HillNoticeDetail"]
		"rest": names=["RestNoticeStrip","RestNoticeText","RestNoticeDetail"]
		_: return [panel.fortune_notice_strip,panel.status,panel.fortune_result]
	return names.map(func(value): return panel.find_child(value,true,false))
func button(panel:Control,text:String) -> Button:
	for child in panel.find_children("*","Button",true,false):
		if child.text==text: return child
	return null
func same_rect(actual:Rect2,expected:Rect2) -> bool:
	return actual.position.distance_to(expected.position)<0.2 and actual.size.distance_to(expected.size)<0.2
func geometry(map:Control,kind:String) -> void:
	var panel:Control=map.overlay
	var controls:Array=pieces(panel,kind)
	check(controls.all(func(node): return is_instance_valid(node) and node.is_visible_in_tree()),kind+": common lower notice and detail visible")
	check(same_rect(controls[0].get_global_rect(),Rect2(340,423,600,150)),kind+": same full parchment rectangle")
	check(same_rect(controls[1].get_global_rect(),Rect2(394,465,492,30)) and same_rect(controls[2].get_global_rect(),Rect2(393,500,494,24)),kind+": both information lines use identical positions")
	check(controls[1].get_theme_font_size("font_size")==20 and controls[2].get_theme_font_size("font_size")==14,kind+": common readable type sizes")
	check(controls[1].get_line_count()==1 and controls[2].get_line_count()==1,kind+": visible wording fits without clipping")
	var upper:int=0
	for child in panel.find_children("*","Label",true,false):
		if child.is_visible_in_tree() and not child.text.is_empty() and child.get_global_rect().position.y<220: upper+=1
	check(upper==0,kind+": no location heading or separate upper instructions")
	var alpha:float=-1.0
	for child in panel.get_children():
		if child is ColorRect and child.get_meta("ui_backdrop",false): alpha=child.color.a
	check(is_equal_approx(alpha,Color("030201d9").a),kind+": identical dim backdrop")
	var exit:Button=button(panel,"맵으로 나가기")
	check(exit!=null and same_rect(Rect2(exit.position,exit.size),map.TILE_EVENT_EXIT_RECT),kind+": same lower exit slot")
func four_ready() -> void:
	for kind in ["graveyard","rest","forest","fortune-teller-camp"]:
		var index:int=location_fixture(kind,kind=="rest")
		var map:Control=await new_map()
		var before:Dictionary=session.world.snapshot().duplicate(true)
		map.show_location(index)
		await create_timer(0.30).timeout
		geometry(map,kind)
		check(session.world.snapshot()==before,kind+": presentation changes no gameplay or RNG")
		if kind=="graveyard":
			var panel:Control=map.overlay
			panel.action_button.pressed.emit()
			check(await until(func(): return panel.graveyard_phase=="ready"),"real digging reveals card")
			check(Rect2(panel.action_button.position,panel.action_button.size)==map.TILE_EVENT_EXIT_RECT and not panel.graveyard_exit_button.visible,"collect-and-exit retains the lower exit position")
		if kind=="fortune-teller-camp":
			var panel:Control=map.overlay
			map.dice.pressed.emit()
			check(await until(func(): return not panel.busy),"longest actual grand prophecy finishes")
			geometry(map,kind)
		await dispose(map)
func rest_states() -> void:
	var index:int=location_fixture("rest",true)
	session.world.event_flags["ui:unlock:rest:action_pending"]=true
	check(session.save_world(),"rest NEW fixture persists")
	var map:Control=await new_map()
	map.show_location(index)
	await create_timer(0.30).timeout
	var panel:Control=map.overlay
	var heal:Button=panel.get_node("RestHealAction")
	var exit:Button=panel.get_node("RestExitToMap")
	var before:Dictionary=session.world.snapshot().duplicate(true)
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(save)
	session.save_file_path="user://missing_rest_shared_%d/save.json"%OS.get_process_id()
	heal.pressed.emit()
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes,"failed rest save rolls back HP receipt NEW and RNG")
	check(not bool(panel.get_meta("rest_busy",false)) and not heal.disabled and not exit.disabled and panel.get_node("RestNoticeText").text.contains("저장"),"failed rest remains visibly retryable in same lower notice")
	check(session.world.event_flags.get("ui:unlock:rest:action_pending",false) and map.pending_location_papers.is_empty(),"failed save preserves NEW and starts no paper consumption")
	session.save_file_path=save
	heal.pressed.emit()
	var committed:Dictionary=session.world.snapshot().duplicate(true)
	var receipt:String=session.place_visit_id("heal",index)
	check(session.world.roster.all(func(unit): return unit.current_hp==unit.max_hp) and session.world.reward_receipts.count(receipt)==1,"actual rest recovery still commits full healing once")
	check(not session.world.event_flags.get("ui:unlock:rest:action_pending",true) and bool(panel.get_meta("rest_busy",false)) and exit.disabled,"successful original recovery clears NEW and locks exit during animation")
	heal.pressed.emit()
	exit.pressed.emit()
	check(session.world.snapshot()==committed and map.overlay==panel,"busy duplicate and exit cannot repeat recovery or close the effect")
	check(await until(func(): return not bool(panel.get_meta("rest_busy",false))),"original recovery effect completes")
	check(not exit.disabled and panel.get_node("RestNoticeText").text.contains("완료"),"completion remains visible at shared lower position")
	map.close_overlay()
	map.show_location(index)
	await create_timer(0.30).timeout
	check(map.overlay.get_node("RestNoticeText").text.contains("완료") and session.world.snapshot()==committed,"spent rest reopening retains completed state without a new save")
	await dispose(map)
	index=location_fixture("rest",false)
	map=await new_map()
	map.show_location(index)
	check(map.overlay.get_node("RestHealAction").disabled and map.overlay.get_node("RestNoticeText").text.contains("가득"),"full-health unused visit has clear disabled guidance")
	await dispose(map)
	index=location_fixture("rest",true)
	map=await new_map()
	map.show_location(index)
	panel=map.overlay
	before=session.world.snapshot().duplicate(true)
	panel.queue_free()
	map._heal_rest(index,weakref(panel))
	check(session.world.snapshot()==before,"queued old rest panel cannot commit healing")
	await dispose(map)
func run() -> void:
	root.size=Vector2i(1280,720)
	session=root.get_node("RunSession")
	var original:String=session.save_file_path
	await four_ready()
	await rest_states()
	var audio:Node=root.get_node_or_null("GameAudio")
	if audio!=null: audio.queue_free()
	var deadline:int=Time.get_ticks_msec()+5000
	while is_instance_valid(audio) and Time.get_ticks_msec()<deadline: await process_frame
	await process_frame
	session.world=null
	session.save_file_path=original
	for path in paths:
		for suffix in ["",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("LOCATION_NOTICE_UNIFORMITY: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
