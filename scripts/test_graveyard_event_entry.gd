extends SceneTree
## P1-03A first-landing and persistence checks with disposable user:// files.

const SessionScript = preload("res://systems/run_session.gd")
const StoryEntry = preload("res://systems/story_event_entry.gd")

var passed: int = 0
var failed: int = 0
var paths: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS graveyard-entry: ",description)
	else:
		failed += 1
		printerr("FAIL graveyard-entry: ",description)


func _new_session(suffix: String):
	var session = SessionScript.new()
	root.add_child(session)
	var test_save: String = "user://graveyard_entry_regression_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(test_save)
	session.save_file_path = test_save
	_delete_path(test_save)
	session.start_new_world()
	_check(session.has_save(),"test save created separately")
	return session


func _delete_path(path: String) -> void:
	for suffix in ["",".tmp"]:
		var file_path: String = path+suffix
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))


func _run() -> void:
	var session = _new_session("main")
	var world = session.world
	var grave: int = world.tiles.find("graveyard")
	var event_tile: int = world.tiles.find("event")
	_check(grave >= 0 and event_tile >= 0,"canonical map contains both event triggers")
	_check(not StoryEntry.can_enter(session,grave),"previewed noncurrent graveyard cannot begin story")
	world.position = grave
	_check(not StoryEntry.can_enter(session,event_tile),"preview of another event tile cannot trigger")
	_check(StoryEntry.can_enter(session,grave),"current graveyard landing is eligible")
	_check(StoryEntry.begin(session,grave),"first landing persists discovery")
	_check(session.get_story_event(StoryEntry.EVENT_ID).status == "seen","first beat sets only seen")
	_check(session.get_story_event(StoryEntry.EVENT_ID).choice.is_empty(),"does not preselect rescue or pass")
	_check(session.get_story_event(StoryEntry.EVENT_ID).battle_result.is_empty(),"does not fabricate combat result")
	_check(session.event_flag_is_set(StoryEntry.SEEN_FLAG),"canonical web-compatible seen flag saved")
	_check(not session.event_flag_is_set(StoryEntry.COMPLETE_FLAG),"discovery is not completion")
	_check(session.encounter.is_empty(),"discovery does not start combat")
	_check(StoryEntry.begin(session,grave),"reentering an unfinished seen event is safe")
	session.reload_world()
	world = session.world
	_check(world.position == grave,"landing tile preserved by reload")
	_check(session.get_story_event(StoryEntry.EVENT_ID).status == "seen","seen survives restart")
	_check(session.event_flag_is_set(StoryEntry.SEEN_FLAG),"seen flag survives restart")
	_check(StoryEntry.can_enter(session,grave),"unfinished seen event remains eligible")
	world.pending_move = {"testing":true}
	_check(not StoryEntry.can_enter(session,grave),"moving blocks event launch")
	world.pending_move = {}
	world.pending_reward = {"testing":true}
	_check(not StoryEntry.can_enter(session,grave),"unclaimed reward blocks event launch")
	world.pending_reward = {}
	world.active_encounter = {"testing":true}
	_check(not StoryEntry.can_enter(session,grave),"restored combat blocks event launch")
	world.active_encounter = {}
	session.encounter = {"testing":true}
	_check(not StoryEntry.can_enter(session,grave),"in-memory combat blocks event launch")
	session.encounter = {}
	var roster = world.roster
	world.roster = []
	_check(not StoryEntry.can_enter(session,grave),"no owned monsters blocks story encounter")
	world.roster = roster
	world.position = event_tile
	_check(StoryEntry.can_enter(session,event_tile),"generic event tile can resume child story")
	_check(StoryEntry.begin(session,event_tile),"event tile reentry does not duplicate progress")
	world.event_flags[StoryEntry.COMPLETE_FLAG] = true
	_check(not StoryEntry.can_enter(session,event_tile),"completed flag consumes event")
	world.event_flags[StoryEntry.COMPLETE_FLAG] = false
	_check(session.advance_story_event(StoryEntry.EVENT_ID,"active"),"active story state can be reached")
	_check(StoryEntry.begin(session,event_tile),"entry preserves already active story")
	_check(session.get_story_event(StoryEntry.EVENT_ID).status == "active","active story never reverts to seen")
	session.free()

	var failed_save = _new_session("rollback")
	var rollback_grave: int = failed_save.world.tiles.find("graveyard")
	failed_save.world.position = rollback_grave
	var before: Dictionary = failed_save.world.snapshot().duplicate(true)
	var original_path: String = failed_save.save_file_path
	failed_save.save_file_path = "user://graveyard_entry_regression_missing_%d/not-created.json" % OS.get_process_id()
	_check(not StoryEntry.begin(failed_save,rollback_grave),"failed save rejects event entry")
	_check(failed_save.world.snapshot() == before,"failed event start rolls back all changes")
	failed_save.save_file_path = original_path
	_check(StoryEntry.begin(failed_save,rollback_grave),"retry succeeds when storage restored")
	failed_save.reload_world()
	_check(failed_save.event_flag_is_set(StoryEntry.SEEN_FLAG),"retried event survives reload")
	failed_save.free()
	for path in paths:
		_delete_path(path)
	print("GRAVEYARD_ENTRY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
