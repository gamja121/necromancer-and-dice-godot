extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_six_routine_cards.gd
## Six real parchment cards; exact save/reload; both options; 5-card
## overflow; no preview rerolls; atomic rejection of duplicate visits.
const Session = preload("res://systems/run_session.gd")
const MapScene = preload("res://map.tscn")
const Routine = preload("res://systems/routine_event_catalog.gd")
const Catalog = preload("res://systems/reward_catalog.gd")
var passed: int = 0
var failed: int = 0
var session

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS six-routine: ",label)
	else:
		failed += 1
		printerr("FAIL six-routine: ",label)

func wait_for(predicate: Callable, limit: int=7000) -> bool:
	var deadline: int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())

func seed_for(event_id: String) -> int:
	var probe := RandomNumberGenerator.new()
	for seed in range(1,600):
		probe.seed=seed
		if Routine.choose(probe)==event_id: return seed
	return -1

func clear_save(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func setup_event(event_id: String) -> int:
	session.start_new_world()
	var world=session.world
	var index: int=world.tiles.find("event")
	world.position=index
	world.move_serial=1
	world.contamination=10
	for unit in world.roster: unit.current_hp=maxi(1,int(unit.max_hp)-1)
	var seed: int=seed_for(event_id)
	check(seed>0,event_id+": original RNG can choose this one of six cards")
	world.rng.seed=seed
	check(session.save_world(),event_id+": original landing state stored")
	return index

func verify_card(event_id: String, receive: bool) -> void:
	var path: String="user://six_routine_%s_%s_%d.json" % [event_id,("take" if receive else "skip"),OS.get_process_id()]
	clear_save(path)
	session.save_file_path=path
	var index: int=setup_event(event_id)
	var before_cards: int=session.world.dice_cards.size()
	var result: Dictionary=session.begin_story_free_event(index)
	check(bool(result.get("ok",false)) and result.get("type","")=="routine" and result.get("event_id","")==event_id,
		event_id+": actual story-free event draws expected persisted card")
	var receipt: String=str(session.world.pending_reward.get("id",""))
	var pending: Dictionary=session.world.pending_reward.duplicate(true)
	var old_rng: int=session.world.rng.state
	check(not bool(session.begin_story_free_event(index).get("ok",false)),event_id+": cannot reroll open card")
	check(session.world.rng.state==old_rng,event_id+": blocked duplicate did not advance RNG")
	session.reload_world()
	check(session.world.pending_reward==pending and session.world.rng.state==old_rng,event_id+": same choice and offered card survive reload")
	var map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	await process_frame
	var card: Control=map.overlay.get_node_or_null("RoutineEventCard") if is_instance_valid(map.overlay) else null
	check(card!=null,event_id+": saved routine is reopened on actual map scene")
	if card==null:
		map.queue_free()
		await process_frame
		clear_save(path)
		return
	var entry: Dictionary=Routine.details(event_id)
	check(card.get_node("EventDiscoveryTitle").text==str(entry.title),event_id+": event title matches the existing card format")
	check(card.get_node("EventDiscoveryDescription").text==str(entry.description),event_id+": event text matches the existing card format")
	check(card.get_node("EventDiscoveryIllustration").texture!=null and card.get_node_or_null("EventDiscoveryTile")==null and card.get_node_or_null("EventDiscoveryReward")==null,event_id+": illustration stays while reward icon and label are absent")
	check(card.get_node_or_null("EventDiscoveryClose")==null,event_id+": no old confirmation button")
	check(card.get_node_or_null("RoutineAccept")!=null and card.get_node_or_null("RoutineDecline")!=null,event_id+": both side choices are present")
	check(card.get_node("RoutineAccept").position.x>card.size.x and card.get_node("RoutineDecline").position.x>card.size.x and card.get_node("RoutineAccept").position.y<card.get_node("RoutineDecline").position.y,event_id+": choices are vertically separated to the right of the card")
	var read_before: Dictionary=session.world.pending_reward.duplicate(true)
	var tap:=InputEventMouseButton.new()
	tap.button_index=MOUSE_BUTTON_LEFT
	tap.pressed=true
	card._gui_input(tap)
	check(session.world.pending_reward==read_before and is_instance_valid(map.overlay),event_id+": plain image click cannot auto-claim a choice")
	card.get_node("RoutineAccept" if receive else "RoutineDecline").pressed.emit()
	if receive:
		check(await wait_for(func(): return is_instance_valid(map.overlay) and map.overlay.get_node_or_null("RoutineRewardMotion")!=null),event_id+": acceptance opens reward presentation")
		var reward_motion: Control=map.overlay.get_node("RoutineRewardMotion")
		check(session.world.pending_reward==read_before,event_id+": reveal does not award before the extra collect click")
		check(await wait_for(func(): return reward_motion.phase=="ready"),event_id+": reward turns to the front before collecting")
		reward_motion.collect()
		check(await wait_for(func(): return not is_instance_valid(map.overlay)),event_id+": one collect click completes reward delivery")
	await process_frame
	check(session.world.pending_reward.is_empty() and receipt in session.world.reward_receipts,event_id+": choice closes and grants one unique visit receipt")
	check(not bool(session.complete_routine_choice("take").get("ok",false)),event_id+": repeated choice cannot duplicate reward")
	if receive:
		match str(entry.effect):
			"dice":
				check(session.world.dice_cards.size()==before_cards+1,event_id+": one registered consumable dice card added")
				check(Catalog.dice_cards().any(func(item): return item.card_id==session.world.dice_cards.back().card_id),event_id+": awarded card exists in original reward catalog")
			"heal":
				check(session.world.roster.all(func(unit): return int(unit.current_hp)==int(unit.max_hp)),event_id+": unit HP recovers exactly 1")
			"cleanse":
				check(session.world.contamination==9,event_id+": contamination decreased by one")
	else:
		check(session.world.dice_cards.size()==before_cards and session.world.contamination==10,event_id+": refusal provides no card or purification")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.pending_reward.is_empty() and receipt in session.world.reward_receipts,event_id+": claim persists on restart")
	check(not bool(session.begin_story_free_event(index).get("ok",false)),event_id+": same landing cannot farm a second event after restart")
	clear_save(path)

func overflow_case() -> void:
	var path: String="user://six_routine_overflow_%d.json" % OS.get_process_id()
	session.save_file_path=path
	clear_save(path)
	var index: int=setup_event("wounded_soldier")
	for i in range(Catalog.DICE_CAPACITY):
		session.world.dice_cards.append(session.create_item("dice",Catalog.dice_cards()[i]))
	check(session.save_world(),"10/10 dice-card fixture saved")
	var result: Dictionary=session.begin_story_free_event(index)
	check(bool(result.get("ok",false)) and str(result.get("event_id",""))=="wounded_soldier","real dice routine drawn with full card inventory")
	var receipt: String=str(session.world.pending_reward.id)
	var choice: Dictionary=session.complete_routine_choice("take")
	check(bool(choice.get("ok",false)) and bool(choice.get("overflow",false)),"10/10 enters existing reward replacement workflow")
	check(session.world.pending_reward.get("phase","")=="overflow" and session.world.dice_cards.size()==Catalog.DICE_CAPACITY,"new card waits rather than exceeding 10/10")
	session.reload_world()
	check(session.world.pending_reward.get("phase","")=="overflow" and session.world.dice_cards.size()==Catalog.DICE_CAPACITY,"overflow choice survives restart")
	var map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	await process_frame
	check(is_instance_valid(map.overlay) and map.overlay.name!="RoutineEventCard" and map.overlay.has_method("finish"),"real map reopens existing RewardOverflow after restart")
	var reject: Dictionary=session.claim_reward("__new__")
	check(bool(reject.get("ok",false)) and not bool(reject.get("kept",true)),"player can decline extra card using existing overflow")
	check(session.world.pending_reward.is_empty() and session.world.dice_cards.size()==Catalog.DICE_CAPACITY and receipt in session.world.reward_receipts,"decline clears reward once and keeps previous cards")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.pending_reward.is_empty() and receipt in session.world.reward_receipts,"declined overflow cannot be collected again after restart")
	clear_save(path)

func discovery_exclusion_case() -> void:
	var path: String="user://six_routine_discovery_%d.json" % OS.get_process_id()
	session.save_file_path=path
	clear_save(path)
	session.start_new_world()
	var world=session.world
	var index: int=world.tiles.find("event")
	world.position=index
	world.move_serial=1
	world.laps=1
	world.contamination=0
	var probe:=RandomNumberGenerator.new()
	for seed in range(1,600):
		probe.seed=seed
		if probe.randf()>=0.60:
			world.rng.seed=seed
			break
	check(session.save_world(),"qualified discovery branch uses genuine seeded 40-percent draw")
	var chosen: Dictionary=session.begin_story_free_event(index)
	check(bool(chosen.get("ok",false)) and chosen.get("type","")=="discovery","qualified location discovery remains possible after routine addition")
	var receipt: String="routine-visit:%d:%d:%d" % [world.map_serial,world.move_serial,index]
	check(receipt in world.reward_receipts and world.pending_reward.is_empty(),"discovery also closes the current visit receipt")
	check(not bool(session.begin_story_free_event(index).get("ok",false)),"same arrival can never award both discovery and routine")
	session.reload_world()
	check(receipt in session.world.reward_receipts and not bool(session.begin_story_free_event(index).get("ok",false)),"discovery visit remains one-choice across process reload")
	clear_save(path)

func failed_save_case() -> void:
	session.save_file_path="user://six_routine_scratch_%d.json" % OS.get_process_id()
	var index: int=setup_event("abandoned_wagon")
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.save_file_path="user://missing_six_routine_directory/no.json"
	check(not bool(session.begin_story_free_event(index).get("ok",false)),"new event grant refuses failed disk save")
	check(session.world.snapshot()==before,"failed write rolls RNG, pending card and all fields back atomically")
	session.save_file_path="user://six_routine_scratch_%d.json" % OS.get_process_id()
	clear_save(session.save_file_path)

func _run() -> void:
	var existing=root.get_node_or_null("RunSession")
	var own: bool=existing==null
	session=Session.new() if own else existing
	if own:
		session.name="RunSession"
		root.add_child(session)
	var prior_path: String=session.save_file_path
	check(Routine.ORDER.size()==6 and Routine.CARDS.size()==6,"exactly six original-format routine cards registered")
	for card_id in Routine.ORDER:
		await verify_card(card_id,true)
		await verify_card(card_id,false)
	await overflow_case()
	await discovery_exclusion_case()
	await failed_save_case()
	session.save_file_path=prior_path
	if own: session.queue_free()
	print("SIX_ROUTINE_CARDS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
