extends SceneTree

const Session = preload("res://systems/run_session.gd")
const State = preload("res://systems/map_state.gd")
const Portal = preload("res://systems/ritual_portal_entry.gd")
const Routine = preload("res://systems/routine_event_catalog.gd")
const Catalog = preload("res://systems/reward_catalog.gd")
const Discovery = preload("res://systems/location_discoveries.gd")
const Rumor = preload("res://systems/cultist_rumor_entry.gd")
const Board = preload("res://map.tscn")
const Child = preload("res://systems/story_event_entry.gd")
const HILL := 16
const TREE := 17
const EVENT := 18

var passed := 0
var failed := 0
var save_path := "user://test_world_tree_assault_%d.json" % OS.get_process_id()
var session: Session

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS world-tree-assault: ", description)
	else:
		failed += 1
		printerr("FAIL world-tree-assault: ", description)

func fixture():
	check(session.start_new_world(), "fresh version-1 fixture")
	session.demo_mode = false
	var world = session.world
	world.tiles[HILL] = "forest"
	world.tiles[TREE] = "unknown"
	world.tiles[EVENT] = "event"
	world.position = HILL
	world.laps = 2
	world.contamination = 30
	for place in Discovery.ORDER:
		world.event_flags[Discovery.unlock_flag(place)] = true
	world.event_flags[Rumor.COMPLETE_FLAG] = true
	session.world_tree_assault_stage_enabled = true
	return world

func seed_for(attack: String) -> int:
	var rng := RandomNumberGenerator.new()
	for seed in range(500):
		rng.seed = seed
		if rng.randf() < 0.30:
			if ("cut" if rng.randi_range(0,1)==0 else "burn") == attack: return seed
		elif attack.is_empty():
			return seed
	return -1

func land_on_event(attack: String) -> void:
	check(session.prepare_hill_move(HILL,2).get("ok",false) and session.complete_map_move(),"real two-step event arrival")
	session.world.rng.seed = seed_for(attack)

func test_visit() -> void:
	var world = fixture()
	check(not world.event_flags.has(State.WORLD_TREE_VISITED_FLAG),"unlock alone does not record a visit")
	land_on_event("cut")
	check(not world.event_flags.has(State.WORLD_TREE_VISITED_FLAG),"passing over the tree does not record a visit")
	var outcome := session.begin_story_free_event(EVENT)
	check(outcome.get("type","")=="routine","an unvisited tree prevents the assault")
	world = fixture()
	check(session.prepare_hill_move(HILL,1).get("ok",false),"world-tree move is prepared")
	check(not world.event_flags.has(State.WORLD_TREE_VISITED_FLAG),"prepared movement does not count as arrival")
	check(session.reload_world() and session.complete_map_move(),"real pending world-tree arrival survives reload")
	check(session.reload_world() and session.event_flag_is_set(State.WORLD_TREE_VISITED_FLAG),"the committed arrival durably records a visit")

	world = fixture()
	for seed in range(500):
		world.rng.seed = seed
		if world.rng.randi_range(1,6)==1:
			world.rng.seed = seed
			break
	check(session.prepare_map_roll().get("landed",-1)==TREE and session.complete_map_move()
		and session.event_flag_is_set(State.WORLD_TREE_VISITED_FLAG),"ordinary die uses the same durable tree visit")
func test_blockers() -> void:
	for blocker in ["disabled","demo","preview","legacy_reload","one_lap","purified","rumor_seen","locked","winter","hell","completed"]:
		var world = fixture()
		world.event_flags[State.WORLD_TREE_VISITED_FLAG] = true
		match blocker:
			"disabled": session.world_tree_assault_stage_enabled = false
			"demo": session.demo_mode = true
			"one_lap": world.laps = 1
			"purified":
				world.max_contamination_reached = 70
				world.contamination = 29
			"rumor_seen":
				world.event_flags.erase(Rumor.COMPLETE_FLAG)
				world.event_flags[Rumor.SEEN_FLAG] = true
			"locked":
				world.event_flags.erase(Discovery.unlock_flag("unknown"))
				world.event_flags[Discovery.pending_flag("unknown")] = true
			"winter","hell": world.region = blocker
			"completed": world.event_flags[State.WORLD_TREE_ASSAULT_COMPLETE_FLAG] = true
		if blocker in ["preview","legacy_reload"]:
			world.position = EVENT
			world.rng.seed = seed_for("cut")
		else:
			land_on_event("cut")
		if blocker == "legacy_reload": check(session.save_world() and session.reload_world(),"legacy arrival has no recorded event landing")
		var outcome := session.begin_story_free_event(EVENT)
		check(outcome.get("type","")=="routine" and session.pending_world_tree_assault().is_empty(),"%s cannot roll an assault" % blocker)

func test_priority_and_miss() -> void:
	var world = fixture()
	world.event_flags[State.WORLD_TREE_VISITED_FLAG] = true
	world.event_flags.erase(Discovery.unlock_flag("altar"))
	land_on_event("cut")
	var rng_before: int = world.rng.state
	var outcome := session.begin_story_free_event(EVENT)
	check(outcome.get("type","") in ["discovery","discovery_pending"] and outcome.get("location","")=="altar",
		"guaranteed altar outranks a successful assault seed")
	check(world.rng.state == rng_before,"guaranteed discovery consumes no assault or routine RNG")
	world = fixture()
	world.event_flags[State.WORLD_TREE_VISITED_FLAG] = true
	land_on_event("")
	outcome = session.begin_story_free_event(EVENT)
	check(outcome.get("type","")=="routine","an eligible miss falls through to the ordinary event resolver")

func test_save_and_resume(attack: String) -> void:
	var world = fixture()
	world.event_flags[State.WORLD_TREE_VISITED_FLAG] = true
	land_on_event(attack)
	check(session.save_world() and session.reload_world() and session.has_world_tree_assault_landing(),"a valid pending arrival survives reloading before the draw")
	world = session.world
	var before: Dictionary = world.snapshot().duplicate(true)
	session.save_file_path = "user://missing_assault_dir_%d/save.json" % OS.get_process_id()
	check(not session.begin_story_free_event(EVENT).get("ok",false) and world.snapshot()==before,
		"%s save failure rolls back the receipt and RNG" % attack)
	session.save_file_path = save_path
	var outcome := session.begin_story_free_event(EVENT)
	var pending := session.pending_world_tree_assault()
	check(outcome.get("type","")==State.WORLD_TREE_ASSAULT and pending.get("attack","")==attack,
		"%s is written after a real landing" % attack)
	check(pending.get("phase","")=="choice" and pending.get("id","")==State.event_visit_id(world.map_serial,world.move_serial,EVENT),
		"%s records phase and real landing identity" % attack)
	var rng_after: int = world.rng.state
	check(session.reload_world() and session.pending_world_tree_assault()==pending and session.world.rng.state==rng_after,
		"%s reopens with the original attack and RNG" % attack)
	check(not session.begin_story_free_event(EVENT).get("ok",false) and session.pending_world_tree_assault()==pending,
		"%s cannot draw a second event on the same arrival" % attack)
	var corrupt: Dictionary = session.world.snapshot().duplicate(true)
	corrupt.pending_reward.attack = "other"
	check(not session.world.restore(corrupt) and session.pending_world_tree_assault()==pending,
		"%s recovery refuses an invalid attack without changing live state" % attack)

func test_main_story_priority() -> void:
	var world = fixture()
	world.event_flags[State.WORLD_TREE_VISITED_FLAG] = true
	check(session.prepare_hill_move(HILL,2).get("ok",false),"main story fixture records a real pending event move")
	world.rng.seed = seed_for("cut")
	var rng_before: int = world.rng.state
	var map := Board.instantiate()
	root.add_child(map)
	var deadline := Time.get_ticks_msec()+8000
	while (not world.pending_move.is_empty() or map.moving) and Time.get_ticks_msec()<deadline:
		await process_frame
	check(session.get_story_event(Child.EVENT_ID).status=="seen" and not map.moving,
		"actual board dispatch starts the eligible main story")
	check(world.pending_reward.is_empty() and world.rng.state==rng_before,
		"main story wins without drawing an otherwise successful assault")
	check(not session.has_world_tree_assault_landing(),"the main story consumes the one-time arrival authorization")
	map.queue_free()
	await process_frame

func test_optional_ritual_window() -> void:
	var world = fixture()
	world.event_flags[State.WORLD_TREE_VISITED_FLAG] = true
	world.event_flags[Portal.SEEN_FLAG] = true
	for attempt in range(5):
		world.position = HILL
		land_on_event("")
		var miss := session.begin_story_free_event(EVENT)
		check(miss.get("type","")=="routine","eligible miss %d remains optional" % (attempt+1))
		check(session.complete_routine_choice("skip").get("ok",false),"ordinary outcome allows another event visit")
	world.position = HILL
	land_on_event("cut")
	check(session.begin_story_free_event(EVENT).get("attack","")=="cut",
		"merely seeing the portal does not close the optional draw")
	var pending := session.pending_world_tree_assault()
	world.event_flags[Portal.COMPLETE_FLAG] = true
	check(session.save_world() and session.reload_world() and session.pending_world_tree_assault()==pending,
		"a previously saved attack survives loading alongside the cutoff")

	for battle_result: String in ["","won","lost"]:
		world = fixture()
		world.event_flags[State.WORLD_TREE_VISITED_FLAG] = true
		world.event_flags[Portal.COMPLETE_FLAG] = true
		var choice := "allow" if battle_result.is_empty() else "intervene"
		world.story_events[Portal.EVENT_ID] = {"status":"complete","choice":choice,"battle_result":battle_result}
		land_on_event("burn")
		var rng := RandomNumberGenerator.new()
		rng.seed = world.rng.seed
		rng.state = world.rng.state
		var expected := Routine.choose(rng)
		if Routine.details(expected).effect=="dice":
			rng.randi_range(0,Catalog.dice_cards().size()-1)
		var outcome := session.begin_story_free_event(EVENT)
		check(outcome.get("type","")=="routine" and outcome.get("event_id","")==expected
			and world.rng.state==rng.state and session.pending_world_tree_assault().is_empty(),
			"completed ritual %s %s skips the assault draw and keeps ordinary RNG" % [choice,battle_result])

func seed_result_face(face: int) -> void:
	var rng: RandomNumberGenerator = session.world.rng
	for seed in range(500):
		rng.seed = seed
		if rng.randi_range(1,6) == face:
			rng.seed = seed
			return

func test_choice_results() -> void:
	for entry in [["safe","cut",0,"default"],["risk","cut",3,"winter"],["risk","burn",4,"default"],["ignore","burn",0,"hell"]]:
		var choice: String = entry[0]
		var attack: String = entry[1]
		var face: int = entry[2]
		var region: String = entry[3]
		var case_name := "%s/%s/%d" % [choice,attack,face]
		var world = fixture()
		world.event_flags[State.WORLD_TREE_VISITED_FLAG] = true
		for i in range(2):
			world.dice_cards.append(session.create_item("dice",Catalog.dice_cards()[0]))
		land_on_event(attack)
		check(session.begin_story_free_event(EVENT).get("ok",false),"%s opens a real assault" % case_name)
		var pending := session.pending_world_tree_assault()
		var receipt_id: String = pending.id
		if face > 0: seed_result_face(face)
		var selected_id: String = world.dice_cards[1].id if choice == "safe" else ""
		var old_cards: Array = world.dice_cards.duplicate(true)
		var old_roster: Array = world.roster.duplicate(true)
		var old_tiles: Array = world.tiles.duplicate()
		if choice == "safe":
			check(not session.resolve_world_tree_assault(receipt_id,"safe","stale-card").get("ok",false),
				"safe choice requires a specific owned instance")
			old_cards.remove_at(1)
		var before: Dictionary = world.snapshot().duplicate(true)
		session.save_file_path = "user://missing_assault_dir_%d/save.json" % OS.get_process_id()
		check(not session.resolve_world_tree_assault(receipt_id,choice,selected_id).get("ok",false)
			and world.snapshot() == before,"failed %s save restores RNG, region and costs" % choice)
		session.save_file_path = save_path
		var resolved := session.resolve_world_tree_assault(receipt_id,choice,selected_id)
		check(resolved.get("ok",false),"%s commits successfully" % case_name)
		var result := session.pending_world_tree_assault()
		check(result.get("phase","")=="result" and result.get("face",-1)==face and world.region==region,
			"%s saves the correct face and destination" % case_name)
		check(world.dice_cards==old_cards and world.roster==old_roster,
			"%s charges only its stated card cost" % case_name)
		check(world.contamination==(38 if choice=="safe" else 30) and world.position==EVENT,
			"%s applies its corruption cost without moving the player" % case_name)
		if choice != "safe":
			check(world.tiles==old_tiles,"changing region keeps the original 24 tiles")
		check(world.reward_receipts.count(receipt_id)==1 and session.reload_world()
			and session.pending_world_tree_assault()==result,"one result receipt survives reload exactly")
		check(not session.resolve_world_tree_assault(receipt_id,choice,selected_id).get("ok",false),
			"resolved choice rejects duplicate input")
		check(session.acknowledge_world_tree_assault(receipt_id) and session.reload_world()
			and session.pending_world_tree_assault().is_empty() and session.world.region==region,
			"continuing retains the region and clears the result")
		check(session.world.event_flags.get(State.WORLD_TREE_ASSAULT_COMPLETE_FLAG,false),
			"the one-time completion record remains after acknowledging")
		check(session.world.world_tree_destroyed() == (region != "default"),
			"%s reload distinguishes real destruction from successful defense" % case_name)
		if region != "default":
			var resumed = session.world
			for key in ["tiles","position","laps","patrol_plan","riot","story_events","boss_assignments","dice_cards","roster"]:
				check(resumed.snapshot().get(key,{}) == before.get(key,{}),"%s retains %s across world transition" % [region,key])
			resumed.position = TREE
			var prayer_before: Dictionary = resumed.snapshot().duplicate(true)
			var prayer: Dictionary = session.pray_world_tree(TREE)
			check(not prayer.get("ok",true) and prayer.get("reason","")==Session.WORLD_TREE_PRAYER_CLOSED
				and resumed.snapshot()==prayer_before,"%s prayer closure consumes no RNG or state" % region)
			resumed.position = EVENT
			check(session.prepare_map_roll().get("ok",false) and session.complete_map_move()
				and resumed.position != EVENT and resumed.region==region,
				"%s continues normal movement after the result is closed" % region)

func displayed_board(map: Control) -> String:
	var background := map.stage.get_child(0) as TextureRect
	return background.texture.resource_path.get_file() if is_instance_valid(background) else ""


func test_region_presentation(attack: String, region: String) -> void:
	var world = fixture()
	world.event_flags[State.WORLD_TREE_VISITED_FLAG] = true
	world.event_flags[Child.COMPLETE_FLAG] = true
	land_on_event(attack)
	check(session.begin_story_free_event(EVENT).get("ok",false),"%s presentation starts from a real assault" % region)
	var choice := "ignore"
	if region == "default":
		choice = "risk"
		seed_result_face(4)
	var id: String = session.pending_world_tree_assault().id
	check(session.resolve_world_tree_assault(id,choice).get("ok",false) and session.reload_world(),
		"%s result is committed and reloaded before acknowledgement" % region)

	var map := Board.instantiate() as Control
	root.add_child(map)
	await process_frame
	var panel: Control = map.overlay
	var advance := panel.get_node_or_null("AssaultContinue") as Button if is_instance_valid(panel) else null
	check(is_instance_valid(advance),"%s reload restores the actual result book" % region)
	if not is_instance_valid(advance):
		map.queue_free()
		await process_frame
		return
	panel.skip_opening()
	panel.typewriter.reveal_all()
	check(displayed_board(map)=="default-map.jpg" and map.tile_path(TREE).ends_with("/unknown.png"),
		"%s pending book keeps the old map and living tree visible" % region)

	if region == "winter":
		session.save_file_path = "user://missing_assault_dir_%d/save.json" % OS.get_process_id()
		advance.pressed.emit()
		session.save_file_path = save_path
		check(map.overlay==panel and not advance.disabled and session.pending_world_tree_assault().id==id
			and not is_instance_valid(map.world_tree_transition) and displayed_board(map)=="default-map.jpg",
			"failed acknowledgement preserves the book and permits retry without playing the effect")

	advance.pressed.emit()
	check(session.pending_world_tree_assault().is_empty() and not is_instance_valid(map.overlay),
		"%s continue consumes the saved receipt and closes the book" % region)
	if region == "default":
		check(not is_instance_valid(map.world_tree_transition) and not map.moving and not map.dice.disabled,
			"successful defense returns immediately to the playable board")
	else:
		var effect: Control = map.world_tree_transition
		check(is_instance_valid(effect) and map.moving and map.dice.disabled
			and displayed_board(map)=="default-map.jpg", "%s transition opens on the old board with the die disabled" % region)
		check(map.handle_cancel() and not map.map_audio.is_open() and not map.keyboard_roll_dice()
			and map.keyboard_focus_controls().is_empty(), "%s transition consumes Escape and blocks keyboard actions" % region)
		var deadline := Time.get_ticks_msec()+8000
		while is_instance_valid(effect) and not effect.board_revealed and Time.get_ticks_msec()<deadline:
			await process_frame
		check(is_instance_valid(effect) and effect.board_revealed and displayed_board(map)=="%s-map.jpg" % region
			and map.tile_path(TREE).ends_with("/world_tree_ruins_%s.png" % region) and map.moving and map.dice.disabled,
			"%s swaps the actual map and tile during the input lock" % region)
		while map.moving and Time.get_ticks_msec()<deadline:
			await process_frame
		check(not map.moving and not map.dice.disabled and not is_instance_valid(map.world_tree_transition),
			"%s animation completes and returns control" % region)

	map.queue_free()
	await process_frame
	check(session.reload_world(),"%s acknowledged result reloads" % region)
	map = Board.instantiate() as Control
	root.add_child(map)
	await process_frame
	check(displayed_board(map)=="%s-map.jpg" % region and session.world.position==EVENT
		and not is_instance_valid(map.overlay) and not is_instance_valid(map.world_tree_transition),
		"%s reload keeps the board and player position without replaying the result" % region)
	map.queue_free()
	await process_frame


func _run() -> void:
	session = root.get_node("RunSession") as Session
	var previous_path := session.save_file_path
	session.save_file_path = save_path
	check(session.world_tree_assault_stage_enabled,"standard player sessions enable the optional assault")
	test_visit()
	test_blockers()
	test_priority_and_miss()
	test_save_and_resume("cut")
	test_save_and_resume("burn")
	test_optional_ritual_window()
	test_choice_results()
	await test_main_story_priority()
	await test_region_presentation("cut","winter")
	await test_region_presentation("burn","hell")
	await test_region_presentation("cut","default")
	for suffix: String in ["",".tmp"]:
		var path := ProjectSettings.globalize_path(save_path+suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	session.save_file_path = previous_path
	session.world = null
	var cleanup_audio := root.get_node_or_null("GameAudio")
	if is_instance_valid(cleanup_audio): cleanup_audio.queue_free()
	await process_frame
	await create_timer(0.30,true,false,true).timeout
	print("WORLD_TREE_ASSAULT_ENTRY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
