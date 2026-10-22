extends SceneTree
## Contamination-80 dragon uses only existing bone + undying mechanics; no lap gates.
const SessionScript = preload("res://systems/run_session.gd")
const Battle = preload("res://systems/battlefield_rules.gd")
const EncounterGenerator = preload("res://systems/encounter_generator.gd")
const StoryFixture = preload("res://scripts/boss_story_test_fixture.gd")
const Hunt = preload("res://systems/monster_king_hunt_entry.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS final-dragon: ",message)
	else:
		failed += 1
		printerr("FAIL final-dragon: ",message)

func battle_at(session: Node, pollution: int, lap: int) -> bool:
	session.start_new_world()
	var w=session.world
	w.laps=lap
	w.contamination=pollution
	StoryFixture.seed_completed_final_hunt(w)
	w.boss_progress.defeated=[20,40]
	w.generate()
	check((w.tiles[23]=="boss")==(pollution>=80),"post-story boss tile only at contamination %d, lap %d" % [pollution,lap])
	var ids: Array=[w.roster[0].id,w.roster[1].id]
	if pollution<80:
		# The old fixed slot can hold an ordinary monster at 79.
		# We must forbid the DRAGON boss, not all nonboss combat.
		var started: bool=session.start_encounter(23,ids)
		return not started or (session.encounter.get("type","")!="boss" and session.encounter.get("enemies",[]).all(func(u): return str(u.slug)!="dragon"))
	return session.start_encounter(23,ids)

func test_stats_and_spawn(session: Node) -> void:
	var data: Dictionary=session.world.definitions
	check(data.has("dragon"),"dragon is registered in the live monster data")
	if not data.has("dragon"): return
	var boss=data.dragon
	check(int(boss.hp)==70 and int(boss.attack)==5 and int(boss.speed)==4,"dragon base stats are exactly HP70 attack5 speed4")
	check(boss.passives==["bone"] and boss.brands.is_empty(),"dragon template has no custom gimmick, added brands or ordinary dual passive")
	check(not "dragon" in EncounterGenerator.eligible_roster(data),"dragon cannot spawn in standard encounters or random card rewards")
	# Even max contamination is insufficient before the genuine last story beat.
	session.start_new_world()
	var world=session.world
	world.contamination=100
	world.boss_progress.defeated=[20,40]
	world.generate()
	check(world.tiles[23]!="boss" and not world.boss_available(),"completed early bosses do not unlock dragon without final story")
	StoryFixture.seed_completed_final_hunt(world,false)
	world.generate()
	check(Hunt.completed(session) and world.tiles[23]!="boss","completed fifth scene without explicit Finish is still locked")
	world.event_flags["event:monster_king_hunt_trace_01:final_acknowledged"]=true
	world.generate()
	check(world.tiles[23]=="boss" and world.boss_available(),"fifth-scene Finish unlocks boss at already-high contamination")
	world.event_flags["event:monster_king_hunt_trace_01:final_acknowledged"]=false
	check(not world.boss_available(),"removing explicit final acknowledgment relocks boss")
	check(battle_at(session,79,60),"lap 60 does not grant boss when contamination is 79")
	check(session.encounter.is_empty() or (session.encounter.type!="boss" and session.encounter.enemies.all(func(u): return u.slug!="dragon")),"low contamination permits regular monsters but never the dragon boss")
	check(battle_at(session,80,0),"even lap 0 can trigger boss when contamination reaches 80")
	check(session.encounter.type=="boss" and session.encounter.enemies.size()==1 and session.encounter.enemies[0].slug=="dragon","completed early tiers + story + contamination select lone dragon without lap gate")
	check(battle_at(session,80,59),"lap 59 receives final boss at contamination 80")
	check(session.encounter.enemies.size()==1 and session.encounter.enemies[0].slug=="dragon","no obsolete lap 60 requirement")
	check(battle_at(session,80,60),"lap 60 also receives same boss at contamination 80")
	check(session.encounter.type=="boss" and session.encounter.enemies.size()==1,"final encounter contains exactly one enemy")
	if session.encounter.enemies.size()!=1: return
	var dragon: Dictionary=session.encounter.enemies[0]
	check(dragon.slug=="dragon" and dragon.max_hp==70 and dragon.attack==5 and dragon.speed==4,"final enemy has requested base stats with no extra phase")
	check(dragon.passive=="bone" and dragon.get("boss_extra_passive","")=="undying" and dragon.get("final_boss",false),"only final enemy is explicitly marked with two existing passives")
	check(Battle.has_passive({"slug":"dragon","team":"enemy","passive":"bone","final_boss":true,"boss_extra_passive":"undying"},"undying"),"second passive activates on final dragon")
	check(not Battle.has_passive({"slug":"dragon","team":"ally","passive":"bone","final_boss":true,"boss_extra_passive":"undying"},"undying"),"recruited dragon cannot use final-boss-only extra passive")
	check(not Battle.has_passive({"slug":"hydra","team":"enemy","passive":"bone","final_boss":true,"boss_extra_passive":"undying"},"undying"),"ordinary enemy cannot gain bonus passive through extra field")

func test_damage_and_checkpoint(session: Node) -> void:
	var snapshot: Dictionary=session.world.snapshot().duplicate(true)
	var checkpoint: Dictionary=session.encounter.checkpoint.duplicate(true)
	var battle=Battle.new(session.world.definitions,712)
	check(battle.restore(checkpoint),"live boss battle checkpoint restores")
	var enemy: Dictionary=battle.find_id("enemy-0")
	check(not enemy.is_empty() and enemy.hp==70 and Battle.has_passive(enemy,"bone") and Battle.has_passive(enemy,"undying"),"checkpoint preserves both passives and initial HP")
	if enemy.is_empty(): return
	var starting_hp: int=int(enemy.hp)
	battle.damage(enemy,10)
	check(enemy.hp==starting_hp-9,"bone reduces a normal attack hit 10 to 9")
	battle.damage(enemy,3,{},"counter")
	check(enemy.hp==starting_hp-11,"bone also reduces counter damage by 1")
	check(battle.has_passive(enemy,"undying"),"undying is available in the same combatant as bone")
	enemy.hp=2
	battle.damage(enemy,20)
	check(enemy.hp==1 and enemy.alive and enemy.undying_used,"lethal damage is survived once at 1 HP")
	var saved: Dictionary=battle.snapshot().duplicate(true)
	var reopened=Battle.new(session.world.definitions,999)
	check(reopened.restore(saved),"damaged boss round-trip snapshot restores")
	var restored: Dictionary=reopened.find_id("enemy-0")
	check(restored.hp==1 and restored.undying_used and Battle.has_passive(restored,"bone") and Battle.has_passive(restored,"undying"),"both passives and spent undying survive battle restore")
	reopened.damage(restored,2)
	check(restored.hp==0 and not restored.alive,"second lethal hit defeats the boss normally")
	# Restore the exact original encounter checkpoint for world save/restart.
	session.world.restore(snapshot)
	session.encounter=session.world.active_encounter.duplicate(true)
	session.reload_world()
	check(session.encounter.type=="boss" and session.encounter.enemies.size()==1 and session.encounter.enemies[0].slug=="dragon","saved game resumes same contamination-80 dragon, never rerolls")
	var persisted=Battle.new(session.world.definitions,177)
	check(persisted.restore(session.encounter.checkpoint) and persisted.find_id("enemy-0").get("boss_extra_passive","")=="undying","battle-state persisted with second passive")

func test_recruitment(session: Node) -> void:
	var before_state: Dictionary=session.world.snapshot().duplicate(true)
	var original: Dictionary=session.encounter.enemies[0].duplicate(true)
	var material: Dictionary={"id":original.id,"slug":original.slug,"unit":original}
	var captured: Dictionary=session.create_item("unit",material)
	check(captured.slug=="dragon" and captured.max_hp==20 and captured.attack==4 and captured.speed==3,"boss capture converts to earlier proposed recruit stats 20/4/3")
	check(captured.passive=="bone" and not captured.has("boss_extra_passive") and not captured.has("final_boss"),"captured dragon has only one ordinary passive")
	check(captured.current_hp==20,"capture starts with full normalized HP")
	session.world.restore(before_state)
	session.encounter=session.world.active_encounter.duplicate(true)
	var fallback: Dictionary=session.create_item("unit",{"slug":"dragon"})
	check(fallback.max_hp==20 and fallback.attack==4 and fallback.speed==3 and fallback.passive=="bone","legacy capture fallback also normalizes the dragon")

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SessionScript.new()
		session.name="RunSession"
		root.add_child(session)
	var prior: String=session.save_file_path
	var scratch: String="user://test_final_dragon_boss_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	test_stats_and_spawn(session)
	if not session.encounter.is_empty() and session.encounter.get("type","")=="boss" and session.encounter.enemies.size()==1 and session.encounter.enemies[0].slug=="dragon":
		test_damage_and_checkpoint(session)
		test_recruitment(session)
	session.save_file_path=prior
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	check(not FileAccess.file_exists(scratch),"temporary save removed")
	print("FINAL_DRAGON_BOSS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
