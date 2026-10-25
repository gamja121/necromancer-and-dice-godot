extends SceneTree
const MapScene=preload("res://map.tscn")
const Routine=preload("res://systems/routine_event_catalog.gd")
const Catalog=preload("res://systems/reward_catalog.gd")
const Loads=preload("res://systems/battle_resources.gd")
var session: Node
var passed: int=0
var failed: int=0
var paths: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("PASS routine-motion: ",message)
	else: failed+=1; printerr("FAIL routine-motion: ",message)
func wait_for(predicate: Callable, limit: int=7000) -> bool:
	var deadline: int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func settle() -> void:
	await process_frame
	await process_frame
func fixture(tag: String, event_id: String, full: bool=false) -> Control:
	var path: String="user://routine_motion_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	session.save_file_path=path
	session.start_new_world()
	var w=session.world
	w.position=w.tiles.find("event")
	w.move_serial=1
	w.contamination=10
	for unit in w.roster: unit.current_hp=maxi(1,int(unit.max_hp)-1)
	if full:
		for source in Catalog.dice_cards().slice(0,Catalog.DICE_CAPACITY): w.dice_cards.append(session.create_item("dice",source))
	var probe=RandomNumberGenerator.new()
	for seed in range(1,600):
		probe.seed=seed
		if Routine.choose(probe)==event_id:
			w.rng.seed=seed
			break
	check(session.begin_story_free_event(w.position).get("event_id","")==event_id,"real saved "+event_id+" fixture")
	var map=MapScene.instantiate()
	root.add_child(map)
	await settle()
	return map
func accept(map: Control) -> Control:
	map.overlay.get_node("RoutineEventCard/RoutineAccept").pressed.emit()
	check(await wait_for(func(): return is_instance_valid(map.overlay) and map.overlay.get_node_or_null("RoutineRewardMotion")!=null),"acceptance creates one presentation")
	return map.overlay.get_node("RoutineRewardMotion")
func dispose(map: Control) -> void:
	map.queue_free()
	await settle()
func click_collect() -> void:
	var point:=Vector2(494,340)
	for down in [true,false]:
		var press=InputEventMouseButton.new()
		press.button_index=MOUSE_BUTTON_LEFT
		press.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		press.position=point
		press.global_position=point
		press.pressed=down
		root.push_input(press,true)
		await process_frame
func normal_case(event_id: String, fail_first: bool=false) -> void:
	var map=await fixture(event_id,event_id)
	var before: Dictionary=session.world.snapshot().duplicate(true)
	var motion=await accept(map)
	check(motion.back.visible and not motion.front.visible and motion.visual.z_index<map.overlay.get_node("RoutineEventCard").z_index,"reward begins behind the actual event card")
	motion.collect()
	check(session.world.snapshot()==before and motion.phase=="opening","early collect is blocked without awarding or rerolling")
	check(await wait_for(func(): return motion.phase=="ready"),"orbit and front flip complete")
	check(motion.front.visible and not motion.back.visible and motion.visual.z_index>map.overlay.get_node("RoutineEventCard").z_index,"front reward is above the original card")
	check(motion.visual.scale.is_equal_approx(Vector2.ONE) and session.world.snapshot()==before,"ready reward is readable and awaiting its one click")
	var artwork_fits: bool=true
	for art in motion.find_children("*","TextureRect",true,false):
		if art.size.x>motion.SIZE.x or art.size.y>motion.SIZE.y: artwork_fits=false
	check(artwork_fits,"native reward artwork fits its card instead of its imported texture minimum")
	var text_fits: bool=true
	for copy in motion.front.find_children("*","Label",true,false):
		if copy.position.x+copy.size.x>motion.SIZE.x or copy.size.y<copy.get_line_count()*copy.get_line_height(): text_fits=false
	check(text_fits,"reward title, amount and wrapped footer stay inside the small card")
	check(map.overlay.get_node("RoutineEventCard/EventDiscoveryDescription").size.x<=368,"event body retains the approved text width")
	var path: String=session.save_file_path
	if fail_first:
		session.save_file_path="user://missing_routine_motion_%d/save.json" % OS.get_process_id()
		motion.collect()
		check(motion.phase=="ready" and session.world.snapshot()==before,"failed collect restores the exact preview and allows retry")
		session.save_file_path=path
	await click_collect()
	check(motion.phase=="collecting" and session.world.pending_reward.is_empty(),"one native extra click saves once and starts delivery")
	var saved: Dictionary=session.world.snapshot().duplicate(true)
	motion.collect()
	check(session.world.snapshot()==saved,"rapid duplicate click cannot duplicate a reward")
	if motion.effect=="dice":
		var target: Vector2=motion.get_global_transform_with_canvas().affine_inverse()*(map.deck_button.get_global_transform_with_canvas()*(map.deck_button.size*0.5))
		check(map.deck_button.visible and map.deck_button.disabled and map.deck_button.mouse_filter==Control.MOUSE_FILTER_IGNORE,"actual right deck is shown but cannot receive input during flight")
		check(motion.delivery_target.distance_to(target)<0.1,"dice reward flies to the actual deck center")
	else:
		check(motion.delivery_target==Vector2(640,490),"health/purification reward descends toward the lower center")
	check(await wait_for(func(): return not is_instance_valid(map.overlay)),"flight/arrival pulse completes and restores playable map")
	check(session.world.snapshot()==saved and not map.routine_deck_delivery,"animation changes no saved result and restores deck state")
	await dispose(map)
	session.reload_world()
	check(session.world.snapshot()==saved,"received reward survives restart without replay or duplicate")
func immediate_case(event_id: String, effect_name: String) -> void:
	var map=await fixture(event_id,event_id)
	var before: Dictionary=session.world.snapshot().duplicate(true)
	var card: Control=map.overlay.get_node("RoutineEventCard")
	var path: String=session.save_file_path
	session.save_file_path="user://missing_routine_effect_%d/save.json" % OS.get_process_id()
	card.get_node("RoutineAccept").pressed.emit()
	check(session.world.snapshot()==before and not card.choosing,"failed immediate reward save restores the same choice")
	check(map.get_node_or_null(effect_name)==null,"failed reward never plays a success effect")
	session.save_file_path=path
	card.get_node("RoutineAccept").pressed.emit()
	check(session.world.pending_reward.is_empty(),"immediate "+event_id+" is saved on the original choice")
	check(map.overlay.get_node_or_null("RoutineRewardMotion")==null and not card.visible,"non-dice reward creates no collectible card")
	var effect: Control=map.get_node_or_null(effect_name)
	check(effect!=null and effect.mouse_filter==Control.MOUSE_FILTER_STOP,"existing effect blocks input while it plays")
	if effect_name=="FullHealEffect":
		check(effect.find_children("*","TextureRect",true,false).size()==18,"recovery reuses all eighteen original full-screen green crosses")
	else:
		await create_timer(0.35).timeout
		check(effect.get_node("RewardTile").get_global_rect().get_center().distance_to(Vector2(640,360))<0.1,"tile alone is centered on the screen")
		check(effect.get_node("TileRewardShade").color.a>0.75 and effect.find_children("*","Label",true,false).is_empty(),"tile reveal darkens its surroundings and adds no caption/card")
	var saved: Dictionary=session.world.snapshot().duplicate(true)
	await click_collect()
	check(session.world.snapshot()==saved,"click during immediate effect cannot award again")
	check(await wait_for(func(): return not is_instance_valid(map.overlay)),"immediate reward clears itself without a collect click")
	check(map.get_node_or_null(effect_name)==null,"completed immediate effect removes its layer")
	await dispose(map)
	session.reload_world()
	check(session.world.snapshot()==saved,"immediate reward is durable once without replay")

func interrupted_preview() -> void:
	var map=await fixture("interrupted","abandoned_wagon")
	var before: Dictionary=session.world.pending_reward.duplicate(true)
	await accept(map)
	await dispose(map)
	session.reload_world()
	check(session.world.pending_reward==before and session.world.dice_cards.is_empty(),"quit during reveal resumes the same unclaimed choice with no reroll")
func interrupted_flight() -> void:
	var map=await fixture("flight","abandoned_wagon")
	var motion=await accept(map)
	await wait_for(func(): return motion.phase=="ready")
	motion.collect()
	var saved: Dictionary=session.world.snapshot().duplicate(true)
	await dispose(map)
	session.reload_world()
	check(session.world.snapshot()==saved and session.world.dice_cards.size()==1,"quit during flight preserves the single already-saved card")
func overflow_case(keep: bool, resume: bool=false) -> void:
	var map=await fixture("overflow_%s_%s" % [keep,resume],"wounded_soldier",true)
	var old_ids: Array=session.world.dice_cards.map(func(item): return item.id)
	var motion=await accept(map)
	await wait_for(func(): return motion.phase=="ready")
	motion.collect()
	check(session.world.pending_reward.get("phase","")=="overflow" and session.world.dice_cards.size()==10,"full hand waits for the original swap before delivery")
	var incoming: String=str(session.world.pending_reward.reward.item.id)
	if resume:
		await dispose(map)
		session.reload_world()
		map=MapScene.instantiate()
		root.add_child(map)
		await settle()
	var popup: Control=map.overlay if resume else map.overlay.get_node("RoutineRewardOverflow")
	check(popup.name=="RoutineRewardOverflow","original overflow UI is available after preview or reload")
	popup.select_card(str(old_ids[0]) if keep else "__new__")
	popup.finish()
	if keep:
		check(incoming in session.world.dice_cards.map(func(item): return item.id) and map.routine_deck_delivery,"only kept overflow reward starts the right-deck delivery")
		if resume:
			var delivery: Control=map.overlay.get_node("RoutineRewardMotion")
			check(map.overlay.z_index==80,"resumed flight stays above map hero and die")
			check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(Rect2(delivery.visual.position,delivery.visual.size)),"clipped overflow reward starts from a visible fallback")
	else:
		check(session.world.dice_cards.map(func(item): return item.id)==old_ids and not map.routine_deck_delivery,"declining overflow keeps the original hand and never flies to the deck")
	check(await wait_for(func(): return not is_instance_valid(map.overlay)),"overflow resolution finishes without a stuck overlay")
	check(session.world.pending_reward.is_empty() and session.world.dice_cards.size()==10,"overflow always preserves capacity and closes the transaction once")
	await dispose(map)
func run() -> void:
	preload("res://systems/audio_settings.gd").apply_saved()
	session=root.get_node("RunSession")
	var old_path: String=session.save_file_path
	await normal_case("abandoned_wagon",true)
	await immediate_case("smoke_camp","FullHealEffect")
	await immediate_case("broken_seal","TileRewardReveal")
	await interrupted_preview()
	await interrupted_flight()
	await overflow_case(true)
	await overflow_case(false)
	await overflow_case(true,true)
	var end: int=Time.get_ticks_msec()+5000
	while not Loads.PendingLoads.active.is_empty() and Time.get_ticks_msec()<end: await process_frame
	session.save_file_path=old_path
	for path in paths:
		for suffix in ["",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("ROUTINE_REWARD_REVEAL: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
