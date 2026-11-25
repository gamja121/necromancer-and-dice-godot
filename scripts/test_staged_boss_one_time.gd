extends SceneTree
## Staged bosses: only one stage encounter per run, distinct boss types,
## selected species stay exclusive to boss encounters; three unselected
## candidates are ordinary hero-grade enemies and reward candidates.
const SessionScript = preload("res://systems/run_session.gd")
const BossStages = preload("res://systems/boss_stage_catalog.gd")
const EncounterGenerator = preload("res://systems/encounter_generator.gd")
const Battle = preload("res://systems/battlefield_rules.gd")
const StoryFixture = preload("res://scripts/boss_story_test_fixture.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS staged-boss: ",what)
	else:
		failed+=1
		printerr("FAIL staged-boss: ",what)

func _fight_and_win(session: Node, stage: int) -> void:
	var w=session.world
	w.position = 23
	var selected: Array=[str(w.roster[0].id),str(w.roster[1].id)]
	check(w.tiles[23]=="boss" and w.boss_available(),"%d: eligible boss tile appears" % stage)
	check(session.start_encounter(23,selected),"%d: existing battle entry accepts staged boss" % stage)
	if session.encounter.is_empty(): return
	var expected := BossStages.formation(stage,w.boss_assignments)
	var boss: String = w.current_boss_slug()
	check(session.encounter.enemies.map(func(enemy): return str(enemy.slug))==expected,"%d: actual enemies match the assigned boss and escorts" % stage)
	check(int(session.encounter.get("boss_stage",0))==stage,"%d: encounter persists stage id" % stage)
	var battle=Battle.new(w.definitions,91)
	check(battle.restore(session.encounter.checkpoint),"%d: live battle can be restored" % stage)
	for enemy in battle.units:
		if enemy.team=="enemy":
			enemy.hp=0
			enemy.alive=false
	check(battle.winner()=="ally","%d: battle is won by allies" % stage)
	check(session.finish_encounter(battle),"%d: victory is durably committed" % stage)
	check(BossStages.defeated(w.event_flags,stage),"%d: stage defeat receipt committed" % stage)
	check(w.tiles[23]=="boss-cleared" and 23 in w.cleared and not w.boss_available(),"%d: victory stores the dedicated defeated boss tile" % stage)
	if stage == 20:
		# Simulate the previous release's generic cleared stone while the
		# same victory's boss harvest is still recoverable.
		w.tiles[23] = "monster"
		check(session.save_world() and session.reload_world(), "legacy harvest save loads")
		w = session.world
		check(w.tiles[23] == "boss-cleared", "pending boss harvest proves which old stone to repair")
	var selected_corpse: int = int(w.pending_reward.selected)
	check(w.pending_reward.corpses.size()==expected.size() and w.pending_reward.corpses[selected_corpse].slug==boss,
		"%d: harvest offers the whole enemy party and starts on the boss" % stage)
	check(session.select_capture(selected_corpse), "%d: normal boss harvest accepts the defeated monster" % stage)
	var roller := RandomNumberGenerator.new()
	for seed in range(1,100):
		roller.seed = seed
		if roller.randi_range(1,6) == 6:
			w.rng.seed = seed
			break
	var rolled: Dictionary = session.roll_capture()
	check(rolled.get("success",false) and session.claim_reward().get("ok",false) and w.roster.any(func(card): return card.slug==boss),
		"%d: boss harvest awards the chosen boss" % stage)
	check(not session.start_encounter(23,selected), "%d: settled boss tile rejects a second battle" % stage)
	session.reload_world()
	w=session.world
	check(BossStages.defeated(w.event_flags,stage) and w.tiles[23]=="boss-cleared","%d: same board keeps the defeated boss tile after reload" % stage)
	check(BossStages.valid(w.definitions,w.boss_assignments),"saved draw remains valid after reload")
	w.generate()
	check(w.tiles[23] not in ["boss","boss-cleared"] and 23 not in w.cleared,"%d: next-lap shuffle replaces the retired stone without respawning its boss" % stage)

func _verify_formations(session: Node) -> void:
	for stage in BossStages.STAGES:
		for slug in BossStages.CANDIDATES:
			session.start_new_world()
			var w = session.world
			var other_bosses: Array = BossStages.CANDIDATES.duplicate()
			other_bosses.erase(slug)
			for tier in BossStages.STAGES:
				w.boss_assignments[str(tier)] = slug if tier == stage else other_bosses.pop_front()
			w.contamination = stage
			w.generate()
			var hill: int = w.tiles.find("basic")
			w.tiles[hill] = "forest"
			w.position = hill
			var scout: Dictionary = session.scout_hill(hill)
			var size: int = 3 if stage == 20 else 4
			check(scout.get("ok",false) and scout.intel.any(func(entry): return entry.type=="boss" and int(entry.count)==size and entry.grade=="hero"),
				"%d / %s: scout saves the actual boss count" % [stage,slug])
			var raw_intel: Array = w.scout.intel
			var old_row: Dictionary = raw_intel.filter(func(entry): return entry.type=="boss").front()
			old_row.count = 1
			check(session.active_scout_intel().any(func(entry): return entry.type=="boss" and int(entry.count)==size),
				"%d / %s: old scout entries show the current formation" % [stage,slug])
			w.position = 23
			var roster: Array = [str(w.roster[0].id)]
			if not session.start_encounter(23,roster):
				check(false,"%d / %s: actual boss encounter opens" % [stage,slug])
				continue
			var enemies: Array = session.encounter.enemies
			var party: Array = enemies.map(func(unit): return str(unit.slug))
			var grades: Array = enemies.map(func(unit): return str(unit.grade))
			check(party.size()==size and party[1]==slug and party.count(slug)==1,
				"%d / %s: assigned boss is in its formation slot with %d enemies" % [stage,slug,size])
			check(grades.count("hero")==1 and grades.count("advanced")==BossStages.STAGES.find(stage),
				"%d / %s: escorts respect the tier's grade mix" % [stage,slug])
			var reserved := BossStages.reserved_slugs(w.boss_assignments)
			check(party.filter(func(member): return member in reserved)==[slug],
				"%d / %s: the assigned boss is the only reserved species" % [stage,slug])
			if stage == 60:
				var battle := Battle.new(w.definitions,0)
				check(battle.restore(session.encounter.checkpoint) and not battle.legions.enemy.active.is_empty(),
					"60 / %s: initial enemy party activates a legion" % slug)


func _verify_legacy_solo(session: Node) -> void:
	session.start_new_world()
	var w = session.world
	w.contamination = 40
	w.generate()
	w.position = 23
	var started: bool = session.start_encounter(23,[str(w.roster[0].id)])
	check(started,"legacy solo fixture enters stage 40")
	if not started: return
	var original: Dictionary = session.encounter.enemies[1].duplicate(true)
	original.id = "enemy-0"
	var battle := Battle.new(w.definitions,0)
	battle.start(session.encounter.allies,[original])
	session.encounter.enemies = [original]
	session.encounter.checkpoint = battle.snapshot()
	w.active_encounter = session.encounter.duplicate(true)
	check(session.save_world() and session.reload_world(),"legacy single-enemy checkpoint can be loaded")
	check(session.encounter.enemies.size()==1 and session.encounter.enemies[0].slug==original.slug and session.encounter.checkpoint.units.size()==2,
		"already-started solo encounter keeps its original enemy and checkpoint")


func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SessionScript.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	var scratch: String="user://staged_boss_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var world=session.world
	var definitions: Dictionary=world.definitions
	check(BossStages.valid(definitions,world.boss_assignments),"three distinct candidates selected in this expedition")
	check(BossStages.CANDIDATES.size()==6 and BossStages.reserved_slugs(world.boss_assignments).size()==4,"six candidates yield three selected boss-only species plus the final dragon")
	var seen_species: Dictionary={}
	var seen_rosters: Dictionary={}
	var all_draws_valid: bool=true
	for seed in range(1,101):
		var draw: Dictionary=BossStages.roll_assignments(seed)
		if not BossStages.valid(definitions,draw): all_draws_valid=false
		seen_rosters[JSON.stringify(draw)]=true
		for stage in BossStages.STAGES:
			seen_species[str(draw[str(stage)])]=true
	check(all_draws_valid,"100 generated expeditions use three distinct eligible bosses")
	check(seen_rosters.size()>1,"different expedition seeds roll different boss trios")
	check(seen_species.size()==6,"all six boss species can be drawn across expeditions")
	var original_draw: Dictionary=world.boss_assignments.duplicate(true)
	check(BossStages.valid(definitions,original_draw),"initial boss assignment is valid")
	var old_snapshot: Dictionary=world.snapshot().duplicate(true)
	old_snapshot.erase("boss_assignments")
	var legacy_world=load("res://systems/map_state.gd").new(definitions,123)
	check(legacy_world.restore(old_snapshot) and legacy_world.boss_assignments==BossStages.legacy_assignments(),"old saves retain the previous fixed trio")
	check(world.snapshot().boss_assignments==original_draw,"legacy restore does not mutate active run")
	check(BossStages.current_stage(19)==0 and BossStages.current_stage(20)==20 and BossStages.current_stage(39)==20,"first stage is 20 to 39")
	check(BossStages.current_stage(40)==40 and BossStages.current_stage(59)==40 and BossStages.current_stage(60)==60 and BossStages.current_stage(79)==60,"next stages are 40 and 60")
	check(BossStages.current_stage(80)==80,"final dragon retains separate 80+ gate")
	var selected: Array=BossStages.reserved_slugs(original_draw)
	var eligible: Array=EncounterGenerator.eligible_roster(definitions,original_draw)
	check(eligible.size()==41,"16 normal, 19 advanced, and six ordinary heroes are available per expedition")
	check(eligible.has("dracula") and not eligible.has("dragon"),"hero Dracula is eligible; the story-only dragon is still final-only")
	for slug in selected:
		check(not slug in eligible,"this expedition's reserved boss %s never appears in normal rolls or rewards" % slug)
	for slug in BossStages.CANDIDATES:
		if not slug in selected:
			check(slug in eligible,"unchosen stage candidate %s returns to regular hero-grade roster" % slug)
	# The same reservation applies to every map seed and survives JSON restore.
	var seen_unselected: Dictionary={}
	for seed in range(1,101):
		var assignment: Dictionary=BossStages.roll_assignments(seed)
		var candidates: Array=EncounterGenerator.eligible_roster(definitions,assignment)
		var blocked: Array=BossStages.reserved_slugs(assignment)
		check(candidates.size()==41 and blocked.size()==4 and blocked.all(func(slug): return not slug in candidates),"seed %d protects only current bosses" % seed)
		for slug in BossStages.CANDIDATES:
			if not slug in blocked and slug in candidates: seen_unselected[slug]=true
	check(seen_unselected.size()==6,"every boss candidate can appear as a normal hero in another expedition")
	# Exercising the *actual* encounter generator also validates selected boss
	# exclusion and a nonzero chance to encounter Dracula and spare candidates.
	var seen_random: Dictionary={}
	var rare_rng=RandomNumberGenerator.new()
	rare_rng.seed=425709
	var rare_valid: bool=true
	for trial in range(1200):
		var slugs: Array=EncounterGenerator.slugs(definitions,80,5,rare_rng,{},"rare-monster",original_draw)
		for slug in slugs:
			if not slug in eligible: rare_valid=false
			seen_random[slug]=true
	check(rare_valid,"all 1200 corruption-80 encounters exclude assigned bosses and the final dragon")
	check(seen_random.has("dracula"),"Dracula can naturally spawn as a hero in rare-monster combat")
	for slug in BossStages.CANDIDATES:
		if not slug in selected:
			check(seen_random.has(slug),"unchosen boss candidate %s actually appears in real rare-tile battles" % slug)
	var stage_fixture: Dictionary=world.snapshot().duplicate(true)
	for pollution in [0,10,19]:
		world.contamination=pollution
		world.generate()
		check(world.tiles[23]!="boss","corruption %d has no early boss" % pollution)
	for pollution in [20,40,60]:
		world.contamination=pollution
		world.generate()
		check(world.tiles[23]=="boss","new tier %d has a boss before defeat" % pollution)
	check(world.restore(stage_fixture),"independent stage preview fixtures restore before actual fights")
	# 20 wins are one-time even when pollution returns to 20 from above.
	world.contamination=20
	world.generate()
	_fight_and_win(session,20)
	world=session.world
	check(world.boss_assignments==original_draw,"first victory and reload preserve full stage draw")
	world.contamination=39
	world.generate()
	check(world.tiles[23]!="boss","defeated first stage never returns at 39")
	world.contamination=40
	world.generate()
	_fight_and_win(session,40)
	world=session.world
	check(world.boss_assignments==original_draw,"second victory and reload preserve full stage draw")
	world.contamination=41
	world.generate()
	check(world.tiles[23]!="boss","defeated second stage never returns")
	world.contamination=60
	world.generate()
	_fight_and_win(session,60)
	world=session.world
	check(world.boss_assignments==original_draw,"third victory and reload preserve full stage draw")
	world.contamination=79
	world.generate()
	check(world.tiles[23]!="boss","defeated third stage never returns")
	world.contamination=80
	world.generate()
	check(world.tiles[23]!="boss","80+ dragon still needs acknowledged final story")
	StoryFixture.seed_completed_final_hunt(world)
	check(world.refresh_final_wormhole() and world.final_dragon_location()>=0 and world.tiles[23]!="boss","real final-story prerequisite unlocks the wormhole")
	check(BossStages.boss_slug(80,world.boss_assignments)=="dragon" and not BossStages.defeated(world.event_flags,80),"dragon remains separate one-time final stage")
	world.mark_boss_defeated(80)
	check(world.final_dragon_location()==-1,"final encounter retires after victory")
	world.generate()
	check(world.tiles[23]!="boss","defeated dragon cannot reappear on later maps")
	_verify_formations(session)
	_verify_legacy_solo(session)
	session.save_file_path=old_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("STAGED_BOSS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
