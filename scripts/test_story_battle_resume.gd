extends SceneTree
## P1-04C: real Rules checkpoint and story return interruption regression.
## Uses only isolated disposable user:// saves.
const SessionScript = preload("res://systems/run_session.gd")
const StoryEntry = preload("res://systems/story_event_entry.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const Registry = preload("res://systems/story_battle_registry.gd")

class BattleResult:
	extends RefCounted
	var result: String
	var units: Array = []
	func _init(value: String) -> void: result=value
	func winner() -> String: return result
	func find_id(_id: String) -> Dictionary: return {}

var ok: int = 0
var errors: int = 0
var paths: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func check(value: bool, what: String) -> void:
	if value:
		ok+=1
		print("PASS story-resume: ",what)
	else:
		errors+=1
		printerr("FAIL story-resume: ",what)

func delete(path: String) -> void:
	for ending in ["",".tmp"]:
		if FileAccess.file_exists(path+ending):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+ending))

func setup(suffix: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path="user://story_resume_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	delete(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.position=s.world.tiles.find("graveyard")
	check(StoryEntry.begin(s,s.world.position),"first discovery")
	check(StoryEntry.choose(s,s.world.position,"protect_child"),"rescue choice stored")
	check(s.start_story_encounter(Registry.GRAVEYARD_ID,s.world.position,[s.world.roster[0].id]),"encounter created")
	return s

func load_rules(s):
	var r=Rules.new(s.world.definitions)
	check(r.restore(s.encounter.checkpoint),"actual combat rules resume")
	return r

func snapshot_matches(s) -> bool:
	return s.encounter == s.world.active_encounter

func test_all_phases() -> void:
	var s=setup("phases")
	var r=load_rules(s)
	var start_snapshot: Dictionary=s.world.snapshot().duplicate(true)
	check(s.encounter.phase=="ready","battle begins ready")
	check(not s.checkpoint_battle(r,"rolled"),"invalid rolled checkpoint rejected")
	check(not s.checkpoint_battle(r,"actions"),"actions cannot precede a die roll")
	check(not s.checkpoint_battle(r,"invalid"),"unknown checkpoint phase rejected")
	check(not s.checkpoint_battle(r,"ready"),"duplicate ready checkpoint rejected")
	check(s.world.snapshot()==start_snapshot,"invalid checkpoint attempts do not change world")
	var rolled: Dictionary=s.prepare_battle_roll(r)
	check(rolled.get("ok",false),"original die-roll session path succeeds")
	check(s.encounter.phase=="rolled","rolled phase is durable")
	check(int(s.encounter.roll.face)>=1 and int(s.encounter.roll.face)<=6,"die face saved")
	check(snapshot_matches(s),"encounter checkpoint matches serialized world after roll")
	check(not s.prepare_battle_roll(r).get("ok",false),"duplicate roll is rejected")
	s.reload_world()
	check(s.encounter.phase=="rolled","restart restores rolled phase")
	check(s.encounter.event_id==Registry.GRAVEYARD_ID,"restarted fight keeps story identity")
	check(not s.graveyard_battle_result_pending(),"mid-round load does not launch result modal")
	r=load_rules(s)
	r.begin_round(int(s.encounter.roll.face))
	check(s.checkpoint_battle(r,"actions"),"rolled to actions checkpoint accepted")
	check(s.encounter.phase=="actions","action phase saved")
	s.reload_world()
	check(s.encounter.phase=="actions","actions resume after restart")
	r=load_rules(s)
	check(r.round_number>=1,"round details survive reload")
	check(snapshot_matches(s),"world has same action checkpoint")
	r=load_rules(s)
	var first: Dictionary=r.next_action()
	check(s.checkpoint_battle(r,"actions"),"individual action progress checkpoint saved")
	check(snapshot_matches(s),"action progress copied into persistent encounter")
	s.reload_world()
	check(s.encounter.phase=="actions","individual action progress survives reload")
	r=load_rules(s)
	if r.winner().is_empty():
		check(s.checkpoint_battle(r,"ready"),"actions may checkpoint next turn")
		check(s.encounter.phase=="ready","next turn becomes ready")
		s.reload_world()
		check(s.encounter.phase=="ready","new ready phase survives reload")
	else:
		check(not s.encounter.checkpoint.is_empty(),"finished round has valid checkpoint")
	check(not s.graveyard_battle_result_pending(),"unfinished battle cannot masquerade as result")
	s.free()

func test_disk_failures() -> void:
	var s=setup("io")
	var r=load_rules(s)
	var good_path: String=s.save_file_path
	var denied: String="user://story_resume_no_directory_%d/no.json" % OS.get_process_id()
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var original_rules: Dictionary=r.snapshot().duplicate(true)
	s.save_file_path=denied
	check(not s.prepare_battle_roll(r).get("ok",false),"roll save error reported")
	check(s.world.snapshot()==before,"failed roll restores all session fields")
	check(r.snapshot()==original_rules,"failed roll restores random generator and Rules")
	check(snapshot_matches(s),"failed roll retains single encounter checkpoint")
	s.save_file_path=good_path
	check(s.prepare_battle_roll(r).get("ok",false),"rolled phase retries after disk recovery")
	before=s.world.snapshot().duplicate(true)
	s.save_file_path=denied
	r.begin_round(int(s.encounter.roll.face))
	check(not s.checkpoint_battle(r,"actions"),"actions checkpoint save error reported")
	check(s.world.snapshot()==before,"failed actions checkpoint restores phase and face")
	check(r.snapshot()==s.encounter.checkpoint,"failed checkpoint restores Rules to persisted snapshot")
	s.save_file_path=good_path
	r.begin_round(int(s.encounter.roll.face))
	check(s.checkpoint_battle(r,"actions"),"retry actions checkpoint after disk recovery")
	before=s.world.snapshot().duplicate(true)
	s.save_file_path=denied
	check(not s.checkpoint_battle(r,"ready"),"end-of-turn save error reported")
	check(s.world.snapshot()==before,"failed ready transition restores actions state")
	check(r.snapshot()==s.encounter.checkpoint,"ready failure preserves action Rules")
	s.save_file_path=good_path
	check(s.checkpoint_battle(r,"ready"),"ready transition retries")
	check(s.encounter.phase=="ready","recovered battle may continue")
	s.free()

func test_pending_receipt_and_retry() -> void:
	var s=setup("receipt")
	var idx: int=s.world.position
	check(s.finish_encounter(BattleResult.new("enemy")),"loss outcome committed")
	check(s.graveyard_battle_result_pending(),"loss receipt is unacknowledged")
	var prior: Dictionary=s.world.snapshot().duplicate(true)
	check(not s.start_story_encounter(Registry.GRAVEYARD_ID,idx,[s.world.roster[0].id]),"cannot start retry before acknowledging loss")
	check(not Registry.can_start(s.world,s.get_story_event(Registry.GRAVEYARD_ID),idx,Registry.definition(Registry.GRAVEYARD_ID)),"registration gate blocks premature retry")
	check(s.world.snapshot()==prior,"failed retry leaves original loss receipt intact")
	check(s.encounter.is_empty(),"failed retry cannot secretly create battle")
	s.reload_world()
	check(s.graveyard_battle_result_pending(),"interrupted loss remains pending after reload")
	check(not s.start_story_encounter(Registry.GRAVEYARD_ID,idx,[s.world.roster[0].id]),"reload cannot bypass receipt")
	check(s.get_story_event(Registry.GRAVEYARD_ID).battle_result=="lost","loss history preserved")
	var correct_path: String=s.save_file_path
	s.save_file_path="user://story_resume_no_directory_%d/no.json" % OS.get_process_id()
	check(not s.acknowledge_story_battle_result(Registry.GRAVEYARD_ID),"ack save failure blocks dismissal")
	check(not s.start_story_encounter(Registry.GRAVEYARD_ID,idx,[s.world.roster[0].id]),"failed acknowledgement still blocks retry")
	check(s.graveyard_battle_result_pending(),"failed ack preserves result for player")
	s.save_file_path=correct_path
	check(s.acknowledge_story_battle_result(Registry.GRAVEYARD_ID),"acknowledge commits")
	check(not s.graveyard_battle_result_pending(),"confirmed loss no longer pending")
	check(s.start_story_encounter(Registry.GRAVEYARD_ID,idx,[s.world.roster[0].id]),"deliberate retry begins after acknowledgement")
	check(s.get_story_event(Registry.GRAVEYARD_ID).battle_result.is_empty(),"new combat clears prior attempt result")
	check(s.finish_encounter(BattleResult.new("ally")),"retry victory commits")
	check(s.story_battle_result_pending(Registry.GRAVEYARD_ID),"new victory creates new receipt")
	check(not s.start_story_encounter(Registry.GRAVEYARD_ID,idx,[s.world.roster[0].id]),"complete event cannot restart")
	s.reload_world()
	check(s.story_battle_result_pending(Registry.GRAVEYARD_ID),"victory receipt survives reload")
	check(s.acknowledge_story_battle_result(Registry.GRAVEYARD_ID),"victory acknowledged")
	check(s.story_battle_presentation(Registry.GRAVEYARD_ID).is_empty(),"acknowledged result no longer shown")
	s.free()

func test_unregistered_and_normal_guards() -> void:
	var s=setup("unexpected")
	var idx: int=s.world.position
	var before: Dictionary=s.world.snapshot().duplicate(true)
	check(not s.start_story_encounter("ritual_portal_trace_01",idx,[s.world.roster[0].id]),"unsupported ritual cannot activate")
	check(not s.start_story_encounter("cultist_altar_encounter_01",idx,[s.world.roster[0].id]),"unsupported cultist cannot activate")
	check(s.world.snapshot()==before,"unsupported requests do not alter encounter")
	check(not s.story_battle_result_pending(Registry.GRAVEYARD_ID),"no result while battle open")
	check(not s.finish_encounter(BattleResult.new("")),"unresolved battle cannot finish")
	check(snapshot_matches(s),"unresolved battle still present")
	s.free()

func _run() -> void:
	test_all_phases()
	test_disk_failures()
	test_pending_receipt_and_retry()
	test_unregistered_and_normal_guards()
	for path in paths: delete(path)
	print("STORY_RESUME_REGRESSION: %d passed, %d failed" % [ok,errors])
	quit(0 if errors==0 else 1)
