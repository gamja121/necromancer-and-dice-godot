extends SceneTree
## P1-03D: disposable-save regression for battle return, acknowledgement and replay.
const SessionScript = preload("res://systems/run_session.gd")
const StoryEntry = preload("res://systems/story_event_entry.gd")
const MapScript = preload("res://map.gd")
const Rules = preload("res://systems/battlefield_rules.gd")

class Result:
	extends RefCounted
	var victor: String
	var units: Array = []
	func _init(value: String) -> void: victor = value
	func winner() -> String: return victor
	func find_id(_id: String) -> Dictionary: return {}

var passed: int = 0
var failed: int = 0
var files: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS graveyard-return: ",label)
	else:
		failed += 1
		printerr("FAIL graveyard-return: ",label)

func _delete(path: String) -> void:
	for suffix in ["",".tmp"]:
		var p: String = path+suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _make(suffix: String):
	var s = SessionScript.new()
	root.add_child(s)
	var path: String = "user://graveyard_return_%d_%s.json" % [OS.get_process_id(),suffix]
	files.append(path)
	_delete(path)
	s.save_file_path = path
	s.start_new_world()
	s.world.position = s.world.tiles.find("graveyard")
	_check(StoryEntry.begin(s,s.world.position),"graveyard entry")
	_check(StoryEntry.choose(s,s.world.position,"protect_child"),"rescue chosen")
	return s

func _start(s) -> bool:
	return s.start_story_encounter(StoryEntry.EVENT_ID,s.world.position,[s.world.roster[0].id])

func _test_win() -> void:
	var s = _make("win")
	_check(not s.graveyard_battle_result_pending(),"no return before combat")
	_check(_start(s),"start real checkpoint")
	_check(not s.graveyard_battle_result_pending(),"combat blocks result presentation")
	_check(not s.acknowledge_graveyard_battle_result(),"cannot acknowledge midbattle")
	_check(s.finish_encounter(Result.new("ally")),"winning battle commits")
	_check(s.graveyard_battle_result_pending(),"win result awaits acknowledgement")
	_check(s.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"only real win rescues child")
	_check(s.get_story_event(StoryEntry.EVENT_ID).status=="complete","win story complete")
	_check(s.world.pending_reward.is_empty(),"win does not show capture before story")
	s.reload_world()
	_check(s.graveyard_battle_result_pending(),"reload reopens unacknowledged victory")
	_check(s.event_flag_is_set(s.GRAVEYARD_RESULT_PENDING_FLAG),"pending indicator serialized")
	_check(s.acknowledge_graveyard_battle_result(),"dismissal commits")
	_check(not s.graveyard_battle_result_pending(),"dismissed result not shown twice")
	_check(not s.acknowledge_graveyard_battle_result(),"cannot acknowledge repeatedly")
	s.reload_world()
	_check(not s.graveyard_battle_result_pending(),"acknowledged victory stays consumed")
	_check(s.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"acknowledgement preserves rescue")
	_check(s.get_story_event(StoryEntry.EVENT_ID).battle_result=="won","acknowledgement preserves battle history")
	s.free()

func _test_lose() -> void:
	var s = _make("lose")
	_check(_start(s),"start losing encounter")
	_check(s.finish_encounter(Result.new("enemy")),"loss commits")
	_check(s.graveyard_battle_result_pending(),"loss result awaits acknowledgement")
	_check(s.get_story_event(StoryEntry.EVENT_ID).battle_result=="lost","loss history stored")
	_check(s.get_story_event(StoryEntry.EVENT_ID).status=="active","loss leaves rescue pending")
	_check(not s.event_flag_is_set("event:graveyard_child_ambush_01:complete"),"loss not completed")
	_check(not s.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"loss is not rescue")
	_check(not s.event_flag_is_set("event:graveyard_child_ambush_01:abandoned"),"loss is not abandonment")
	s.reload_world()
	_check(s.graveyard_battle_result_pending(),"loss modal pending after restart")
	_check(s.acknowledge_graveyard_battle_result(),"player acknowledges loss")
	_check(not s.graveyard_battle_result_pending(),"acknowledged loss hidden")
	_check(s.get_story_event(StoryEntry.EVENT_ID).status=="active","loss acknowledgement keeps story open")
	_check(_start(s),"retry starts after acknowledgement")
	_check(not s.graveyard_battle_result_pending(),"no stale loss result in new battle")
	_check(s.finish_encounter(Result.new("ally")),"winning retry commits")
	_check(s.graveyard_battle_result_pending(),"retry win gets its own result panel")
	_check(s.get_story_event(StoryEntry.EVENT_ID).battle_result=="won","retry result replaces previous loss")
	_check(s.acknowledge_graveyard_battle_result(),"retry win acknowledgement")
	s.free()

func _test_rollback() -> void:
	var s = _make("rollback")
	_check(_start(s),"rollback test fight starts")
	var before: Dictionary = s.world.snapshot().duplicate(true)
	var original: String = s.save_file_path
	s.save_file_path = "user://graveyard_result_uncreated_%d/no.json" % OS.get_process_id()
	_check(not s.finish_encounter(Result.new("ally")),"combat commit fails without directory")
	_check(s.world.snapshot()==before,"failed combat does not mark rescue or result pending")
	_check(not s.graveyard_battle_result_pending(),"failed combat cannot show result")
	s.save_file_path = original
	_check(s.finish_encounter(Result.new("ally")),"combat commit succeeds on retry")
	before = s.world.snapshot().duplicate(true)
	s.save_file_path = "user://graveyard_result_uncreated_%d/no.json" % OS.get_process_id()
	_check(not s.acknowledge_graveyard_battle_result(),"acknowledgement save failure is detected")
	_check(s.world.snapshot()==before,"failed acknowledgement retains original state")
	_check(s.graveyard_battle_result_pending(),"failed acknowledgement keeps result visible")
	s.save_file_path = original
	_check(s.acknowledge_graveyard_battle_result(),"acknowledgement retry succeeds")
	s.reload_world()
	_check(not s.graveyard_battle_result_pending(),"successful acknowledgement persisted")
	s.free()

func _test_guards() -> void:
	var s = _make("guard")
	var idx: int = s.world.position
	_check(not s.graveyard_battle_result_pending(),"unplayed rescue has no result")
	s.world.event_flags[s.GRAVEYARD_RESULT_PENDING_FLAG]=true
	_check(not s.graveyard_battle_result_pending(),"invalid active/unplayed state cannot show fabricated result")
	s.world.event_flags.erase(s.GRAVEYARD_RESULT_PENDING_FLAG)
	_check(_start(s),"guard fight starts")
	_check(s.finish_encounter(Result.new("enemy")),"guard loss commits")
	s.world.pending_reward={"kind":"treasure"}
	_check(not s.graveyard_battle_result_pending(),"pending reward preempts story result")
	s.world.pending_reward={}
	s.world.pending_move={"testing":true}
	_check(not s.graveyard_battle_result_pending(),"pending movement preempts story result")
	s.world.pending_move={}
	_check(s.graveyard_battle_result_pending(),"result resumes after blockers cleared")
	_check(s.world.position==idx,"pending result does not move hero")
	s.free()

func _test_visual_code_paths() -> void:
	var script: String = FileAccess.get_file_as_string("res://map.gd")
	_check(not script.is_empty(),"map screen script exists")
	_check(script.contains('returning_story_event_id = str(session.encounter.get("event_id",""))'),"embedded battle remembers event context")
	_check(script.contains('completed_story_event_id == StoryEventEntry.EVENT_ID'),"only event battle opens result on return")
	_check(script.contains('call_deferred("show_graveyard_battle_result")'),"reload dispatches pending results")
	_check(script.contains('func show_graveyard_battle_result() -> void:'),"dedicated result modal is present")
	_check(script.contains('func acknowledge_graveyard_result(retry: bool) -> void:'),"result close/retry handler is present")
	_check(script.contains('session.acknowledge_graveyard_battle_result()'),"results acknowledged on explicit UI click")
	_check(script.contains("구울이 쓰러지자 아이는 당신을 바라본다."),"canonical rescued narration reused")
	_check(script.contains('"다시 도전"'),"loss UI includes retry")
	_check(script.contains('"맵으로"'),"result UI has exit button")
	_check(script.contains("if not rescued and not world.roster.is_empty():"),"retry hidden when no units survive")

func _run() -> void:
	_test_win()
	_test_lose()
	_test_rollback()
	_test_guards()
	_test_visual_code_paths()
	for path in files: _delete(path)
	print("GRAVEYARD_RETURN_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
