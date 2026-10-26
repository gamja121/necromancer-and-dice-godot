extends SceneTree
const State=preload("res://systems/map_state.gd")
const Plan=preload("res://systems/route_plan.gd")
const Discovery=preload("res://systems/location_discoveries.gd")
var passed: int=0
var failed: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PASS patrol-budget: ",label)
	else: failed+=1; printerr("FAIL patrol-budget: ",label)
func discovered(w) -> void:
	w.laps=2
	w.patrol_plan.rest_unlocked=true
	w.patrol_plan.rest_discovered=true
	for kind in Discovery.ORDER: w.event_flags[Discovery.unlock_flag(kind)]=true
func matches(w, counts: Dictionary) -> bool:
	for kind in State.NAMES:
		if w.tiles.count(kind)!=int(counts.get(kind,0)): return false
	return w.tiles.size()==24
func preserves(w) -> bool:
	for kind in Discovery.ORDER:
		if w.tiles.count(kind)<(2 if kind=="graveyard" else 1): return false
	return w.tiles[0]=="fortune-teller-camp" and w.tiles[8]=="village" and w.tiles[15]=="home" and w.tiles.count("event")==2
func run() -> void:
	var defs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var caps: Dictionary={0:3,14:3,15:3,30:3,40:2,80:1}
	for level in caps:
		var w=State.new(defs,1042+int(level))
		discovered(w)
		w.contamination=int(level)
		w.lap_ready=false
		w.patrol_plan.selection.monster=6
		var saved: Dictionary=w.snapshot().duplicate(true)
		var p: Dictionary=w.patrol_preview(w.patrol_plan)
		check(w.snapshot()==saved,"preview is pure at %d" % level)
		check(int(p.capacity)==int(caps[level]) and int(p.remaining)<0 and not bool(p.valid),"unsafe six-pick budget is rejected at %d" % level)
		var requested: Dictionary=w.patrol_plan.duplicate(true)
		w.generate()
		check(preserves(w),"every earned place, event and anchor survives at %d" % level)
		check(matches(w,p.counts),"actual generation matches preview counts at %d" % level)
		check(w.tiles.count("swamp")==State.required_swamp_count(int(level)),"15/30 swamp quantity retained at %d" % level)
		check(w.patrol_plan==requested,"generation does not silently rewrite stored choices at %d" % level)
		w.lap_ready=true
		var next: Dictionary=w.patrol_preview(w.patrol_plan)
		var safe: Dictionary=w.patrol_plan.duplicate(true)
		safe.selection.monster=int(next.capacity)
		w.patrol_plan=safe
		saved=w.snapshot().duplicate(true)
		next=w.patrol_preview(safe)
		check(w.snapshot()==saved and int(next.contamination)==mini(100,int(level)+7),"next-exit preview accounts for +7 without mutation at %d" % level)
		var actual=State.new(defs,999)
		check(actual.restore(saved),"preview fixture restores at %d" % level)
		actual.leave_home()
		check(matches(actual,next.counts) and preserves(actual),"real State HOME exit equals prediction at %d" % level)
	var fresh=State.new(defs,1024)
	check(fresh.tiles.count("basic")==11 and fresh.tiles.count("monster")==5 and fresh.tiles.count("event")==2,"fresh expedition baseline unchanged")
	check(int(fresh.patrol_preview(fresh.patrol_plan).capacity)==6,"no-discovery route retains maximum six choices")
	var legacy: Dictionary={"current":Plan.CURRENT.duplicate(),"reserve":Plan.RESERVE.duplicate()}
	var old=State.new(defs,2000,legacy)
	check(old.tiles.count("basic")==7 and old.tiles.count("rest")==2 and old.tiles.count("event")==2 and old.tiles.count("swamp")==2,"ordinary legacy inventory quantities unchanged")
	var restored=State.new(defs,11)
	check(restored.restore(old.snapshot()) and restored.patrol_plan==legacy,"legacy save schema and route payload remain loadable")
	var session: Node=root.get_node("RunSession")
	var old_path: String=session.save_file_path
	var scratch: String="user://patrol_budget_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var w=session.world
	discovered(w)
	w.contamination=30
	w.generate()
	w.position=State.HOME
	w.lap_ready=true
	w.patrol_plan.selection.monster=6
	var visit: String=session.place_visit_id("patrol",State.HOME)
	w.reward_receipts.append(visit)
	check(session.save_world(),"old unsafe confirmed plan stored in isolated save")
	var before: Dictionary=w.snapshot().duplicate(true)
	check(not session.patrol_edit_locked(),"only unsafe stored plan reopens confirmed visit for repair")
	check(not session.leave_home() and w.snapshot()==before,"unsafe actual session departure refuses without state mutation")
	check(not bool(session.confirm_patrol(w.patrol_plan).get("ok",false)) and w.snapshot()==before,"unsafe repeated confirmation refuses atomically")
	var repaired: Dictionary=w.patrol_plan.duplicate(true)
	repaired.selection.monster=int(w.patrol_preview(repaired).capacity)
	session.save_file_path="user://missing_patrol_budget_%d/save.json" % OS.get_process_id()
	check(not bool(session.confirm_patrol(repaired).get("ok",false)) and w.snapshot()==before,"failed repair save restores choices and the original receipt")
	session.save_file_path=scratch
	check(bool(session.confirm_patrol(repaired).get("ok",false)),"explicit safe repair succeeds")
	check(w.reward_receipts.count(visit)==1 and session.patrol_edit_locked(),"repair retains one receipt and locks the now-safe visit")
	check(not bool(session.confirm_patrol(repaired).get("ok",false)),"safe confirmed visit cannot be confirmed repeatedly")
	session.reload_world()
	check(session.world.patrol_plan==repaired and session.world.reward_receipts.count(visit)==1,"repair survives restart exactly once")
	session.save_file_path=old_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("PATROL_BUDGET_PRESERVATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
