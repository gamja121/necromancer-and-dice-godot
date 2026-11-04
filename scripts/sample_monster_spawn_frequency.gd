extends SceneTree
## Read-only experiment: call production random selection functions unchanged.
const GENERATOR=preload("res://systems/encounter_generator.gd")
const BOSSES=preload("res://systems/boss_stage_catalog.gd")
const STATE=preload("res://systems/map_state.gd")
const SEEDS=[20261029,1729,7919,104729,130363,524287,999983,15485863,32452843,49979687]
var BATTLE_DRAWS:int=10000
var SHOP_DRAWS:int=3000
var definitions:Dictionary
var assignments:Dictionary
var output:Dictionary
var destination:String

class MemorySession extends "res://systems/run_session.gd":
	# Avoid per-draw disk IO. The production spawn/offer bodies remain unchanged.
	func persist_change(_before:Dictionary) -> bool: return true
	func save_world() -> bool: return true

func _initialize() -> void: call_deferred("run")
func blank_counts() -> Dictionary:
	var result:Dictionary={}
	for slug in definitions: result[slug]=0
	return result
func save_result(mode:String) -> void:
	var file:=FileAccess.open(destination.path_join(mode+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"  "))
	file.close()
	print("SPAWN_AUDIT_COMPLETE: ",mode)
func base_row(id:String) -> Dictionary:
	return {"id":id,"counts":blank_counts(),"anchors":blank_counts(),"trials":BATTLE_DRAWS,"individuals":0,"invalid":0,"blocks":[]}

func battle_sample(kind:String,level:int,lap:int,scouted:bool) -> void:
	var id:String="%s_c%d_loop%d_%s"%[kind,level,lap,"scout" if scouted else "plain"]
	var row:Dictionary=base_row(id)
	row.merge({"tile":kind,"contamination":level,"loop":lap,"scouted":scouted})
	var rng:=RandomNumberGenerator.new()
	var block_draws:int=BATTLE_DRAWS/SEEDS.size()
	for seed_value in SEEDS:
		rng.seed=int(seed_value)+level*101+(50000 if kind=="rare-monster" else 0)+(80000 if scouted else 0)
		var block:Dictionary={"seed":rng.seed,"counts":blank_counts(),"anchors":blank_counts()}
		for draw in range(block_draws):
			var intel:Dictionary=GENERATOR.scout_intel(definitions,level,lap,rng,1,kind,assignments) if scouted else {}
			var group:Array=GENERATOR.slugs(definitions,level,lap,rng,intel,kind,assignments)
			if group.is_empty(): row.invalid+=1;continue
			row.anchors[group[0]]+=1
			block.anchors[group[0]]+=1
			var unique:Dictionary={}
			for slug in group:
				if unique.has(slug): row.invalid+=1
				unique[slug]=true
				row.counts[slug]+=1
				block.counts[slug]+=1
				row.individuals+=1
			if kind=="monster" and definitions[group[0]].grade!="normal": row.invalid+=1
			if kind=="rare-monster" and definitions[group[0]].grade not in ["advanced","hero"]: row.invalid+=1
			if lap<=2 and group.size()!=1: row.invalid+=1
		row.blocks.append(block)
		await process_frame
	output.battles.append(row)
	print("SPAWN_AUDIT_BATCH: ",id," trials=",BATTLE_DRAWS," individuals=",row.individuals," invalid=",row.invalid)

func sample_encounters() -> void:
	for level in [0,20,40,60,80]:
		for kind in ["monster","rare-monster"]: await battle_sample(kind,level,4,false)
	await battle_sample("monster",0,1,false)
	await battle_sample("rare-monster",20,2,false)
	for kind in ["monster","rare-monster"]: await battle_sample(kind,80,4,true)

func sample_rewards() -> void:
	var session:=MemorySession.new()
	session.world=STATE.new(definitions,20261029)
	session.world.boss_assignments=assignments.duplicate(true)
	session.world.contamination=80
	session.world.laps=3
	var gem:int=session.world.tiles.find("gem")
	var chest:Dictionary=base_row("treasure")
	chest.merge({"mimic_events":0,"mimic_individuals":0,"normal_chests":0})
	for seed_value in SEEDS:
		session.world.rng.seed=int(seed_value)+70000
		for draw in range(BATTLE_DRAWS/SEEDS.size()):
			session.world.pending_reward={}
			session.world.move_serial+=1
			if not session.open_treasure(gem): chest.invalid+=1;continue
			var pending:Dictionary=session.world.pending_reward
			if pending.kind=="mimic":
				chest.mimic_events+=1
				chest.mimic_individuals+=int(pending.count)
			else:
				chest.normal_chests+=1
				for offer in pending.offers:
					if offer.kind=="unit": chest.counts[offer.source.slug]+=1;chest.individuals+=1
		await process_frame
	output.treasure=chest
	print("SPAWN_AUDIT_BATCH: treasure trials=",BATTLE_DRAWS," invalid=",chest.invalid)
	session.world.pending_reward={}
	var village:int=session.world.tiles.find("village")
	var eligible:Array=GENERATOR.eligible_roster(definitions,assignments)
	for grade in ["normal","advanced","hero"]:
		var pool:Array=eligible.filter(func(slug):return definitions[slug].grade==grade)
		session.world.roster=[]
		for slug in pool: session.world.roster.append(session.create_item("unit",{"slug":slug}))
		var row:Dictionary=base_row("shop_"+grade)
		row.trials=SHOP_DRAWS
		row["grade"]=grade
		for block_index in range(SEEDS.size()):
			session.world.rng.seed=int(SEEDS[block_index])+90000
			for draw in range(SHOP_DRAWS/SEEDS.size()):
				var donor:Dictionary=session.world.roster[(block_index*(SHOP_DRAWS/SEEDS.size())+draw)%pool.size()]
				session.world.move_serial+=1
				var offered:Dictionary=session.shop_offers(village,str(donor.id))
				if not offered.get("ok",false): row.invalid+=1;continue
				for offer in offered.offers:
					if offer.kind=="unit": row.counts[offer.item.slug]+=1;row.individuals+=1
			await process_frame
		output.shops.append(row)
		print("SPAWN_AUDIT_BATCH: shop_",grade," trials=",SHOP_DRAWS," invalid=",row.invalid)
	session.free()
	var boss:Dictionary={"id":"new_run_bosses","trials":BATTLE_DRAWS,"counts":blank_counts(),"stages":{},"availability":blank_counts(),"rare_counts":blank_counts(),"rare_anchors":blank_counts()}
	for stage_value in BOSSES.STAGES: boss.stages[str(stage_value)]=blank_counts()
	var rng:=RandomNumberGenerator.new()
	var run_rng:=RandomNumberGenerator.new()
	for seed_value in SEEDS:
		rng.seed=seed_value
		run_rng.seed=int(seed_value)+123456
		for draw in range(BATTLE_DRAWS/SEEDS.size()):
			var assigned:Dictionary=BOSSES.roll_assignments(int(rng.randi()))
			for stage_value in BOSSES.STAGES:
				var slug:String=str(assigned[str(stage_value)])
				boss.counts[slug]+=1
				boss.stages[str(stage_value)][slug]+=1
			for slug in GENERATOR.eligible_roster(definitions,assigned): boss.availability[slug]+=1
			var group:Array=GENERATOR.slugs(definitions,80,4,run_rng,{},"rare-monster",assigned)
			boss.rare_anchors[group[0]]+=1
			for slug in group: boss.rare_counts[slug]+=1
		await process_frame
	output.new_runs=boss
	print("SPAWN_AUDIT_BATCH: new_runs trials=",BATTLE_DRAWS)

func run() -> void:
	var raw_draws:String=OS.get_environment("SPAWN_AUDIT_DRAWS")
	if not raw_draws.is_empty():
		if not raw_draws.is_valid_int() or int(raw_draws)<10 or int(raw_draws)%10!=0:
			printerr("SPAWN_AUDIT_DRAWS must be a positive multiple of ten")
			quit(2)
			return
		BATTLE_DRAWS=int(raw_draws)
		SHOP_DRAWS=BATTLE_DRAWS*3/10
	destination=OS.get_environment("SPAWN_AUDIT_OUT_DIR")
	if destination.is_empty(): destination=ProjectSettings.globalize_path("user://spawn_frequency_audit")
	DirAccess.make_dir_recursive_absolute(destination)
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	assignments=BOSSES.roll_assignments(20261029)
	var catalog:Dictionary={}
	for slug in definitions:
		catalog[slug]={"name":definitions[slug].name,"grade":definitions[slug].grade,"legions":definitions[slug].legions}
	output={"source_revision":OS.get_environment("SPAWN_AUDIT_REVISION"),"draws_per_condition":BATTLE_DRAWS,"shop_draws_per_grade":SHOP_DRAWS,"encounter_source_sha256":FileAccess.get_file_as_string("res://systems/encounter_generator.gd").sha256_text(),"boss_source_sha256":FileAccess.get_file_as_string("res://systems/boss_stage_catalog.gd").sha256_text(),"seeds":SEEDS,"fixed_boss_assignments":assignments,"eligible":GENERATOR.eligible_roster(definitions,assignments),"catalog":catalog,"battles":[],"shops":[]}
	var args:PackedStringArray=OS.get_cmdline_user_args()
	var mode:String=args[0] if not args.is_empty() else "encounters"
	if mode=="encounters": await sample_encounters()
	else: await sample_rewards()
	save_result(mode)
	await process_frame
	var invalid:int=int(output.get("treasure",{}).get("invalid",0))
	for row in output.get("battles",[]): invalid+=int(row.invalid)
	for row in output.get("shops",[]): invalid+=int(row.invalid)
	quit(0 if invalid==0 else 1)
