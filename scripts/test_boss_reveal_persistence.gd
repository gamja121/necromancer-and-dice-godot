extends SceneTree
## Exercise actual purification, saved encounters and HOME generation.
const State=preload("res://systems/map_state.gd")
const Stages=preload("res://systems/boss_stage_catalog.gd")
const Fixture=preload("res://scripts/boss_story_test_fixture.gd")
const Battle=preload("res://systems/battlefield_rules.gd")
var passed:int=0
var failed:int=0
var session:Node
var scratch:String
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("PASS boss-persistence: ",label)
	else: failed+=1; printerr("FAIL boss-persistence: ",label)
func six_seed() -> int:
	var rng=RandomNumberGenerator.new()
	for seed in range(1,1000):
		rng.seed=seed
		if rng.randi_range(1,6)==6: return seed
	return 0
func prepare(stage:int) -> int:
	session.start_new_world()
	var w=session.world
	if stage==80: Fixture.seed_completed_final_hunt(w)
	w.contamination=stage
	w.generate()
	var at:int=w.tiles.find("basic")
	w.tiles[at]="unknown"
	w.position=at
	w.rng.seed=six_seed()
	check(session.persist_change(w.snapshot().duplicate(true)),"%d: baseline saved"%stage)
	return at
func persistence(stage:int) -> void:
	var at:int=prepare(stage)
	var w=session.world
	var slug:String=w.current_boss_slug()
	var stone:int=w.final_dragon_location() if stage==80 else State.BOSS_TILE_INDEX
	var stone_type:String="warp" if stage==80 else "boss"
	var before:Dictionary=w.snapshot().duplicate(true)
	var rng=RandomNumberGenerator.new()
	rng.state=w.rng.state
	check(rng.randi_range(1,6)==6,"deterministic real prayer gives six")
	var result:Dictionary=session.pray_world_tree(at)
	check(result.ok and int(result.face)==6 and w.contamination==stage-5,"%d: actual prayer reduces contamination by five"%stage)
	check(w.tiles==before.tiles and w.map_serial==int(before.map_serial),"%d: purification keeps actual board and boss stone"%stage)
	check(w.current_boss_stage()==stage and w.current_boss_slug()==slug and w.boss_available(),"%d: same boss stays playable below threshold"%stage)
	check(w.rng.state==rng.state,"%d: preserving boss consumes no extra RNG"%stage)
	check(w.reward_receipts.count(session.place_visit_id("purify",at))==1,"%d: exactly one real prayer receipt"%stage)
	session.reload_world()
	w=session.world
	check(w.tiles[stone]==stone_type and w.current_boss_stage()==stage and w.current_boss_slug()==slug and w.boss_available(),"%d: disk restart preserves boss identity"%stage)
	before=w.snapshot().duplicate(true)
	w.contamination=0
	check(session.persist_change(before) and w.tiles[stone]==stone_type and w.current_boss_stage()==stage,"%d: even zero pollution keeps already revealed stage"%stage)
	var preview_before:Dictionary=w.snapshot().duplicate(true)
	var preview:Dictionary=w.patrol_preview(w.patrol_plan)
	check(preview.valid and int(preview.counts.boss)==(0 if stage==80 else 1) and w.snapshot()==preview_before,"%d: pure HOME preview reserves the retained boss"%stage)
	w.position=State.HOME
	w.lap_ready=false
	check(session.leave_home(),"%d: real HOME departure regenerates board"%stage)
	check(w.contamination==0 and w.tiles.size()==24 and w.tiles.count("boss")==int(preview.counts.boss) and w.current_boss_slug()==slug,"%d: shuffled board keeps same boss at zero pollution"%stage)
	stone=w.final_dragon_location() if stage==80 else State.BOSS_TILE_INDEX
	if stage==80: check(Fixture.acknowledge_wormhole(session),"purified final wormhole opens the three scenes")
	else: w.position=stone
	var selected:Array=[str(w.roster[0].id),str(w.roster[1].id)]
	check(session.start_encounter(stone,selected),"%d: actual boss battle can start after purification"%stage)
	if session.encounter.is_empty(): return
	check(int(session.encounter.get("boss_stage",0))==stage and session.encounter.enemies.size()==1 and str(session.encounter.enemies[0].slug)==slug,"%d: actual enemy and stored stage remain unchanged"%stage)
	var fight_before:Dictionary=JSON.parse_string(JSON.stringify(session.encounter))
	session.reload_world()
	w=session.world
	check(JSON.parse_string(JSON.stringify(session.encounter))==fight_before,"%d: ongoing boss battle survives restart unchanged"%stage)
	var battle=Battle.new(w.definitions,113)
	check(battle.restore(session.encounter.checkpoint),"%d: original battle checkpoint restores"%stage)
	for enemy in battle.units:
		if enemy.team=="enemy": enemy.hp=0; enemy.alive=false
	check(session.finish_encounter(battle),"%d: actual victory saves below threshold"%stage)
	check(Stages.defeated(w.event_flags,stage) and not w.boss_available(),"%d: only victory retires original stage"%stage)
	check([20,40,60,80].all(func(other):return other==stage or not Stages.defeated(w.event_flags,other)),"%d: no different stage receives defeat receipt"%stage)
	if stage!=80:
		w.pending_reward={}
		check(session.save_world(),"%d: isolated harvest fixture closes"%stage)
		w.generate()
		check(w.tiles[23]!="boss" and not w.boss_available(),"%d: won stage never respawns after shuffle"%stage)
func run() -> void:
	session=root.get_node("RunSession")
	var original:String=session.save_file_path
	scratch="user://boss_persistence_%d.json"%OS.get_process_id()
	session.save_file_path=scratch
	for stage in [20,40,60,80]: persistence(stage)
	# A story-locked dragon was never revealed: historical pollution is insufficient.
	session.start_new_world()
	var w=session.world
	w.contamination=80
	w.generate()
	check(not w.boss_available() and w.tiles[23]!="boss","unseen final dragon stays story-locked at eighty")
	var before:Dictionary=w.snapshot().duplicate(true)
	w.contamination=0
	check(session.persist_change(before),"unseen high-pollution history saves")
	Fixture.seed_completed_final_hunt(w)
	check(session.persist_change(w.snapshot().duplicate(true)) and not w.final_dragon_available() and w.tiles[23]!="boss","later story completion at zero does not reveal an unseen dragon")
	# Increasing pollution into the locked final band cannot hide an existing stage.
	prepare(60)
	w=session.world
	before=w.snapshot().duplicate(true)
	w.contamination=80
	check(session.persist_change(before) and w.tiles[23]=="boss" and w.current_boss_stage()==60 and not w.final_dragon_available(),"locked final gate preserves already shown intermediate boss")
	# A real higher-stage appearance replaces stale intelligence, without RNG.
	prepare(20)
	w=session.world
	w.scout={"scouted":true,"intel":[{"index":23,"type":"boss","count":1,"grade":"hero","legion":"skeleton"}]}
	before=w.snapshot().duplicate(true)
	w.contamination=40
	check(session.persist_change(before) and w.current_boss_stage()==40 and w.scout.intel.is_empty(),"higher revealed stage retires old boss intelligence")
	check(w.rng.state==int(before.rng_state) and w.map_serial==int(before.map_serial) and w.tiles.size()==24 and w.tiles[23]=="boss","same-stone stage upgrade never rerolls map or RNG")
	# Failed writes restore the entire prayer and the newly revealed flag.
	var at:int=prepare(20)
	w=session.world
	before=w.snapshot().duplicate(true)
	session.save_file_path="user://missing_boss_persistence_%d/save.json"%OS.get_process_id()
	check(not session.pray_world_tree(at).ok and w.snapshot()==before,"failed purification restores boss, pollution, receipt and RNG")
	session.save_file_path=scratch
	check(session.pray_world_tree(at).ok and w.tiles[23]=="boss","same saved prayer can retry without losing boss")
	session.start_new_world()
	w=session.world
	w.contamination=19
	w.generate()
	at=w.tiles.find("basic")
	w.tiles[at]="unknown"
	w.position=at
	var rng=RandomNumberGenerator.new()
	for seed in range(1,1000):
		rng.seed=seed
		if rng.randi_range(1,6)<=3: w.rng.seed=seed; break
	before=w.snapshot().duplicate(true)
	session.save_file_path="user://missing_boss_appearance_%d/save.json"%OS.get_process_id()
	check(not session.pray_world_tree(at).ok and w.snapshot()==before,"failed first appearance rolls back new reveal flag and all state")
	session.save_file_path=scratch
	check(session.pray_world_tree(at).ok and w.tiles[23]=="boss","retry reveals first boss atomically")
	# Only an actually visible old boss can seed the new boolean receipt.
	prepare(40)
	w=session.world
	var old:Dictionary=w.snapshot().duplicate(true)
	for key in old.event_flags.keys():
		if str(key).begins_with(Stages.PREFIX) and str(key).ends_with(":revealed"): old.event_flags.erase(key)
	var file=FileAccess.open(scratch,FileAccess.WRITE)
	file.store_string(JSON.stringify(old)); file.close()
	session.reload_world()
	w=session.world
	before=w.snapshot().duplicate(true)
	w.contamination=0
	check(session.persist_change(before) and w.tiles[23]=="boss" and w.current_boss_stage()==40,"actual legacy boss migrates before later purification")
	w.position=23
	check(session.start_encounter(23,[str(w.roster[0].id)]),"legacy ongoing boss fixture starts")
	old=w.snapshot().duplicate(true)
	for key in old.event_flags.keys():
		if str(key).begins_with(Stages.PREFIX) and str(key).ends_with(":revealed"): old.event_flags.erase(key)
	file=FileAccess.open(scratch,FileAccess.WRITE)
	file.store_string(JSON.stringify(old)); file.close()
	session.reload_world()
	w=session.world
	check(w.contamination==0 and w.current_boss_stage()==40 and int(session.encounter.get("boss_stage",0))==40,"legacy active boss stage migrates at zero without changing encounter")
	session.save_file_path=original
	session.world=null
	session.encounter={}
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("BOSS_REVEAL_PERSISTENCE: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
