extends SceneTree
## New reward economy: no brand cards offered by merchants or treasure chests.
## godot --headless --path . --script res://scripts/test_shop_treasure_no_brand_rewards.gd
const Session = preload("res://systems/run_session.gd")
const EncounterGenerator = preload("res://systems/encounter_generator.gd")
const Catalog = preload("res://systems/reward_catalog.gd")
const LayeredUnitCard = preload("res://systems/layered_unit_card.gd")
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
		check(candidates.size() >= 2,"%s grade has at least one different-species merchant candidate" % grade)
		if candidates.is_empty(): continue
		var donor: Dictionary = session.create_item("unit",{"slug":str(candidates[0])})
		world.roster.append(donor)
		var donor_id: String = str(donor.id)
		var result: Dictionary = session.shop_offers(8,donor_id)
		check(result.get("ok",false),"%s donor opens a real merchant offer" % grade)
		if not result.get("ok",false): continue
		var offers: Array = result.offers
		var expected_count: int = 3
		check(offers.size()==expected_count,"%s still gets %d offers" % [grade,expected_count])
		# The six boss-only hero species cannot be used to pad shop offers.
		# If a grade has fewer distinct species, surplus monster slots become dice.
		var requested_monsters: int = 2 if grade=="hero" else 1
		var expected_monsters: int = mini(requested_monsters,candidates.size()-1)
		var monster_offers: Array = offers.filter(func(offer): return offer.kind=="unit")
		var dice_offers: Array = offers.filter(func(offer): return offer.kind=="dice")
		check(monster_offers.size()==expected_monsters,"%s offers every available distinct same-grade monster up to its monster slots" % grade)
		check(dice_offers.size()==expected_count-expected_monsters,"%s fills missing monster slots with dice cards" % grade)
		var distinct_dice: Dictionary = {}
		for offer in dice_offers:
			distinct_dice[str(offer.item.card_id)] = true
		check(distinct_dice.size()==dice_offers.size(),"%s merchant dice controls do not repeat" % grade)
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
				check(LayeredUnitCard.supports(str(item.slug)) and ResourceLoader.exists(str(LayeredUnitCard.PORTRAITS.get(str(item.slug),""))) and ResourceLoader.exists(str(LayeredUnitCard.BACKGROUNDS.get(str(item.slug),LayeredUnitCard.BACKGROUND))),"merchant monster has live layered artwork")
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
	old_offers[1] = {"kind":"brand","item":{"id":"legacy-brand-test","brand":{"type":"critical","bless":[2],"curse":[]}}}
	world.shop_trade.offers[donor_id] = old_offers
	check(session.save_world(),"legacy brand-offer fixture saved")
	session.reload_world()
	world = session.world
	check(not world.shop_trade.offers.has(donor_id),"old merchant brand offer is purged immediately upon save load")
	var upgraded: Dictionary = session.shop_offers(8,donor_id)
	check(upgraded.get("ok",false) and upgraded.offers.all(func(offer): return offer.kind in ["unit","dice"]),"reopened merchant regenerates only monster and dice offers")
	if not upgraded.get("ok",false): return
	check(upgraded.offers.any(func(offer): return offer.kind=="unit"),"obsolete brand slot is replaced with a real monster option")
	var revised: Array = upgraded.offers.duplicate(true)
	session.reload_world()
	check(session.shop_offers(8,donor_id).offers==revised,"new merchant offers persist across subsequent reload")

func test_shop_window_limits(session: Node) -> void:
	session.start_new_world()
	var world=session.world
	var donor_id:String=str(world.roster[0].id)
	var original:Array=session.shop_offers(8,donor_id).offers.duplicate(true)
	var legacy:Array=original.duplicate(true)
	for n in range(2): legacy.append({"kind":"dice","item":session.create_item("dice",Catalog.dice_cards()[n])})
	world.shop_trade.offers[donor_id]=legacy
	world.shop_trade.used=1
	check(session.save_world(),"legacy five-offer fixture saves")
	session.reload_world()
	world=session.world
	check(session.shop_trades_remaining(8)==2,"saved used count restores as an integer")
	var before:Dictionary=world.snapshot().duplicate(true)
	var good_path:String=session.save_file_path
	session.save_file_path="user://shop_missing_%d/save.json" % OS.get_process_id()
	check(not session.shop_offers(8,donor_id).get("ok",false) and world.snapshot()==before,"failed legacy trim restores exact offers, count, RNG and serial")
	session.save_file_path=good_path
	check(not session.shop_trade(8,donor_id,4).get("ok",false) and world.snapshot()==before,"hidden legacy fourth/fifth offer cannot be purchased")
	var trimmed:Dictionary=session.shop_offers(8,donor_id)
	check(trimmed.get("ok",false) and trimmed.offers==original,"legacy cache keeps precisely the original first three cards")
	check(world.rng.state==int(before.rng_state) and world.next_serial==int(before.next_serial) and session.shop_trades_remaining(8)==2,"trim spends no RNG, identity or trade allowance")
	session.reload_world()
	world=session.world
	check(session.shop_offers(8,donor_id).offers==original,"trimmed cards are durable across restart")
	before=world.snapshot().duplicate(true)
	session.save_file_path="user://shop_missing_%d/save.json" % OS.get_process_id()
	check(not session.shop_trade(8,donor_id,1).get("ok",false) and world.snapshot()==before,"failed trade restores donor, prize, cached offers and allowance atomically")
	session.save_file_path=good_path
	world.dice_cards.clear()
	for n in range(Catalog.DICE_CAPACITY): world.dice_cards.append(session.create_item("dice",Catalog.dice_cards()[0]))
	before=world.snapshot().duplicate(true)
	check(not session.shop_trade(8,donor_id,0).get("ok",false) and world.snapshot()==before,"full dice inventory cannot spend donor or allowance")
	world.dice_cards.clear()
	world.roster=world.roster.filter(func(u): return str(u.id)==donor_id)
	before=world.snapshot().duplicate(true)
	check(not session.shop_trade(8,donor_id,1).get("ok",false) and world.snapshot()==before,"last monster cannot spend allowance")
	# A new visit has its own three successful transactions.
	world.roster.append(session.create_item("unit",{"slug":"skeleton-archer"}))
	world.move_serial+=1
	check(session.shop_trades_remaining(8)==3,"new visit starts with three transactions")
	for n in range(3):
		donor_id=str(world.roster[0].id)
		var choices:Dictionary=session.shop_offers(8,donor_id)
		check(choices.get("ok",false) and choices.offers.size()==3,"visit trade %d has three offers" % n)
		var chosen:int=-1
		for i in range(choices.offers.size()):
			if choices.offers[i].kind=="unit": chosen=i; break
		check(chosen>=0 and session.shop_trade(8,donor_id,chosen).get("ok",false),"successful monster trade consumes one allowance")
		check(session.shop_trades_remaining(8)==2-n,"remaining allowance decreases exactly once")
		session.reload_world()
		world=session.world
		check(session.shop_trades_remaining(8)==2-n,"remaining allowance survives restart")
	before=world.snapshot().duplicate(true)
	donor_id=str(world.roster[0].id)
	check(not session.shop_offers(8,donor_id).get("ok",false) and not session.shop_trade(8,donor_id,0).get("ok",false) and world.snapshot()==before,"fourth transaction blocked without any state change")
	world.move_serial+=1
	check(session.shop_trades_remaining(8)==3 and session.shop_offers(8,donor_id).get("ok",false),"only a genuinely new visit restores allowance")

func test_treasure(session: Node) -> void:
	var generated: int = 0
	for seed in range(1,45):
		session.start_new_world()
		var world = session.world
		var index: int = world.tiles.find("gem")
		world.position = index
		world.rng.seed = seed
		check(session.open_treasure(index),"treasure seed %d opens a valid transaction" % seed)
		var preview=RandomNumberGenerator.new()
		preview.seed=seed
		check((world.pending_reward.kind=="mimic")==bool(preview.randf()<0.10),"treasure seed %d preserves original mimic branch" % seed)
		if world.pending_reward.kind=="mimic":
			var mimic: Dictionary=world.pending_reward.duplicate(true)
			session.reload_world()
			check(session.world.pending_reward==mimic,"mimic contents survive restart without becoming normal treasure")
			continue
		generated += 1
		var offers: Array = world.pending_reward.offers
		check(offers.size()==3 and offers.all(func(offer): return offer.kind in ["unit","dice"]),"treasure seed %d offers three brand-free rewards" % seed)
		check(offers.filter(func(offer): return offer.kind=="unit").size()==1 and offers.filter(func(offer): return offer.kind=="dice").size()==2,"treasure seed %d has exactly one monster and two dice cards" % seed)
		var dice: Array=offers.filter(func(offer): return offer.kind=="dice")
		check(dice[0].source.card_id!=dice[1].source.card_id,"treasure seed %d has two distinct dice controls" % seed)
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

func exact_mix(offers: Array) -> bool:
	return offers.size()==3 and offers.filter(func(o): return o.kind=="unit").size()==1 and offers.filter(func(o): return o.kind=="dice").size()==2

func test_pending_mix(session: Node) -> void:
	for all_units in [true,false]:
		for selected in [-1,0,1,2]:
			for prepared in [false,true]:
				if prepared and selected<0: continue
				session.start_new_world()
				var w=session.world
				w.position=w.tiles.find("gem")
				w.move_serial=17
				var roster: Array=EncounterGenerator.eligible_roster(w.definitions)
				var offers: Array=[]
				for i in range(3):
					var slug: String=str(roster[i])
					offers.append({"kind":"unit","source":{"slug":slug,"name":w.definitions[slug].name}} if all_units else {"kind":"dice","source":Catalog.dice_cards()[i]})
				w.pending_reward={"id":"treasure-visit:0:17:%d" % w.position,"kind":"treasure","offers":offers,"selected":selected}
				if prepared: w.pending_reward.reward={"kind":offers[selected].kind,"item":session.create_item(offers[selected].kind,offers[selected].source)}
				var chosen: Dictionary=offers[selected].duplicate(true) if selected>=0 else {}
				var prize: Dictionary=w.pending_reward.get("reward",{}).duplicate(true)
				var rng_state: int=w.rng.state
				var serial: int=w.next_serial
				check(session.save_world(),"legacy mix fixture saves")
				session.reload_world()
				w=session.world
				check(exact_mix(w.pending_reward.offers),"old three-monster/three-dice chest upgrades to exact one-plus-two")
				check(int(w.pending_reward.selected)==selected and (selected<0 or w.pending_reward.offers[selected]==chosen),"upgrade preserves selected slot and complete source")
				check(JSON.parse_string(JSON.stringify(w.pending_reward.get("reward",{})))==JSON.parse_string(JSON.stringify(prize)) and w.rng.state==rng_state and w.next_serial==serial,"upgrade preserves prepared prize ID, RNG and next item serial")
				var normalized: Dictionary=w.pending_reward.duplicate(true)
				check(session.save_world(),"normalized mix saves")
				session.reload_world()
				w=session.world
				check(w.pending_reward==normalized,"normalized pending offers are stable across another reload")
				if prepared:
					var before_count: int=w.roster.size() if prize.kind=="unit" else w.dice_cards.size()
					var path: String=session.save_file_path
					var before: Dictionary=w.snapshot().duplicate(true)
					session.save_file_path="user://treasure_missing_%d/save.json" % OS.get_process_id()
					check(not session.claim_reward().get("ok",false) and w.snapshot()==before,"failed migrated claim rolls back exact pending mix and inventories")
					session.save_file_path=path
					var result: Dictionary=session.claim_reward()
					check(result.get("ok",false) and (w.roster.size() if prize.kind=="unit" else w.dice_cards.size())==before_count+1,"selected prepared card alone is granted after retry")
					check(not session.claim_reward().get("ok",false),"prepared treasure cannot award a second card")
	# A failed new opening must restore the RNG and all three candidates atomically.
	session.start_new_world()
	var w=session.world
	w.position=w.tiles.find("gem")
	var preview=RandomNumberGenerator.new()
	for seed in range(1,50):
		preview.seed=seed
		if preview.randf()>=0.10:
			w.rng.seed=seed
			break
	var before: Dictionary=w.snapshot().duplicate(true)
	var path: String=session.save_file_path
	session.save_file_path="user://treasure_open_missing_%d/save.json" % OS.get_process_id()
	check(not session.open_treasure(w.position) and w.snapshot()==before,"failed new chest save rolls back RNG and pending offers")
	session.save_file_path=path
	check(session.open_treasure(w.position) and exact_mix(w.pending_reward.offers),"same chest retries with exact one-monster two-dice composition")

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
	test_shop_window_limits(session)
	test_treasure(session)
	test_pending_mix(session)
	session.save_file_path = old_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	check(not FileAccess.file_exists(scratch),"disposable test save removed")
	print("SHOP_TREASURE_NO_BRAND: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
