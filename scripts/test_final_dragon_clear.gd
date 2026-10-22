extends SceneTree
const Session = preload("res://systems/run_session.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const MapState = preload("res://systems/map_state.gd")
const Progress = preload("res://systems/final_dragon_progress.gd")
const Fixture = preload("res://scripts/boss_story_test_fixture.gd")
const Hunt = preload("res://systems/monster_king_hunt_entry.gd")
const Portal = preload("res://systems/ritual_portal_entry.gd")
var passed := 0
var failed := 0
var scratch: String

func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1
	print(("PASS " if value else "FAIL ") + message)

func prepare_encounter(s: Node, boss: bool = true) -> void:
	s.start_new_world()
	var w = s.world
	if boss:
		Fixture.seed_completed_final_hunt(w)
		w.contamination = 80
		w.generate()
	w.position = 23 if boss else w.tiles.find("monster")
	check(s.save_world(),"fixture persists real board")
	var rng_before: int = w.rng.state
	if boss:
		check(not s.acknowledge_final_dragon_intro(0),"preview cannot acknowledge book")
		check(s.acknowledge_final_dragon_intro(23),"actual boss arrival can acknowledge book")
		check(w.rng.state==rng_before and s.encounter.is_empty(),"book acknowledgement creates no combat or RNG")
	check(s.start_encounter(w.position,[w.roster[0].id,w.roster[1].id]),"actual encounter starts")

func defeated_rules(s: Node, win: bool = true):
	var rules = Rules.new(s.world.definitions)
	check(rules.restore(s.encounter.checkpoint),"actual encounter checkpoint restores")
	for unit in rules.units:
		if unit.team==("enemy" if win else "ally"):
			rules.damage(unit,9999)
			if unit.alive: rules.damage(unit,9999)
	check(rules.winner()==("ally" if win else "enemy"),"real damage produces intended winner")
	return rules

func capture_seed(s: Node, success: bool) -> void:
	var target: int = int(s.world.pending_reward.corpses[0].target)
	var rng := RandomNumberGenerator.new()
	for value in range(100):
		rng.seed = value
		if (rng.randi_range(1,6)>=target)==success:
			s.world.rng.seed = value
			return
	check(false,"deterministic capture fixture exists")

func _run() -> void:
	var s: Node = root.get_node("RunSession")
	var prior: String = s.save_file_path
	scratch = "user://final_clear_%d.json" % OS.get_process_id()
	s.save_file_path = scratch
	prepare_encounter(s)
	var rules = defeated_rules(s)
	var before: Dictionary = s.world.snapshot().duplicate(true)
	var disk_before: String = FileAccess.get_file_as_string(scratch)
	s.save_file_path = "user://missing_final_clear_directory/save.json"
	check(not s.finish_encounter(rules),"failed victory save rejected")
	check(s.world.snapshot()==before and not s.encounter.is_empty(),"failed victory restores encounter, roster, flags and RNG")
	check(FileAccess.get_file_as_string(scratch)==disk_before,"failed save leaves previous disk bytes")
	s.save_file_path = scratch
	check(s.finish_encounter(rules),"victory commits")
	check(Progress.cleared(s.world) and s.world.run_result.reason==Progress.REASON,"final victory becomes terminal clear")
	check(s.world.event_flags.get(Progress.COMPLETE,false) and not s.world.event_flags.get(Progress.ACTIVE,true),"final quest completed, no active quest")
	check(Hunt.completed(s) and Portal.completed(s),"earlier story remains historically complete")
	check(s.world.pending_reward.kind=="capture" and s.encounter.is_empty(),"same save retains last soul harvest and retires battle")
	var committed: Dictionary = s.world.snapshot().duplicate(true)
	check(s.finish_encounter(rules) and s.world.snapshot()==committed,"duplicate settlement cannot reward or count twice")
	check(not s.prepare_map_roll().ok and not s.enter_home() and not s.leave_home(),"terminal expedition cannot move or regenerate")
	check(not s.open_treasure() and not s.place_allowed(s.world.position,"monster").ok,"terminal expedition cannot start place actions")
	check(not s.start_encounter(23,[s.world.roster[0].id]),"terminal expedition cannot replay fight")
	s.reload_world()
	check(s.world.run_result==committed.run_result and s.world.pending_reward.id==committed.pending_reward.id,"reload keeps clear and same pending harvest")
	check(Hunt.completed(s) and Portal.completed(s),"story remains complete after reload")
	var restored = MapState.new(s.world.definitions)
	var incomplete: Dictionary = committed.duplicate(true)
	incomplete.event_flags.erase(Progress.DEFEATED)
	check(not restored.restore(incomplete),"inconsistent terminal clear is rejected")
	var legacy: Dictionary = committed.duplicate(true)
	legacy.run_result = {}
	legacy.pending_reward = {}
	legacy.event_flags.erase(Progress.DEFEATED)
	legacy.event_flags.erase(Progress.COMPLETE)
	legacy.event_flags[Progress.ACTIVE] = true
	check(restored.restore(legacy) and not Progress.cleared(restored),"legacy tile clear alone is not misclassified as final victory")
	check(restored.restore(committed),"valid terminal save restores")
	restored.contamination = 100
	restored.position = MapState.HOME
	restored.lap_ready = true
	restored.leave_home()
	check(not restored.boss_available() and not "boss" in restored.tiles,"even direct next-lap generation cannot respawn defeated dragon")
	# Both possible harvest outcomes must retain the clear across interruption.
	for success in [true,false]:
		check(s.world.restore(committed),"restore pending final harvest branch")
		s.encounter = {}
		capture_seed(s,success)
		check(s.save_world(),"deterministic capture RNG saved")
		var capture_before: Dictionary = s.world.snapshot().duplicate(true)
		s.save_file_path = "user://missing_final_clear_directory/save.json"
		check(not s.roll_capture().ok and s.world.snapshot()==capture_before,"capture save failure rolls back final reward and RNG")
		s.save_file_path = scratch
		var outcome: Dictionary = s.roll_capture()
		check(outcome.ok and outcome.success==success,"real harvest resolves expected outcome")
		s.reload_world()
		check(Progress.cleared(s.world) and s.world.pending_reward.phase==("success" if success else "failed"),"harvest outcome survives reload")
		var resolved: Dictionary = s.world.snapshot().duplicate(true)
		s.save_file_path = "user://missing_final_clear_directory/save.json"
		if success: check(not s.claim_reward().ok,"failed reward claim remains retryable")
		else: check(not s.dismiss_failed_capture(),"failed harvest dismissal remains retryable")
		check(s.world.snapshot()==resolved,"failed harvest finish preserves entire state")
		s.save_file_path = scratch
		if success:
			check(s.claim_reward().ok,"final dragon reward remains claimable after run ends")
			var unit: Dictionary = s.world.roster.back()
			check(unit.slug=="dragon" and unit.max_hp==20 and unit.passive=="bone" and not unit.has("final_boss"),"existing 20/4/3 recruit normalization preserved")
		else: check(s.dismiss_failed_capture(),"failed harvest closes")
		check(not s.claim_reward().ok and not s.dismiss_failed_capture(),"harvest cannot be claimed twice")
		s.reload_world()
		check(Progress.cleared(s.world) and s.world.pending_reward.is_empty(),"completed harvest resumes at ending")
		check(s.world.reward_receipts.count(committed.pending_reward.id)==1,"exactly one harvest receipt")
	prepare_encounter(s,false)
	check(s.finish_encounter(defeated_rules(s)) and s.world.run_result.is_empty(),"ordinary victory does not clear expedition")
	prepare_encounter(s)
	check(s.finish_encounter(defeated_rules(s,false)),"final dragon loss commits")
	check(s.world.run_result.reason=="battle_defeat" and not Progress.cleared(s.world),"dragon loss retains original defeat ending")
	s.reload_world()
	check(s.world.run_result.reason=="battle_defeat","defeat save backward compatibility")
	s.start_new_world()
	check(s.world.run_result.is_empty() and not Progress.cleared(s.world),"explicit new expedition resets its own completion")
	s.save_file_path = prior
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("FINAL_DRAGON_CLEAR: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
