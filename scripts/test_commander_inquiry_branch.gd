extends SceneTree
const Session=preload("res://systems/run_session.gd")
const Fixture=preload("res://scripts/cultist_mistrust_fixture.gd")
const Inquiry=preload("res://systems/commander_inquiry_entry.gd")
const Beats=preload("res://systems/commander_inquiry_beats.gd")
const Mistrust=preload("res://systems/village_mistrust_entry.gd")
const Portal=preload("res://systems/ritual_portal_entry.gd")
var passed: int=0
var failed: int=0
var save: String
var s: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> bool:
	if ok: passed+=1; print("PASS commander-inquiry: ",label)
	else: failed+=1; printerr("FAIL commander-inquiry: ",label)
	return ok
func clean() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))
func failed_save(call: Callable, label: String) -> void:
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path="user://inquiry_missing_%d/save.json" % OS.get_process_id()
	check(not call.call() and s.world.snapshot()==before,label+": full save rollback")
	s.save_file_path=save
func reload_same(label: String) -> void:
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.reload_world()
	check(s.world.snapshot()==before,label+": exact JSON restart")
func gameplay() -> Dictionary:
	var state: Dictionary=s.world.snapshot().duplicate(true)
	state.erase("story_events")
	state.erase("event_flags")
	return state
func outcomes_absent() -> bool:
	for key in [Inquiry.COMPLETE_FLAG,Inquiry.TESTIMONY_FLAG,Inquiry.DEFERRED_FLAG,Inquiry.WITHHELD_FLAG,Inquiry.WATCH_FLAG,Inquiry.ESCALATED_FLAG]:
		if s.event_flag_is_set(key): return false
	return true
func scenario(decision: String) -> void:
	if not check(Fixture.prepare_mistrust(s),"genuine source chain completes first mistrust "+decision): return
	var at: int=s.world.position
	check(not Inquiry.begin(s,at),"same visit cannot chain inquiry after rumor")
	var old: Dictionary=s.world.snapshot().duplicate(true)
	s.world.map_serial+=1
	check(Inquiry.can_enter(s,at),"next map visit differs even with same movement serial")
	s.world.restore(old)
	s.world.move_serial+=1
	s.world.contamination=0
	# Normalize the existing low-corruption boss layout before comparison.
	# Restart/rollback correctly removes a boss left by the high-level fixture.
	check(s.world.conceal_boss_below_threshold(),"low-corruption fixture normalized")
	check(s.save_world() and Inquiry.can_enter(s,at),"later village visit has no invented contamination threshold")
	var original_events: Dictionary=s.world.story_events.duplicate(true)
	var original_flags: Dictionary=s.world.event_flags.duplicate(true)
	var initial: Dictionary=gameplay()
	var valid: Dictionary=s.world.snapshot().duplicate(true)
	for key in [Inquiry.COMPLETE_FLAG,Inquiry.EXPLAIN_FLAG,Inquiry.WITHHOLD_FLAG,Inquiry.WATCH_FLAG,Inquiry.progress_flag(2),"event:%s:beat:99" % Inquiry.EVENT_ID,"event:%s:beat:01" % Inquiry.EVENT_ID]:
		s.world.event_flags[key]=true
		check(not Inquiry.begin(s,at),"stray or malformed receipt rejected: "+key)
		s.world.restore(valid)
	for field in ["pending_move","pending_reward","active_encounter"]:
		s.world.set(field,{"test":true})
		check(not Inquiry.can_enter(s,at),"in-flight operation blocks entry: "+field)
		s.world.restore(valid)
	s.encounter={"test":true}
	check(not Inquiry.can_enter(s,at),"session battle blocks entry")
	s.encounter={}
	s.world.run_result={"status":"defeat"}
	check(not Inquiry.can_enter(s,at),"finished run blocks inquiry")
	s.world.restore(valid)
	s.world.position=s.world.tiles.find("event")
	check(not Inquiry.can_enter(s,s.world.position) and not Inquiry.can_enter(s,at),"generic event and remote village are not valid arrivals")
	s.world.restore(valid)
	for key in [Mistrust.COMPLETE_FLAG,Mistrust.DISTRUST_FLAG,Fixture.Altar.COOPERATION_WITNESSED_FLAG,Fixture.Prophet.COMPLETE_FLAG]:
		s.world.event_flags[key]=false
		check(not Inquiry.begin(s,at),"full source provenance required: "+key)
		s.world.restore(valid)
	s.world.story_events[Fixture.Altar.EVENT_ID].choice="pass"
	check(not Inquiry.begin(s,at),"original pass cannot inherit covert consequences")
	s.world.restore(valid)
	failed_save(func():return Inquiry.begin(s,at),"arrival")
	check(Inquiry.begin(s,at),"arrival deliberately discovered")
	var after: Dictionary=s.world.snapshot().duplicate(true)
	check(Inquiry.begin(s,at) and s.world.snapshot()==after,"resume begin is idempotent")
	for beat in range(2):
		reload_same("opening "+str(beat))
		failed_save(func():return Inquiry.advance(s,at,beat),"opening "+str(beat))
		check(Inquiry.advance(s,at,beat),"one explicit opening checkpoint")
		after=s.world.snapshot().duplicate(true)
		check(not Inquiry.advance(s,at,beat) and s.world.snapshot()==after,"stale opening callback cannot advance twice")
	check(not Inquiry.advance(s,at,2) and not Inquiry.choose(s,at,2,"fight") and not Inquiry.choose(s,at,1,decision),"question requires valid deliberate choice")
	failed_save(func():return Inquiry.choose(s,at,2,decision),"response intent")
	check(Inquiry.choose(s,at,2,decision) and outcomes_absent(),"intent alone commits no outcome")
	failed_save(func():return Inquiry.reconsider(s,at),"reconsider")
	check(Inquiry.reconsider(s,at) and Inquiry.current_beat(s)==2 and outcomes_absent(),"choice can change before account acknowledged")
	var alternate: String="withhold" if decision=="explain" else "explain"
	check(Inquiry.choose(s,at,2,alternate) and Inquiry.reconsider(s,at) and Inquiry.choose(s,at,2,decision),"both responses remain selectable before commitment")
	valid=s.world.snapshot().duplicate(true)
	for key in [Inquiry.EXPLAIN_FLAG if decision=="withhold" else Inquiry.WITHHOLD_FLAG,Inquiry.COMPLETE_FLAG,Inquiry.WATCH_FLAG,Inquiry.progress_flag(5)]:
		s.world.event_flags[key]=true
		check(not Inquiry.can_enter(s,at),"contradictory active receipt rejected: "+key)
		s.world.restore(valid)
	s.world.story_events[Inquiry.EVENT_ID].battle_result="won"
	check(not Inquiry.can_enter(s,at),"noncombat account cannot invent battle result")
	s.world.restore(valid)
	for beat in range(3,Beats.count()):
		check(Inquiry.current_beat(s)==beat and outcomes_absent(),"exact uncommitted response checkpoint "+str(beat))
		reload_same("response "+str(beat))
		failed_save(func():return Inquiry.advance(s,at,beat),"response acknowledgement "+str(beat))
		check(Inquiry.advance(s,at,beat),"explicit response acknowledgement "+str(beat))
		after=s.world.snapshot().duplicate(true)
		check(not Inquiry.reconsider(s,at) and not Inquiry.advance(s,at,beat) and s.world.snapshot()==after,"acknowledged account cannot rewind or double advance")
	check(Inquiry.completed(s) and s.get_story_event(Inquiry.EVENT_ID).choice==decision,"final acknowledgement alone completes "+decision)
	check(s.event_flag_is_set(Inquiry.TESTIMONY_FLAG)==(decision=="explain") and s.event_flag_is_set(Inquiry.DEFERRED_FLAG)==(decision=="explain"),"explained account and deferred judgment are exclusive")
	check(s.event_flag_is_set(Inquiry.WITHHELD_FLAG)==(decision=="withhold") and s.event_flag_is_set(Inquiry.WATCH_FLAG)==(decision=="withhold") and s.event_flag_is_set(Inquiry.ESCALATED_FLAG)==(decision=="withhold"),"withheld account alone escalates watch and distrust")
	var final_gameplay: Dictionary=gameplay()
	for key in initial:
		if final_gameplay[key]!=initial[key]: printerr("DIFF gameplay: ",key," ",initial[key]," => ",final_gameplay[key])
	check(final_gameplay==initial,"RNG, roster, dice, rewards, movement and schema untouched")
	for key in original_events: check(s.world.story_events[key]==original_events[key],"historical story unchanged: "+str(key))
	for key in original_flags:
		if s.world.event_flags[key]!=original_flags[key]: check(false,"historical flag changed: "+str(key))
	reload_same("completed inquiry")
	check(not Inquiry.begin(s,at),"completed event never repeats")
	check(s.place_allowed(at,"village").ok and s.place_allowed(s.world.tiles.find("home"),"home").ok,"village and HOME features remain available")
	s.world.position=s.world.tiles.find("event")
	s.world.contamination=75
	check(Portal.can_enter(s,s.world.position),"ritual investigation remains playable after "+decision)
func legacy_guard() -> void:
	if not check(Fixture.prepare_mistrust(s),"legacy source prepared"): return
	var at: int=s.world.position
	s.world.event_flags.erase(Mistrust.finished_visit_flag(s,at))
	check(Inquiry.can_enter(s,at),"older complete save without visit marker remains eligible at next actual arrival")
	s.world.story_events[Mistrust.EVENT_ID].status="seen"
	check(not Inquiry.begin(s,at),"complete flags cannot replace acknowledged rumor state")
func run() -> void:
	save="user://commander_inquiry_%d.json" % OS.get_process_id()
	clean()
	s=Session.new()
	root.add_child(s)
	s.save_file_path=save
	for decision in ["explain","withhold"]: scenario(decision)
	legacy_guard()
	s.free()
	clean()
	print("COMMANDER_INQUIRY_BRANCH: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
