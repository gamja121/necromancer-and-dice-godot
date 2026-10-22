extends SceneTree
## W080: source-anchored 46-unit parity, original encounter/treasure pools,
## and backward compatibility for Godot-only Dracula in older player saves.
const EncounterGenerator = preload("res://systems/encounter_generator.gd")
const BossStages = preload("res://systems/boss_stage_catalog.gd")
const SessionScript = preload("res://systems/run_session.gd")
const MapState = preload("res://systems/map_state.gd")
const BattleRules = preload("res://systems/battle_rules.gd")

var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed+=1
		print("PASS web-catalog: ",message)
	else:
		failed+=1
		printerr("FAIL web-catalog: ",message)

func check_azazel_save_names(session: Node, definitions: Dictionary) -> void:
	var maker = BattleRules.new(definitions,404)
	var legacy = maker.individual("doom-executor","legacy-azazel-1")
	check(legacy.name=="아자젤","newly created doom-executor uses Azazel")
	legacy.name = "흑각 악마"
	legacy.current_hp = legacy.max_hp
	var opponent = maker.individual("skeleton-spear","rename-opponent-1")
	maker.start([legacy],[opponent])
	var checkpoint = maker.snapshot()
	var before_checkpoint: String = JSON.stringify(checkpoint)
	var resumed = BattleRules.new(definitions,2)
	check(resumed.restore(checkpoint),"old-named battle checkpoint remains readable")
	check(resumed.units[0].name=="아자젤","battle unit receives current display name")
	check(resumed.units[0].id==legacy.id and resumed.units[0].hp==checkpoint.units[0].hp and resumed.units[0].base_attack==checkpoint.units[0].base_attack and resumed.units[0].brands==checkpoint.units[0].brands,"battle identity, health, attack and brands retained")
	check(resumed.rng.state==int(checkpoint.rng_state) and JSON.stringify(checkpoint)==before_checkpoint,"battle RNG and caller's saved input retained")
	var saved: Dictionary = session.world.snapshot().duplicate(true)
	saved.roster.append(legacy.duplicate(true))
	saved.graveyard_corpses.append(legacy.duplicate(true))
	saved.pending_reward = {"kind":"treasure","offers":[{"kind":"unit","source":legacy.duplicate(true)}],"reward":{"kind":"unit","item":legacy.duplicate(true)}}
	saved.active_encounter = {"phase":"ready","allies":[legacy.duplicate(true)],"enemies":[opponent.duplicate(true)],"checkpoint":checkpoint.duplicate(true)}
	var before_map: String = JSON.stringify(saved)
	var restored = MapState.new(definitions,2)
	var readable: bool = restored.restore(saved)
	check(readable,"old-named owned, corpse, reward and encounter save remains readable")
	if readable:
		for item in [restored.roster.back(),restored.graveyard_corpses.back(),restored.pending_reward.offers[0].source,restored.pending_reward.reward.item,restored.active_encounter.allies[0],restored.active_encounter.checkpoint.units[0]]:
			check(item.name=="아자젤" and item.id==legacy.id and item.slug=="doom-executor","nested saved unit gets Azazel without changing identity")
		check(restored.roster.back().max_hp==legacy.max_hp and restored.roster.back().current_hp==legacy.current_hp and restored.roster.back().attack==legacy.attack and restored.roster.back().speed==legacy.speed and restored.roster.back().brands==legacy.brands,"owned stats and brands retained")
		check(restored.active_encounter.enemies[0].name==opponent.name,"other species names remain intact")
		check(restored.rng.state==int(saved.rng_state),"map RNG retained")
	check(JSON.stringify(saved)==before_map,"map caller's saved input remains untouched")

func _run() -> void:
	var file=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/fixtures/web_v2_units_46.json"))
	var current=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json"))
	if not file is Dictionary or not current is Dictionary:
		check(false,"catalog and fixed web fixture parse");quit(1);return
	var original: Dictionary=file.units
	var definitions: Dictionary=current.units
	check(original.size()==46,"46 authoritative original web species")
	check(definitions.size()==48 and definitions.has("dracula") and definitions.has("dragon"),"46 original monsters, old Dracula, and isolated final boss are registered")
	check(not original.has("dragon") and not EncounterGenerator.eligible_roster(definitions).has("dragon"),"boss-only dragon cannot enter original web random battle/reward catalog")
	check(not original.has("dracula"),"Dracula is absent from fixed original web V2")
	for slug in original:
		check(definitions.has(slug),"original unit exists: "+slug)
		if not definitions.has(slug): continue
		for key in original[slug]:
			var expected = "아자젤" if slug=="doom-executor" and key=="name" else original[slug][key]
			check(definitions[slug].get(key,null)==expected,"source field parity or approved name: %s.%s" % [slug,key])
	var expected_pool: Array=original.keys().filter(func(slug): return original[slug].grade in ["normal","advanced","hero"] and not slug in BossStages.reserved_slugs())
	var actual_pool: Array=EncounterGenerator.eligible_roster(definitions)
	check(actual_pool.size()==expected_pool.size() and actual_pool.size()==40,"three designated boss monsters are excluded from the old 43 random species")
	check(not actual_pool.has("dracula"),"extra Dracula excluded from new source-parity runs")
	check(BossStages.valid(definitions) and BossStages.reserved_slugs().size()==4 and BossStages.reserved_slugs().all(func(slug): return not actual_pool.has(slug)),"every designated stage boss is reserved for boss encounters only")
	check(not actual_pool.has("guardian-seed") and not actual_pool.has("spiderling") and not actual_pool.has("goblin-commoner"),"summon-only species are never in the random pool")
	for slug in expected_pool:
		check(actual_pool.has(slug),"original spawn-eligible unit retained: "+slug)
	var rng=RandomNumberGenerator.new()
	rng.seed=80191
	var no_additional_species: bool=true
	for contamination in [0,20,40,60,80,100]:
		for i in range(85):
			var encountered=EncounterGenerator.slugs(definitions,contamination,4,rng)
			for slug in encountered:
				if not actual_pool.has(slug): no_additional_species=false
	check(no_additional_species,"510 staged random encounters contain no extra Godot species")
	var scout_safe: bool=true
	for i in range(48):
		var intel=EncounterGenerator.scout_intel(definitions,60,5,rng,12,"monster")
		var anchored=EncounterGenerator.slugs(definitions,60,5,rng,intel)
		for slug in anchored:
			if not actual_pool.has(slug): scout_safe=false
	check(scout_safe,"48 scout-directed encounters use original species only")
	var test_path: String="user://web_v2_unit_catalog_%d.json" % OS.get_process_id()
	var session=SessionScript.new()
	root.add_child(session)
	session.save_file_path=test_path
	session.start_new_world()
	var treasure_index: int=session.world.tiles.find("gem")
	check(treasure_index>=0,"treasure tile exists for real reward-generation test")
	var offers_safe: bool=treasure_index>=0
	var recorded_unit_offers: int=0
	if treasure_index>=0:
		session.world.position=treasure_index
		for i in range(48):
			session.world.pending_reward={}
			if not session.open_treasure(treasure_index):
				offers_safe=false
				break
			if session.world.pending_reward.get("kind","")=="treasure":
				for offer in session.world.pending_reward.offers:
					if offer.kind=="unit":
						recorded_unit_offers+=1
						if not actual_pool.has(offer.source.slug): offers_safe=false
	check(offers_safe and recorded_unit_offers>0,"real treasure offers exclude Dracula and non-native species")
	# Old Godot 47-species saves must not become invalid when generation is
	# restricted to the original web pool; never delete the extra metadata.
	var rules=BattleRules.new(definitions,404)
	var existing=rules.individual("dracula","legacy-dracula-1")
	existing.current_hp=existing.max_hp
	session.world.roster.append(existing)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(session.world.snapshot()))
	var restored=MapState.new(definitions,1234)
	check(restored.restore(saved),"existing Godot save containing Dracula remains readable")
	check(restored.roster.any(func(u): return u.slug=="dracula" and u.current_hp>0),"existing owned Dracula survives load with stats and brands")
	check_azazel_save_names(session,definitions)
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if FileAccess.file_exists(test_path+".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path+".tmp"))
	session.free()
	check(not FileAccess.file_exists(test_path),"isolated test save cleaned up")
	print("WEB_UNIT_CATALOG_PARITY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
