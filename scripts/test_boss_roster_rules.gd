extends SceneTree
## User-approved: 3 reserved run bosses, 20/40/60 gates, tile grades and no respawn.
const BossRoster = preload("res://systems/boss_roster.gd")
const MapState = preload("res://systems/map_state.gd")
const EncounterGenerator = preload("res://systems/encounter_generator.gd")
const BattleRules = preload("res://systems/battlefield_rules.gd")
const CultistAltarEnemies = preload("res://systems/cultist_altar_enemies.gd")
const RitualPortalEnemies = preload("res://systems/ritual_portal_enemies.gd")
var passed = 0
var failed = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS boss-rules: ",label)
	else:
		failed += 1
		printerr("FAIL boss-rules: ",label)

func _run() -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var state = MapState.new(definitions,221)
	check(BossRoster.CANDIDATES.size()==6, "six canonical hero boss candidates")
	check(BossRoster.valid_order(state.boss_order),"three distinct bosses chosen once at run creation")
	for slug in BossRoster.CANDIDATES:
		check(definitions[slug].grade=="hero","candidate has hero grade: "+slug)
		for tier in BossRoster.TIERS:
			check(BossRoster.valid_formation(definitions,slug,tier,BossRoster.CANDIDATES),"formation legal at %d for %s" % [tier,slug])
	for seed_value in range(30):
		var sample = MapState.new(definitions,seed_value)
		check(BossRoster.valid_order(sample.boss_order),"valid boss lottery seed %d" % seed_value)
	var initial_order: Array = state.boss_order.duplicate()
	for contamination_level in [0,16,19]:
		state.contamination=contamination_level
		state.boss_peak=contamination_level
		state.generate()
		check(state.tiles.count("rare-monster")==0 and state.tiles[23]=="monster","no yellow or red monster stones below 20")
	state.contamination=20
	state.boss_peak=20
	state.generate()
	check(state.tiles[23]=="boss" and state.current_boss_tier()==20,"tier 20 appears on reserved red stone")
	check(state.boss_order==initial_order,"stone shuffle never redraws run bosses")
	state.boss_defeated=[20]
	state.generate()
	check(state.tiles[23]=="monster" and state.current_boss_tier()==0,"defeated tier 20 never respawns before 40")
	state.boss_peak=40
	check(state.reveal_boss_at_threshold() and state.current_boss_tier()==40,"queued tier 40 unlocked after 20 clear")
	state.boss_defeated=[20,40]
	state.boss_peak=60
	state.generate()
	check(state.tiles[23]=="boss" and state.current_boss_tier()==60,"tier 60 waits for both prior clears")
	state.boss_defeated=[20,40,60]
	state.generate()
	check(state.tiles[23]=="monster" and state.current_boss_tier()==0,"all 3 cleared: no recurring red boss stone")
	state.contamination=100
	state.generate()
	check(state.current_boss_tier()==0,"unimplemented final boss is not replaced with a repeat hero")
	var stored: Dictionary = state.snapshot().duplicate(true)
	var loaded = MapState.new(definitions,9999)
	check(loaded.restore(stored),"saved boss order and defeat state restores")
	check(loaded.boss_order==initial_order and loaded.boss_defeated==[20,40,60] and loaded.boss_peak==100,"boss roster and peak survive reload")

	# Green parties contain only normals. Yellow parties always include advanced/hero.
	var rng=RandomNumberGenerator.new()
	rng.seed=4401
	for tier in [0,20,40,60,80]:
		for i in range(20):
			var normals: Array = EncounterGenerator.slugs(definitions,tier,3,rng,{},"monster",initial_order)
			check(not normals.is_empty() and normals.all(func(id): return definitions[id].grade=="normal" and not id in initial_order),"green grade and reservation at %d" % tier)
			if tier>=20:
				var yellow: Array = EncounterGenerator.slugs(definitions,tier,3,rng,{},"rare-monster",initial_order)
				check(not yellow.is_empty() and yellow.any(func(id): return definitions[id].grade in ["advanced","hero"]) and yellow.all(func(id): return not id in initial_order),"yellow grade and reservation at %d" % tier)
	var available: Dictionary = definitions.duplicate()
	for slug in initial_order: available.erase(slug)
	for i in range(25):
		var altar: Array = CultistAltarEnemies.select(available,rng)
		var portal: Array = RitualPortalEnemies.select(available,rng)
		check(altar.all(func(id): return not id in initial_order),"cultist story excludes reserved heroes")
		check(portal.all(func(id): return not id in initial_order),"ritual story excludes reserved heroes")

	var rules = BattleRules.new(definitions,93)
	rules.forbidden_species = ["crystal-devourer"]
	var source = rules.individual("skeleton-spear","ally-a")
	var seed_unit = rules.individual("guardian-seed","enemy-seed")
	rules.start([source],[seed_unit])
	for unit in rules.units:
		if unit.slug=="guardian-seed": unit.born_round=0
	rules.round_number=3
	rules.summon_round()
	check(rules.units.any(func(u): return u.slug=="raging-treant") and not rules.units.any(func(u): return u.slug=="crystal-devourer"),"reserved plant cannot appear via seed growth")
	var restored_rules=BattleRules.new(definitions,98)
	check(restored_rules.restore(rules.snapshot()) and "crystal-devourer" in restored_rules.forbidden_species,"summon exclusion survives checkpoint reload")

	var session = root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload exists")
		quit(1)
		return
	var old_path: String=session.save_file_path
	var test_path="user://boss_roster_rules_test.json"
	session.save_file_path=test_path
	session.start_new_world()
	session.world.contamination=20
	session.world.boss_peak=20
	session.world.generate()
	session.world.position=MapState.BOSS_TILE_INDEX
	check(session.save_world(),"boss combat fixture saved")
	var selected: Array=session.world.roster.map(func(u): return str(u.id))
	check(session.start_encounter(MapState.BOSS_TILE_INDEX,selected),"run starts actual tier 20 boss battle")
	if not session.encounter.is_empty():
		var ids: Array=session.encounter.enemies.map(func(u): return str(u.slug))
		check(ids==BossRoster.formation(session.world.boss_order[0],20) and ids.size()==3,"real battle fields selected boss and two normals")
		var battle=BattleRules.new(definitions,32)
		check(battle.restore(session.encounter.checkpoint),"battle checkpoint restores")
		for unit in battle.units:
			if unit.team=="enemy":
				unit.hp=0
				unit.alive=false
		check(session.finish_encounter(battle),"tier 20 boss defeat saved")
		check(session.world.boss_defeated==[20] and session.world.tiles[23]=="monster","boss becomes permanently defeated at stone 24")
		check(session.world.pending_reward.get("corpses",[]).all(func(item): return not item.slug in session.world.boss_order),"boss corpse is never capturable")
		session.reload_world()
		check(session.world.boss_defeated==[20] and session.world.tiles[23]=="monster","real run clear survives disk reload")
		session.world.pending_reward={}
		session.world.contamination=40
		var before=session.world.snapshot().duplicate(true)
		check(session.persist_change(before),"next unlocked tier persisted")
		check(session.world.current_boss_tier()==40 and session.world.tiles[23]=="boss","queued 40 boss replaces green stone immediately")
	session.save_file_path=old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("BOSS_ROSTER_RULES: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
