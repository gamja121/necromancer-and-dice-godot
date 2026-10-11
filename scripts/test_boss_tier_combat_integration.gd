extends SceneTree
## Independent end-to-end test for tier 20/40/60 run boss combat and loss/retry.
## Deliberately kept separate from test_boss_roster_rules.gd so queued-boss
## scouting and succession checks can evolve without overwriting each other.
const BossRoster = preload("res://systems/boss_roster.gd")
const MapState = preload("res://systems/map_state.gd")
const BattleRules = preload("res://systems/battlefield_rules.gd")

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS boss-tier-combat: ",label)
	else:
		failed += 1
		printerr("FAIL boss-tier-combat: ",label)

func _run() -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var session = root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload exists")
		quit(1)
		return
	var old_path: String=session.save_file_path
	var test_path="user://boss_tier_combat_integration.json"
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

	# Full session/real checkpoint path at tier 40.
	check(session.start_encounter(MapState.BOSS_TILE_INDEX,selected),"tier 40 encounter enters through real session")
	if not session.encounter.is_empty():
		var selected_40: Array = session.encounter.enemies.map(func(u): return str(u.slug))
		check(selected_40==BossRoster.formation(session.world.boss_order[1],40) and selected_40.size()==4,"tier 40 uses second preselected hero and 3 escorts")
		var grades_40: Array = selected_40.map(func(slug): return str(definitions[slug].grade))
		check(grades_40.count("hero")==1 and grades_40.count("advanced")==1 and grades_40.count("normal")==2,"tier 40 has one advanced and two normals")
		var battle_40 = BattleRules.new(definitions,334)
		check(battle_40.restore(session.encounter.checkpoint),"tier 40 checkpoint restores")
		for unit in battle_40.units:
			if unit.team=="enemy":
				unit.hp=0
				unit.alive=false
		check(session.finish_encounter(battle_40),"tier 40 victory commits")
		check(session.world.boss_defeated==[20,40] and session.world.current_boss_tier()==0 and session.world.tiles[23]=="monster","tier 40 stays defeated until tier 60 unlocked")
		session.world.pending_reward={}
		session.world.contamination=60
		var before_60: Dictionary = session.world.snapshot().duplicate(true)
		check(session.persist_change(before_60),"tier 60 threshold and red boss stone persist")
		check(session.world.current_boss_tier()==60 and session.world.tiles[23]=="boss","tier 60 unlocks only after prior victories")
		check(session.start_encounter(MapState.BOSS_TILE_INDEX,selected),"tier 60 encounter enters through real session")
		if not session.encounter.is_empty():
			var selected_60: Array=session.encounter.enemies.map(func(u): return str(u.slug))
			check(selected_60==BossRoster.formation(session.world.boss_order[2],60) and selected_60.size()==4,"tier 60 uses the third preselected hero with 3 escorts")
			var legions_60: Dictionary=session.encounter.checkpoint.legions
			check(not legions_60.enemy.active.is_empty(),"tier 60 enemy party activates at least one legion")
			var battle_60=BattleRules.new(definitions,335)
			check(battle_60.restore(session.encounter.checkpoint),"tier 60 checkpoint restores")
			for unit in battle_60.units:
				if unit.team=="enemy":
					unit.hp=0
					unit.alive=false
			check(session.finish_encounter(battle_60),"tier 60 victory commits")
			check(session.world.boss_defeated==[20,40,60] and session.world.current_boss_tier()==0 and session.world.tiles[23]=="monster","all three bosses stay defeated")
			session.reload_world()
			check(session.world.boss_defeated==[20,40,60] and session.world.boss_peak==60,"all boss victories survive disk reload")
			session.world.pending_reward={}
			session.world.contamination=100
			var before_end: Dictionary=session.world.snapshot().duplicate(true)
			check(session.persist_change(before_end),"highest corruption without final-boss implementation persists")
			check(session.world.current_boss_tier()==0 and session.world.tiles[23]=="monster","80-plus never respawns a defeated normal-tier boss")

	# Skipping uncompleted tiers is prohibited even at high corruption.
	var queued = MapState.new(definitions,8871)
	queued.boss_peak=65
	queued.contamination=65
	queued.generate()
	check(queued.current_boss_tier()==20,"unbeaten tier 20 blocks 40 and 60 even at contamination 65")
	queued.boss_defeated=[20]
	check(queued.current_boss_tier()==40,"tier 40 queues behind defeated tier 20")
	queued.boss_defeated=[20,40]
	check(queued.current_boss_tier()==60,"tier 60 follows the first two defeats")

	# Loss must not consume the boss; remaining owned units can retry.
	session.start_new_world()
	session.world.contamination=20
	session.world.boss_peak=20
	session.world.generate()
	session.world.position=MapState.BOSS_TILE_INDEX
	check(session.save_world(),"loss/retry fixture saved")
	var lone_id: String=str(session.world.roster[0].id)
	check(session.start_encounter(MapState.BOSS_TILE_INDEX,[lone_id]),"single ally may challenge boss")
	if not session.encounter.is_empty():
		var defeat_battle=BattleRules.new(definitions,336)
		check(defeat_battle.restore(session.encounter.checkpoint),"losing fight checkpoint restored")
		for unit in defeat_battle.units:
			if unit.team=="ally":
				unit.hp=0
				unit.alive=false
		check(session.finish_encounter(defeat_battle),"defeat saves surviving roster and boss state")
		check(session.world.boss_defeated.is_empty() and session.world.tiles[23]=="boss","boss survives failed player attempt")
		session.reload_world()
		check(session.world.boss_defeated.is_empty() and session.world.tiles[23]=="boss","unbeaten boss persists across save reload")
		var survivor_ids: Array=session.world.roster.map(func(u): return str(u.id))
		check(survivor_ids.size()==1 and session.start_encounter(MapState.BOSS_TILE_INDEX,survivor_ids),"remaining owned unit can retry the same boss")

	session.save_file_path=old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("BOSS_TIER_COMBAT_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
