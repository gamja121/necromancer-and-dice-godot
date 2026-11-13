extends SceneTree
const Wormhole = preload("res://systems/king_portal_encounter.gd")
const KingPortalTile = preload("res://systems/king_portal_tile.gd")
const StoryBook = preload("res://systems/main_story_book.gd")
const MAP = preload("res://map.tscn")
const Fixture = preload("res://scripts/boss_story_test_fixture.gd")
const Progress = preload("res://systems/final_dragon_progress.gd")
const Demo = preload("res://systems/demo_ending_screen.gd")
const DieLayout = preload("res://systems/final_dragon_die_layout.gd")
const Book = preload("res://systems/final_chapter_screen.gd")
const BattleDeck = preload("res://systems/battle_deck.gd")
var passed := 0
var failed := 0
var screenshots := ""
var source_story := ""

func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	if value: passed += 1
	else: failed += 1
	print(("PASS " if value else "FAIL ")+label)

func until_ready(predicate: Callable, seconds: float = 25.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())

func capture(label: String) -> void:
	if screenshots.is_empty() or DisplayServer.get_name()=="headless": return
	if label in ["wormhole-scene-1","wormhole-scene-2"]: await create_timer(0.72).timeout
	if label=="wormhole-deck": await create_timer(0.88).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screenshots.path_join(label+".png"))==OK,"native image "+label)

func action(book: Control, title: String) -> Button:
	for child in book.get_children():
		if child is Button and child.text==title: return child
	return null

func press_story(map: Control, title: String) -> void:
	var panel: Control = map.overlay
	await until_ready(func(): return panel.typewriter!=null and panel.typewriter.is_inside_tree())
	map._reveal_story_text(panel)
	var button: Button=action(panel,title)
	check(button!=null,"story button "+title)
	if button!=null: button.pressed.emit()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): screenshots=arg.trim_prefix("--screenshots=")
		if arg.begins_with("--source-story="): source_story=arg.trim_prefix("--source-story=")
	var s: Node = root.get_node("RunSession")
	var original_path: String = s.save_file_path
	var scratch := "user://final_chapter_ui_%d.json" % OS.get_process_id()
	s.save_file_path = scratch
	for stage_value in [20,40,60]:
		s.start_new_world()
		s.world.contamination=stage_value
		s.world.generate()
		s.world.position=23
		check(s.save_world(),"stage %d approach persists" % stage_value)
		var stage_map: Control=MAP.instantiate()
		root.add_child(stage_map)
		current_scene=stage_map
		await process_frame
		check(await until_ready(func(): return is_instance_valid(stage_map.overlay) and stage_map.overlay is BattleDeck),"stage %d opens ordinary battle selection" % stage_value)
		check(not stage_map.overlay is StoryBook and not s.world.event_flags.get(Wormhole.SEEN,false),"stage %d never consumes the final book" % stage_value)
		stage_map.queue_free()
		await process_frame
	s.start_new_world()
	if source_story.is_empty():
		Fixture.seed_completed_final_hunt(s.world)
		s.world.contamination = 80
		s.world.generate()
	else:
		var completed_story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_story))
		check(s.world.restore(completed_story),"load actual full-story completion receipts")
	s.world.position = 15
	s.world.dice_visual_position = [811,274]
	s.world.dice_visual_face = 4
	s.world.dice_visual_rotation = 28
	s.world.refresh_final_wormhole()
	var target: int=s.world.final_dragon_location()
	check(target>=0 and s.save_world(),"existing final gate is ready")
	var map: Control = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	var before_preview: Dictionary=s.world.snapshot().duplicate(true)
	map.show_tile(target)
	map.show_tile(s.world.warp_destination(target))
	check(not is_instance_valid(map.overlay) and s.world.snapshot()==before_preview,"remote clicks on both warp stones cannot move the hero or start an encounter")
	await capture("wormhole-map")

	s.world.position=(target+23)%24
	var probe:=RandomNumberGenerator.new()
	for seed_value in range(100):
		probe.seed=seed_value
		if probe.randi_range(1,6)==1:
			s.world.rng.seed=seed_value
			break
	map.render()
	check(s.save_world(),"approach to the wormhole saved")
	var previous_move: int=s.world.move_serial
	await map.roll_move()
	check(s.world.position==target and s.world.move_serial==previous_move+1 and s.world.pending_move.is_empty(),"actual map die arrives directly at the marked warp")
	check(map.overlay is StoryBook and Wormhole.beat(s.world)==0 and s.encounter.is_empty(),"actual arrival opens the first story scene before combat")
	await until_ready(func(): return map.overlay.typewriter!=null)
	map._reveal_story_text(map.overlay)
	await capture("wormhole-scene-1")
	await press_story(map,"계속")
	check(Wormhole.beat(s.world)==1,"first explicit continue is saved")
	current_scene = null
	map.queue_free()
	await process_frame
	s.reload_world()
	map = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	check(await until_ready(func(): return map.overlay is StoryBook),"saved second scene reopens after restart")
	check(Wormhole.beat(s.world)==1 and map.tile_path(target)==KingPortalTile.PATHS.back(),"reload keeps the second scene and transformed stone")
	await until_ready(func(): return map.overlay.typewriter!=null)
	map._reveal_story_text(map.overlay)
	await capture("wormhole-scene-2")
	await press_story(map,"계속")
	check(Wormhole.beat(s.world)==2,"second explicit continue reaches the last scene")
	await until_ready(func(): return map.overlay.typewriter!=null)
	map._reveal_story_text(map.overlay)
	await capture("wormhole-scene-3")
	var before_deck: int=s.world.rng.state
	var last_book: Control=map.overlay
	s.save_file_path = "user://missing_final_chapter_directory/save.json"
	await press_story(map,"전투 준비")
	check(map.overlay==last_book and not s.event_flag_is_set(Wormhole.ACK),"failed acknowledgement remains retryable")
	s.save_file_path = scratch
	await press_story(map,"전투 준비")
	check(map.overlay is BattleDeck and s.event_flag_is_set(Wormhole.ACK) and s.encounter.is_empty() and s.world.rng.state==before_deck,"explicit confirmation opens deck without starting combat")
	check(map.stage.get_node_or_null("MainStoryBook")==null,"the story book closes before the deck can receive input")
	await capture("wormhole-deck")
	var deck: Control = map.overlay
	var real_die: TextureButton = map.dice
	var saved_face: int=s.world.dice_visual_face
	var saved_angle: float=real_die.rotation_degrees
	for unit in s.world.roster.slice(0,2): deck.toggle_unit(str(unit.id))
	deck.confirm_button.pressed.emit()
	check(await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.entry_summon_active),"selected deck summons into real boss battle")
	var battle: Control = map.embedded_battle
	if is_instance_valid(battle.brand_reference):
		battle.brand_reference.close()
		check(await until_ready(func(): return not is_instance_valid(battle.brand_reference)),"entry reference closes")
	check(battle.external_main_dice==real_die and battle.dice==real_die,"battle uses identical physical die")
	check(Progress.is_final_encounter(s.encounter) and s.encounter.get("entry","")==Wormhole.ENTRY,"one real dragon fight is saved at the wormhole")
	check(s.world.dice_visual_face==saved_face and is_equal_approx(real_die.rotation_degrees,saved_angle),"entry preserves die result and angle (face %d, angle %.8f)" % [s.world.dice_visual_face,real_die.rotation_degrees])
	var obstacle: Rect2 = map.final_dragon_die_exclusion()
	var radius: float = real_die.size.length()*0.55
	check(obstacle.has_area() and not obstacle.grow(radius).has_point(real_die.position+real_die.size*0.5),"saved overlap is moved outside dragon canvas")
	var visual_rng_before: int = s.world.rng.state
	for x in range(700,1080,60):
		for y in range(240,480,60):
			var safe: Vector2 = DieLayout.rest_position(Vector2(x,y),real_die.size,map.SHARED_DIE_AREA,obstacle)
			check(not obstacle.grow(radius).has_point(safe+real_die.size*0.5),"safe rest avoids dragon at %d,%d" % [x,y])
	check(s.world.rng.state==visual_rng_before,"pose correction does not consume gameplay RNG")
	await capture("final-battle-clear-view")
	# Deterministic completion fixture: boost allied stats only. Enemy HP70,
	# bone + undying, dice, action queue, death and harvest are production.
	for unit in battle.rules.units:
		if unit.team=="ally":
			unit.base_attack=999
			unit.attack=999
			unit.base_speed=999
			unit.speed=999
	battle.rules.refresh()
	s.encounter.checkpoint=battle.rules.snapshot()
	s.world.active_encounter=s.encounter.duplicate(true)
	check(s.save_world(),"test-only allied checkpoint saves")
	var encounter_id: String = s.encounter.id
	# Reload mid-battle must bypass book and restore the exact one encounter.
	current_scene = null
	map.queue_free()
	await process_frame
	s.reload_world()
	map = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	battle = map.embedded_battle
	check(is_instance_valid(battle) and s.encounter.id==encounter_id and not (map.overlay is Book),"battle restart restores encounter without replaying intro")
	for round_index in range(4):
		if not battle.rules.winner().is_empty(): break
		await battle.roll_round()
	check(battle.rules.winner()=="ally" and Progress.cleared(s.world),"actual boss combat commits clear")
	check(s.world.pending_reward.kind=="capture" and not is_instance_valid(map.final_chapter_screen) and not is_instance_valid(map.game_over_screen),"harvest precedes ending and never uses defeat screen")
	check(not map.final_dragon_die_exclusion().grow(radius).has_point(map.dice.position+map.dice.size*0.5),"rolled die also settles outside dragon")
	await capture("final-harvest")
	current_scene = null
	map.queue_free()
	await process_frame
	s.reload_world()
	map = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	battle = map.embedded_battle
	check(is_instance_valid(battle) and is_instance_valid(battle.capture_panel) and not is_instance_valid(map.final_chapter_screen),"restart after victory resumes pending harvest first")
	for attempt in range(3):
		if s.world.pending_reward.is_empty(): break
		await battle.capture_panel.roll()
	check(await until_ready(func(): return is_instance_valid(map.final_chapter_screen) and not map.battle_returning),"actual harvest returns cards and opens book ending")
	check(not map.dice.visible and map.dice.disabled and not is_instance_valid(map.game_over_screen),"ending hides and blocks shared die, no defeat shatter")
	check(not s.prepare_map_roll().ok,"unconfirmed ending locks map movement")
	check(await until_ready(func(): return not map.final_chapter_screen.action_button.disabled,6.0),"ending book and illustration finish before closing")
	check(map.final_chapter_screen.action_button.text=="원정 계속","the wormhole victory offers Continue Expedition")
	await capture("final-ending")
	var ending_state: Dictionary = s.world.snapshot().duplicate(true)
	current_scene = null
	map.queue_free()
	await process_frame
	s.reload_world()
	map = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	check(await until_ready(func(): return is_instance_valid(map.final_chapter_screen) and not map.final_chapter_screen.action_button.disabled),"restart before confirmation restores the same ending")
	var chapter: Control = map.final_chapter_screen
	check(chapter.record==ending_state.run_result,"reopened book displays the same victory summary")
	s.save_file_path = "user://missing_final_chapter_directory/save.json"
	chapter.action_button.pressed.emit()
	check(map.overlay==chapter and not chapter.book.closing and not chapter.action_button.disabled and "실패" in chapter.hint.text,"save failure gives a visible retry and keeps the book open")
	check(Progress.ending_pending(s.world) and not s.event_flag_is_set(Progress.ENDING_ACK),"failed confirmation keeps the saved ending pending")
	s.save_file_path = scratch
	chapter.action_button.pressed.emit()
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scratch))
	check(chapter.book.closing and disk.run_result.is_empty() and disk.event_flags.get(Progress.ENDING_ACK,false),"continue saves before the book finishes closing")
	check(await until_ready(func(): return not is_instance_valid(map.final_chapter_screen),4.0),"physical book closes back onto the current map")
	check(current_scene==map and not is_instance_valid(map.overlay) and map.dice.visible and not map.dice.disabled and not map.map_music.stream_paused,"same map resumes with die, controls and music")
	check(s.world.position==int(ending_state.position) and s.world.map_serial==int(ending_state.map_serial) and s.world.rng.state==int(ending_state.rng_state),"returning to the map preserves location, board and RNG")
	check(s.world.dice_visual_face==ending_state.dice_visual_face and is_equal_approx(map.dice.rotation_degrees,float(ending_state.dice_visual_rotation)),"restored map die uses the same saved face and angle")
	check(s.world.roster==ending_state.roster and s.world.reward_receipts==ending_state.reward_receipts,"continuation preserves the roster and one harvest receipt")
	check(map.tile_path(target)=="res://assets/map/tiles/warp.png","the settled entrance displays a regular warp")
	await capture("continued-expedition")

	check(change_scene_to_file("res://title.tscn")==OK,"return to title after continuing")
	check(await until_ready(func(): return current_scene!=null and current_scene.scene_file_path=="res://title.tscn"),"title loaded for restart check")
	var title: Control = current_scene
	title.continue_button.pressed.emit()
	check(await until_ready(func(): return current_scene!=null and current_scene.scene_file_path=="res://map.tscn"),"title Continue opens the saved expedition")
	map=current_scene
	check(not is_instance_valid(map.final_chapter_screen) and not is_instance_valid(map.overlay) and map.dice.visible and not map.dice.disabled,"reopened continued run goes straight to the map")
	check(s.world.reward_receipts==ending_state.reward_receipts and Progress.cleared(s.world),"restart cannot duplicate the reward or erase the dragon defeat")
	var ordinary_index: int=s.world.tiles.find("monster")
	s.world.position=ordinary_index
	var ordinary_started: bool=s.start_encounter(ordinary_index,[s.world.roster[0].id])
	check(ordinary_started,"the continued run starts a real ordinary encounter")
	if ordinary_started:
		map.open_embedded_battle(false)
		var ordinary_battle: Control=map.embedded_battle
		for unit in ordinary_battle.rules.units:
			if unit.team=="enemy": ordinary_battle.rules.damage(unit,9999)
		check(s.finish_encounter(ordinary_battle.rules),"ordinary victory settles after the final chapter")
		for attempt in range(3):
			if s.world.pending_reward.is_empty(): break
			var rolled: Dictionary=s.roll_capture()
			if rolled.get("success",false): s.claim_reward()
			elif s.world.pending_reward.get("phase","")=="failed": s.dismiss_failed_capture()
		check(s.world.pending_reward.is_empty(),"the later ordinary harvest resolves normally")
		await map.finish_embedded_battle()
		check(not is_instance_valid(map.final_chapter_screen),"a later battle return cannot reopen the acknowledged ending")

	var demo_state := ending_state.duplicate(true)
	check_demo_matrix()

	# The old fixed-slot ending still closes to the real title.
	ending_state.run_result.erase("entry")
	ending_state.position=23
	check(s.world.restore(ending_state) and s.save_world(),"save a genuine victory summary without wormhole provenance")
	current_scene=null
	map.queue_free()
	await process_frame
	s.reload_world()
	map=MAP.instantiate()
	root.add_child(map)
	current_scene=map
	check(await until_ready(func(): return is_instance_valid(map.final_chapter_screen) and not map.final_chapter_screen.action_button.disabled),"legacy terminal ending still opens")
	check(map.final_chapter_screen.action_button.text=="책을 덮고 타이틀로","legacy book retains its title action")
	map.final_chapter_screen.action_button.pressed.emit()
	check(await until_ready(func(): return current_scene!=null and current_scene.scene_file_path=="res://title.tscn",4.0),"legacy ending still returns to title")
	check(Progress.ending_pending(s.world) and not Progress.can_continue(s.world),"legacy title action keeps the old terminal record")
	current_scene.queue_free()
	current_scene=null
	await process_frame
	await check_demo_scene(s, scratch, demo_state)
	s.save_file_path = original_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	# Release this isolated run's active ending/book cues before SceneTree exit.
	var sound_service: Node = root.get_node_or_null("GameAudio")
	if sound_service != null: sound_service.queue_free()
	await create_timer(0.10).timeout
	print("FINAL_CHAPTER_UI: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)

func check_demo_matrix() -> void:
	var variants := [
		Demo.chapter_for({}, ""),
		Demo.chapter_for({}, "stopped"),
		Demo.chapter_for({}, "burned"),
		Demo.chapter_for({Demo.Hunt.DAMAGED_FLAG:true}, ""),
		Demo.chapter_for({}, "active")
	]
	check(variants.map(func(branch): return branch.id) == ["quiet","protected","burned","damaged","unresolved"],
		"demo keeps all five house outcomes distinct")
	check(Demo.chapter_for({Demo.Hunt.PROTECTED_FLAG:true}, "").id == "protected"
		and Demo.chapter_for({Demo.Hunt.BURNED_FLAG:true}, "").id == "burned"
		and Demo.chapter_for({}, "", true).id == "unresolved", "legacy home and unfinished fire outcomes remain readable")
	var art_paths: Array = variants.map(func(branch): return branch.art)
	check(art_paths.all(func(path): return ResourceLoader.exists(path)) and variants.map(func(branch): return branch.title).count(variants[0].title) == 1,
		"every demo house outcome has an existing image")
	var route := Demo.chapter_for({Demo.Rumor.ABANDONED_FLAG:true, Demo.Altar.INFILTRATE_FLAG:true,
		Demo.Inquiry.WATCH_FLAG:true, Demo.Ritual.FULL_REVIVAL_FLAG:true, Demo.Hunt.RESCUED_FLAG:true}, "burned")
	check(route.trail.size() == 5 and "부활 의식은 끝까지 이어졌다." in route.trail,
		"demo epilogue keeps all compatible story outcomes together")
	var alternate := Demo.chapter_for({Demo.Rumor.RESCUED_FLAG:true, Demo.Altar.FIGHT_FLAG:true,
		Demo.Inquiry.TESTIMONY_FLAG:true, Demo.Ritual.WEAKENED_FLAG:true}, "")
	check(alternate.trail == ["공동묘지에서 아이를 구했다.", "제단에서 광신도와 맞섰다.",
		"기사단에 진술을 남겼다.", "부활 의식의 힘을 약화했다."], "alternate choices produce different journal lines")
	check(Demo.chapter_for({Demo.Altar.PASS_FLAG:true}, "").trail == ["제단을 지나 의식의 흔적을 추적했다."],
		"passing the altar has its own journal entry")
	check(Demo.chapter_for({Demo.Hunt.PUBLIC_FLAG:true, Demo.Hunt.ESCORT_FLAG:true}, "stopped").village
		== ["목격자와 공개 대면했다.", "경비의 동행을 요청했다."], "public testimony and escort appear in the chapter")
	check(Demo.chapter_for({Demo.Hunt.REFUSED_FLAG:true, Demo.Hunt.ALONE_FLAG:true}, "burned").village
		== ["목격자와의 대면을 거절했다.", "경비 없이 집으로 향했다."], "refusal and traveling alone remain visible")

func check_demo_scene(s: Node, scratch: String, state: Dictionary) -> void:
	s.demo_mode = true
	state.riot = {"state":"burned","index":15,"face":2,"pending":{}}
	state.event_flags.erase(Demo.Rumor.RESCUED_FLAG)
	state.event_flags[Demo.Rumor.ABANDONED_FLAG] = true
	state.event_flags.erase(Demo.Ritual.WEAKENED_FLAG)
	state.event_flags[Demo.Ritual.FULL_REVIVAL_FLAG] = true
	check(s.world.restore(state) and s.save_world() and s.reload_world(), "demo final victory saves and reloads before acknowledgement")
	var map = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	var ready := await until_ready(func(): return is_instance_valid(map.final_chapter_screen) and not map.final_chapter_screen.action_button.disabled, 7.0)
	check(ready, "demo book completes its illustration and brief fissure animation")
	if not ready:
		map.queue_free()
		current_scene = null
		s.demo_mode = false
		return
	var chapter: Control = map.final_chapter_screen
	check(chapter.hint.modulate.a > 0.99, "fissure line has faded in before completion")
	check(chapter is Demo and chapter.epilogue.id == "burned" and chapter.title.text == "재가 남은 길", "real demo scene shows the saved burned-house epilogue")
	check(chapter.action_button.text == "체험판 완료" and not s.continue_after_final_ending(), "demo stops at the chapter rather than continuing the board")
	await capture("demo-ending-burned")
	s.save_file_path = "user://missing_demo_ending_directory/save.json"
	chapter.action_button.pressed.emit()
	check(not chapter.book.closing and not s.event_flag_is_set(Progress.DEMO_ENDING_ACK) and "저장하지 못했습니다" in chapter.hint.text, "demo shows a retry when acknowledgement cannot be stored")
	s.save_file_path = scratch
	chapter.action_button.pressed.emit()
	check(chapter.book.closing and s.has_demo_record() and s.world.run_result == state.run_result, "demo acknowledgement saves before close and preserves the victory")
	check(await until_ready(func(): return current_scene != null and current_scene.scene_file_path == "res://title.tscn", 4.0), "demo ends at the real title")
	var title_scene = current_scene
	check(title_scene.continue_button.text == "원정 기록" and title_scene.continue_button.icon == null, "completed demo has a visible Expedition Record title action")
	var bytes := FileAccess.get_file_as_bytes(scratch)
	title_scene.continue_button.pressed.emit()
	check(is_instance_valid(title_scene.demo_record) and title_scene.demo_record.epilogue == chapter_for_test(s), "title reopens the same epilogue in read-only mode")
	check(FileAccess.get_file_as_bytes(scratch) == bytes and s.world.reward_receipts == state.reward_receipts, "record viewing does not write the save or duplicate harvest")
	if is_instance_valid(title_scene.demo_record):
		await until_ready(func(): return not title_scene.demo_record.book.opening)
		title_scene.demo_record.action_button.pressed.emit()
		check(await until_ready(func(): return not is_instance_valid(title_scene.demo_record), 4.0), "archived book closes back to title")
	title_scene.queue_free()
	current_scene = null
	await process_frame
	s.demo_mode = false

func chapter_for_test(s: Node) -> Dictionary:
	return Demo.chapter_for(s.world.event_flags, str(s.world.riot.state))
