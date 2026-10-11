extends SceneTree
## W080: source-anchored 46-unit parity, original encounter/treasure pools,
## and backward compatibility for Godot-only Dracula in older player saves.
const EncounterGenerator = preload("res://systems/encounter_generator.gd")
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

func _run() -> void:
	var file=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/fixtures/web_v2_units_46.json"))
	var current=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json"))
	if not file is Dictionary or not current is Dictionary:
		check(false,"catalog and fixed web fixture parse");quit(1);return
	var original: Dictionary=file.units
	var definitions: Dictionary=current.units
	check(original.size()==46,"46 authoritative original web species")
	check(definitions.size()==47 and definitions.has("dracula"),"Godot optional Dracula metadata retained for existing runs")
	check(not original.has("dracula"),"Dracula is absent from fixed original web V2")
	for slug in original:
		check(definitions.has(slug),"original unit exists: "+slug)
		if not definitions.has(slug): continue
		for key in original[slug]:
			check(definitions[slug].get(key,null)==original[slug][key],"source field parity: %s.%s" % [slug,key])
	var expected_pool: Array=original.keys().filter(func(slug): return original[slug].grade in ["normal","advanced","hero"])
	var actual_pool: Array=EncounterGenerator.eligible_roster(definitions)
	check(actual_pool.size()==expected_pool.size() and actual_pool.size()==43,"43 battle/reward-eligible species match fixed web data")
	check(not actual_pool.has("dracula"),"extra Dracula excluded from new source-parity runs")
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
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if FileAccess.file_exists(test_path+".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path+".tmp"))
	session.free()
	check(not FileAccess.file_exists(test_path),"isolated test save cleaned up")
	print("WEB_UNIT_CATALOG_PARITY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
