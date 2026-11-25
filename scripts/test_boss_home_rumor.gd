extends SceneTree
## Real home and book controls, temporary save slots, and exact lap/RNG receipts.

const MapScene = preload("res://map.tscn")
const State = preload("res://systems/map_state.gd")
const Rumor = preload("res://systems/boss_home_rumor.gd")
const Book = preload("res://systems/main_story_book.gd")
const Gear = preload("res://systems/map_gear_shift.gd")
const FinalFixture = preload("res://scripts/boss_story_test_fixture.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> bool:
	print("PASS boss rumor: " if ok else "FAIL boss rumor: ",message)
	if not ok:
		failures += 1
	return ok


func until(condition: Callable) -> bool:
	for frame in range(1200):
		if condition.call(): return true
		await process_frame
	return false


func click(control: Control) -> void:
	var point := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*0.5))
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event)
		await process_frame


func accept() -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = down
		root.push_input(event)
		await process_frame


func make_map() -> Control:
	var map := MapScene.instantiate()
	root.add_child(map)
	current_scene = map
	for frame in range(5):
		await process_frame
	return map


func seeded_board(session: Node, level: int, slug: String, stage: int) -> void:
	session.start_new_world()
	var world = session.world
	world.boss_assignments = {str(stage):slug}
	for other in State.BossStages.STAGES:
		if str(other) in world.boss_assignments: continue
		for candidate in State.BossStages.CANDIDATES:
			if candidate in world.boss_assignments.values(): continue
			world.boss_assignments[str(other)] = candidate
			break
	world.contamination = level
	world.generate()
	world.position = State.HOME
	world.lap_ready = true
	session.save_world()


func run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
	var session = root.get_node("RunSession")
	var language = root.get_node("GameLanguage")
	language.set_language("ko",false)
	var old_path: String = session.save_file_path
	var path := "user://boss-home-rumor-test-%d.json" % OS.get_process_id()
	session.save_file_path = path

	seeded_board(session,13,"goblin-chief",20)
	var world = session.world
	var baseline: Dictionary = world.snapshot().duplicate(true)
	var expected := State.new(world.definitions,0)
	expected.restore(baseline)
	expected.leave_home()
	expected.tiles = Gear.compose_board(baseline.tiles,expected.tiles,expected.map_serial)
	var map := await make_map()
	map.show_home(true)
	var depart: Button
	for button in map.overlay.find_children("*","Button",true,false):
		if button.text == "다음 바퀴 출발": depart = button; break
	if not check(is_instance_valid(depart),"existing HOME departure button found"):
		quit(1)
		return
	await click(depart)
	if not check(await until(func(): return map.overlay is Book),"actual HOME click opens the original storybook"):
		quit(1)
		return
	var first: Control = map.overlay
	var first_page_id := first.get_instance_id()
	check(world.pending_reward.get("stage",0)==20 and world.pending_reward.get("page",-1)==0,"stage 20 rumor is saved before re-generating")
	check(world.tiles==baseline.tiles and world.map_serial==baseline.map_serial and world.rng.state==int(baseline.rng_state),"opening the book preserves the exact old board and RNG")
	check(not session.prepare_map_roll().ok and not session.leave_home(),"rolling and duplicate departure are gated while the book is open")
	check(await until(func(): return not first.opening),"first manuscript opening settles")
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	root.window_input.emit(cancel)
	await process_frame
	cancel = InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	root.window_input.emit(cancel)
	await process_frame
	await process_frame
	check(map.overlay == first and first._chapter == null,"Escape cannot dismiss an unnumbered side-story book")
	var first_line: String = Rumor.DIALOGUE["goblin-chief"][0]
	var labels: Array = first.find_children("*","Label",true,false)
	check(labels.any(func(label): return label.text==first_line),"first page matches the goblin actually assigned to this run")
	await accept()
	check(map.overlay == first and int(world.pending_reward.page)==0 and not first.typewriter.is_revealing(),"first Enter only finishes the typewriter")
	await accept()
	if not check(await until(func(): return map.overlay is Book and map.overlay.get_instance_id()!=first_page_id and int(world.pending_reward.page)==1),"second Enter turns to the resident reply"):
		quit(1)
		return
	map.queue_free()
	await process_frame
	if not check(session.reload_world(),"reload succeeds during the second page"):
		quit(1)
		return
	world = session.world
	map = await make_map()
	if not check(await until(func(): return map.overlay is Book and not map.overlay.opening),"Continue reloads the real book"):
		quit(1)
		return
	var reply: Control = map.overlay
	var reply_labels: Array = reply.find_children("*","Label",true,false)
	check(int(world.pending_reward.page)==1 and reply_labels.any(func(label): return label.text==Rumor.DIALOGUE["goblin-chief"][1]),"Continue resumes the saved Goblin Chieftain reply")
	reply.typewriter.reveal_all()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(args[0].path_join("boss-home-rumor-live.png"))==OK,"captured the actual in-game book")

	var action: Control = reply.get_node("BossRumorAction")
	var before_failure: Dictionary = world.snapshot().duplicate(true)
	session.save_file_path = "user://boss-rumor-unwritable-%d/temp.json" % OS.get_process_id()
	await click(action)
	check(map.overlay==reply and not reply.closing and world.snapshot()==before_failure,"failed final save keeps the reply, old board, and RNG for retry")
	session.save_file_path = path
	var old_boss_texture: Texture2D = map.buttons[State.BOSS_TILE_INDEX].texture_normal
	await click(action)
	check(reply.closing and map.buttons[State.BOSS_TILE_INDEX].texture_normal==old_boss_texture,"next board is still hidden while the book closes")
	check(await until(func(): return not map.moving and not is_instance_valid(map.overlay)),"book fully closes and the existing board rotation finishes")
	check(world.tiles==expected.tiles and world.map_serial==expected.map_serial and world.rng.state==expected.rng.state,"departure uses exactly the ordinary board and RNG with one lap increment")
	check(world.current_boss_slug()=="goblin-chief" and map.buttons[State.BOSS_TILE_INDEX].texture_normal==map.texture("res://assets/map/tiles/boss.png"),"the announced boss appears on the actual board")
	check(world.reward_receipts.count(Rumor.receipt(20))==1 and world.pending_reward.is_empty(),"the seen record and departure are saved together")
	world.lap_ready = true
	check(not session.prepare_boss_home_rumor().get("rumor",false),"the same undefeated stage does not repeat the book")
	map.queue_free()
	await process_frame

	for slug in State.BossStages.CANDIDATES:
		seeded_board(session,33,slug,40)
		check(session.prepare_boss_home_rumor().get("rumor",false) and session.world.pending_reward.stage==40,"stage 40 selects "+slug)
		check(Rumor.DIALOGUE[slug][1].contains(session.world.definitions[slug].name),"reply uses the correct localized species name for "+slug)
	check(State.BossStages.CANDIDATES.size()==Rumor.DIALOGUE.size(),"all six intermediate bosses have two pages")
	seeded_board(session,53,"spider-knight",60)
	check(session.prepare_boss_home_rumor().get("rumor",false) and session.world.pending_reward.stage==60,"stage 60 uses its own assignment")
	seeded_board(session,12,"goblin-chief",20)
	check(not session.prepare_boss_home_rumor().get("rumor",false),"a departure before 20 stays ordinary")
	seeded_board(session,13,"goblin-chief",20)
	session.world.mark_boss_defeated(20)
	check(not session.prepare_boss_home_rumor().get("rumor",false),"a defeated boss is not announced")
	seeded_board(session,13,"goblin-chief",20)
	session.world.position = 1
	check(not session.prepare_boss_home_rumor().get("rumor",false),"remote home interaction does not open the rumor")
	seeded_board(session,73,"goblin-chief",20)
	FinalFixture.seed_completed_final_hunt(session.world)
	check(not session.prepare_boss_home_rumor().get("rumor",false),"the final dragon follows the existing story")
	language.set_language("en",false)
	check(tr(Rumor.TITLE)=="Rumors on the Road" and State.BossStages.CANDIDATES.all(
		func(slug): return Rumor.DIALOGUE[slug].all(func(line): return str(tr(line))!=line)),"the book and all six conversations have English translations")

	session.save_file_path = old_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("BOSS_HOME_RUMOR failures=",failures)
	quit(0 if failures == 0 else 1)
