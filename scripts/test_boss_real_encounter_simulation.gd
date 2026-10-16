extends SceneTree
## Real boss encounter contract: 4 upgraded owned allies, actual generated enemies,
## actual battle rules, terminal state and persistent save. No fabricated victory.
const Session = preload("res://systems/run_session.gd")
const State = preload("res://systems/map_state.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const TRIALS = 80
const ENEMY_LEGION = "skeleton"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var failures := 0
	var wins := 0
	var losses := 0
	var stage_results: Dictionary = {}
	for trial in range(TRIALS):
		var session = Session.new()
		session.save_file_path = "user://boss_end_to_end_%d_%d.json" % [OS.get_process_id(),trial]
		root.add_child(session)
		session.start_new_world()
		var world = session.world
		world.rng.seed = trial + 99101
		var pool: Array = world.definitions.keys()
		pool = pool.filter(func(slug): return str(world.definitions[slug].get("grade","")) != "special")
		pool.sort()
		var generator = Rules.new(world.definitions,trial+99001)
		world.roster.clear()
		for i in range(4):
			var unit: Dictionary = generator.individual(str(pool[(trial * 4+i) % pool.size()]),world.next_id("unit"))
			unit.attack += 3
			unit.max_hp += 6
			unit.current_hp = unit.max_hp
			unit.altar_enhancements = 3
			var kinds: Array = generator.COUNTS.keys()
			while unit.brands.size() < 3:
				unit.brands.append(generator.make_brand(str(kinds[(trial+i+unit.brands.size()) % kinds.size()])))
			world.roster.append(unit)
		for lap_index in range([3,6,9,12][trial % 4]):
			world.lap_ready = true
			world.leave_home()
		if world.tiles[State.BOSS_TILE_INDEX] != "boss":
			printerr("BOSS ERROR boss tile missing trial=",trial)
			failures += 1
			session.queue_free()
			continue
		world.position = State.BOSS_TILE_INDEX
		var ids: Array = world.roster.map(func(u): return str(u.id))
		if not session.save_world() or not session.start_encounter(State.BOSS_TILE_INDEX,ids):
			printerr("BOSS ERROR cannot start actual encounter trial=",trial)
			failures += 1
			session.queue_free()
			continue
		var battle = Rules.new(world.definitions,trial+99100)
		if not battle.restore(session.encounter.checkpoint):
			printerr("BOSS ERROR cannot restore combat checkpoint trial=",trial)
			failures += 1
			session.queue_free()
			continue
		# Test-only boss enemy roster: activate the genuine skeleton legion.
		var enemy_team: Array = []
		for i in range(4):
			var slug: String = ["skeleton-spear","skeleton-archer","skeleton-cavalry","skeleton-spear"][i]
			enemy_team.append(battle.individual(slug,"enemy-"+str(i)))
		var ally_team: Array = world.roster.duplicate(true)
		battle.start(ally_team,enemy_team)
		if not battle.active("enemy",ENEMY_LEGION):
			printerr("BOSS ERROR skeleton legion inactive trial=",trial)
			failures += 1
			session.queue_free()
			continue
		session.encounter.checkpoint = battle.snapshot()
		world.active_encounter = session.encounter.duplicate(true)
		if not session.save_world():
			failures += 1
			session.queue_free()
			continue
		for round_index in range(80):
			if not battle.winner().is_empty(): break
			battle.begin_round()
			for action_index in range(80):
				if battle.next_action().is_empty(): break
		var stage: int = [20,40,60,80][trial % 4]
		if not stage_results.has(stage): stage_results[stage] = {"wins":0,"losses":0}
		if battle.winner().is_empty() or not session.finish_encounter(battle):
			printerr("BOSS ERROR unresolved/unsaved fight trial=",trial)
			failures += 1
		elif battle.winner() == "ally":
			wins += 1
			stage_results[stage].wins += 1
			if not State.BOSS_TILE_INDEX in world.cleared: failures += 1
		else:
			losses += 1
			stage_results[stage].losses += 1
			if world.run_result.get("reason","") != "battle_defeat": failures += 1
		print("BOSS contamination=",world.contamination," trial=",trial," winner=",battle.winner()," rounds=",battle.round_number," roster=",world.roster.size())
		for suffix in ["",".tmp"]:
			var path: String = session.save_file_path + suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		session.queue_free()
	print("BOSS test_enemy_legion=",ENEMY_LEGION," stage_results=",stage_results)
	print("BOSS trials=",TRIALS," wins=",wins," losses=",losses," failures=",failures)
	quit(0 if failures == 0 else 1)
