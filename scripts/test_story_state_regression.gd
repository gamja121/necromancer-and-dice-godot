extends SceneTree
## P1-02D headless story-state regression. Writes only uniquely named test saves.
## Run: godot --headless --path . --script res://scripts/test_story_state_regression.gd

const SessionScript = preload("res://systems/run_session.gd")
const StateScript = preload("res://systems/map_state.gd")

var failures: int = 0
var passed: int = 0
var test_paths: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS story-state: ",label)
	else:
		failures += 1
		printerr("FAIL story-state: ",label)


func _new_run(suffix: String):
	var session = SessionScript.new()
	root.add_child(session)
	var path: String = "user://story_state_regression_%d_%s.json" % [OS.get_process_id(),suffix]
	test_paths.append(path)
	session.save_file_path = path
	_delete_path(path)
	session.start_new_world()
	_check(session.has_save(),"isolated new-game save: "+suffix)
	return session


func _delete_path(path: String) -> void:
	for ending in ["",".tmp"]:
		var file_path: String = path + ending
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))


func _prepare_ritual(session, won: bool) -> void:
	_check(session.advance_story_event("ritual_portal_trace_01","seen"),"ritual seen")
	_check(session.advance_story_event("ritual_portal_trace_01","active"),"ritual active")
	_check(session.choose_story_event("ritual_portal_trace_01","intervene"),"ritual choice")
	_check(not session.finalize_ritual_portal_outcome(),"ritual cannot finish without result")
	_check(session.record_story_battle_result("ritual_portal_trace_01",won),"ritual actual battle result")
	_check(session.record_story_battle_result("ritual_portal_trace_01",won),"same result is idempotent")
	_check(not session.record_story_battle_result("ritual_portal_trace_01",not won),"opposite outcome cannot overwrite")
	_check(not session.advance_story_event("ritual_portal_trace_01","complete"),"ritual generic completion forbidden")


func _test_legacy_and_validation() -> void:
	var session = _new_run("legacy")
	var old_save: Dictionary = session.world.snapshot().duplicate(true)
	old_save.erase("event_flags")
	old_save.erase("story_events")
	var old_world = StateScript.new(session.world.definitions,123)
	_check(old_world.restore(old_save),"pre-story save restores")
	_check(old_world.story_events.is_empty(),"old save starts with no story progress")
	var pre_outcome: Dictionary = session.world.snapshot().duplicate(true)
	pre_outcome["story_events"] = {"old_event":{"status":"active","choice":"protect_child"}}
	_check(old_world.restore(pre_outcome),"P1-02B event without battle_result restores")
	session.world = old_world
	_check(session.get_story_event("old_event").battle_result == "","missing battle_result defaults pending")
	var bad: Dictionary = pre_outcome.duplicate(true)
	bad["story_events"] = {"old_event":{"status":"active","choice":"","battle_result":"draw"}}
	_check(not old_world.restore(bad),"invalid battle result rejected")
	bad = pre_outcome.duplicate(true)
	bad["story_events"] = {"old_event":{"status":"seen","choice":"protect_child","battle_result":""}}
	_check(not old_world.restore(bad),"choice before active rejected")
	bad = pre_outcome.duplicate(true)
	bad["story_events"] = {"old_event":{"status":"seen","choice":"","battle_result":"won"}}
	_check(not old_world.restore(bad),"result before active rejected")
	session.free()


func _test_transitions_and_reload() -> void:
	var session = _new_run("stages")
	_check(session.get_story_event("child").status == "unseen","initial state unseen")
	_check(not session.advance_story_event("child","complete"),"cannot skip unseen-to-complete")
	_check(not session.choose_story_event("child","protect_child"),"choice requires active")
	_check(not session.record_story_battle_result("child",true),"battle result requires active")
	_check(session.advance_story_event("child","seen"),"mark child seen")
	_check(session.advance_story_event("child","seen"),"same seen event idempotent")
	_check(not session.advance_story_event("child","complete"),"cannot skip seen-to-complete")
	_check(session.advance_story_event("child","active"),"activate child")
	_check(not session.advance_story_event("child","seen"),"cannot regress active-to-seen")
	_check(session.choose_story_event("child","protect_child"),"record choice")
	_check(session.choose_story_event("child","protect_child"),"choice replay idempotent")
	_check(not session.choose_story_event("child","leave"),"choice is immutable")
	_check(session.record_story_battle_result("child",true),"record win")
	_check(session.advance_story_event("child","complete"),"generic child completion")
	_check(not session.advance_story_event("child","active"),"cannot regress completed event")
	_check(session.set_event_flag("story:test:seen"),"canonical boolean flag saved")
	session.reload_world()
	var restored: Dictionary = session.get_story_event("child")
	_check(restored.status == "complete","reload preserves completion")
	_check(restored.choice == "protect_child","reload preserves choice")
	_check(restored.battle_result == "won","reload preserves battle outcome")
	_check(session.event_flag_is_set("story:test:seen"),"reload preserves existing flag")
	_check(session.set_event_flag("story:test:seen"),"repeated flag write idempotent")
	session.free()


func _test_ritual_branch(won: bool) -> void:
	var suffix: String = "ritual_win" if won else "ritual_loss"
	var session = _new_run(suffix)
	_prepare_ritual(session,won)
	_check(session.finalize_ritual_portal_outcome(),"ritual finalization: "+suffix)
	_check(session.finalize_ritual_portal_outcome(),"ritual completion replay: "+suffix)
	_check(session.monster_king_revival_state() == ("weakened" if won else "full"),"revival matches battle: "+suffix)
	_check(session.monster_king_hunt_eligible(),"both revival branches enable hunt")
	_check(session.event_flag_is_set("battle:ritual_portal_trace_01:won") == won,"web-compatible win flag")
	_check(session.event_flag_is_set("battle:ritual_portal_trace_01:lost") != won,"web-compatible loss flag")
	_check(session.event_flag_is_set("quest:monster_king_hunt:active"),"hunt quest activated")
	session.reload_world()
	_check(session.get_story_event("ritual_portal_trace_01").status == "complete","ritual completion reload")
	_check(session.monster_king_revival_state() == ("weakened" if won else "full"),"ritual revival reload")
	_check(session.advance_story_event("monster_king_hunt_trace_01","seen"),"hunt seen")
	_check(session.advance_story_event("monster_king_hunt_trace_01","active"),"hunt active")
	_check(not session.advance_story_event("monster_king_hunt_trace_01","complete"),"hunt generic completion forbidden")
	_check(session.complete_monster_king_hunt(),"hunt scene marks quest complete")
	_check(session.complete_monster_king_hunt(),"hunt completion replay idempotent")
	_check(not session.monster_king_hunt_eligible(),"finished hunt cannot replay")
	_check(session.event_flag_is_set("quest:monster_king_final_battle:active"),"final story battle becomes eligible")
	session.reload_world()
	_check(session.event_flag_is_set("quest:monster_king_hunt:complete"),"hunt completion survives reload")
	_check(not session.event_flag_is_set("quest:monster_king_hunt:active"),"hunt no longer active after reload")
	_check(session.monster_king_revival_state() == ("weakened" if won else "full"),"hunt leaves revival branch intact")
	session.free()


func _test_save_failure_rollback() -> void:
	var session = _new_run("rollback")
	_prepare_ritual(session,true)
	var before: Dictionary = session.world.snapshot().duplicate(true)
	var working_path: String = session.save_file_path
	# This directory is deliberately never created. No production save is touched.
	session.save_file_path = "user://story_state_regression_no_directory_%d/broken.json" % OS.get_process_id()
	_check(not session.finalize_ritual_portal_outcome(),"unwritable save fails atomically")
	_check(session.world.snapshot() == before,"write failure restores entire world snapshot")
	_check(session.get_story_event("ritual_portal_trace_01").status == "active","failed commit does not complete ritual")
	_check(not session.monster_king_hunt_eligible(),"failed commit does not activate hunt")
	session.save_file_path = working_path
	_check(session.finalize_ritual_portal_outcome(),"retry completes after storage restored")
	session.reload_world()
	_check(session.monster_king_hunt_eligible(),"successful retry survives reload")
	# Contradictory revival flags must not launch the hunt.
	session.world.event_flags["story:monster_king:revival_complete"] = true
	_check(session.monster_king_revival_state().is_empty(),"dual revival flags are rejected")
	_check(not session.monster_king_hunt_eligible(),"contradictory flags block hunt")
	session.free()


func _run() -> void:
	_test_legacy_and_validation()
	_test_transitions_and_reload()
	_test_ritual_branch(true)
	_test_ritual_branch(false)
	_test_save_failure_rollback()
	for path in test_paths:
		_delete_path(path)
	print("STORY_STATE_REGRESSION: %d passed, %d failed" % [passed,failures])
	quit(0 if failures == 0 else 1)
