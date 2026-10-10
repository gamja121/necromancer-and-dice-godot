extends SceneTree
## P1-04A. Isolated headless contract tests for the shared story battle API.
const SessionScript = preload("res://systems/run_session.gd")
const StoryEntry = preload("res://systems/story_event_entry.gd")
const StoryBattles = preload("res://systems/story_battle_registry.gd")

class Result:
	extends RefCounted
	var outcome: String
	var units: Array = []
	func _init(winner_id: String) -> void: outcome = winner_id
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed := 0
var failed := 0
var paths: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS story-battle-contract: ",title)
	else:
		failed += 1
		printerr("FAIL story-battle-contract: ",title)

func delete_file(path: String) -> void:
	for ending in ["",".tmp"]:
		if FileAccess.file_exists(path+ending):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+ending))

func fresh_session(suffix: String):
	var s = SessionScript.new()
	root.add_child(s)
	var path: String = "user://story_battle_contract_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	delete_file(path)
	s.save_file_path = path
	s.start_new_world()
	s.world.position = s.world.tiles.find("graveyard")
	check(StoryEntry.begin(s,s.world.position),"isolated discovery saved")
	check(StoryEntry.choose(s,s.world.position,"protect_child"),"isolated choice saved")
	return s

func fight(s) -> bool:
	return s.start_story_encounter(StoryBattles.GRAVEYARD_ID,s.world.position,[s.world.roster[0].id])

func contract_guards() -> void:
	var spec: Dictionary = StoryBattles.definition(StoryBattles.GRAVEYARD_ID)
	check(StoryBattles.valid_definition(spec),"registered spec validates")
	check(spec.encounter_type=="event-graveyard-child","original encounter type preserved")
	check(spec.tiles==["graveyard","event"],"original designated and wildcard tiles preserved")
	check(spec.enemies==["ghoul"],"original single ghoul preserved")
	check(spec.choice=="protect_child","original committed story choice required")
	check(StoryBattles.definition("ritual_portal_trace_01").is_empty(),"unwired ritual remains disabled")
	check(StoryBattles.definition("cultist_altar_encounter_01").is_empty(),"unwired cultist remains disabled")
	check(StoryBattles.definition("nonexistent").is_empty(),"unregistered event has no accidental fallback")
	var altered: Dictionary = StoryBattles.definition(StoryBattles.GRAVEYARD_ID)
	altered.enemies[0] = "goblin-rider"
	altered.tiles.clear()
	check(StoryBattles.definition(StoryBattles.GRAVEYARD_ID).enemies==["ghoul"],"returned contract cannot mutate registry")
	check(StoryBattles.definition(StoryBattles.GRAVEYARD_ID).tiles==["graveyard","event"],"returned tile list cannot mutate registry")
	check(not StoryBattles.valid_definition({}),"missing specification rejected")
	check(not StoryBattles.valid_definition({"event_id":"fake"}),"partial specification rejected")
	var malformed: Dictionary = spec.duplicate(true)
	malformed.enemies = []
	check(not StoryBattles.valid_definition(malformed),"contract without enemies rejected")
	malformed = spec.duplicate(true)
	malformed.encounter_type = "monster"
	check(not StoryBattles.valid_definition(malformed),"story battle requires event namespace")
	malformed = spec.duplicate(true)
	malformed.tiles = []
	check(not StoryBattles.valid_definition(malformed),"no eligible tiles rejected")

func runtime_guards() -> void:
	var s = fresh_session("guards")
	var idx: int = s.world.position
	var state: Dictionary = s.get_story_event(StoryBattles.GRAVEYARD_ID)
	var spec: Dictionary = StoryBattles.definition(StoryBattles.GRAVEYARD_ID)
	check(StoryBattles.can_start(s.world,state,idx,spec),"valid story context eligible")
	check(not StoryBattles.can_start(s.world,state,idx+1,spec),"noncurrent tile blocked")
	check(not StoryBattles.can_start(s.world,state,idx,{}),"empty event spec blocked")
	check(not s.start_story_encounter("ritual_portal_trace_01",idx,[s.world.roster[0].id]),"ritual cannot start without registration")
	check(not s.start_story_encounter("cultist_altar_encounter_01",idx,[s.world.roster[0].id]),"cultist cannot start without registration")
	check(not s.story_battle_result_pending("ritual_portal_trace_01"),"unknown event cannot open battle result")
	check(not s.acknowledge_story_battle_result("cultist_altar_encounter_01"),"unknown event cannot acknowledge")
	s.world.tiles[idx] = "village"
	check(not s.start_story_encounter(StoryBattles.GRAVEYARD_ID,idx,[s.world.roster[0].id]),"nonmatching tile blocked")
	s.world.tiles[idx] = "graveyard"
	s.world.story_events[StoryBattles.GRAVEYARD_ID].choice = "leave"
	check(not s.start_story_encounter(StoryBattles.GRAVEYARD_ID,idx,[s.world.roster[0].id]),"wrong choice blocked")
	s.world.story_events[StoryBattles.GRAVEYARD_ID].choice = "protect_child"
	check(fight(s),"registered event starts through generic route")
	check(s.encounter.type==spec.encounter_type and s.encounter.event_id==spec.event_id,"checkpoint metadata uses registry")
	var before: Dictionary = s.world.snapshot().duplicate(true)
	s.encounter.event_id = "unknown"
	check(not s.finish_encounter(Result.new("ally")),"unknown event context rejected on finish")
	check(s.world.snapshot()==before,"unknown context cannot consume monsters/flags")
	s.encounter.event_id = StoryBattles.GRAVEYARD_ID
	s.encounter.type = "event-mismatched"
	check(not s.finish_encounter(Result.new("ally")),"mismatched registered event type rejected")
	check(s.world.snapshot()==before,"mismatched context cannot mutate world")
	s.encounter.type = spec.encounter_type
	check(s.finish_encounter(Result.new("ally")),"corrected context completes")
	check(s.story_battle_result_pending(StoryBattles.GRAVEYARD_ID),"generic result gate accepts completed rescue")
	s.reload_world()
	check(s.story_battle_result_pending(StoryBattles.GRAVEYARD_ID),"generic result survives reload")
	check(s.acknowledge_story_battle_result(StoryBattles.GRAVEYARD_ID),"generic acknowledgement commits")
	check(not s.graveyard_battle_result_pending(),"old UI wrapper sees acknowledged result")
	check(s.get_story_event(StoryBattles.GRAVEYARD_ID).battle_result=="won","generic acknowledgement preserves win")
	s.free()

func loss_and_rollback() -> void:
	var s = fresh_session("lost")
	check(fight(s),"registered encounter before loss")
	check(s.finish_encounter(Result.new("enemy")),"generic loss recorded")
	check(s.story_battle_result_pending(StoryBattles.GRAVEYARD_ID),"generic result sees loss")
	check(s.acknowledge_story_battle_result(StoryBattles.GRAVEYARD_ID),"loss acknowledged")
	check(not s.story_battle_result_pending(StoryBattles.GRAVEYARD_ID),"loss result consumed")
	check(fight(s),"loss can still retry from registry")
	check(s.get_story_event(StoryBattles.GRAVEYARD_ID).battle_result.is_empty(),"retry reset previous result")
	check(s.finish_encounter(Result.new("ally")),"retry can win")
	var prior: Dictionary = s.world.snapshot().duplicate(true)
	var original_path: String = s.save_file_path
	s.save_file_path = "user://story_battle_contract_missing_%d/x.json" % OS.get_process_id()
	check(not s.acknowledge_story_battle_result(StoryBattles.GRAVEYARD_ID),"generic acknowledgement reports disk error")
	check(s.world.snapshot()==prior,"generic acknowledgement rolls back disk failure")
	check(s.graveyard_battle_result_pending(),"failed acknowledgement leaves result pending")
	s.save_file_path = original_path
	check(s.acknowledge_story_battle_result(StoryBattles.GRAVEYARD_ID),"generic acknowledgement retries cleanly")
	s.reload_world()
	check(not s.story_battle_result_pending(StoryBattles.GRAVEYARD_ID),"generic ack durable across restart")
	s.free()

func _run() -> void:
	contract_guards()
	runtime_guards()
	loss_and_rollback()
	for path in paths: delete_file(path)
	print("STORY_BATTLE_CONTRACT_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
