extends "res://scripts/test_location_shared_capture.gd"
const Deck=preload("res://systems/battle_deck.gd")
func shot(tag:String) -> void:
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	check(session.world.tiles[23]=="boss" and map.buttons[23].texture_normal==map.texture("res://assets/map/tiles/boss.png"),"actual boss stone visible "+tag)
	var image:Image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(1280,720) and image.save_png(out.path_join("boss_retained_"+tag+".png"))==OK,"actual native screenshot "+tag)
func create_map() -> void:
	map=MAP.instantiate()
	root.add_child(map)
	map.map_music.stop()
	map.map_music.stream=null
	AudioServer.set_bus_mute(0,true)
	for frame in range(5): await process_frame
	if is_instance_valid(map.overlay): map.close_overlay()
	await create_timer(0.5).timeout
func run() -> void:
	root.size=Vector2i(1280,720)
	out=OS.get_environment("BOSS_CAPTURE_DIR")
	if out.is_empty(): out=ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(out)
	session=root.get_node("RunSession")
	original_path=session.save_file_path
	isolated="user://boss_retained_native_%d.json"%OS.get_process_id()
	session.save_file_path=isolated
	var language:Node=root.get_node("GameLanguage")
	var original_locale:String=language.locale
	for locale in ["ko","en"]:
		language.set_language(locale,false)
		session.start_new_world()
		session.world.contamination=20
		session.world.generate()
		var index:int=session.world.tiles.find("basic")
		session.world.tiles[index]="unknown"
		session.world.position=index
		var rng=RandomNumberGenerator.new()
		for seed in range(1,1000):
			rng.seed=seed
			if rng.randi_range(1,6)==6: session.world.rng.seed=seed; break
		check(session.save_world(),"native baseline stores a shown boss "+locale)
		await create_map()
		await shot(locale+"_01_pollution20")
		map.show_location(index)
		check(is_instance_valid(map.overlay) and map.overlay.type=="unknown","actual prayer UI opens "+locale)
		map.dice.pressed.emit()
		check(await until(func():return not map.overlay.busy),"actual prayer finishes "+locale)
		check(session.world.contamination==15 and int(session.world.prayer_result.face)==6,"actual purification saves twenty to fifteen "+locale)
		map.overlay.close_button.pressed.emit()
		check(await until(func():return not is_instance_valid(map.overlay)),"return to actual map "+locale)
		await shot(locale+"_02_pollution15")
		await dispose()
		session.reload_world()
		await create_map()
		check(session.world.contamination==15 and session.world.boss_available(),"saved boss remains playable at fifteen "+locale)
		await shot(locale+"_03_reloaded15")
		session.world.position=23
		check(session.save_world(),"isolated actual boss arrival "+locale)
		map.show_tile(23,true)
		check(await until(func():return map.overlay is Deck),"actual low-pollution boss opens original deck "+locale)
		check(await until(func():return is_equal_approx(map.overlay.hand.position.y,496.8) and map.overlay.confirm_button.modulate.a>0.99),"original deck entrance fully settles "+locale)
		map.overlay.toggle_unit(str(session.world.roster[0].id))
		check(not map.overlay.confirm_button.disabled,"original deck accepts a real owned card "+locale)
		await shot(locale+"_04_boss_deck")
		await dispose()
	language.set_language(original_locale,false)
	var audio:Node=root.get_node_or_null("GameAudio")
	if audio!=null: audio.queue_free()
	await process_frame
	session.world=null
	session.encounter={}
	session.save_file_path=original_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(isolated+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated+suffix))
	print("BOSS_REVEAL_CAPTURE: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
