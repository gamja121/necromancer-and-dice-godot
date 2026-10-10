extends SceneTree
## P1-03B: canonical beat order and durable choice branches.
## All writes use disposable user:// paths, never the player's map save.

const SessionScript = preload("res://systems/run_session.gd")
const StoryEntry = preload("res://systems/story_event_entry.gd")
const Beats = preload("res://systems/graveyard_story_beats.gd")

var passed: int = 0
var failed: int = 0
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS graveyard-choice: ",description)
	else:
		failed += 1
		printerr("FAIL graveyard-choice: ",description)

func _delete(path: String) -> void:
	for suffix in ["",".tmp"]:
		var file_path: String = path + suffix
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))

func _make(suffix: String):
	var s = SessionScript.new()
	root.add_child(s)
	var path: String = "user://graveyard_choice_regression_%d_%s.json" % [OS.get_process_id(),suffix]
	s.save_file_path = path
	paths.append(path)
	_delete(path)
	s.start_new_world()
	_check(s.has_save(),"isolated session saved")
	s.world.position = s.world.tiles.find("graveyard")
	return s

func _run() -> void:
	_check(Beats.BEATS.size() == 4,"four canonical story beats")
	_check(Beats.beat(0).id == "discovery","first beat discovery")
	_check(Beats.beat(1).id == "threat" and Beats.beat(1).ghoul,"second beat reveals ghoul")
	_check(Beats.beat(2).id == "dialogue" and not Beats.beat(2).dialogue.is_empty(),"third beat child dialogue")
	_check(Beats.beat(3).id == "choice" and Beats.beat(3).choice,"fourth beat displays choice")
	_check(Beats.beat(-1).is_empty() and Beats.beat(4).is_empty(),"invalid beats rejected")
	_check(ResourceLoader.exists(Beats.BASE_ART),"child background resource exists")
	_check(ResourceLoader.exists(Beats.GHOUL_ART),"ghoul layer resource exists")

	var rescue = _make("protect")
	var tile: int = rescue.world.position
	var original_roster: Array = rescue.world.roster.duplicate(true)
	_check(not StoryEntry.choose(rescue,tile,"protect_child"),"cannot select before seen")
	_check(StoryEntry.begin(rescue,tile),"rescue path first discovery")
	_check(not StoryEntry.choose(rescue,tile,"invalid"),"unknown choice rejected")
	_check(StoryEntry.choose(rescue,tile,"protect_child"),"rescue route chosen")
	_check(rescue.get_story_event(StoryEntry.EVENT_ID).status == "active","rescue requires battle")
	_check(rescue.get_story_event(StoryEntry.EVENT_ID).choice == "protect_child","rescue choice persisted")
	_check(rescue.get_story_event(StoryEntry.EVENT_ID).battle_result.is_empty(),"no fake battle result")
	_check(not rescue.event_flag_is_set(StoryEntry.COMPLETE_FLAG),"rescue not complete before battle")
	_check(not rescue.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"no rescued flag before battle")
	_check(StoryEntry.choose(rescue,tile,"protect_child"),"repeated rescue selection is safe")
	_check(not StoryEntry.choose(rescue,tile,"leave"),"cannot change rescue to abandon")
	_check(rescue.world.roster == original_roster,"choice does not alter owned monsters")
	rescue.reload_world()
	_check(rescue.get_story_event(StoryEntry.EVENT_ID).status == "active","pending fight state reloads")
	_check(rescue.get_story_event(StoryEntry.EVENT_ID).choice == "protect_child","pending fight choice reloads")
	_check(StoryEntry.can_enter(rescue,rescue.world.position),"pending rescue can reopen event panel")
	rescue.free()

	var abandon = _make("leave")
	var abandon_tile: int = abandon.world.position
	_check(StoryEntry.begin(abandon,abandon_tile),"abandon path first discovery")
	_check(StoryEntry.choose(abandon,abandon_tile,"leave"),"abandon route persisted")
	_check(abandon.get_story_event(StoryEntry.EVENT_ID).status == "complete","abandon immediately completes event")
	_check(abandon.get_story_event(StoryEntry.EVENT_ID).choice == "leave","abandon choice saved")
	_check(abandon.event_flag_is_set(StoryEntry.COMPLETE_FLAG),"web complete flag saved")
	_check(abandon.event_flag_is_set("event:graveyard_child_ambush_01:abandoned"),"abandoned flag saved")
	_check(not abandon.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"abandon never rescues child")
	_check(not StoryEntry.can_enter(abandon,abandon_tile),"finished event does not replay")
	_check(not StoryEntry.choose(abandon,abandon_tile,"protect_child"),"cannot override completed abandon")
	abandon.reload_world()
	_check(abandon.get_story_event(StoryEntry.EVENT_ID).status == "complete","abandon completion reloads")
	_check(abandon.event_flag_is_set("event:graveyard_child_ambush_01:abandoned"),"abandon flag survives reload")
	abandon.free()

	var fail_rescue = _make("rollback_protect")
	var before: Dictionary = fail_rescue.world.snapshot().duplicate(true)
	var real_path: String = fail_rescue.save_file_path
	fail_rescue.save_file_path = "user://graveyard_choice_uncreated_%d/blocked.json" % OS.get_process_id()
	_check(not StoryEntry.begin(fail_rescue,fail_rescue.world.position),"discovery failure blocks choice")
	_check(fail_rescue.world.snapshot() == before,"failed discovery reverts entire snapshot")
	fail_rescue.save_file_path = real_path
	_check(StoryEntry.begin(fail_rescue,fail_rescue.world.position),"discovery retry succeeds")
	before = fail_rescue.world.snapshot().duplicate(true)
	fail_rescue.save_file_path = "user://graveyard_choice_uncreated_%d/blocked.json" % OS.get_process_id()
	_check(not StoryEntry.choose(fail_rescue,fail_rescue.world.position,"protect_child"),"rescue choice fails on unwritable save")
	_check(fail_rescue.world.snapshot() == before,"failed rescue rolls back")
	fail_rescue.save_file_path = real_path
	_check(StoryEntry.choose(fail_rescue,fail_rescue.world.position,"protect_child"),"rescue retry commits")
	fail_rescue.free()

	var fail_abandon = _make("rollback_leave")
	_check(StoryEntry.begin(fail_abandon,fail_abandon.world.position),"abandon rollback setup discovered")
	before = fail_abandon.world.snapshot().duplicate(true)
	real_path = fail_abandon.save_file_path
	fail_abandon.save_file_path = "user://graveyard_choice_uncreated_%d/blocked.json" % OS.get_process_id()
	_check(not StoryEntry.choose(fail_abandon,fail_abandon.world.position,"leave"),"abandon choice save failure detected")
	_check(fail_abandon.world.snapshot() == before,"failed abandon restores flags and status")
	_check(not fail_abandon.event_flag_is_set(StoryEntry.COMPLETE_FLAG),"failed abandon does not consume event")
	fail_abandon.save_file_path = real_path
	_check(StoryEntry.choose(fail_abandon,fail_abandon.world.position,"leave"),"abandon choice retry succeeds")
	fail_abandon.reload_world()
	_check(fail_abandon.event_flag_is_set(StoryEntry.COMPLETE_FLAG),"abandon retry survives reload")
	fail_abandon.free()

	for path in paths: _delete(path)
	print("GRAVEYARD_CHOICE_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
