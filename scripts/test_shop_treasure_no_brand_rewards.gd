extends SceneTree
## New reward economy: no brand cards offered by merchants or treasure chests.
## godot --headless --path . --script res://scripts/test_shop_treasure_no_brand_rewards.gd
const Session = preload("res://systems/run_session.gd")
const EncounterGenerator = preload("res://systems/encounter_generator.gd")
const Catalog = preload("res://systems/reward_catalog.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS shop-treasure: ",label)
	else:
		failed += 1
		printerr("FAIL shop-treasure: ",label)

func test_shops(session: Node) -> void:
	for grade in ["normal","advanced","hero"]:
		session.start_new_world()
		var world = session.world
		var candidates: Array = EncounterGenerator.eligible_roster(world.definitions).filter(func(slug): return str(world.definitions[slug].grade)==grade)
		check(candidates.size() >= 3,"%s grade has enough distinct merchant candidates" % grade)
		if candidates.is_empty(): continue
		var donor: Dictionary = session.create_item("unit",{"slug":str(candidates[0])})
		world.roster.append(donor)
		var donor_id: String = str(donor.id)
		var result: Dictionary = session.shop_offers(8,donor_id)
		check(result.get("ok",false),"%s donor opens a real merchant offer" % grade)
		if not result.get("ok",false): continue
		var offers: Array = result.offers
		var expected_count: int = 5 if grade=="hero" else (4 if grade=="advanced" else 3)
		check(offers.size()==expected_count,"%s still gets %d offers" % [grade,expected_count])
		check(offers.all(func(offer): return offer.kind in ["unit","dice"]),"no %s merchant offer is a brand card" % grade)
		var unit_ids: Array = []
		var unit_slugs: Array = []
		var selected_index: int = -1
		for i in range(offers.size()):
			var offer: Dictionary = offers[i]
			if offer.kind=="unit":
				var item: Dictionary = offer.item
				unit_slugs.append(str(item.slug))
				unit_ids.append(str(item.id))
				selected_index = i
				check(str(item.grade)==grade and str(item.slug)!=str(donor.slug),"merchant monster matches donor grade but differs in species")
				check(ResourceLoader.exists(Catalog.image("unit",item)),"merchant monster artwork exists")
		check(unit_slugs.size()==unit_slugs.duplicate().size(),"unit offer count retained")
		var distinct: Dictionary = {}
		for slug in unit_slugs: distinct[slug] = true
		check(distinct.size()==unit_slugs.size(),"merchant species offers do not repeat")
		var cached: Array = offers.duplicate(true)
		check(session.shop_offers(8,donor_id).offers==cached,"merchant re-entry never rerolls offers")
		session.reload_world()
		world = session.world
		check(session.shop_offers(8,donor_id).offers==cached,"merchant choices survive save reload")
		if selected_index < 0: continue
		var chosen_id: String = str(cached[selected_index].item.id)
		var count_before: int = world.roster.size()
		var trade: Dictionary = session.shop_trade(8,donor_id,selected_index)
		check(trade.get("ok",false),"merchant completes a same-grade monster trade")
		check(world.roster.size()==count_before and world.roster.any(func(unit): return str(unit.id)==chosen_id) and not world.roster.any(func(unit): return str(unit.id)==donor_id),"one donor is removed and exactly one chosen monster joins roster")
		session.reload_world()
		world = session.world
		check(world.roster.size()==count_before and world.roster.any(func(unit): return str(unit.id)==chosen_id),"monster trade survives reload without duplication")

func test_legacy_shop(session: Node) -> void:
	session.start_new_world()
	var world = session.world
	var donor: Dictionary = world.roster[0]
	var donor_id: String = str(donor.id)
	var current: Dictionary = session.shop_offers(8,donor_id)
	check(current.get("ok",false),"new merchant offer available before legacy fixture")
	if not current.get("ok",false): return
	var old_offers: Array = current.offers.duplicate(true)
	old_offers[1] = {"kind":"brand","item":session.create_item("brand",{})}
	world.shop_trade.offers[donor_id] = old_offers
	check(session.save_world(),"legacy brand-offer fixture saved")
	session.reload_world()
	world = session.world
	check(world.shop_trade.offers[donor_id][1].kind=="brand","legacy brand offers remain loadable before migration")
	var upgraded: Dictionary = session.shop_offers(8,donor_id)
	check(upgraded.get("ok",false) and upgraded.offers.all(func(offer): return offer.kind in ["unit","dice"]),"opening an old shop replaces its pending brand offer")
	if not upgraded.get("ok",false): return
	check(upgraded.offers[0]==old_offers[0],"saved dice offers keep their exact item and ID")
	var revised: Array = upgraded.offers.duplicate(true)
	session.reload_world()
	check(session.shop_offers(8,donor_id).offers==revised,"upgraded old offers persist without additional rerolls")

func test_treasure(session: Node) -> void:
	var generated: int = 0
	for seed in range(1,45):
		session.start_new_world()
		var world = session.world
		var index: int = world.tiles.find("gem")
		world.position = index
		world.rng.seed = seed
		check(session.open_treasure(index),"treasure seed %d opens a valid transaction" % seed)
		if world.pending_reward.kind=="mimic": continue
		generated += 1
		var offers: Array = world.pending_reward.offers
		check(offers.size()==3 and offers.all(func(offer): return offer.kind in ["unit","dice"]),"treasure seed %d offers three brand-free rewards" % seed)
		check(offers.any(func(offer): return offer.kind=="unit"),"treasure seed %d always includes a monster" % seed)
		if generated==1:
			var kind: String = str(offers[0].kind)
			check(session.select_treasure(0),"treasure choice can be saved")
			check(session.prepare_treasure_reward(0),"treasure reward can be prepared")
			var reward_id: String = str(world.pending_reward.id)
			var count_before: int = world.roster.size() if kind=="unit" else world.dice_cards.size()
			var claim: Dictionary = session.claim_reward()
			check(claim.get("ok",false) and claim.get("kept",false),"brand-free treasure claim succeeds")
			check(reward_id in world.reward_receipts and (world.roster.size() if kind=="unit" else world.dice_cards.size())==count_before+1,"chosen card and unique receipt are persisted")
			session.reload_world()
			check(reward_id in session.world.reward_receipts and session.world.pending_reward.is_empty(),"treasure claim does not reopen after reload")
	check(generated >= 30,"multiple independent treasure rolls were checked")

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = Session.new()
		session.name = "RunSession"
		root.add_child(session)
	var old_path: String = session.save_file_path
	var scratch: String = "user://shop_treasure_no_brand_%d.json" % OS.get_process_id()
	session.save_file_path = scratch
	test_shops(session)
	test_legacy_shop(session)
	test_treasure(session)
	session.save_file_path = old_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	check(not FileAccess.file_exists(scratch),"disposable test save removed")
	print("SHOP_TREASURE_NO_BRAND: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
