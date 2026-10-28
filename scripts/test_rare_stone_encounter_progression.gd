extends SceneTree
## Rare-stone grade, first-lap gate, legacy migration and true victory-cleared art.
const MapState=preload("res://systems/map_state.gd")
const MapScene=preload("res://map.tscn")
const Generator=preload("res://systems/encounter_generator.gd")
const Rules=preload("res://systems/battlefield_rules.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, reason: String) -> void:
	if value:
		passed+=1
		print("PASS rare-stone: ",reason)
	else:
		failed+=1
		printerr("FAIL rare-stone: ",reason)

func fight_to_win(session: Node, tile_index: int) -> void:
	var world=session.world
	world.position=tile_index
	check(session.save_world(),"save real arrival on monster tile")
	check(session.start_encounter(tile_index,[str(world.roster[0].id)]),"start authentic encounter on tile %d" % tile_index)
	if session.encounter.is_empty(): return
	var tile_type: String=str(session.encounter.type)
	var grades: Array = session.encounter.enemies.map(func(e): return str(e.grade))
	check((tile_type=="rare-monster" and grades.any(func(g): return g in ["advanced","hero"])) or (tile_type=="monster" and grades.all(func(g): return g=="normal")),"battle enemy grades agree with green/purple tile art")
	var rules=Rules.new(world.definitions,4321)
	check(rules.restore(session.encounter.checkpoint),"restore saved combat checkpoint")
	for unit in rules.units:
		if unit.team=="enemy":
			unit.hp=0
			unit.alive=false
	check(rules.winner()=="ally","combat ends with actual ally victory")
	check(session.finish_encounter(rules),"persist real victory and rewards")
	check(tile_index in world.cleared,"victory marks the exact monster tile completed")
	var expected: String="res://assets/map/tiles/%s-cleared.png" % tile_type
	var map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(map.tile_path(tile_index)==expected,"winning tile points to correct grade-matched broken stone")
	check(map.buttons[tile_index].texture_normal==load(expected),"visible in-game map tile uses grade-matched broken texture")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(tile_index in session.world.cleared and session.world.tiles[tile_index]==tile_type,"victory tile kind and completion persist across restart")

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	check(session!=null,"game session autoload exists")
	if session==null:
		quit(1)
		return
	var original: String=session.save_file_path
	var scratch: String="user://rare_stone_progress_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var w=session.world
	check(w.tiles.count("monster")==5 and w.tiles.count("rare-monster")==0,"first lap has five ordinary and no rare stones")
	w.laps=1
	w.generate()
	check(w.tiles.size()==24 and w.tiles.count("rare-monster")==1 and w.tiles.count("monster")==4,"second lap replaces one regular stone, keeping five fights and 24 board cells")
	check(w._patrol_manifest(w.patrol_plan,w.contamination,1).counts["rare-monster"]==1,"home patrol forecast includes rare stone on lap two")
	# Every threshold upgrades combat quality, not combat quantity. Tiles
	# remain visually truthful, and previews use the same stage quota.
	var last_count: int=0
	for level in [0,19,20,29,30,39,40,60,80]:
		w.contamination=level
		w.generate()
		var rare_count: int=w.tiles.count("rare-monster")
		var boss_count: int=w.tiles.count("boss")
		var expected: int=MapState.rare_stone_target(level,w.laps)
		check(rare_count==expected,"corruption %d creates %d rare stones" % [level,expected])
		check(rare_count>=last_count,"rare encounters never decrease as contamination rises to %d" % level)
		var expected_total: int=5+(2 if level>=80 else (1 if level>=40 else 0))
		check(w.tiles.count("monster")+rare_count+boss_count==expected_total,"corruption %d preserves %d original and contamination-bonus combat/boss stones" % [level,expected_total])
		check(w.tiles.size()==24 and w.tiles.count("event")==2,"corruption %d never increases tile or story-event budget" % level)
		check(int(w._patrol_manifest(w.patrol_plan,level,w.laps).counts["rare-monster"])==rare_count,"corruption %d patrol preview matches real rare stones" % level)
		last_count=rare_count
	w.contamination=0
	w.generate()
	for grade in ["normal","rare"]:
		for level in [0,20,40,60,80]:
			var kind: String="monster" if grade=="normal" else "rare-monster"
			var rng=RandomNumberGenerator.new()
			rng.seed=level+410
			var rolls: Array=Generator.slugs(w.definitions,level,3,rng,{},kind)
			var grades: Array=rolls.map(func(slug): return str(w.definitions[slug].grade))
			check(not rolls.is_empty() and ((grades.all(func(g): return g=="normal")) if kind=="monster" else (grades.filter(func(g): return g in ["advanced","hero"]).size()==1)),"encounter grade matches tile kind at corruption %d on %s" % [level,kind])
			var scout=Generator.scout_intel(w.definitions,level,3,rng,1,kind)
			check((str(scout.grade)=="normal") if kind=="monster" else (str(scout.grade) in ["advanced","hero"]),"scout grade matches actual tile kind at %d on %s" % [level,kind])
	var rare: int=w.tiles.find("rare-monster")
	var initial_path="res://assets/map/tiles/rare-monster.png"
	var map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(map.tile_path(rare)==initial_path and map.buttons[rare].texture_normal==load(initial_path),"live map renders rare instead of green stone")
	map.queue_free()
	await process_frame
	# Recover old lap-2 saves that never allocated any rare stones, preserving
	# every random roll, board serial, finished encounters and selected route.
	w.tiles[rare]="monster"
	w.position=MapState.HOME
	var saved_serial=w.map_serial
	var saved_rng=w.rng.state
	check(session.save_world(),"legacy green-only board fixture stored")
	session.reload_world()
	w=session.world
	check(w.tiles.count("rare-monster")==1 and w.tiles.count("monster")==4,"old save gains one real rare stone on load")
	check(w.map_serial==saved_serial and w.rng.state==saved_rng,"legacy correction consumes no map turn or RNG")
	var migrated_snapshot: Dictionary=w.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==migrated_snapshot,"legacy conversion saved once without repeated mutation")
	var fight_rare: int=session.world.tiles.find("rare-monster")
	await fight_to_win(session,fight_rare)
	# Old high-contamination boards may still have the former single rare
	# stone; load must upgrade to four while preserving RNG and map serial.
	session.start_new_world()
	w=session.world
	w.laps=2
	w.contamination=40
	w.generate()
	for index in range(w.tiles.size()):
		if w.tiles[index]=="rare-monster" and w.tiles.count("rare-monster")>1: w.tiles[index]="monster"
	check(w.tiles.count("rare-monster")==1,"legacy corruption-40 fixture retains just one rare stone")
	var old_state: int=w.rng.state
	var old_serial: int=w.map_serial
	check(session.save_world(),"persist pre-upgrade corruption-40 board")
	session.reload_world()
	w=session.world
	check(w.tiles.count("rare-monster")==4 and w.tiles.count("monster")==1,"old corruption-40 board upgrades unused normal monsters to four rare, retaining the bonus ordinary stone")
	check(w.rng.state==old_state and w.map_serial==old_serial,"high-corruption restoration preserves RNG and board serial")
	# A threshold reached in the middle of a lap should upgrade eligible
	# cards in the same successful save without touching map/dice RNG.
	session.start_new_world()
	w=session.world
	w.laps=2
	w.contamination=19
	w.generate()
	var before_raise: Dictionary=w.snapshot().duplicate(true)
	var unchanged_serial: int=w.map_serial
	var unchanged_rng: int=w.rng.state
	w.contamination=20
	check(session.persist_change(before_raise),"mid-lap crossing corruption 20 saves rare-stone upgrade")
	check(w.tiles.count("rare-monster")==2,"crossing corruption 20 upgrades an unused normal encounter")
	check(w.map_serial==unchanged_serial and w.rng.state==unchanged_rng,"mid-lap rare upgrade never reshuffles or consumes RNG")
	# Independent disposable normal encounter; its cleared art stays green.
	session.start_new_world()
	w=session.world
	var ordinary: int=w.tiles.find("monster")
	await fight_to_win(session,ordinary)
	session.save_file_path=original
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("RARE_STONE_PROGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
