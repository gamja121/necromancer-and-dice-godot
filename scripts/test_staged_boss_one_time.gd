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
	var selected: Array=[str(w.roster[0].id),str(w.roster[1].id)]
	check(w.tiles[23]=="boss" and w.boss_available(),"%d: eligible boss tile appears" % stage)
	check(session.start_encounter(23,selected),"%d: existing battle entry accepts staged boss" % stage)
	if session.encounter.is_empty(): return
	check(session.encounter.enemies.size()==1 and str(session.encounter.enemies[0].slug)==w.current_boss_slug(),"%d: only selected boss species appears" % stage)
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
	check(w.tiles[23]!="boss" and not w.boss_available(),"%d: boss tile immediately disappears after victory" % stage)
	# Discard pending corpse rewards in this isolated test fixture; actual
	# corpse capture semantics are independently tested elsewhere.
	w.pending_reward={}
	check(session.save_world(),"%d: test save stores completed victory" % stage)
	session.reload_world()
	w=session.world
	check(BossStages.defeated(w.event_flags,stage) and w.tiles[23]!="boss","%d: stage cannot respawn on save reload" % stage)
	check(BossStages.valid(w.definitions,w.boss_assignments),"saved draw remains valid after reload")
	w.generate()
	check(w.tiles[23]!="boss","%d: stage does not return on next-lap shuffle" % stage)

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
	for pollution in [0,10,19]:
		world.contamination=pollution
		world.generate()
		check(world.tiles[23]!="boss","corruption %d has no early boss" % pollution)
	for pollution in [20,40,60]:
		world.contamination=pollution
		world.generate()
		check(world.tiles[23]=="boss","new tier %d has a boss before defeat" % pollution)
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
	check(world.reveal_boss_at_threshold() and world.tiles[23]=="boss","real existing final-story prerequisite unlocks dragon")
	check(BossStages.boss_slug(80,world.boss_assignments)=="dragon" and not BossStages.defeated(world.event_flags,80),"dragon remains separate one-time final stage")
	world.mark_boss_defeated(80)
	check(world.conceal_boss_below_threshold(),"final boss can be retired after victory")
	world.generate()
	check(world.tiles[23]!="boss","defeated dragon cannot reappear on later maps")
	session.save_file_path=old_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("STAGED_BOSS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
