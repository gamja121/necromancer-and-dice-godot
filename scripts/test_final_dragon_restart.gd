extends SceneTree
## Each phase runs in a NEW Godot process against an isolated disposable save.
const Rules = preload("res://systems/battlefield_rules.gd")
const Fixture = preload("res://scripts/boss_story_test_fixture.gd")
const Progress = preload("res://systems/final_dragon_progress.gd")
const SAVE = "user://test_final_dragon_process_restart.json"
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1
	print(("PASS " if value else "FAIL ")+message)
func battle(s: Node):
	var rules = Rules.new(s.world.definitions)
	check(rules.restore(s.encounter.checkpoint),"saved battle checkpoint restores")
	return rules
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := str(args[0]) if not args.is_empty() else ""
	var s: Node = root.get_node("RunSession")
	s.save_file_path = SAVE
	if phase=="approach":
		s.start_new_world()
		Fixture.seed_completed_final_hunt(s.world)
		s.world.contamination=80
		s.world.generate()
		s.world.position=23
		s.world.dice_visual_position=[811,274]
		s.world.dice_visual_face=4
		check(s.save_world(),"approach persisted")
	else:
		check(FileAccess.file_exists(SAVE),"previous process produced a save")
		if not FileAccess.file_exists(SAVE): quit(1); return
		s.reload_world()
	if phase=="battle":
		check(s.world.position==23 and s.world.boss_available() and not s.event_flag_is_set(Progress.INTRO_SEEN),"restart returns to unacknowledged boss book")
		check(s.acknowledge_final_dragon_intro(23),"explicit book action saved")
		check(s.start_encounter(23,[s.world.roster[0].id,s.world.roster[1].id]),"one final encounter started")
		var rules = battle(s)
		check(s.prepare_battle_roll(rules).ok,"real rolled checkpoint saved")
		rules.damage(rules.find_id("enemy-0"),999)
		check(rules.find_id("enemy-0").hp==1 and rules.find_id("enemy-0").undying_used,"first lethal damage consumes existing undying")
		check(s.checkpoint_battle(rules,"actions"),"in-progress wounded dragon saved")
	elif phase=="victory":
		check(s.event_flag_is_set(Progress.INTRO_SEEN) and s.encounter.get("phase","")=="actions","new process resumes combat, not book")
		var rules = battle(s)
		check(rules.find_id("enemy-0").hp==1 and rules.find_id("enemy-0").undying_used,"boss HP and spent passive survive process exit")
		rules.damage(rules.find_id("enemy-0"),2)
		check(rules.winner()=="ally" and s.finish_encounter(rules),"second lethal hit atomically commits final clear")
		check(Progress.cleared(s.world) and s.world.pending_reward.get("phase","")=="choose","victory and pending harvest stored together")
	elif phase=="harvest":
		check(Progress.cleared(s.world) and s.encounter.is_empty(),"restart cannot revive defeated boss")
		check(s.world.pending_reward.get("phase","")=="choose","restart preserves pending harvest")
		var target: int = int(s.world.pending_reward.corpses[0].target)
		var rng := RandomNumberGenerator.new()
		for value in range(100):
			rng.seed=value
			if rng.randi_range(1,6)>=target:
				s.world.rng.seed=value
				break
		check(s.save_world(),"deterministic harvest fixture saved")
		check(s.roll_capture().get("success",false),"production harvest success saved before claim")
	elif phase=="claim":
		check(Progress.cleared(s.world) and s.world.pending_reward.get("phase","")=="success","harvest success survives new process")
		check(s.claim_reward().get("ok",false),"last reward claimed through ordinary transaction")
		check(s.world.pending_reward.is_empty() and not s.world.run_result.is_empty(),"ending remains durable after claim")
	elif phase=="ending":
		check(Progress.cleared(s.world) and s.world.pending_reward.is_empty() and s.encounter.is_empty(),"final process resumes ending only")
		check(s.world.event_flags.get(Progress.COMPLETE,false) and not s.world.event_flags.get(Progress.ACTIVE,true),"completed final quest remains closed")
		var receipt := "capture-"+str(s.world.run_result.encounter_id)
		check(s.world.reward_receipts.count(receipt)==1,"exactly one reward receipt across six processes")
		check(s.world.roster.filter(func(u): return u.slug=="dragon").size()==1,"exactly one captured dragon across six processes")
		check(not s.prepare_map_roll().ok and not s.world.boss_available(),"completed run cannot move or respawn boss")
		for suffix in ["",".tmp"]:
			if FileAccess.file_exists(SAVE+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
	elif phase!="approach":
		check(false,"unknown restart phase")
	print("FINAL_DRAGON_RESTART: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
