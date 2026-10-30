extends SceneTree
const Session=preload("res://systems/run_session.gd")
const Fixture=preload("res://scripts/cultist_mistrust_fixture.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")
const Beats=preload("res://systems/cultist_altar_beats.gd")
const Mistrust=preload("res://systems/village_mistrust_entry.gd")
const RumorBeats=preload("res://systems/village_mistrust_beats.gd")
const Portal=preload("res://systems/ritual_portal_entry.gd")
var passed: int=0
var failed: int=0
var save: String
var s: Node

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> bool:
	if ok: passed+=1; print("PASS cultist-mistrust: ",label)
	else: failed+=1; printerr("FAIL cultist-mistrust: ",label)
	return ok
func clean() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))
func gameplay() -> Dictionary:
	var snapshot: Dictionary=s.world.snapshot()
	var result: Dictionary={}
	for key in ["rng_seed","rng_state","roster","reward_receipts","dice_cards","prophecy","last_prophecy","last_face","active_encounter","pending_reward","next_serial","enemies_defeated"]:
		result[key]=snapshot[key].duplicate(true) if snapshot[key] is Array or snapshot[key] is Dictionary else snapshot[key]
	return result
func absent() -> bool:
	return not s.event_flag_is_set(Altar.COOPERATION_WITNESSED_FLAG) and not s.event_flag_is_set(Altar.MISTRUST_PENDING_FLAG) and not s.event_flag_is_set(Mistrust.DISTRUST_FLAG)
func reload_same(label: String) -> void:
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.reload_world()
	check(s.world.snapshot()==before,label+": exact JSON restart")
func failed_save(call: Callable, label: String) -> void:
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path="user://cultist_mistrust_missing_%d/save.json" % OS.get_process_id()
	check(not call.call() and s.world.snapshot()==before,label+": full rollback")
	s.save_file_path=save

func scenario() -> void:
	if not check(Fixture.prepare(s),"genuine leave -> prophet -> cultist tracking chain"): return
	var at: int=s.world.position
	var initial: Dictionary=gameplay()
	var valid: Dictionary=s.world.snapshot().duplicate(true)
	for key in [Altar.COOPERATION_WITNESSED_FLAG,Altar.MISTRUST_PENDING_FLAG]:
		s.world.event_flags[key]=true
		check(not Altar.choose(s,at,2,"infiltrate"),"stray consequence receipt cannot accept a trapped intent")
		s.world.restore(valid)
	s.world.event_flags[Fixture.Prophet.COMPLETE_FLAG]=false
	check(not Altar.can_infiltrate(s) and not Altar.choose(s,at,2,"infiltrate"),"incomplete clue source cannot unlock new choice")
	s.world.restore(valid)
	failed_save(func():return Altar.choose(s,at,2,"infiltrate"),"choice")
	check(Altar.choose(s,at,2,"infiltrate") and absent(),"intent alone creates no consequence")
	failed_save(func():return Altar.reconsider(s,at),"undo")
	check(Altar.reconsider(s,at) and absent(),"intent can be undone before action")
	check(Altar.choose(s,at,2,"pass") and Altar.reconsider(s,at),"original pass remains selectable")
	check(Altar.choose(s,at,2,"infiltrate"),"covert investigation deliberately selected")
	valid=s.world.snapshot().duplicate(true)
	for key in [Altar.PASS_FLAG,Altar.BATTLE_WON_FLAG,Altar.infiltration_progress_flag(2),"event:%s:infiltration:beat:99" % Altar.EVENT_ID]:
		s.world.event_flags[key]=true
		check(not Altar.can_enter(s,at),"contradictory or skipped receipt rejected: "+key)
		s.world.restore(valid)
	check(not Altar.finish(s,at),"intent cannot skip actual investigation")
	for beat in range(Beats.infiltration_count()-1):
		failed_save(func():return Altar.advance_infiltration(s,at,beat),"infiltration "+str(beat))
		check(Altar.advance_infiltration(s,at,beat),"explicit action "+str(beat))
		var after: Dictionary=s.world.snapshot().duplicate(true)
		check(not Altar.reconsider(s,at) and not Altar.advance_infiltration(s,at,beat) and s.world.snapshot()==after,"performed action cannot be undone or double advanced")
		check(absent(),"consequence waits for final acknowledgement")
		reload_same("investigation "+str(beat))
	failed_save(func():return Altar.finish(s,at),"investigation Finish")
	check(Altar.finish(s,at) and Altar.completed(s),"noncombat Finish commits ritual tracking")
	check(s.event_flag_is_set(Altar.COOPERATION_WITNESSED_FLAG) and s.event_flag_is_set(Mistrust.PENDING_FLAG) and not s.event_flag_is_set(Mistrust.DISTRUST_FLAG),"witness queues first later rumor")
	check(s.get_story_event(Altar.EVENT_ID).battle_result=="" and s.encounter.is_empty(),"no invented battle result")
	check(gameplay()==initial,"investigation preserves dice, RNG, roster and rewards")
	reload_same("completed investigation")
	# The modern board has no hill before discovery; use the real story wildcard.
	s.world.position=s.world.tiles.find("event")
	s.world.contamination=75
	check(Portal.can_enter(s,s.world.position),"ritual investigation remains playable")
	s.world.position=at
	check(not Mistrust.can_enter(s,at),"generic event is not a village consequence")
	var village: int=s.world.tiles.find("village")
	check(not Mistrust.can_enter(s,village),"remote village preview blocked")
	s.world.position=village
	s.world.contamination=0
	check(Mistrust.can_enter(s,village),"no invented contamination threshold for a delayed consequence")
	valid=s.world.snapshot().duplicate(true)
	for key in [Mistrust.progress_flag(2),"event:%s:beat:99" % Mistrust.EVENT_ID]:
		s.world.event_flags[key]=true
		check(not Mistrust.begin(s,village),"malformed rumor checkpoint rejected")
		s.world.restore(valid)
	for field in ["pending_move","pending_reward","active_encounter"]:
		s.world.set(field,{"test":true})
		check(not Mistrust.can_enter(s,village),"unfinished operation blocks rumor: "+field)
		s.world.restore(valid)
	s.world.story_events[Altar.EVENT_ID].choice="pass"
	check(not Mistrust.begin(s,village),"isolated consequence flags cannot replace actual altar choice")
	s.world.restore(valid)
	failed_save(func():return Mistrust.begin(s,village),"rumor discovery")
	check(Mistrust.begin(s,village),"village rumor discovered")
	var rumor_gameplay: Dictionary=gameplay()
	for beat in range(RumorBeats.count()):
		check(Mistrust.current_beat(s)==beat and not s.event_flag_is_set(Mistrust.DISTRUST_FLAG),"exact uncommitted rumor checkpoint "+str(beat))
		reload_same("rumor "+str(beat))
		failed_save(func():return Mistrust.advance(s,village,beat),"rumor acknowledgement "+str(beat))
		check(Mistrust.advance(s,village,beat),"rumor step "+str(beat))
	check(Mistrust.completed(s) and s.event_flag_is_set(Mistrust.DISTRUST_FLAG) and not s.event_flag_is_set(Mistrust.PENDING_FLAG),"only final acknowledgement commits distrust")
	check(gameplay()==rumor_gameplay,"rumor preserves RNG, dice and rewards")
	reload_same("final distrust")
	var after: Dictionary=s.world.snapshot().duplicate(true)
	check(not Mistrust.begin(s,village) and not Mistrust.advance(s,village,RumorBeats.count()-1),"consequence cannot repeat")
	check(Altar.finish(s,at) and s.world.snapshot()==after,"historical Finish cannot requeue rumor")
	check(s.get_story_event("monster_hunter_encounter_01").status=="unseen","hunter history remains untouched")
	s.world.position=s.world.tiles.find("event")
	s.world.contamination=75
	check(Portal.can_enter(s,s.world.position),"distrust does not erase investigation")

func hunter_guard() -> void:
	s.start_new_world()
	s.world.contamination=93
	s.world.lap_ready=true
	s.world.leave_home()
	# A compatible saved hunter history remains a distinct original route.
	s.world.story_events["monster_hunter_encounter_01"]={"status":"complete","choice":"","battle_result":""}
	for flag in ["event:monster_hunter_encounter_01:complete","quest:contamination_hunter_01:complete",Fixture.Cultist.HUMAN_CLUE_FLAG,Fixture.Cultist.COMPLETE_FLAG,Fixture.Cultist.SEEN_FLAG,Fixture.Cultist.TRACKING_FLAG]:
		s.world.event_flags[flag]=true
	s.world.story_events[Fixture.Cultist.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	var at: int=s.world.tiles.find("event")
	s.world.position=at
	check(Fixture.Cultist.route(s)=="hunter" and Altar.begin(s,at) and Altar.advance(s,at,0) and Altar.advance(s,at,1),"original hunter route reaches its altar decision")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	check(not Altar.can_infiltrate(s) and not Altar.choose(s,at,2,"infiltrate") and s.world.snapshot()==before,"hunter route cannot take prophet-only option")
	check(Altar.choose(s,at,2,"pass") and Altar.finish(s,at) and Altar.completed(s),"original hunter pass still completes")
	s.world.position=s.world.tiles.find("village")
	s.world.event_flags[Mistrust.PENDING_FLAG]=true
	s.world.event_flags[Mistrust.WITNESS_FLAG]=true
	check(not Mistrust.begin(s,s.world.position),"witness flags alone cannot turn a pass into mistrust")

func run() -> void:
	save="user://cultist_mistrust_%d.json" % OS.get_process_id()
	clean()
	s=Session.new()
	root.add_child(s)
	s.save_file_path=save
	scenario()
	hunter_guard()
	s.free()
	clean()
	print("CULTIST_MISTRUST_BRANCH: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
