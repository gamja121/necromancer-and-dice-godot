extends SceneTree
## Cemetery loot uses the existing 18 dice-control cards; never a brand.
## godot --headless --path . --script res://scripts/test_graveyard_random_dice.gd
const SESSION = preload("res://systems/run_session.gd")
const CATALOG = preload("res://systems/reward_catalog.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS grave-dice: ",message)
	else:
		failed += 1
		printerr("FAIL grave-dice: ",message)

func open_cemetery(session: Node) -> int:
	session.start_new_world()
	session.world.lap_ready = true
	session.world.leave_home()
	var index: int = session.world.tiles.find("graveyard")
	check(index>=0,"first completed lap exposes a cemetery")
	session.world.position = index
	return index

func basic_rewards(session: Node) -> void:
	var valid: Array = CATALOG.dice_cards().map(func(card): return str(card.card_id))
	check(valid.size()==18,"the existing pool contains eighteen control cards")
	var different: Dictionary = {}
	for seed in range(1,35):
		var index: int = open_cemetery(session)
		var world = session.world
		world.graveyard_corpses = []
		world.rng.seed = seed
		var result: Dictionary = session.dig_graveyard(index)
		check(result.get("ok",false) and not result.get("overflow",true),"seed %d digs without any fallen ally" % seed)
		if not result.get("ok",false): continue
		different[str(result.item.card_id)] = true
		check(str(result.item.card_id) in valid and world.dice_cards.size()==1,"seed %d adds exactly one real dice-control card" % seed)
		check(not world.snapshot().has("brand_cards") and not world.snapshot().has("legacy_brand_cards") and world.graveyard_corpses.is_empty(),"seed %d never creates a brand or consumes a corpse" % seed)
		check(session.place_visit_id("grave-extract",index) in world.reward_receipts,"seed %d commits a one-visit receipt" % seed)
		check(not session.dig_graveyard(index).get("ok",false),"seed %d cannot dig twice" % seed)
		if seed==1:
			var found_id: String = str(result.item.id)
			session.reload_world()
			check(session.world.dice_cards.size()==1 and str(session.world.dice_cards[0].id)==found_id and session.place_visit_id("grave-extract",index) in session.world.reward_receipts,"dug card and receipt survive save reload")
	check(different.size()>4,"seeded digs produce multiple different dice-card types")

func full_deck(session: Node) -> void:
	var index: int = open_cemetery(session)
	var world = session.world
	for card in CATALOG.dice_cards().slice(0,5):
		world.dice_cards.append(session.create_item("dice",card))
	check(world.dice_cards.size()==5,"fixture begins with full dice hand")
	var original_ids: Array = world.dice_cards.map(func(card): return str(card.id))
	var outcome: Dictionary = session.dig_graveyard(index)
	check(outcome.get("ok",false) and outcome.get("overflow",false),"full hand queues card replacement rather than losing prize")
	check(world.pending_reward.get("kind","")=="grave-dig" and world.pending_reward.reward.kind=="dice","pending reward holds one exact rolled dice card")
	check(world.dice_cards.size()==5 and not session.place_visit_id("grave-extract",index) in world.reward_receipts,"full hand is not changed or marked collected prematurely")
	var found_id: String = str(world.pending_reward.reward.item.id)
	session.reload_world()
	world = session.world
	check(str(world.pending_reward.reward.item.id)==found_id and world.pending_reward.index==index,"pending choice and grave index survive reload")
	check(not session.dig_graveyard(index).get("ok",false),"unfinished replacement cannot start another dig")
	var discard: String = str(world.dice_cards[0].id)
	var resolved: Dictionary = session.claim_reward(discard)
	check(resolved.get("ok",false) and resolved.get("kept",false),"existing overflow claim replaces selected old card")
	check(world.dice_cards.size()==5 and world.dice_cards.any(func(card): return str(card.id)==found_id) and not world.dice_cards.any(func(card): return str(card.id)==discard),"replacement preserves five-card capacity with new find")
	check(world.pending_reward.is_empty() and session.place_visit_id("grave-extract",index) in world.reward_receipts,"claim closes pending transaction and records visit")
	session.reload_world()
	check(session.world.dice_cards.size()==5 and session.world.dice_cards.any(func(card): return str(card.id)==found_id),"replaced card persists after reload")
	index = open_cemetery(session)
	world = session.world
	for card in CATALOG.dice_cards().slice(0,5): world.dice_cards.append(session.create_item("dice",card))
	outcome = session.dig_graveyard(index)
	check(outcome.get("overflow",false),"second full hand opens identical reward resolution path")
	var ids_before: Array = world.dice_cards.map(func(card): return str(card.id))
	resolved = session.claim_reward("__new__")
	check(resolved.get("ok",false) and not resolved.get("kept",true),"player may refuse found card")
	check(world.dice_cards.map(func(card): return str(card.id))==ids_before and world.pending_reward.is_empty(),"refusal preserves existing hand and closes choice")
	check(not session.dig_graveyard(index).get("ok",false),"refusing reward still spends visit")

func legacy_and_failure(session: Node) -> void:
	var index: int = open_cemetery(session)
	var world = session.world
	world.reward_receipts.append(session.place_visit_id("grave-extract",index))
	check(not session.dig_graveyard(index).get("ok",false),"legacy brand extraction receipt blocks duplicate dice reward")
	index = open_cemetery(session)
	world = session.world
	var before: Dictionary = world.snapshot().duplicate(true)
	var previous_path: String = session.save_file_path
	session.save_file_path = "user://grave_dig_no_folder_%d/save.json" % OS.get_process_id()
	var result: Dictionary = session.dig_graveyard(index)
	check(not result.get("ok",false),"failed storage prevents graveyard reward")
	check(world.snapshot()==before,"save failure restores RNG, cards and receipt atomically")
	session.save_file_path = previous_path
	check(session.dig_graveyard(index).get("ok",false),"retry after storage recovery succeeds")

func _run() -> void:
	var session: Node = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var previous: String = session.save_file_path
	var temporary: String = "user://grave_dice_%d.json" % OS.get_process_id()
	session.save_file_path = temporary
	basic_rewards(session)
	full_deck(session)
	legacy_and_failure(session)
	session.save_file_path = previous
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(temporary+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary+suffix))
	check(not FileAccess.file_exists(temporary),"isolated save removed")
	print("GRAVEYARD_RANDOM_DICE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
