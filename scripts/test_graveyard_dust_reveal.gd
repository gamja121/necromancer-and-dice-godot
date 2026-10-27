extends SceneTree
## Real dig commits once; soil/reveal is presentation, collect delivers it.
const MAP=preload("res://map.tscn")
const DIG=preload("res://systems/exploration_actions.gd")
const PLACE=preload("res://systems/place_actions.gd")
const CATALOG=preload("res://systems/reward_catalog.gd")
const OVERFLOW=preload("res://systems/reward_overflow.gd")
var passed:int=0
var failed:int=0
var scratch:String

func _initialize() -> void: call_deferred("run")

func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("PASS graveyard-reveal: ",label)
	else: failed+=1; printerr("FAIL graveyard-reveal: ",label)

func wait_for(predicate:Callable,limit:int=5000) -> bool:
	var deadline:int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())

func fixture(session:Node,full:bool=false) -> int:
	session.start_new_world()
	var world=session.world
	world.lap_ready=true
	world.leave_home()
	var grave:int=world.tiles.find("graveyard")
	world.position=grave
	world.graveyard_corpses=[]
	if full:
		var pool:Array=CATALOG.dice_cards()
		while world.dice_cards.size()<CATALOG.DICE_CAPACITY:
			world.dice_cards.append(session.create_item("dice",pool[world.dice_cards.size()%pool.size()]))
	world.rng.seed=521
	check(grave>=0 and session.save_world(),"isolated first-lap cemetery fixture saves")
	return grave

func open_map(grave:int) -> Control:
	var map:Control=MAP.instantiate()
	root.add_child(map)
	for frame in range(3): await process_frame
	if not is_instance_valid(map.overlay): map.show_location(grave)
	check(await wait_for(func(): return is_instance_valid(map.overlay) and map.overlay.get_script()==DIG),"real cemetery opens the direct digging UI")
	return map

func close_map(map:Control) -> void:
	var audio:Node=root.get_node_or_null("GameAudio")
	await wait_for(func(): return audio==null or audio.voices.is_empty())
	map.queue_free()
	await process_frame
	var loads=preload("res://systems/battle_resources.gd")
	await wait_for(func(): return loads.PendingLoads.active.is_empty())

func check_geometry(map:Control,panel:Control) -> void:
	var strip:TextureRect=panel.content.find_child("GraveyardNoticeStrip",true,false)
	var notice:Label=panel.content.find_child("GraveyardNoticeText",true,false)
	check(strip!=null and notice!=null,"digging retains one live lower parchment and notice")
	var fortune:=PLACE.new()
	map.add_child(fortune)
	var fortune_index:int=map.world.tiles.find("fortune-teller-camp")
	check(fortune_index>=0,"real prophet tile exists for the shared parchment reference")
	if fortune_index<0:
		fortune.queue_free()
		return
	fortune.setup(map,fortune_index)
	if strip!=null and notice!=null:
		check(strip.texture==fortune.fortune_notice_strip.texture and strip.position==fortune.fortune_notice_strip.position and strip.size==fortune.fortune_notice_strip.size,"graveyard reuses the actual prophet parchment asset and geometry")
		check(strip.position==Vector2(340,423) and strip.size==Vector2(600,150),"shared lower parchment preserves the approved 600 by 150 window")
		check(notice.position==fortune.status.position and notice.size==fortune.status.size and notice.get_theme_font_size("font_size")==fortune.status.get_theme_font_size("font_size"),"graveyard notice matches prophet placement and readable font")
		check(strip.mouse_filter==Control.MOUSE_FILTER_IGNORE and notice.mouse_filter==Control.MOUSE_FILTER_IGNORE,"parchment and labels cannot steal button input")
	fortune.queue_free()
	await process_frame
	for button in [panel.action_button,panel.graveyard_exit_button]:
		var rect:Rect2=map.TILE_EVENT_ACTION_RECT if button==panel.action_button else map.TILE_EVENT_EXIT_RECT
		check(button.position==rect.position and button.size==rect.size,"graveyard action uses the shared ordinary-tile button geometry")
		var style:StyleBoxTexture=button.get_theme_stylebox("normal") as StyleBoxTexture
		check(style!=null and style.texture.resource_path.ends_with("parchment_button_variant_04.png") and button.get_theme_font_size("font_size")==18 and button.z_index==11,"graveyard action keeps the original tile button artwork, font and depth")

func normal_case(session:Node) -> void:
	var grave:int=fixture(session)
	var map:Control=await open_map(grave)
	var panel:Control=map.overlay
	await check_geometry(map,panel)
	var count_before:int=session.world.dice_cards.size()
	panel.action_button.pressed.emit()
	check(panel.busy and panel.graveyard_phase=="revealing","dig begins the complete reveal and input lock")
	check(panel.action_button.disabled and panel.graveyard_exit_button.disabled,"dig and exit both remain locked during reveal")
	check(session.world.dice_cards.size()==count_before+1 and session.place_visit_id("grave-extract",grave) in session.world.reward_receipts,"backend card and once-visit receipt are durable before reveal")
	var committed:Dictionary=session.world.snapshot().duplicate(true)
	var saved:PackedByteArray=FileAccess.get_file_as_bytes(scratch)
	var random_after:int=session.world.rng.state
	panel.dig_graveyard()
	panel.action_button.pressed.emit()
	panel.graveyard_exit_button.pressed.emit()
	check(session.world.snapshot()==committed and is_instance_valid(map.overlay),"repeated dig and early exit cannot duplicate a reward or bypass reveal")
	check(await wait_for(func(): return not panel.busy and panel.graveyard_phase=="ready"),"soil shedding and card reveal finish before collect is enabled")
	check(is_instance_valid(panel.graveyard_motion) and panel.graveyard_motion.name=="GraveyardRewardMotion","revealed reward belongs to the complete graveyard motion")
	check(panel.find_child("GraveyardFoundDiceCard",true,false) is Control,"complete found-card visual remains nested inside the motion")
	var card:TextureRect=panel.graveyard_motion.front if is_instance_valid(panel.graveyard_motion) else null
	var item:Dictionary=session.world.dice_cards[-1]
	check(card!=null and card.texture!=null and card.texture.resource_path=="res://assets/cards/dice-control-ko-%s.png"%str(item.image),"ready face uses the actual original green dice-control card")
	check(panel.action_button.name=="GraveyardCollectConfirm" and panel.action_button.text=="챙기고 나가기" and not panel.action_button.disabled,"ready reward waits for the explicit collect primary")
	check(not map.routine_deck_delivery and panel.find_child("RewardOverflow",true,false)==null,"a normal revealed card has neither early delivery nor overflow popup")
	await create_timer(0.10).timeout
	check(is_instance_valid(map.overlay) and session.world.snapshot()==committed,"ready card is not collected automatically")
	check(session.world.rng.state==random_after and FileAccess.get_file_as_bytes(scratch)==saved,"reveal consumes no extra RNG and rewrites no saved reward")
	panel.action_button.pressed.emit()
	check(panel.busy and panel.graveyard_phase=="delivering","explicit collection starts delivery")
	check(map.routine_deck_delivery and map.deck_button.visible and map.deck_button.z_index>panel.z_index,"the actual right deck is raised as the flight destination")
	panel.collect_graveyard()
	check(session.world.snapshot()==committed,"double collection does not grant or save another card")
	check(await wait_for(func(): return not is_instance_valid(map.overlay)),"map closes only after right-deck delivery finishes")
	check(not map.routine_deck_delivery and map.deck_button.texture_normal.resource_path.ends_with("map-card-deck.png"),"delivery restores the real deck chrome")
	check(session.world.snapshot()==committed and session.world.rng.state==random_after and FileAccess.get_file_as_bytes(scratch)==saved,"delivery and cleanup preserve committed gameplay and save bytes")
	await close_map(map)
	session.reload_world()
	check(session.world.snapshot()==committed,"collected card and receipt survive reload unchanged")

func save_failure_case(session:Node) -> void:
	var grave:int=fixture(session)
	var map:Control=await open_map(grave)
	var panel:Control=map.overlay
	var before:Dictionary=session.world.snapshot().duplicate(true)
	var saved:PackedByteArray=FileAccess.get_file_as_bytes(scratch)
	session.save_file_path="user://missing_graveyard_reveal_%d/save.json"%OS.get_process_id()
	panel.action_button.pressed.emit()
	await process_frame
	check(not panel.busy and panel.graveyard_phase=="idle" and panel.graveyard_result.is_empty(),"failed backend save releases the lock without presenting a reward")
	check(not panel.action_button.disabled and not is_instance_valid(panel.graveyard_overflow),"failed save leaves a retryable dig without a reward decision")
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(scratch)==saved,"failed UI dig rolls back RNG, receipt and inventory and leaves the old save intact")
	session.save_file_path=scratch
	await close_map(map)

func full_hand_case(session:Node,keep:bool,resume:bool=false) -> void:
	var grave:int=fixture(session,true)
	var map:Control=await open_map(grave)
	var panel:Control=map.overlay
	var old_ids:Array=session.world.dice_cards.map(func(item): return str(item.id))
	panel.action_button.pressed.emit()
	check(session.world.pending_reward.get("kind","")=="grave-dig" and session.world.dice_cards.size()==CATALOG.DICE_CAPACITY,"full hand immediately saves one exact pending reward without granting it")
	var prize:Dictionary=session.world.pending_reward.reward.item.duplicate(true)
	var random_after:int=session.world.rng.state
	check(not is_instance_valid(panel.graveyard_overflow),"overflow popup does not cover the card reveal")
	check(await wait_for(func(): return not panel.busy and panel.graveyard_phase=="ready"),"full hand also finishes the reveal before a player decision")
	check(not is_instance_valid(panel.graveyard_overflow),"ready full-hand card still waits for explicit collection")
	if resume:
		await close_map(map)
		session.reload_world()
		map=await open_map(grave)
		panel=map.overlay
		check(panel.graveyard_phase=="ready" and not panel.busy and not is_instance_valid(panel.graveyard_overflow),"saved overflow resumes directly at ready without replaying the dig or opening a popup")
		check(str(panel.graveyard_result.id)==str(prize.id) and session.world.rng.state==random_after,"resume presents the exact saved card without another random draw")
	panel.action_button.pressed.emit()
	check(await wait_for(func(): return is_instance_valid(panel.graveyard_overflow)),"collect opens the existing explicit overflow decision")
	var popup:Control=panel.graveyard_overflow
	check(popup.get_script()==OVERFLOW and panel.graveyard_phase=="overflow" and not map.routine_deck_delivery,"replacement precedes delivery and uses the unchanged overflow UI")
	if keep: popup.select_card(str(old_ids[0]))
	else: popup.select_card("__new__")
	popup.confirm.pressed.emit()
	check(session.world.pending_reward.is_empty() and session.place_visit_id("grave-extract",grave) in session.world.reward_receipts,"keep or refusal saves the once-visit receipt before any delivery")
	var resolved:Dictionary=session.world.snapshot().duplicate(true)
	var resolved_bytes:PackedByteArray=FileAccess.get_file_as_bytes(scratch)
	if keep:
		check(panel.graveyard_phase=="delivering" and map.routine_deck_delivery,"kept overflow starts flight only after the replacement commit")
		check(session.world.dice_cards.size()==CATALOG.DICE_CAPACITY and session.world.dice_cards.any(func(item): return str(item.id)==str(prize.id)) and not session.world.dice_cards.any(func(item): return str(item.id)==str(old_ids[0])),"kept result contains the saved new card and removes only the chosen old one")
		check(await wait_for(func(): return not is_instance_valid(map.overlay)),"kept overflow finishes its deck flight and exits")
	else:
		check(not map.routine_deck_delivery and (not is_instance_valid(map.overlay) or panel.graveyard_phase!="delivering"),"refusal never animates an unowned card into the deck")
		check(session.world.dice_cards.map(func(item): return str(item.id))==old_ids,"refusal preserves all original cards")
		await create_timer(0.15).timeout
		check(not map.routine_deck_delivery,"refusal does not start a delayed delivery")
	check(session.world.snapshot()==resolved and session.world.rng.state==random_after and FileAccess.get_file_as_bytes(scratch)==resolved_bytes,"overflow presentation does not reroll or change the resolved transaction")
	await close_map(map)
	session.reload_world()
	check(session.world.snapshot()==resolved,"overflow decision and receipt survive reload")

func interrupted_reveal_case(session:Node,detached:bool=false) -> void:
	var grave:int=fixture(session)
	var map:Control=await open_map(grave)
	var panel:Control=map.overlay
	panel.action_button.pressed.emit()
	check(panel.busy and panel.graveyard_phase=="revealing","interruption fixture removes a reveal that is actually in flight")
	var committed:Dictionary=session.world.snapshot().duplicate(true)
	var saved:PackedByteArray=FileAccess.get_file_as_bytes(scratch)
	await create_timer(0.20).timeout
	var old_content:Control=panel.content
	var child_count:int=panel.get_child_count()
	var panel_reference:WeakRef=weakref(panel)
	if detached:
		root.remove_child(map)
		await process_frame
		check(not map.is_inside_tree() and panel.content==old_content and panel.get_child_count()==child_count,"detaching the actual map does not rebuild its exiting digging UI")
		map.free()
	else:
		map.queue_free()
		await process_frame
	await create_timer(0.10).timeout
	check(panel_reference.get_ref()==null,"queued or detached map teardown frees its digging panel")
	check(root.find_child("GraveyardRewardMotion",true,false)==null,"removing the owning map removes the unfinished soil and card motion")
	check(session.world.snapshot()==committed and FileAccess.get_file_as_bytes(scratch)==saved,"cancelling presentation cannot undo or rewrite the already saved card")
	session.reload_world()
	check(session.world.snapshot()==committed,"reload after interrupted reveal retains the exact granted card and receipt")
	map=await open_map(grave)
	panel=map.overlay
	check(not panel.busy and panel.action_button.disabled and session.world.snapshot()==committed,"interrupted normal dig reopens as a spent visit without rerolling or granting another card")
	await close_map(map)

func interrupted_delivery_case(session:Node,detach_during_settle:bool=false) -> void:
	var grave:int=fixture(session)
	var map:Control=await open_map(grave)
	var panel:Control=map.overlay
	panel.action_button.pressed.emit()
	check(await wait_for(func(): return not panel.busy and panel.graveyard_phase=="ready"),"delivery cancellation fixture first completes the saved reward reveal")
	var committed:Dictionary=session.world.snapshot().duplicate(true)
	var saved:PackedByteArray=FileAccess.get_file_as_bytes(scratch)
	var random_after:int=session.world.rng.state
	var motion:Control=panel.graveyard_motion
	var motion_reference:WeakRef=weakref(motion)
	var panel_reference:WeakRef=weakref(panel)
	panel.action_button.pressed.emit()
	check(panel.graveyard_phase=="delivering" and motion.get_parent()==map.stage and map.routine_deck_delivery,"cancellation starts with a real motion reparented to the map stage")
	if detach_during_settle:
		check(await wait_for(func(): return map.stage.find_child("GraveyardDeliveryCount",true,false)!=null),"map detachment targets the receiving-deck settle pulse after flight")
		var tag:Node=map.stage.find_child("GraveyardDeliveryCount",true,false)
		var tag_reference:WeakRef=weakref(tag) if tag!=null else null
		check(tag!=null and motion.phase=="done" and panel.graveyard_phase=="delivering","settle pulse still belongs to the live delivery owner")
		var old_content:Control=panel.content
		var child_count:int=panel.get_child_count()
		root.remove_child(map)
		await process_frame
		check(not map.is_inside_tree() and panel.content==old_content and panel.get_child_count()==child_count,"detaching the map during settle does not rebuild its exiting UI")
		map.free()
		await process_frame
		check(tag_reference==null or tag_reference.get_ref()==null,"map cancellation frees the count tag from the interrupted settle pulse")
	else:
		await create_timer(0.12).timeout
		check(motion.phase=="collecting" and map.stage.find_child("GraveyardDeliveryCount",true,false)==null,"owner removal targets the card flight before its receiving pulse")
		panel.queue_free()
		check(await wait_for(func(): return map.overlay==null and not map.routine_deck_delivery),"removing only the owner clears the map overlay and delivery flag")
		check(await wait_for(func(): return motion_reference.get_ref()==null),"owner removal cancels and frees the reparented flight motion")
		check(map.stage.find_child("GraveyardDeliveryCount",true,false)==null,"cancelled card flight leaves no receiving count tag")
		check(map.dice.visible and not map.dice.disabled and map.deck_button.scale==Vector2.ONE and map.deck_button.texture_normal.resource_path.ends_with("map-card-deck.png"),"owner-only cancellation restores shared die input and the closed deck")
		await close_map(map)
	await create_timer(0.10).timeout
	check(panel_reference.get_ref()==null and motion_reference.get_ref()==null,"delivery cancellation releases both its owner and reparented effect")
	check(root.find_child("GraveyardRewardMotion",true,false)==null and root.find_child("GraveyardDeliveryCount",true,false)==null,"cancelled delivery leaves no motion or count tag in the live tree")
	check(session.world.snapshot()==committed and session.world.rng.state==random_after and FileAccess.get_file_as_bytes(scratch)==saved,"owner or map cancellation preserves the exact committed save, snapshot and RNG")
	session.reload_world()
	check(session.world.snapshot()==committed,"cancelled delivery reward and receipt survive reload without another grant")

func run() -> void:
	var session:Node=root.get_node("RunSession")
	var old_path:String=session.save_file_path
	scratch="user://graveyard_reveal_%d.json"%OS.get_process_id()
	session.save_file_path=scratch
	await normal_case(session)
	await save_failure_case(session)
	await full_hand_case(session,true,true)
	await full_hand_case(session,false)
	await interrupted_reveal_case(session,false)
	await interrupted_reveal_case(session,true)
	await interrupted_delivery_case(session,false)
	await interrupted_delivery_case(session,true)
	var loads=preload("res://systems/battle_resources.gd")
	check(await wait_for(func(): return loads.PendingLoads.active.is_empty()),"all exited resource requests drain before shutdown")
	var audio:Node=root.get_node_or_null("GameAudio")
	check(await wait_for(func(): return audio==null or audio.voices.is_empty()),"all isolated presentation audio finishes before shutdown")
	if audio!=null: audio.queue_free()
	await create_timer(0.10).timeout
	session.save_file_path=old_path
	session.world=null
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	check(not FileAccess.file_exists(scratch),"isolated graveyard save is removed")
	print("GRAVEYARD_DUST_REVEAL: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
