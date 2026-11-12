extends "res://scripts/test_cultist_mistrust_capture.gd"
## Reuse the shared book/framebuffer harness; only the authored route differs.
const HF=preload("res://scripts/witch_hunt_fixture.gd")
const HUNT=HF.Hunt
const HUNT_BEATS=HF.Beats
func settle(locale: String) -> bool:
	if not await super.settle(locale): return false
	var picture: TextureRect=map.overlay.find_child("WitchHuntScene",true,false) as TextureRect
	check(picture!=null and picture.texture.get_size()==Vector2(1672,941) and picture.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"full-size manuscript and mipmap filter")
	return true
func snap(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var shot: Image=root.get_texture().get_image()
	if check(shot.get_size()==Vector2i(1280,720) and shot.save_png("res://witch_hunt_%s.png" % tag)==OK,"actual framebuffer "+tag): captures+=1
func pawn_near(pawn: TextureRect, tile: int, distance: float = 57.0) -> bool:
	if not is_instance_valid(pawn): return false
	var foot := pawn.position + pawn.size * Vector2(0.5, 1.0)
	return foot.distance_to(map.center(tile) + Vector2(0, map.HERO_BASE_ABOVE_TILE_CENTER)) < distance


func check_board_march(at: int, take_captures: bool) -> bool:
	var march: Control = map.overlay
	if not check(is_instance_valid(march) and march.name == "VillageMobMarch", "first HOME arrival starts on the board"): return false
	if not check(march.get_child_count() == 1, "the villagers share one board pawn"): return false
	var pawn := march.get_child(0) as TextureRect
	if not check(pawn != null and pawn.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the crowd pawn has no click target"): return false
	check(pawn.size == map.hero.size, "crowd pawn uses the protagonist pawn size")
	var village: int = session.world.tiles.find("village")
	check(pawn_near(pawn, village), "the crowd pawn departs from the village tile")
	check(march.mouse_filter == Control.MOUSE_FILTER_STOP and map.dice.disabled and not map.dice.visible, "march blocks board controls")
	var before: Dictionary = session.world.snapshot().duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(save)
	map.show_tile(at, true)
	check(map.overlay == march, "repeated HOME dispatch cannot skip or restart the march")
	if take_captures:
		if not check(await until(func(): return is_instance_valid(march) and pawn.modulate.a >= 0.99, 15000), "the crowd pawn fades in"): return false
		await snap("board_crowd_departure")
	if not check(await until(func(): return pawn_near(pawn, village + 3), 15000), "the crowd pawn travels down the right-hand tile path"): return false
	if take_captures: await snap("board_crowd_corner")
	if not check(await until(func(): return pawn_near(pawn, at, 74.0), 15000), "the crowd pawn reaches the house"): return false
	check(pawn.position.x - map.hero.position.x > pawn.size.x * 0.5, "crowd arrives alongside the hero")
	if take_captures: await snap("board_crowd_arrival")
	if not check(await until(func(): return map.overlay is BOOK, 15000), "arson book opens when the march finishes"): return false
	check(session.world.snapshot() == before and FileAccess.get_file_as_bytes(save) == bytes, "march leaves the saved encounter, player position and RNG intact")
	return true


func play_stage(locale: String, story_stage: int, decision: String, tag: String) -> void:
	if not check(HF.arrive(session,story_stage),"new actual village or home visit"): return
	var at: int=session.world.position
	var before: Dictionary=session.world.snapshot().duplicate(true)
	map.show_tile(at,false)
	check(session.get_story_event(HUNT.IDS[story_stage]).status=="unseen" and session.world.snapshot()==before,"preview cannot discover next event")
	await dispose()
	session.reload_world()
	await create_map()
	check(session.get_story_event(HUNT.IDS[story_stage]).status=="unseen","loading alone cannot discover next event")
	map.show_tile(at,true)
	if story_stage==2:
		if not await check_board_march(at, tag == "burned" and locale == "ko"): return
		before=session.world.snapshot().duplicate(true)
		for kind in ["warp","monster"]:
			map.close_overlay()
			map.show_tile(session.world.tiles.find(kind),false)
			check(session.world.snapshot()==before and HUNT.current_beat(session,2)==0 and map.overlay is BOOK,"closed HOME book blocks remote "+kind+" and resumes its exact page")
	for beat in range(HUNT_BEATS.CHOICE_INDEX+1):
		if not await settle(locale): return
		check(HUNT.current_beat(session,story_stage)==beat,"exact opening beat")
		if beat==HUNT_BEATS.CHOICE_INDEX:
			if tag=="burned": await snap("stage%d_choice_%s" % [story_stage,locale])
		elif not await press("계속"): return
	var option: int=HUNT_BEATS.DECISIONS[story_stage].find(decision)
	if not await press(HUNT_BEATS.CHOICES[story_stage][option]): return
	if not await settle(locale): return
	if not await press("선택 변경"): return
	if not await settle(locale): return
	check(HUNT.current_beat(session,story_stage)==3,"actual undo button restores choice")
	if not await press(HUNT_BEATS.CHOICES[story_stage][option]): return
	for beat in range(4,HUNT_BEATS.count()):
		if not await settle(locale): return
		check(HUNT.current_beat(session,story_stage)==beat and not HUNT.completed(session,story_stage),"outcome waits for final acknowledgement")
		if story_stage==1 and beat==HUNT_BEATS.count()-1:
			var expected_seal: String="동행" if decision=="escort" else "단독"
			check(map.overlay.find_children("*","Label",true,false).any(func(label):return label.text==expected_seal),"final seal agrees with the saved escort decision")
		if beat==5:
			check(button("선택 변경")==null,"performed action locks choice")
			before=session.world.snapshot().duplicate(true)
			await dispose()
			session.reload_world()
			await create_map()
			check(session.world.snapshot()==before and HUNT.current_beat(session,story_stage)==beat,"restart resumes exact performed action including HOME")
			if not await settle(locale): return
		if story_stage==2 and beat==HUNT_BEATS.count()-1: await snap(tag+"_"+locale)
		if not await press("마치기" if beat==HUNT_BEATS.count()-1 else "계속"): return
	check(HUNT.completed(session,story_stage),"actual Finish commits stage once")
	if story_stage==1:
		var pawn: Node = map.stage.get_node_or_null("VillageRiotPawn")
		var mini_die: TextureRect = pawn.find_child("VillagerCrowdDie", true, false) as TextureRect if pawn != null else null
		check(mini_die != null and mini_die.size.x < map.dice.size.x and map.moving, "live riot shows a small separate die while the board is locked")
		if tag=="burned" and locale=="ko": await snap("riot_opening_die")
		check(await until(func(): return not map.moving, 15000) and session.world.riot.face in [1,2,3], "opening riot roll finishes on the live board")
		# Keep the already-in-progress v1 HOME event and all three outcomes covered.
		session.world.riot.clear()
		check(session.save_world(),"legacy HOME fixture saved")
		map.render()
	if story_stage<2:
		before=session.world.snapshot().duplicate(true)
		map.show_tile(at,true)
		check(session.world.snapshot()==before,"same actual arrival cannot chain next stage")
		map.close_overlay()
func check_ruins(locale: String) -> void:
	await create_timer(0.5).timeout # Inspect final coordinates after the shared entrance motion.
	check(HUNT.home_burned(session) and is_instance_valid(map.overlay) and map.overlay.name=="BurnedHomePanel","final acknowledgement opens actual ruined home")
	check(button("들어가기")==null and button("낙인 계승")==null and button("순찰경로")==null,"ruins never offer blocked services")
	check(map.buttons[HF.State.HOME].find_child("HomeBlockadeBadge",true,false)!=null,"board home is visibly blocked")
	check(map.overlay.find_child("LocationNoticeStrip",true,false)!=null,"ruins reuse the same information strip as other locations")
	check(button("다음 바퀴 출발").position==map.TILE_EVENT_EXIT_RECT.position and button("돌아가기").position==map.TILE_EVENT_ACTION_RECT.position,"ruins retain the shared location action coordinates")
	for label in map.overlay.find_children("*","Label",true,false):
		check(label.get_line_count()*label.get_line_height()<=label.size.y+1,"ruins copy fits")
		if locale=="en": check(not ENGLISH.has_korean(label.tr(label.text)),"ruins copy translated")
	await snap("ruins_"+locale)
	var before: Dictionary=session.world.snapshot().duplicate(true)
	map.close_overlay()
	map.show_exploration_actions(HF.State.HOME)
	check(map.overlay.name=="BurnedHomePanel" and session.world.snapshot()==before,"direct patrol UI cannot bypass blockade")
	session.save_file_path="user://witch_hunt_capture_missing_%d/save.json" % OS.get_process_id()
	if not await press("다음 바퀴 출발"): return
	check(await until(func():return not map.moving),"failed departure settles")
	check(session.world.snapshot()==before and map.overlay.name=="BurnedHomePanel" and map.overlay.find_child("HomeDepartureFeedback",true,false)!=null,"failed departure rolls back and explains retry on ruins")
	session.save_file_path=save
	if not await press("다음 바퀴 출발"): return
	check(await until(func():return not map.moving,16000),"ruins departure animation settles")
	check(session.world.map_serial==int(before.map_serial)+1 and session.world.laps==int(before.laps)+1 and session.world.contamination==mini(100,int(before.contamination)+7),"actual ruins button starts one next lap")
	check(HUNT.home_burned(session) and session.world.tiles[HF.State.HOME]=="home","blockade survives next map without deleting home waypoint")
func play_case(locale: String, escorted: bool) -> void:
	root.get_node("GameLanguage").set_language(locale,false)
	if not check(HF.prepare(session,escorted),"genuine inquiry before consequence chain"): return
	await create_map()
	var tag: String="protected" if escorted else "burned"
	await play_stage(locale,0,"confront" if escorted else "avoid",tag)
	await play_stage(locale,1,"escort" if escorted else "alone",tag)
	await play_stage(locale,2,"rescue",tag)
	if escorted:
		check(not HUNT.home_burned(session) and session.home_services_allowed().ok,"escort saves person and house with services intact")
	else: await check_ruins(locale)
	await dispose()
func damaged_case(locale: String) -> void:
	root.get_node("GameLanguage").set_language(locale,false)
	if not check(HF.prepare(session) and HF.arrive(session,0) and HF.finish_stage(session,0,"confront") and HF.arrive(session,1) and HF.finish_stage(session,1,"alone"),"genuine unescorted source for fire-first result"): return
	session.world.riot.clear()
	if not check(session.save_world(), "legacy damaged fixture saved"): return
	await create_map()
	await play_stage(locale,2,"extinguish","damaged")
	check(session.event_flag_is_set(HUNT.DAMAGED_FLAG) and session.event_flag_is_set(HUNT.INJURED_FLAG) and not HUNT.home_burned(session),"fire-first outcome keeps house and records resident injury")
	await dispose()
func run() -> void:
	root.size=Vector2i(1280,720)
	session=root.get_node("RunSession")
	var original: String=session.save_file_path
	save="user://witch_hunt_capture_%d.json" % OS.get_process_id()
	session.save_file_path=save
	clean()
	for locale in ["ko","en"]:
		for escorted in [true,false]: await play_case(locale,escorted)
		await damaged_case(locale)
	await dispose()
	var audio: Node=root.get_node_or_null("GameAudio")
	check(await until(func():return audio==null or audio.voices.is_empty()),"audio drains before shutdown")
	for frame in range(3): await process_frame
	var deadline: int=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<deadline: await process_frame
	if DisplayServer.get_name()!="headless": check(captures==18,"fourteen book captures, three legacy march frames and one live riot die")
	session.world=null
	session.save_file_path=original
	clean()
	print("WITCH_HUNT_CAPTURE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
