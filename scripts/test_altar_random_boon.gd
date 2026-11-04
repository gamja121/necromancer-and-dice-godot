extends SceneTree
const Boons=preload("res://systems/altar_boon_catalog.gd")
const State=preload("res://systems/map_state.gd")
var passed:int=0
var failed:int=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,what:String) -> void:
	if ok: passed+=1
	else: failed+=1; printerr("FAIL altar-random: ",what)
func run() -> void:
	var rng=RandomNumberGenerator.new()
	rng.seed=20261104
	var counts:Dictionary={"attack":0,"hp":0,"speed":0,"jackpot":0,"attack_max":0,"hp_max":0,"speed_max":0,"speed_mid":0}
	var all_valid:bool=true
	for i in range(100000):
		var boon:Dictionary=Boons.draw(rng)
		all_valid=all_valid and Boons.valid(boon)
		if boon.jackpot: counts.jackpot+=1
		elif int(boon.attack)>0:
			counts.attack+=1
			if int(boon.attack)==2: counts.attack_max+=1
		elif int(boon.hp)>0:
			counts.hp+=1
			if int(boon.hp)==3: counts.hp_max+=1
		else:
			counts.speed+=1
			if int(boon.speed)==3: counts.speed_max+=1
			if int(boon.speed)==2: counts.speed_mid+=1
	check(all_valid,"all sampled outcomes belong to the allowed range")
	for kind in ["attack","hp","speed"]: check(absf(float(counts[kind])/100000.0-0.33)<0.008,"equal category frequency "+kind)
	check(absf(float(counts.jackpot)/100000.0-0.01)<0.0015,"one percent jackpot frequency")
	for kind in ["attack","hp","speed"]: check(absf(float(counts[kind+"_max"])/float(counts[kind])-0.05)<0.012,"rare maximum conditional frequency "+kind)
	check(absf(float(counts.speed_mid)/float(counts.speed)-0.20)<0.015,"speed middle frequency")
	print("ALTAR_SAMPLE_100000: ",JSON.stringify(counts))
	var session=root.get_node("RunSession")
	var old_path:String=session.save_file_path
	var save:String="user://altar_random_core_%d.json"%OS.get_process_id()
	session.save_file_path=save
	session.start_new_world()
	var world=session.world
	var index:int=world.tiles.find("basic")
	world.tiles[index]="altar"
	world.position=index
	world.conceal_boss_below_threshold()
	world.roster.append(session.create_item("unit",{"slug":"goblin-commoner"}))
	var donor:String=str(world.roster[0].id)
	var target:String=str(world.roster[1].id)
	var capped:String=str(world.roster[2].id)
	world.roster[1].altar_enhancements=3
	world.roster[2].altar_enhancements=3
	check(session.save_world(),"capped fixture saves")
	var before:Dictionary=world.snapshot().duplicate(true)
	check(not session.altar_sacrifice(index,donor).ok and world.snapshot()==before,"cannot consume the only uncapped monster")
	world.roster[0].altar_enhancements=3
	world.roster[1].altar_enhancements=2
	var before_target:Dictionary=world.roster[1].duplicate(true)
	check(session.save_world(),"valid final enhancement fixture saves")
	var result:Dictionary=session.altar_sacrifice(index,donor)
	check(result.ok and session.owned_unit(donor).is_empty(),"capped donor can be consumed for another valid receiver")
	var pending:Dictionary=session.altar_boon(index)
	check(Boons.valid_pending(world.snapshot(),world.definitions),"pending transaction validates")
	var copy:Dictionary=session.altar_boon(index)
	copy.boon.attack=99
	check(session.altar_boon(index)==pending,"query returns isolated nested copy")
	before=world.snapshot().duplicate(true)
	check(not session.altar_sacrifice(index,capped).ok and world.snapshot()==before,"cannot replace pending draw")
	check(not session.altar_apply_boon(index,capped).ok and world.snapshot()==before,"capped receiver cannot consume boon")
	check(not session.altar_apply_boon(index,donor).ok and world.snapshot()==before,"consumed donor cannot receive boon")
	check(not session.claim_reward().ok and not session.dismiss_failed_capture(),"other reward APIs cannot dispose of boon")
	var invalids:Array=[]
	var bad:Dictionary=before.duplicate(true)
	bad.pending_reward.id="ritual-visit:other"
	invalids.append(bad)
	bad=before.duplicate(true)
	bad.pending_reward.boon.attack=3
	invalids.append(bad)
	bad=before.duplicate(true)
	bad.pending_reward.index=0.5
	invalids.append(bad)
	bad=before.duplicate(true)
	bad.roster.append(bad.pending_reward.donor.duplicate(true))
	invalids.append(bad)
	bad=before.duplicate(true)
	bad.reward_receipts.append(bad.pending_reward.id)
	invalids.append(bad)
	bad=before.duplicate(true)
	for unit in bad.roster: unit.altar_enhancements=3
	invalids.append(bad)
	for candidate in invalids:
		var restored=State.new(world.definitions,1)
		check(not restored.restore(candidate),"malformed pending save rejected atomically")
	var rng_state:int=world.rng.state
	session.reload_world()
	world=session.world
	check(world.snapshot()==before and typeof(world.pending_reward.boon.attack)==TYPE_INT,"pending transaction survives JSON with integer stats")
	check(world.rng.state==rng_state,"reload preserves draw RNG")
	result=session.altar_apply_boon(index,target)
	check(result.ok and int(session.owned_unit(target).altar_enhancements)==3,"last legal enhancement applies")
	var enhanced:Dictionary=session.owned_unit(target)
	check(int(enhanced.attack)==int(before_target.attack)+int(pending.boon.attack),"attack bonus correct")
	check(int(enhanced.max_hp)==int(before_target.max_hp)+int(pending.boon.hp),"HP bonus correct")
	check(int(enhanced.speed)==int(before_target.speed)+int(pending.boon.speed),"speed bonus correct")
	before=world.snapshot().duplicate(true)
	check(not session.altar_apply_boon(index,target).ok and world.snapshot()==before,"duplicate application is inert")
	session.reload_world()
	check(session.world.snapshot()==before,"completed and old-format level records persist")
	var legacy:Dictionary=before.duplicate(true)
	legacy.erase("pending_reward")
	var legacy_world=State.new(world.definitions,2)
	check(legacy_world.restore(legacy) and legacy_world.pending_reward.is_empty(),"legacy save without pending reward remains compatible")
	var outcomes:Array=[
		{"attack":1,"hp":0,"speed":0,"jackpot":false},{"attack":2,"hp":0,"speed":0,"jackpot":false},
		{"attack":0,"hp":2,"speed":0,"jackpot":false},{"attack":0,"hp":3,"speed":0,"jackpot":false},
		{"attack":0,"hp":0,"speed":1,"jackpot":false},{"attack":0,"hp":0,"speed":2,"jackpot":false},
		{"attack":0,"hp":0,"speed":3,"jackpot":false},{"attack":2,"hp":3,"speed":3,"jackpot":true}]
	for expected in outcomes:
		var seed_value:int=0
		for candidate in range(1,10000):
			rng.seed=candidate
			if Boons.draw(rng)==expected:
				seed_value=candidate
				break
		check(seed_value>0,"every valid blessing has a reachable real RNG seed")
		session.start_new_world()
		world=session.world
		index=world.tiles.find("basic")
		world.tiles[index]="altar"
		world.position=index
		world.conceal_boss_below_threshold()
		donor=str(world.roster[0].id)
		target=str(world.roster[1].id)
		world.roster[1].current_hp=int(world.roster[1].max_hp)-1
		before_target=world.roster[1].duplicate(true)
		world.rng.seed=seed_value
		check(session.altar_sacrifice(index,donor).ok,"each blessing can be sacrificed and persisted")
		rng_state=world.rng.state
		check(session.altar_apply_boon(index,target).ok,"each blessing applies to a real damaged receiver")
		enhanced=session.owned_unit(target)
		check(int(enhanced.attack)==int(before_target.attack)+int(expected.attack) and int(enhanced.speed)==int(before_target.speed)+int(expected.speed),"each blessing changes exactly attack and speed")
		check(int(enhanced.max_hp)==int(before_target.max_hp)+int(expected.hp) and int(enhanced.current_hp)==int(before_target.current_hp)+int(expected.hp),"HP blessing increases both maxima and damaged current HP without full healing")
		check(world.rng.state==rng_state and int(enhanced.altar_enhancements)==1,"apply uses one enhancement without RNG")

	session.save_file_path=old_path
	session.world=null
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))
	for frame in range(5): await process_frame
	print("ALTAR_RANDOM_BOON: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
