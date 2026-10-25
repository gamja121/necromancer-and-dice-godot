extends SceneTree
const Catalog=preload("res://systems/reward_catalog.gd")
const Overflow=preload("res://systems/reward_overflow.gd")
var passed: int=0
var failed: int=0
var session: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("PASS ten-dice: ",message)
	else: failed+=1; printerr("FAIL ten-dice: ",message)
func fixture(count: int) -> void:
	session.start_new_world()
	for i in range(count): session.world.dice_cards.append(session.create_item("dice",Catalog.dice_cards()[i%18]))
func legacy_pending(count: int) -> String:
	fixture(count)
	session.world.lap_ready=true
	session.world.leave_home()
	var index: int=session.world.tiles.find("graveyard")
	session.world.position=index
	var item: Dictionary=session.create_item("dice",Catalog.dice_cards()[11])
	session.world.pending_reward={"id":session.place_visit_id("grave-extract",index),"index":index,"kind":"grave-dig","reward":{"kind":"dice","item":item}}
	return str(item.id)
func ids() -> Array:
	return session.world.dice_cards.map(func(item): return str(item.id))
func run() -> void:
	preload("res://systems/audio_settings.gd").apply_saved()
	session=root.get_node("RunSession")
	var original_path: String=session.save_file_path
	var path: String="user://ten_dice_capacity_%d.json" % OS.get_process_id()
	session.save_file_path=path
	check(Catalog.DICE_CAPACITY==10 and Catalog.UNIT_CAPACITY==10,"dice cap is ten and monster storage unchanged")
	fixture(9)
	session.world.lap_ready=true
	session.world.leave_home()
	var index: int=session.world.tiles.find("graveyard")
	session.world.position=index
	var result: Dictionary=session.dig_graveyard(index)
	check(result.get("ok",false) and not result.get("overflow",true) and ids().size()==10,"tenth real cemetery reward is granted directly")
	var ten_ids: Array=ids()
	session.reload_world()
	check(ids()==ten_ids,"all ten stable card IDs survive save reload")
	session.world.move_serial+=1
	result=session.dig_graveyard(index)
	check(result.get("overflow",false) and ids().size()==10,"eleventh reward opens replacement with no silent loss")
	var replacement: String=str(session.world.pending_reward.reward.item.id)
	result=session.claim_reward(str(ten_ids[0]))
	check(result.get("ok",false) and ids().size()==10 and replacement in ids() and not ten_ids[0] in ids(),"full ten-card replacement keeps capacity and correct identities")
	session.world.move_serial+=1
	result=session.dig_graveyard(index)
	var before_ids: Array=ids()
	check(result.get("overflow",false),"later full-hand reward also overflows")
	result=session.claim_reward("__new__")
	check(result.get("ok",false) and not result.get("kept",true) and ids()==before_ids,"full-hand refusal keeps all ten cards")
	var incoming: String=legacy_pending(5)
	check(session.save_world(),"legacy five-card pending overflow fixture saves")
	session.reload_world()
	var old_ids: Array=ids()
	var panel=Overflow.new()
	root.add_child(panel)
	panel.setup(session)
	check(panel.dice_room_available and panel.choices.has("__claim__") and panel.choices.size()==1 and not panel.confirm.disabled,"old five-card save offers collect and decline without asking to discard")
	panel.finish()
	check(ids().size()==6 and incoming in ids() and old_ids.all(func(id): return id in ids()),"collect from legacy UI adds sixth card and keeps all old cards")
	check(session.world.pending_reward.is_empty() and session.world.reward_receipts.has(session.place_visit_id("grave-extract",session.world.position)),"legacy UI commits receipt and closes pending transaction")
	check(not session.claim_reward().get("ok",false),"resolved legacy reward cannot be collected twice")
	panel.queue_free()
	await process_frame
	legacy_pending(5)
	old_ids=ids()
	panel=Overflow.new()
	root.add_child(panel)
	panel.setup(session)
	panel.decline_button.pressed.emit()
	check(ids()==old_ids and session.world.pending_reward.is_empty(),"legacy UI refusal preserves original five cards")
	panel.queue_free()
	await process_frame
	incoming=legacy_pending(5)
	old_ids=ids()
	check(not session.claim_reward("missing-card").get("ok",false) and ids()==old_ids,"unknown discard ID is rejected without mutation")
	result=session.claim_reward(str(old_ids[0]))
	check(result.get("ok",false) and ids().size()==6 and old_ids[0] in ids() and incoming in ids(),"legacy caller carrying an old discard ID safely keeps that card")
	legacy_pending(5)
	panel=Overflow.new()
	root.add_child(panel)
	panel.setup(session)
	session.save_file_path="user://missing_ten_dice_ui_%d/save.json" % OS.get_process_id()
	panel.decline_button.pressed.emit()
	check(panel.selected=="__claim__" and not panel.confirm.disabled and ids().size()==5,"failed refusal restores collect selection with matching button meaning")
	session.save_file_path=path
	panel.confirm.pressed.emit()
	check(ids().size()==6 and session.world.pending_reward.is_empty(),"collect after failed refusal actually collects the reward")
	panel.queue_free()
	await process_frame
	legacy_pending(5)
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.save_file_path="user://missing_ten_dice_%d/save.json" % OS.get_process_id()
	result=session.claim_reward(str(ids()[0]))
	check(not result.get("ok",false) and session.world.snapshot()==before,"failed legacy claim restores cards, RNG, receipt and pending reward")
	session.save_file_path=path
	result=session.claim_reward()
	check(result.get("ok",false) and ids().size()==6,"legacy claim retries after storage recovery")
	session.reload_world()
	check(ids().size()==6 and session.world.pending_reward.is_empty(),"migrated six-card result persists")
	# Exercise the actual map deck button without consuming a card or moving.
	fixture(10)
	var map=load("res://map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	var unchanged: Dictionary=session.world.snapshot().duplicate(true)
	map.deck_button.pressed.emit()
	var deadline: int=Time.get_ticks_msec()+3000
	while is_instance_valid(map.overlay) and map.overlay.opening and Time.get_ticks_msec()<deadline: await process_frame
	check(is_instance_valid(map.overlay) and map.overlay.options.size()==10 and not map.overlay.battle_mode,"actual map deck button opens the lower ten-card hand")
	check(map.dice_count_label.text=="주사위 카드 10/10","actual map count reflects ten-card capacity")
	map.overlay.close_button.pressed.emit()
	deadline=Time.get_ticks_msec()+2500
	while is_instance_valid(map.overlay) and Time.get_ticks_msec()<deadline: await process_frame
	check(not is_instance_valid(map.overlay) and session.world.snapshot()==unchanged,"closing actual map hand restores board without changing the saved run")
	map.queue_free()
	await process_frame
	deadline=Time.get_ticks_msec()+5000
	while not preload("res://systems/battle_resources.gd").PendingLoads.active.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	session.save_file_path=original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("TEN_DICE_CAPACITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
