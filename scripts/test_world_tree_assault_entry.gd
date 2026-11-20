extends SceneTree

const Session = preload("res://systems/run_session.gd")
const State = preload("res://systems/map_state.gd")
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
	for blocker in ["disabled","preview","reload","one_lap","purified","rumor_seen","locked","winter","hell","completed"]:
		var world = fixture()
		world.event_flags[State.WORLD_TREE_VISITED_FLAG] = true
		match blocker:
			"disabled": session.world_tree_assault_stage_enabled = false
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
		if blocker == "preview":
			world.position = EVENT
			world.rng.seed = seed_for("cut")
		else:
			land_on_event("cut")
		if blocker == "reload": check(session.reload_world(),"reload with no saved assault")
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
	check(session._world_tree_assault_landing.is_empty(),"the main story consumes the one-time arrival authorization")
	map.queue_free()
	await process_frame

func _run() -> void:
	session = root.get_node("RunSession") as Session
	var previous_path := session.save_file_path
	session.save_file_path = save_path
	check(not session.world_tree_assault_stage_enabled,"player sessions default to normal event flow")
	test_visit()
	test_blockers()
	test_priority_and_miss()
	test_save_and_resume("cut")
	test_save_and_resume("burn")
	await test_main_story_priority()
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
