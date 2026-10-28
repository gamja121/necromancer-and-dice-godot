extends "res://scripts/test_fortune_direct_flow.gd"
## GPU proof of the actual direct prophecy UI, using only disposable saves.
var output:String
func snap(tag:String,settle_frames:int=6) -> void:
	for frame in range(settle_frames): await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(1280,720),"native full viewport "+tag)
	check(image.save_png(output.path_join("prophecy_%s.png"%tag))==OK,"native screenshot "+tag)
func click_at(point:Vector2) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=point
	event.global_position=point
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=point
	event.global_position=point
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	root.size=Vector2i(1280,720)
	output=OS.get_environment("PROPHECY_CAPTURE_DIR")
	if output.is_empty(): output=ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(output)
	session=root.get_node("RunSession")
	var original:String=session.save_file_path
	var camp:int=fixture("capture_grand",6)
	var map:Control=await new_map()
	var panel:Control=enter(map,camp)
	await create_timer(0.30).timeout
	check(Rect2(panel.fortune_notice_strip.position,panel.fortune_notice_strip.size)==Rect2(340,423,600,150),"GPU retains common full-size parchment")
	check(panel.get_node_or_null("FortuneLocationTitle")==null and panel.get_node_or_null("FortuneVisitHint")==null and Rect2(panel.close_button.position,panel.close_button.size)==map.TILE_EVENT_EXIT_RECT,"GPU has no upper heading and preserves common exit")
	var before:Dictionary=session.world.snapshot().duplicate(true)
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(save)
	await snap("01_ready")
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes,"GPU preview changes no world save or RNG")
	map.dice.pressed.emit()
	await snap("02_rolling")
	check(await until(func(): return panel.fortune_effect.active),"grand outcome reaches actual ink effect")
	while panel.fortune_effect.progress<0.42: await process_frame
	await snap("03_grand_ink",0)
	check(await until(func(): return not panel.busy),"grand result completes")
	await snap("04_grand_result")
	var committed:Dictionary=session.world.snapshot().duplicate(true)
	bytes=FileAccess.get_file_as_bytes(save)
	# Force only the rendered die over the exit to test actual GUI hit routing.
	# No gameplay fields or stopping pose are saved by this diagnostic.
	map.dice.position=map.TILE_EVENT_EXIT_RECT.get_center()-map.dice.size*0.5
	check(map.dice.mouse_filter==Control.MOUSE_FILTER_IGNORE,"used die passes exit clicks even at an overlapping stopping point")
	await click_at(map.TILE_EVENT_EXIT_RECT.get_center())
	check(await until(func(): return not is_instance_valid(map.overlay)),"actual pointer click exits through an overlapping used die")
	panel=enter(map,camp)
	await snap("05_saved_result")
	check(map.dice.disabled and not panel.fortune_effect.active and session.world.snapshot()==committed and FileAccess.get_file_as_bytes(save)==bytes,"native result reopens without reroll grant or persistence")
	await dispose(map)
	camp=fixture("capture_curse",1)
	map=await new_map()
	panel=enter(map,camp)
	map.dice.pressed.emit()
	check(await until(func(): return panel.fortune_effect.active),"curse outcome reaches actual ink effect")
	while panel.fortune_effect.progress<0.40: await process_frame
	await snap("06_curse_ink",0)
	check(await until(func(): return not panel.busy),"curse reveal completes")
	await snap("07_curse_result")
	check(panel.status.text.contains("저주") and panel.fortune_result.text.contains("적 공격 +1"),"native curse uses real saved enemy effect")
	await dispose(map)
	camp=fixture("capture_heal",2)
	map=await new_map()
	panel=enter(map,camp)
	map.dice.pressed.emit()
	check(await until(func(): return not panel.busy),"native immediate recovery completes")
	await snap("08_heal_result")
	check(session.world.roster.all(func(unit): return unit.current_hp==unit.max_hp) and panel.status.text.contains("즉시"),"native healing is immediate and distinct from next-battle total")
	await dispose(map)
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
	print("FORTUNE_DIRECT_CAPTURE: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
