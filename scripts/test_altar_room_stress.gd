extends SceneTree
## Repeated native Godot test of altar placement room with actual MapState,
## RoutePlan, discovery prerequisites and event dispatcher. No gameplay edits.
const Discovery = preload("res://systems/location_discoveries.gd")
const RoutePlan = preload("res://systems/route_plan.gd")
const State = preload("res://systems/map_state.gd")
const SAMPLES_PER_CASE = 300
const LEVELS = [20,30,40,50,80]
const PAST_LOCATIONS = [
	["unknown"],
	["unknown","forest"],
	["unknown","forest","rest"],
	["unknown","forest","rest","graveyard"]
]
var passed: int = 0
var failed: int = 0
var sample_count: int = 0
var refused_count: int = 0
var blocked_cases: int = 0
var chance_cases: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL altar-room-stress: ",label)

func configure(w, level: int, owned: Array, selected: int) -> Dictionary:
	w.contamination = level
	w.max_contamination_reached = level
	w.laps = 3
	w.lap_ready = false
	w.event_flags = {}
	w.story_events = {}
	w.reward_receipts = []
	w.pending_reward = {}
	w.pending_move = {}
	w.active_encounter = {}
	w.run_result = {}
	for kind in owned:
		w.event_flags[Discovery.unlock_flag(str(kind))] = true
		w.event_flags[Discovery.receipt_flag(str(kind))] = true
	var plan: Dictionary = RoutePlan.default_plan()
	plan.selection.monster = selected
	if "rest" in owned:
		plan.rest_unlocked = true
		plan.rest_discovered = true
	w.patrol_plan = plan
	return w.patrol_preview(plan)

func stress_case(w, level: int, owned: Array, selected: int, case_id: int) -> void:
	var preview: Dictionary = configure(w,level,owned,selected)
	check(RoutePlan.valid(w.patrol_plan),"valid structured plan, case "+str(case_id))
	if not bool(preview.valid):
		return
	check(Discovery.eligible(w,"altar"),"altar eligible, case "+str(case_id))
	check(Discovery.next_main_eligible(w)=="altar","altar is highest qualified discovery, case "+str(case_id))
	var min_roads: int=999
	var max_roads: int=0
	var refusals: int=0
	var successes: int=0
	var ignored_boss_slot: int=0
	for attempt in range(SAMPLES_PER_CASE):
		w.rng.seed = 123456 + case_id * 100000 + attempt
		w.generate()
		var event_index: int = w.tiles.find("event")
		check(event_index>=0,"real event tile exists "+str(case_id))
		w.position=event_index
		w.move_serial+=1
		var roads: int = w.tiles.count("basic")
		min_roads=mini(min_roads,roads)
		max_roads=maxi(max_roads,roads)
		check(roads==int(preview.counts.basic),"generated map matches actual patrol manifest")
		var route_blocked: bool=roads<=maxi(0,RoutePlan.RESERVED_SWAMP_ROADS-w.tiles.count("swamp"))
		if route_blocked: refused_count+=1
		if roads>0 and w.tiles[State.BOSS_TILE_INDEX]=="basic": ignored_boss_slot+=1
		var index: int = w.reveal_discovered_location("altar")
		if index<0:
			refusals+=1
		else:
			successes+=1
			check(w.tiles[index]=="altar" and index!=event_index and index!=State.BOSS_TILE_INDEX,
				"altar converted exactly one permitted road")
		sample_count+=1
	if refusals==SAMPLES_PER_CASE: blocked_cases+=1
	elif refusals>0: chance_cases+=1
	if selected>=int(preview.capacity)-1 or refusals>0:
		print("ALTAR_ROOM_CASE ",JSON.stringify({
			"level":level,"already_owned":owned,"selected":selected,
			"capacity":preview.capacity,"roads":[min_roads,max_roads],
			"swamp_reserved":maxi(0,RoutePlan.RESERVED_SWAMP_ROADS-State.required_swamp_count(level)),
			"attempts":SAMPLES_PER_CASE,"success":successes,"blocked":refusals,
			"slot23_was_basic":ignored_boss_slot
		}))
	check(successes+refusals==SAMPLES_PER_CASE,"all attempts classified")

func _run() -> void:
	var session: Node = root.get_node_or_null("RunSession")
	check(session!=null,"production RunSession singleton")
	if session==null: quit(1); return
	var old_path: String = session.save_file_path
	var scratch: String = "user://altar_room_stress_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var w=session.world
	var case_id: int=0
	for level in LEVELS:
		for owned in PAST_LOCATIONS:
			for chosen in range(7):
				case_id+=1
				stress_case(w,level,owned,chosen,case_id)
	# End-to-end proof: a valid plan with no spendable road turns a
	# guaranteed main-story altar discovery into an ordinary random event.
	var preview: Dictionary=configure(w,20,["unknown","forest"],6)
	check(bool(preview.valid) and int(preview.counts.basic)==1 and int(preview.capacity)==6,
		"reproduction uses legal six-stone patrol with one swamp-reserved road")
	w.rng.seed=493
	w.generate()
	w.position=w.tiles.find("event")
	w.move_serial+=1
	check(Discovery.next_main_eligible(w)=="altar","real event dispatcher should prioritize altar")
	check(session.save_world(),"save actual input world for dispatcher reproduction")
	var before: Dictionary=w.snapshot().duplicate(true)
	var outcome: Dictionary=session.begin_story_free_event(w.position)
	check(bool(outcome.get("ok",false)) and outcome.get("type","")=="routine",
		"CONFIRMED: actual event yields routine despite altar priority and sufficient progress")
	check(not Discovery.is_unlocked(w,"altar") and w.tiles.count("altar")==0,
		"CONFIRMED: altar remains absent from map after blocked arrival")
	check(w.pending_reward.get("kind","")=="routine",
		"CONFIRMED: failure is presented as ordinary event, not an unlock failure")
	print("ALTAR_ROOM_REPRO ",JSON.stringify({
		"level":20,"unlocked":["unknown","forest"],"selected_monsters":6,
		"capacity":preview.capacity,"basic":before.tiles.count("basic"),
		"swamp_reserved":1,"outcome":outcome,"altar_unlocked":Discovery.is_unlocked(w,"altar")
	}))
	session.world=null
	session.save_file_path=old_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("ALTAR_ROOM_STRESS: %d attempts, %d fully blocked legal cases, %d partly blocked cases, %d checks passed, %d failed" % [sample_count,blocked_cases,chance_cases,passed,failed])
	quit(0 if failed==0 and sample_count>10000 and blocked_cases>0 else 1)
