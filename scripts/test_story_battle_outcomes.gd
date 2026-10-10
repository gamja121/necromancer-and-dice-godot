extends SceneTree
## P1-04B: verifies declarative result policies, UI metadata, reload and rollback.
const SessionScript = preload("res://systems/run_session.gd")
const StoryEntry = preload("res://systems/story_event_entry.gd")
const Registry = preload("res://systems/story_battle_registry.gd")
const Outcomes = preload("res://systems/story_battle_outcomes.gd")

class BattleResult:
	extends RefCounted
	var outcome: String
	var units: Array = []
	func _init(winner_name: String) -> void: outcome = winner_name
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int = 0
var failed: int = 0
var paths: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS story-outcome: ",description)
	else:
		failed += 1
		printerr("FAIL story-outcome: ",description)

func remove_test_file(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fresh(suffix: String):
	var s = SessionScript.new()
	root.add_child(s)
	var path: String = "user://story_outcome_regression_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	remove_test_file(path)
	s.save_file_path = path
	s.start_new_world()
	s.world.position = s.world.tiles.find("graveyard")
	check(StoryEntry.begin(s,s.world.position),"discovery saved")
	check(StoryEntry.choose(s,s.world.position,"protect_child"),"protect committed")
	return s

func battle(s, winner: String) -> bool:
	if not s.start_story_encounter(Registry.GRAVEYARD_ID,s.world.position,[s.world.roster[0].id]): return false
	return s.finish_encounter(BattleResult.new(winner))

func registry_and_presentation() -> void:
	var spec: Dictionary = Registry.definition(Registry.GRAVEYARD_ID)
	check(Registry.registered_ids()==[Registry.GRAVEYARD_ID],"only activated event is graveyard")
	check(Registry.valid_definition(spec),"declarative outcome policy validates")
	check(spec.outcomes.won.flags["event:graveyard_child_ambush_01:rescued"]==true,"victory policy rescues")
	check(spec.outcomes.lost.flags["battle:graveyard_child_ambush_01:lost"]==true,"defeat policy records loss")
	check(spec.outcomes.won.presentation.narration.begins_with("구울이 쓰러지자 아이는"),"original victory script retained")
	check(spec.outcomes.won.presentation.overlay=="","win hides ghoul layer")
	check(spec.outcomes.lost.presentation.overlay.ends_with("graveyard-child-ghoul-event-v3.webp"),"loss retains ghoul layer")
	check(spec.outcomes.won.presentation.retry==false and spec.outcomes.lost.presentation.retry==true,"retry metadata depends on result")
	check(ResourceLoader.exists(spec.outcomes.won.presentation.background),"background asset exists")
	check(ResourceLoader.exists(spec.outcomes.lost.presentation.overlay),"ghoul asset exists")
	var alternate: Dictionary = spec.duplicate(true)
	alternate.outcomes.won.presentation.title = "modified"
	check(Registry.definition(Registry.GRAVEYARD_ID).outcomes.won.presentation.title=="아이 구조 성공","presentation metadata is copied")
	var broken: Dictionary = spec.duplicate(true)
	broken.outcomes.lost.erase("presentation")
	check(not Registry.valid_definition(broken),"missing presentation blocked")
	broken = spec.duplicate(true)
	broken.outcomes.won.flags["event:graveyard_child_ambush_01:rescued"] = "yes"
	check(not Registry.valid_definition(broken),"nonboolean outcome flag blocked")

func test_actual_win_loss() -> void:
	for winner in ["ally","enemy"]:
		var s = fresh("actual_"+winner)
		check(s.story_battle_presentation(Registry.GRAVEYARD_ID).is_empty(),"no premature result scene")
		check(battle(s,winner),"real battle persistence succeeds")
		var result: String = "won" if winner=="ally" else "lost"
		var expect_title: String = "아이 구조 성공" if winner=="ally" else "아이 구조 실패"
		check(s.pending_story_battle_event_id()==Registry.GRAVEYARD_ID,"registered outcome routed after combat")
		check(s.story_battle_presentation(Registry.GRAVEYARD_ID).title==expect_title,"appropriate title appears")
		check(Outcomes.valid_result(s.world,Registry.GRAVEYARD_ID,Registry.definition(Registry.GRAVEYARD_ID)),"outcome flags and stage consistent")
		check(s.story_battle_presentation("ritual_portal_trace_01").is_empty(),"other event cannot show scene")
		s.reload_world()
		check(s.pending_story_battle_event_id()==Registry.GRAVEYARD_ID,"pending result routes after restart")
		check(s.story_battle_presentation(Registry.GRAVEYARD_ID).title==expect_title,"restarted scene uses same outcome")
		check(s.acknowledge_story_battle_result(Registry.GRAVEYARD_ID),"explicit close commits")
		check(s.pending_story_battle_event_id().is_empty(),"acknowledged result not reopened")
		check(s.story_battle_presentation(Registry.GRAVEYARD_ID).is_empty(),"acknowledged presentation unavailable")
		s.reload_world()
		check(s.pending_story_battle_event_id().is_empty(),"acknowledgement survives restart")
		s.free()

func test_synthetic_policy_without_activation() -> void:
	var spec: Dictionary = Registry.definition(Registry.GRAVEYARD_ID)
	var alt: Dictionary = spec.duplicate(true)
	alt.event_id = "test_only_second_event"
	alt.encounter_type = "event-test-only"
	alt.complete_flag = "test:complete"
	alt.pending_flag = "test:pending"
	alt.outcomes.won.flags = {"test:complete":true,"test:won":true}
	alt.outcomes.lost.flags = {"test:won":false,"test:lost":true}
	alt.outcomes.won.presentation.title = "Second Event Victory"
	check(Registry.valid_definition(alt),"another event's independent result policy validates")
	var s = fresh("synthetic")
	s.world.story_events[alt.event_id] = {"status":"active","choice":"protect_child","battle_result":""}
	check(Outcomes.apply(s.world,alt.event_id,alt,false)==alt.outcomes.lost.notice,"synthetic loss processed from policy")
	check(s.world.story_events[alt.event_id].status=="active","synthetic loss remains active")
	check(Outcomes.valid_result(s.world,alt.event_id,alt),"synthetic loss receipt validates")
	check(not s.story_battle_result_pending(alt.event_id),"unregistered synthetic event never exposed to game")
	check(Outcomes.presentation(alt,s.world.story_events[alt.event_id]).retry,"synthetic retry presentation follows policy")
	s.world.story_events[alt.event_id] = {"status":"active","choice":"protect_child","battle_result":""}
	check(Outcomes.apply(s.world,alt.event_id,alt,true)==alt.outcomes.won.notice,"synthetic victory processed from policy")
	check(s.world.event_flags["test:won"] and s.world.event_flags["test:complete"],"synthetic flags applied")
	check(Outcomes.valid_result(s.world,alt.event_id,alt),"synthetic victory receipt validates")
	check(Outcomes.presentation(alt,s.world.story_events[alt.event_id]).title=="Second Event Victory","synthetic artwork/title independent from graveyard")
	check(not s.start_story_encounter(alt.event_id,s.world.position,[s.world.roster[0].id]),"synthetic policy does not activate an encounter")
	s.free()

func test_guard_and_storage() -> void:
	var s = fresh("guard")
	check(battle(s,"ally"),"victory ready for guard test")
	var spec: Dictionary = Registry.definition(Registry.GRAVEYARD_ID)
	s.world.event_flags["event:graveyard_child_ambush_01:rescued"] = false
	check(not s.story_battle_result_pending(Registry.GRAVEYARD_ID),"contradictory victory flag rejects scene")
	s.world.event_flags["event:graveyard_child_ambush_01:rescued"] = true
	check(s.story_battle_result_pending(Registry.GRAVEYARD_ID),"restored flag restores scene")
	var before: Dictionary = s.world.snapshot().duplicate(true)
	var real_path: String = s.save_file_path
	s.save_file_path = "user://story_outcome_uncreated_%d/dont.json" % OS.get_process_id()
	check(not s.acknowledge_story_battle_result(Registry.GRAVEYARD_ID),"missing destination rejects ack")
	check(s.world.snapshot()==before,"failed acknowledgement does not consume scene")
	s.save_file_path = real_path
	check(s.acknowledge_story_battle_result(Registry.GRAVEYARD_ID),"retry succeeds")
	s.reload_world()
	check(not s.story_battle_result_pending(Registry.GRAVEYARD_ID),"retry acknowledged durably")
	check(not Outcomes.valid_result(null,Registry.GRAVEYARD_ID,spec),"missing world rejected")
	check(Outcomes.presentation({},{}).is_empty(),"unknown outcome has no presentation")
	s.free()

func test_ui_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://map.gd")
	check(source.contains('func show_story_battle_result(event_id: String) -> void:'),"generic modal uses event ID")
	check(source.contains('session.story_battle_presentation(event_id)'),"modal reads registered presentation")
	check(source.contains('func show_pending_story_battle_result() -> void:'),"map reload scans pending event receipts")
	check(source.contains('session.pending_story_battle_event_id()'),"map calls pending result router")
	check(source.contains('func acknowledge_story_battle_result_ui(event_id: String, retry: bool) -> void:'),"generic close/retry handler exists")
	check(source.contains('show_story_battle_deck(event_id,index)'),"retry always returns to the existing deck selector")
	check(source.contains('func show_graveyard_battle_result() -> void:'),"original graveyard wrapper retained")
	check(source.contains('func acknowledge_graveyard_result(retry: bool) -> void:'),"original acknowledgement wrapper retained")

func _run() -> void:
	registry_and_presentation()
	test_actual_win_loss()
	test_synthetic_policy_without_activation()
	test_guard_and_storage()
	test_ui_contract()
	for path in paths: remove_test_file(path)
	print("STORY_OUTCOME_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
