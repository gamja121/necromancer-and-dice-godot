extends SceneTree
## Regression: one chosen exclusive boss at 20, a new boss at 40,
## final story-gated dragon at 80, all once per run and across reloads.
const Session = preload("res://systems/run_session.gd")
const State = preload("res://systems/map_state.gd")
const EncounterGenerator = preload("res://systems/encounter_generator.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const FinalStory = preload("res://scripts/boss_story_test_fixture.gd")
var good=0
var bad=0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, text_label: String) -> void:
	if ok:
		good+=1
		print("PASS staged-boss: ",text_label)
	else:
		bad+=1
		printerr("FAIL staged-boss: ",text_label)

func win_boss(session: Node) -> void:
	var b=Rules.new(session.world.definitions,404)
	check(b.restore(session.encounter.checkpoint),"encounter battle checkpoint restores")
	if b.units.is_empty(): return
	for u in b.units:
		if u.team=="enemy":
			u.hp=0
			u.alive=false
	check(b.winner()=="ally","test win results from defeated enemies")
	check(session.finish_encounter(b),"boss victory commits exact stage in saved world")

func verify_once_and_select(session: Node, stage: int, last_slug: String = "") -> String:
	var w=session.world
	check(w.boss_stage()==stage and w.tiles[23]=="boss","stage %d has one boss stone" % stage)
	w.position=23
	var before: int=w.rng.state
	var r: Dictionary=session.prepare_boss_offers(23)
	check(r.get("ok",false) and r.get("offers",[]).size()==3,"stage %d shows three selectable bosses" % stage)
	if not r.get("ok",false): return ""
	var offers: Array=r.offers
	check(not offers.has(last_slug) if not last_slug.is_empty() else true,"previously selected boss never returns in next candidate list")
	check(offers.all(func(slug): return EncounterGenerator.BOSS_CANDIDATES.has(slug)),"all stage choices are exclusive bosses")
	var name: String=str(offers[0])
	check(not session.start_encounter(23,w.roster.map(func(unit): return str(unit.id))),"boss battle cannot start before choice")
	check(session.select_stage_boss(23,name),"player selects one available boss")
	check(not session.select_stage_boss(23,str(offers[1])),"chosen boss cannot be changed after confirmation")
	var frozen: int=w.rng.state
	session.reload_world()
	w=session.world
	check(w.boss_stage()==stage and w.boss_selected(stage)==name and w.boss_offers(stage)==offers,"selection and offers survive restart")
	check(w.rng.state==frozen and session.prepare_boss_offers(23).offers==offers,"reopen does not reroll stage choices")
	check(session.start_encounter(23,w.roster.map(func(unit): return str(unit.id))),"chosen boss enters battle")
	check(session.encounter.enemies.size()==1 and session.encounter.enemies[0].slug==name,"only the selected species appears in battle")
	check(int(session.encounter.get("boss_stage",-1))==stage,"encounter persists precise stage identity")
	win_boss(session)
	check(session.world.boss_progress.defeated.has(stage),"victory marks stage %d defeated" % stage)
	check(session.world.boss_stage()!=stage,"stage %d immediately becomes unavailable" % stage)
	return name

func verify_legacy_dragon_save(session: Node) -> void:
	session.start_new_world()
	var world=session.world
	world.contamination=80
	FinalStory.seed_completed_final_hunt(world)
	world.boss_progress.defeated=[20,40]
	world.generate()
	world.position=23
	check(session.start_encounter(23,world.roster.map(func(unit): return str(unit.id))),"legacy fixture creates final dragon fight")
	world.active_encounter.erase("boss_stage")
	check(session.save_world(),"save an old final encounter without a boss stage")
	session.reload_world()
	check(session.encounter.get("type","")=="boss" and int(session.encounter.get("boss_stage",0))==80,"old in-progress dragon fight resumes at stage80")
	check(session.world.boss_progress.defeated==[20,40] and session.world.boss_stage()==80,"older final encounter never regresses to stage20")
	session.world.active_encounter={}
	session.encounter={}
	session.world.pending_reward={"kind":"capture","corpses":[{"slug":"dragon","id":"old-dead-dragon"}]}
	check(session.save_world(),"simulate historical already-defeated dragon capture save")
	session.world.boss_progress.defeated=[]
	check(session.save_world(),"store historical capture without stage records")
	session.reload_world()
	check(session.world.boss_progress.defeated==[20,40,80] and session.world.boss_stage()==0,"legacy dead dragon capture never respawns any boss")

func _run() -> void:
	var sess=root.get_node_or_null("RunSession")
	var created: bool=sess==null
	if created:
		sess=Session.new()
		sess.name="RunSession"
		root.add_child(sess)
	var previous: String=sess.save_file_path
	var tmp: String="user://test_staged_boss_%d.json" % OS.get_process_id()
	sess.save_file_path=tmp
	sess.start_new_world()
	var w=sess.world
	check(State.FIRST_BOSS_CONTAMINATION==20 and State.SECOND_BOSS_CONTAMINATION==40 and State.BOSS_CONTAMINATION==80,"three contamination thresholds unchanged by lap")
	check(EncounterGenerator.BOSS_CANDIDATES.size()==6,"six hero bosses reserved exclusively for player selection")
	var normal: Array=EncounterGenerator.eligible_roster(w.definitions)
	check(EncounterGenerator.BOSS_CANDIDATES.all(func(slug): return not normal.has(slug)),"no boss candidate appears in monster, shop, or treasure pool")
	for level in [0,19]:
		w.contamination=level
		w.generate()
		check(not w.boss_available() and w.tiles[23]!="boss","no boss below contamination 20")
	w.contamination=20
	w.generate()
	var first: String=verify_once_and_select(sess,20)
	w=sess.world
	check(w.tiles[23]!="boss","first defeated boss tile disappears")
	w.pending_reward={}
	w.contamination=39
	w.generate()
	check(w.tiles[23]!="boss" and w.boss_stage()==0,"first boss never returns before stage 40")
	w.contamination=40
	w.generate()
	var second: String=verify_once_and_select(sess,40,first)
	w=sess.world
	check(w.boss_progress.defeated.has(20) and w.boss_progress.defeated.has(40),"both boss stages retain clear flags")
	w.pending_reward={}
	w.contamination=79
	w.generate()
	check(w.tiles[23]!="boss" and w.boss_stage()==0,"no duplicate boss between 40 and final 80")
	w.contamination=100
	w.generate()
	check(w.tiles[23]!="boss","final dragon remains story-locked at contamination100")
	FinalStory.seed_completed_final_hunt(w,false)
	w.generate()
	check(w.tiles[23]!="boss","fifth story scene without Finish still blocks dragon")
	w.event_flags["event:monster_king_hunt_trace_01:final_acknowledged"]=true
	w.contamination=80
	w.generate()
	check(w.boss_stage()==80 and w.tiles[23]=="boss","final story and 80 unlock dragon once")
	w.position=23
	check(sess.start_encounter(23,w.roster.map(func(unit): return str(unit.id))),"dragon battle starts after both earlier stages")
	check(sess.encounter.enemies.size()==1 and sess.encounter.enemies[0].slug=="dragon" and int(sess.encounter.get("boss_stage",0))==80,"final stage preserves solitary dragon")
	win_boss(sess)
	w=sess.world
	check(w.boss_progress.defeated.has(80) and w.tiles[23]!="boss","defeated final dragon cannot respawn")
	w.pending_reward={}
	w.contamination=100
	w.generate()
	check(w.tiles[23]!="boss" and w.boss_stage()==0,"even at contamination100 final defeat stays permanent")
	check(sess.save_world(),"all clears saved")
	sess.reload_world()
	w=sess.world
	check(w.boss_progress.defeated.size()==3 and w.tiles[23]!="boss","all boss clear flags survive process save/load")
	check(w.boss_selected(20)==first and w.boss_selected(40)==second,"two chosen boss identities saved after reload")
	verify_legacy_dragon_save(sess)
	sess.save_file_path=previous
	if created: sess.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(tmp+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp+suffix))
	print("STAGED_BOSS_CHOICES: %d passed, %d failed" % [good,bad])
	quit(0 if bad==0 else 1)
