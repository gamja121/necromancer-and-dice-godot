extends "res://scripts/test_location_shared_capture.gd"
## Native screenshots of the actual direct world-tree UI and original prayer FX.
func capture(tag:String) -> void:
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var panel:Control=map.overlay
	check(panel.type=="unknown" and panel.dice==map.dice,"actual direct prayer panel "+tag)
	check(root.get_texture().get_image().save_png(out.path_join("world_tree_direct_"+tag+".png"))==OK,"native prayer screenshot "+tag)
	check(Rect2(panel.prayer_notice_strip.position,panel.prayer_notice_strip.size)==Rect2(340,423,600,150),"original common parchment "+tag)
	check(Rect2(panel.close_button.position,panel.close_button.size)==map.TILE_EVENT_EXIT_RECT,"common exit "+tag)
	check(panel.prayer_detail.is_visible_in_tree(),"second guidance line visible "+tag)
	for child in panel.get_children():
		if child is Label and child.is_visible_in_tree() and not child.text.is_empty():
			check(child.position.y>=423,"no title or information outside painting "+tag)
	records.append({"screen":tag,"main":panel.status.text,"detail":panel.prayer_detail.text,"die_position":str(map.dice.position),"die_size":str(map.dice.size),"die_face":map.dice.texture_normal.resource_path,"exit":str(panel.close_button.get_global_rect())})

func run() -> void:
	root.size=Vector2i(1280,720)
	out=OS.get_environment("WORLD_TREE_CAPTURE_DIR")
	if out.is_empty(): out=ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(out)
	session=root.get_node("RunSession")
	original_path=session.save_file_path
	isolated="user://world_tree_native_%d.json"%OS.get_process_id()
	session.save_file_path=isolated
	session.start_new_world()
	var index:int=session.world.tiles.find("basic")
	check(index>=0,"ordinary world-tree fixture road exists")
	session.world.tiles[index]="unknown"
	session.world.position=index
	session.world.contamination=30
	var probe:=RandomNumberGenerator.new()
	for seed in range(1,1000):
		probe.seed=seed
		if probe.randi_range(1,6)==6:
			session.world.rng.seed=seed
			break
	check(session.save_world(),"native fixture saves")
	var before:Dictionary=session.world.snapshot().duplicate(true)
	map=MAP.instantiate()
	root.add_child(map)
	map.map_music.stop()
	map.map_music.stream=null
	AudioServer.set_bus_mute(0,true)
	for frame in range(3): await process_frame
	map.show_location(index)
	await create_timer(0.8).timeout
	check(session.world.snapshot()==before,"direct opening grants nothing and preserves RNG")
	await capture("01_ready")
	map.dice.pressed.emit()
	check(await until(func(): return not map.overlay.busy),"actual prayer die finishes")
	check(session.world.contamination==25 and int(session.world.prayer_result.face)==6,"actual saved six gives original minus5 contamination")
	await create_timer(0.1).timeout
	var original_effect:Control=null
	for child in map.overlay.get_children():
		if child.get_script()==preload("res://systems/world_tree_prayer_effect.gd"): original_effect=child
	check(original_effect!=null and original_effect.position==Vector2(556,315),"original prayer effect and position retained")
	await capture("02_effect")
	await create_timer(1.3).timeout
	await capture("03_result")
	var complete:Dictionary=session.world.snapshot().duplicate(true)
	map.overlay.close_button.pressed.emit()
	check(await until(func(): return not is_instance_valid(map.overlay)),"single exit returns to playable map")
	check(not map.dice.disabled,"map die usable after single exit")
	map.show_location(index)
	await create_timer(0.8).timeout
	check(session.world.snapshot()==complete and map.dice.disabled,"reopen displays saved result without reroll")
	await capture("04_reopened")
	await dispose()
	var audio:Node=root.get_node_or_null("GameAudio")
	if audio!=null: audio.queue_free()
	var deadline:int=Time.get_ticks_msec()+5000
	while is_instance_valid(audio) and Time.get_ticks_msec()<deadline: await process_frame
	await process_frame
	session.world=null
	session.save_file_path=original_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(isolated+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated+suffix))
	var file:=FileAccess.open(out.path_join("world_tree_native_audit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"screens":records},"  "))
	file.close()
	print("WORLD_TREE_DIRECT_CAPTURE: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
