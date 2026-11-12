extends SceneTree
const Session=preload("res://systems/run_session.gd")
const Fixture=preload("res://scripts/witch_hunt_fixture.gd")
const Hunt=Fixture.Hunt
const Beats=Fixture.Beats
const Inquiry=Fixture.Inquiry
const Portal=preload("res://systems/ritual_portal_entry.gd")
var passed: int=0
var failed: int=0
var save: String
var s: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> bool:
	if ok: passed+=1; print("PASS witch-hunt: ",label)
	else: failed+=1; printerr("FAIL witch-hunt: ",label)
	return ok
func clean() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))
func failed_save(call: Callable, label: String) -> void:
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path="user://witch_hunt_missing_%d/save.json" % OS.get_process_id()
	check(not call.call() and s.world.snapshot()==before,label+": full rollback")
	s.save_file_path=save
func reload_same(label: String) -> void:
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.reload_world()
	check(s.world.snapshot()==before,label+": exact disk restart")
func gameplay() -> Dictionary:
	var state: Dictionary=s.world.snapshot().duplicate(true)
	state.erase("story_events")
	state.erase("event_flags")
	return state
func no_outcome(stage: int) -> bool:
	for key in Hunt.all_outcome_flags(stage):
		if s.event_flag_is_set(key): return false
	return not s.event_flag_is_set(Hunt.flag(stage,"complete"))
func stage_run(stage: int, decision: String, exhaustive: bool) -> void:
	if stage<2: check(not Hunt.begin(s,stage,s.world.position),"same village visit cannot chain stage "+str(stage))
	if not check(Fixture.arrive(s,stage),"later actual place saved"): return
	var at: int=s.world.position
	var initial: Dictionary=gameplay()
	var valid: Dictionary=s.world.snapshot().duplicate(true)
	if exhaustive:
		for key in [Hunt.flag(stage,"complete"),Hunt.progress_flag(stage,2),Hunt.flag(stage,"beat:99"),Hunt.flag(stage,"beat:01"),Hunt.all_outcome_flags(stage)[0]]:
			s.world.event_flags[key]=true
			check(not Hunt.begin(s,stage,at),"stray or malformed receipt rejected")
			s.world.restore(valid)
		for field in ["pending_move","pending_reward","active_encounter"]:
			s.world.set(field,{"test":true})
			check(not Hunt.can_enter(s,stage,at),"unfinished operation blocks entry")
			s.world.restore(valid)
		s.encounter={"test":true}
		check(not Hunt.can_enter(s,stage,at),"session battle blocks entry")
		s.encounter={}
		s.world.run_result={"status":"defeat"}
		check(not Hunt.can_enter(s,stage,at),"terminal run blocks entry")
		s.world.restore(valid)
		s.world.event_flags[Inquiry.COMPLETE_FLAG]=false
		check(not Hunt.begin(s,stage,at),"genuine inquiry provenance required")
		s.world.restore(valid)
		s.world.position=s.world.tiles.find("event")
		check(not Hunt.can_enter(s,stage,at) and Hunt.can_enter(s,stage,s.world.position)==(stage==1),"only riot may begin on a different occupied tile")
		s.world.restore(valid)
		failed_save(func():return Hunt.begin(s,stage,at),"entry")
	check(Hunt.begin(s,stage,at),"deliberate entry")
	var after: Dictionary=s.world.snapshot().duplicate(true)
	check(Hunt.begin(s,stage,at) and s.world.snapshot()==after,"resume begin writes nothing")
	if stage==2:
		check(not s.enter_home() and not s.home_action_allowed().ok and not s.confirm_patrol(s.world.patrol_plan).ok,"active home event blocks healing, inheritance and route editing")
		check(not s.leave_home() and not s.prepare_map_roll().ok,"unfinished home event cannot be skipped by departure or die")
		check(not s.warp_from(s.world.tiles.find("warp")).ok,"remote warp cannot strand an active HOME story off its tile")
		check(s.world.snapshot()==after,"blocked home actions consume no resources or RNG")
	for beat in range(Beats.CHOICE_INDEX):
		if exhaustive: failed_save(func():return Hunt.advance(s,stage,at,beat),"opening")
		check(Hunt.advance(s,stage,at,beat),"one opening beat")
		after=s.world.snapshot().duplicate(true)
		check(not Hunt.advance(s,stage,at,beat) and s.world.snapshot()==after,"stale opening callback rejected")
	check(not Hunt.advance(s,stage,at,Beats.CHOICE_INDEX) and not Hunt.choose(s,stage,at,2,decision) and not Hunt.choose(s,stage,at,3,"invalid"),"question requires explicit valid choice")
	if exhaustive: failed_save(func():return Hunt.choose(s,stage,at,3,decision),"choice")
	check(Hunt.choose(s,stage,at,3,decision) and no_outcome(stage),"intent creates no finished consequence")
	if exhaustive: failed_save(func():return Hunt.reconsider(s,stage,at),"undo")
	check(Hunt.reconsider(s,stage,at) and Hunt.current_beat(s,stage)==3,"intent may change before action")
	check(Hunt.choose(s,stage,at,3,decision),"deliberately select response")
	valid=s.world.snapshot().duplicate(true)
	if exhaustive:
		var other: String=Beats.DECISIONS[stage][1] if decision==Beats.DECISIONS[stage][0] else Beats.DECISIONS[stage][0]
		s.world.event_flags[Hunt.flag(stage,"choice_"+other)]=true
		check(not Hunt.can_enter(s,stage,at),"contradictory choices rejected")
		s.world.restore(valid)
		s.world.story_events[Hunt.IDS[stage]].battle_result="won"
		check(not Hunt.can_enter(s,stage,at),"noncombat event rejects battle receipt")
		s.world.restore(valid)
	for beat in range(4,Beats.count()):
		check(Hunt.current_beat(s,stage)==beat and no_outcome(stage),"outcome waits for exact final acknowledgement")
		reload_same("response")
		if exhaustive: failed_save(func():return Hunt.advance(s,stage,at,beat),"response")
		check(Hunt.advance(s,stage,at,beat),"one acknowledged response")
		after=s.world.snapshot().duplicate(true)
		check(not Hunt.reconsider(s,stage,at) and not Hunt.advance(s,stage,at,beat) and s.world.snapshot()==after,"action cannot rewind or double advance")
	check(Hunt.completed(s,stage) and not Hunt.begin(s,stage,at),"completed story never repeats")
	if stage==1:
		# Preserve coverage of the old v1 save, before the live riot existed.
		s.world.riot.clear()
		s.world.rng.state=int(initial.rng_state)
		check(s.save_world(),"legacy pending HOME story snapshot saved")
	check(gameplay()==initial,"story preserves all gameplay fields")
	reload_same("completed stage")
func scenario(explained: bool, first: String, second: String, last: String) -> void:
	if not check(Fixture.prepare(s,explained),"genuine inquiry source chain"): return
	var historical: Dictionary=s.world.story_events.duplicate(true)
	var exhaustive: bool=first=="confront" and second=="alone" and last=="rescue"
	stage_run(0,first,exhaustive)
	stage_run(1,second,exhaustive)
	stage_run(2,last,exhaustive)
	if not Hunt.completed(s,2): return
	var expected: String=Beats.outcome(last,second=="escort")
	check(s.event_flag_is_set(Hunt.BURNED_FLAG)==(expected=="burned") and s.event_flag_is_set(Hunt.DAMAGED_FLAG)==(expected=="damaged") and s.event_flag_is_set(Hunt.PROTECTED_FLAG)==(expected=="protected"),"three exclusive home outcomes")
	check(s.event_flag_is_set(Hunt.RESCUED_FLAG)==(last=="rescue") and s.event_flag_is_set(Hunt.INJURED_FLAG)==(expected=="damaged"),"player rescue and injury are distinct memories")
	check(s.event_flag_is_set(Hunt.ARSON_FLAG),"arson responsibility is recorded in every branch")
	for key in historical: check(s.world.story_events[key]==historical[key],"historical event preserved")
	if expected=="burned":
		var before: Dictionary=s.world.snapshot().duplicate(true)
		check(not s.enter_home() and not s.home_action_allowed().ok and not s.rest_unlock_allowed().ok and not s.confirm_patrol(s.world.patrol_plan).ok,"burned home rejects all services")
		check(s.world.snapshot()==before,"blocked services preserve exact state")
		failed_save(func():return s.leave_home(),"ruins departure")
	else: check(s.home_services_allowed().ok and s.home_action_allowed().ok,"saved home services remain available")
	var lap: int=s.world.laps
	var serial: int=s.world.map_serial
	var level: int=s.world.contamination
	var roster: Array=s.world.roster.duplicate(true)
	var plan: Dictionary=s.world.patrol_plan.duplicate(true)
	check(s.leave_home() and s.world.laps==lap+1 and s.world.map_serial==serial+1 and s.world.contamination==mini(100,level+7),"next lap proceeds exactly once after every outcome")
	check(s.world.roster==roster and s.world.patrol_plan==plan and Hunt.completed(s,2),"next map preserves roster, plan and story history")
	reload_same("next map")
	check(Hunt.home_burned(s)==(expected=="burned"),"blockade persists after next-lap restart")
	s.world.position=s.world.tiles.find("event")
	s.world.contamination=75
	check(Portal.can_enter(s,s.world.position),"ritual investigation remains playable")
func run() -> void:
	save="user://witch_hunt_%d.json" % OS.get_process_id()
	clean()
	s=Session.new()
	root.add_child(s)
	s.save_file_path=save
	for explained in [true,false]:
		for first in Beats.DECISIONS[0]:
			for second in Beats.DECISIONS[1]:
				for last in Beats.DECISIONS[2]: scenario(explained,first,second,last)
	s.free()
	clean()
	print("WITCH_HUNT_BRANCH: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
