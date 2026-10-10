extends SceneTree
## P1-03C: real Godot Rules checkpoint with isolated saves and simulated results.
## No production user://map_run_v1.json file is touched.
const SessionScript = preload("res://systems/run_session.gd")
const StoryEntry = preload("res://systems/story_event_entry.gd")
const Rules = preload("res://systems/battlefield_rules.gd")

class BattleResult:
	extends RefCounted
	var outcome: String
	var units: Array = []
	func _init(value: String) -> void: outcome = value
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int = 0
var failures: int = 0
var paths: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS graveyard-combat: ",label)
	else:
		failures += 1
		printerr("FAIL graveyard-combat: ",label)

func _clear(path: String) -> void:
	for ending in ["",".tmp"]:
		var p: String = path+ending
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _make(suffix: String):
	var session = SessionScript.new()
	root.add_child(session)
	var path: String = "user://graveyard_combat_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	_clear(path)
	session.save_file_path = path
	session.start_new_world()
	session.world.position = session.world.tiles.find("graveyard")
	_check(session.has_save(),"isolated save exists")
	_check(StoryEntry.begin(session,session.world.position),"first discovery persisted")
	_check(StoryEntry.choose(session,session.world.position,"protect_child"),"protect action committed")
	return session

func _ids(session, count: int) -> Array:
	while session.world.roster.size() < count:
		var unit: Dictionary = session.world.roster[0].duplicate(true)
		unit["id"] = "test-owned-%d" % session.world.roster.size()
		session.world.roster.append(unit)
	var ids: Array = []
	for i in range(count): ids.append(session.world.roster[i].id)
	return ids

func _test_party_count(count: int) -> void:
	var session = _make("party_%d" % count)
	var idx: int = session.world.position
	var ids: Array = _ids(session,count)
	_check(session.start_story_encounter(StoryEntry.EVENT_ID,idx,ids),"party of %d can start story battle" % count)
	_check(session.encounter.get("type","") == "event-graveyard-child","dedicated story encounter type")
	_check(session.encounter.get("event_id","") == StoryEntry.EVENT_ID,"event ID saved in encounter context")
	_check(session.encounter.allies.size() == count,"only deliberately selected allies deployed")
	_check(session.encounter.enemies.size() == 1 and session.encounter.enemies[0].slug == "ghoul","single ghoul opponent")
	_check(session.encounter.get("phase","")=="ready","battle begins at ready phase")
	_check(session.get_story_event(StoryEntry.EVENT_ID).status=="active","story incomplete before combat")
	_check(not session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"entry never claims rescue")
	_check(not session.start_story_encounter(StoryEntry.EVENT_ID,idx,ids),"cannot double-start an active fight")
	var restored_rules = Rules.new(session.world.definitions)
	_check(restored_rules.restore(session.encounter.checkpoint),"saved fight checkpoint restores in actual battle rules")
	session.reload_world()
	_check(session.encounter.get("event_id","") == StoryEntry.EVENT_ID,"encounter context survives reload")
	_check(session.encounter.allies.size() == count,"selected lineup survives reload")
	_check(session.encounter.enemies.size() == 1,"ghoul survives reload")
	_check(session.finish_encounter(BattleResult.new("ally")),"story fight winner commits")
	_check(session.get_story_event(StoryEntry.EVENT_ID).status=="complete","victory completes graveyard event")
	_check(session.get_story_event(StoryEntry.EVENT_ID).battle_result=="won","victory stored in event history")
	_check(session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"rescue success only after victory")
	_check(session.event_flag_is_set("event:graveyard_child_ambush_01:complete"),"completion flag set on win")
	_check(not session.event_flag_is_set("event:graveyard_child_ambush_01:abandoned"),"rescue never marks abandoned")
	_check(session.world.pending_reward.is_empty(),"event ghoul does not trigger ordinary capture reward")
	_check(not idx in session.world.cleared,"event never clears unrelated monster tile")
	_check(not session.start_story_encounter(StoryEntry.EVENT_ID,idx,ids),"finished story cannot restart")
	session.reload_world()
	_check(session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"rescued state survives full reload")
	_check(session.encounter.is_empty(),"finished encounter clears checkpoint")
	session.free()

func _test_guards() -> void:
	var s = _make("guards")
	var idx: int = s.world.position
	var ids: Array = _ids(s,5)
	_check(not s.start_story_encounter("unknown",idx,ids.slice(0,1)),"unknown story ID rejected")
	_check(not s.start_story_encounter(StoryEntry.EVENT_ID,idx+1,ids.slice(0,1)),"wrong tile rejected")
	_check(not s.start_story_encounter(StoryEntry.EVENT_ID,idx,[]),"empty lineup rejected")
	_check(not s.start_story_encounter(StoryEntry.EVENT_ID,idx,ids),"more than four rejected")
	_check(not s.start_story_encounter(StoryEntry.EVENT_ID,idx,[ids[0],ids[0]]),"duplicate owned ID rejected")
	_check(not s.start_story_encounter(StoryEntry.EVENT_ID,idx,["invented"]),"unowned unit rejected")
	s.world.roster[0].current_hp = 0
	_check(not s.start_story_encounter(StoryEntry.EVENT_ID,idx,[ids[0]]),"dead card not allowed")
	s.world.roster[0].current_hp = s.world.roster[0].max_hp
	var before: Dictionary = s.world.snapshot().duplicate(true)
	var good_path: String = s.save_file_path
	s.save_file_path = "user://graveyard_combat_no_dir_%d/blocked.json" % OS.get_process_id()
	_check(not s.start_story_encounter(StoryEntry.EVENT_ID,idx,ids.slice(0,1)),"save failure blocks battle start")
	_check(s.world.snapshot() == before,"save failure rolls back complete encounter and RNG state")
	_check(s.encounter.is_empty(),"failed save cannot enter battle")
	s.save_file_path = good_path
	_check(s.start_story_encounter(StoryEntry.EVENT_ID,idx,ids.slice(0,1)),"retry after save recovery starts")
	s.free()

func _test_loss_and_retry() -> void:
	var s = _make("lost")
	var idx: int = s.world.position
	var ids: Array = _ids(s,1)
	_check(s.start_story_encounter(StoryEntry.EVENT_ID,idx,ids),"first rescue attempt starts")
	_check(s.finish_encounter(BattleResult.new("enemy")),"loss persists")
	_check(s.get_story_event(StoryEntry.EVENT_ID).status=="active","loss keeps quest unfinished")
	_check(s.get_story_event(StoryEntry.EVENT_ID).battle_result=="lost","loss result recorded")
	_check(s.event_flag_is_set("battle:graveyard_child_ambush_01:lost"),"loss journal flag saved")
	_check(not s.event_flag_is_set("event:graveyard_child_ambush_01:abandoned"),"losing is not abandonment")
	_check(not s.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"losing is not rescue")
	s.reload_world()
	_check(s.get_story_event(StoryEntry.EVENT_ID).battle_result=="lost","loss survives reload")
	_check(s.start_story_encounter(StoryEntry.EVENT_ID,idx,ids),"a new deliberate retry allowed")
	_check(s.get_story_event(StoryEntry.EVENT_ID).battle_result.is_empty(),"only new attempt resets pending battle result")
	_check(s.finish_encounter(BattleResult.new("ally")),"winning retry saves")
	_check(s.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"successful retry rescues child")
	s.free()

func _test_finish_failure() -> void:
	var s = _make("finish_fail")
	var idx: int = s.world.position
	_check(s.start_story_encounter(StoryEntry.EVENT_ID,idx,_ids(s,1)),"rollback fixture battle starts")
	var before: Dictionary = s.world.snapshot().duplicate(true)
	var real_path: String = s.save_file_path
	s.save_file_path = "user://graveyard_combat_no_dir_%d/blocked.json" % OS.get_process_id()
	_check(not s.finish_encounter(BattleResult.new("ally")),"unwritable finish rejected")
	_check(s.world.snapshot() == before,"unwritable finish restores story/roster/active battle")
	_check(s.encounter.get("event_id","")==StoryEntry.EVENT_ID,"encounter context retained after failed finish")
	s.save_file_path = real_path
	_check(s.finish_encounter(BattleResult.new("ally")),"retry commits victory")
	_check(s.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"saved victory appears after retry")
	s.free()

func _run() -> void:
	for count in range(1,5): _test_party_count(count)
	_test_guards()
	_test_loss_and_retry()
	_test_finish_failure()
	var m: String = FileAccess.get_file_as_string("res://map.gd")
	_check(m.contains("show_story_battle_deck(StoryEventEntry.EVENT_ID,index)"),"UI dispatch uses shared 1-4 card deck with story ID")
	_check(m.contains("session.start_story_encounter(story_event_id,index,ids)"),"deck confirmation uses dedicated story entry")
	_check(m.contains("open_embedded_battle()"),"confirmed encounter opens embedded battlefield")
	for path in paths: _clear(path)
	print("GRAVEYARD_COMBAT_REGRESSION: %d passed, %d failed" % [passed,failures])
	quit(0 if failures == 0 else 1)
