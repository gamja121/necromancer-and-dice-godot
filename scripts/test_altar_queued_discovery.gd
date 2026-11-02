extends SceneTree
## Production Godot reproduction of blocked altar discovery and guaranteed
## next-lap placement. Uses a scratch save; never touches personal progress.
const Discovery=preload("res://systems/location_discoveries.gd")
const State=preload("res://systems/map_state.gd")
const RoutePlan=preload("res://systems/route_plan.gd")
const MapScene=preload("res://map.tscn")
var passed:int=0
var failed:int=0

func _initialize() -> void: call_deferred("_run")

func check(condition:bool, note:String) -> void:
	if condition:
		passed+=1
		print("PASS altar-queue: ",note)
	else:
		failed+=1
		printerr("FAIL altar-queue: ",note)

func _run() -> void:
	var session:Node=root.get_node("RunSession")
	var old_path:String=session.save_file_path
	var scratch:String="user://altar_queue_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var w=session.world
	w.laps=3
	w.contamination=20
	w.max_contamination_reached=20
	w.event_flags[Discovery.unlock_flag("unknown")]=true
	w.event_flags[Discovery.unlock_flag("forest")]=true
	w.event_flags[Discovery.receipt_flag("unknown")]=true
	w.event_flags[Discovery.receipt_flag("forest")]=true
	w.patrol_plan.selection.monster=6
	w.generate()
	var initial:Dictionary=w.patrol_preview(w.patrol_plan)
	check(bool(initial.valid) and initial.selected==6 and initial.applied==6,
		"full legal six additional stones remain selectable")
	check(w.tiles.count("basic")==1 and w.tiles.count("swamp")==1,
		"the last road is reserved for future marsh")
	var index:int=w.tiles.find("event")
	check(index>=0,"real event tile exists")
	w.position=index
	w.move_serial+=1
	check(session.save_world(),"fixture saved using production save function")
	check(Discovery.next_main_eligible(w)=="altar","altar is next story priority")
	var result:Dictionary=session.begin_story_free_event(index)
	check(result.get("ok",false)==true and result.get("type","")=="discovery_pending"
		and result.get("location","")=="altar",
		"real event visit reserves altar rather than falling back to routine")
	check(Discovery.is_pending(w,"altar") and not Discovery.is_unlocked(w,"altar") and w.tiles.count("altar")==0,
		"queued site is NOT prematurely granted")
	check(w.pending_reward.is_empty() and w.reward_receipts.size()==1,
		"queued discovery consumes one real event and never creates a routine")
	check(Discovery.next_main_eligible(w)!="altar",
		"queued altar does not repeatedly hijack later events")
	var saved:Dictionary=w.snapshot().duplicate(true)
	var repeat:Dictionary=session.begin_story_free_event(index)
	check(not repeat.get("ok",false) and w.snapshot()==saved,
		"same event cannot grant duplicate reservations or alter RNG")
	session.reload_world()
	w=session.world
	check(Discovery.is_pending(w,"altar") and not Discovery.is_unlocked(w,"altar"),
		"pending flag is durable across save/restart")
	w.position=State.HOME
	w.lap_ready=true
	var before:Dictionary=w.snapshot().duplicate(true)
	var forecast:Dictionary=w.patrol_preview(w.patrol_plan)
	check(bool(forecast.valid) and int(forecast.selected)==6
		and int(forecast.applied)==5 and int(forecast.trimmed)==1
		and int(forecast.reserved_roads)==1 and int(forecast.basic_roads)==1,
		"preview clearly distinguishes 6 requested / 5 applied / reserved road")
	check(w.snapshot()==before,"next-map preview does not mutate world/save")
	check(session.save_world(),"before departure saved")
	check(session.leave_home(),"real session HOME departure succeeds with auto-fit")
	check(Discovery.is_unlocked(w,"altar") and not Discovery.is_pending(w,"altar")
		and w.tiles.count("altar")==1,
		"queued altar is awarded atomically with an actual next-map stone")
	check(w.patrol_plan.selection.monster==6 and w.tiles.count("monster")+w.tiles.count("rare-monster")>=5,
		"request stays six and five core monster stones survive")
	check(w.tiles.count("basic")==1 and w.tiles.count("swamp")==1
		and w.tiles[0]=="fortune-teller-camp" and w.tiles[8]=="village" and w.tiles[15]=="home",
		"map stays 24 tiles with fixed destinations and protected swamp room")
	check(w.event_flags.get(Discovery.home_flag("altar"),false)==true
		and w.event_flags.get(Discovery.receipt_flag("altar"),false)==true,
		"home NEW and discovery receipt are committed with real stone")
	check(w.reward_receipts.size()==1 and w.pending_reward.is_empty(),
		"pending event does not re-open a reward after HOME transition")
	session.reload_world()
	w=session.world
	check(Discovery.is_unlocked(w,"altar") and w.tiles.count("altar")==1
		and w.patrol_plan.selection.monster==6,
		"actual altar and requested selection survive restart")
	# Pending multiple main places must all have guaranteed space.
	w.event_flags[Discovery.unlock_flag("altar")]=false
	w.event_flags[Discovery.unlock_flag("unknown")]=false
	w.event_flags[Discovery.unlock_flag("forest")]=false
	for kind in Discovery.MAIN_STORY_ORDER:
		w.event_flags[Discovery.pending_flag(kind)]=true
	w.contamination=40
	w.max_contamination_reached=40
	w.generate()
	for kind in Discovery.MAIN_STORY_ORDER:
		check(w.tiles.count(kind)==1 and Discovery.is_unlocked(w,kind)
			and not Discovery.is_pending(w,kind),
			"simultaneous queued "+kind+" placed before optional patrol")
	check(w.tiles.size()==24 and w.patrol_plan.selection.monster==6,
		"multiple reservations keep 24 spaces and original requested plan")
	# Failed save must not leave a reservation or duplicate event receipt.
	session.start_new_world()
	w=session.world
	w.laps=3
	w.contamination=20
	w.max_contamination_reached=20
	w.event_flags[Discovery.unlock_flag("unknown")]=true
	w.event_flags[Discovery.unlock_flag("forest")]=true
	w.patrol_plan.selection.monster=6
	w.generate()
	w.position=w.tiles.find("event")
	w.move_serial+=1
	before=w.snapshot().duplicate(true)
	session.save_file_path="user://nonexistent_altar_queue_%d/never.json" % OS.get_process_id()
	var fail_result:Dictionary=session.begin_story_free_event(w.position)
	check(not fail_result.get("ok",false) and w.snapshot()==before,
		"failed persist atomically restores original map and queued flags")
	session.save_file_path=old_path
	session.world=null
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("ALTAR_QUEUE_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
