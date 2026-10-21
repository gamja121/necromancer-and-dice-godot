extends SceneTree
## P4-01D: real map die -> treasure card selection -> saved reward ->
## home arrival -> heal -> visible stone shuffle -> next lap persistence.
## All changes use a PID-isolated user:// save; production data is untouched.

const MapScene = preload("res://map.tscn")
const MapState = preload("res://systems/map_state.gd")
const SessionScript = preload("res://systems/run_session.gd")

var passed: int = 0
var failed: int = 0
var path: String = ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-reward-home: ",label)
	else:
		failed += 1
		printerr("FAIL p4-reward-home: ",label)

func clear_save() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func until_ready(condition: Callable, limit_msec: int = 20000) -> bool:
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < limit_msec:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())

func panel_button(map: Control, button_text: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for child in map.overlay.get_children():
		if child is Button and child.text == button_text and child.visible:
			return child
	return null

## The genuine map RNG still chooses the die; change only two tile positions
## in the disposable test board so its first landing is a treasure tile.
func prepare_treasure_landing(world) -> int:
	# A real chest has a 10% mimic roll. Choose a predictable ordinary chest
	# seed in this disposable test only, without overriding reward behavior.
	var preview = RandomNumberGenerator.new()
	for seed_value in range(1,200):
		preview.seed = seed_value
		preview.randi_range(1,6)
		if preview.randf() >= 0.10:
			world.rng.seed = seed_value
			break
	preview.state = world.rng.state
	var destination: int = (MapState.HOME+preview.randi_range(1,6))%24
	var chest: int = world.tiles.find("gem")
	if chest < 0: return -1
	var previous: String = str(world.tiles[destination])
	world.tiles[destination] = "gem"
	world.tiles[chest] = previous
	return destination

func test_treasure(session: Node) -> void:
	session.start_new_world()
	var world = session.world
	var destination: int = prepare_treasure_landing(world)
	check(destination >= 0,"normal 24-tile board supplies an authentic chest landing")
	if destination < 0: return
	check(session.save_world(),"fixture tile swap persisted")
	var map: Control = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	await map.roll_move()
	check(world.position==destination and world.pending_move.is_empty(),"real die and hero arrive at gem tile once")
	var loaded: bool = await until_ready(func(): return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("treasure_reward.gd") and map.overlay.options.size()==3 and not map.overlay.busy)
	check(loaded,"original animated chest opens three real reward-card controls")
	if not loaded:
		map.queue_free()
		await process_frame
		return
	var initial_receipts: int = world.reward_receipts.size()
	var reward_id: String = str(world.pending_reward.id)
	check(world.pending_reward.kind=="treasure" and world.pending_reward.selected==-1,"offered reward transaction saved before selection")
	map.overlay.options[0].pressed.emit()
	check(int(world.pending_reward.selected)==0 and not world.pending_reward.has("reward"),"first card press selects only; no premature item")
	var pending_at_interrupt: Dictionary = world.pending_reward.duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	world = session.world
	check(world.pending_reward==pending_at_interrupt,"half-selected treasure resumes from JSON without new random offers")
	map = MapScene.instantiate()
	root.add_child(map)
	var resumed: bool = await until_ready(func(): return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("treasure_reward.gd") and map.overlay.options.size()==3 and not map.overlay.busy)
	check(resumed,"actual Map scene restores interrupted treasure panel")
	if not resumed:
		map.queue_free()
		await process_frame
		return
	var offer_kind: String = str(world.pending_reward.offers[0].kind)
	var count_before: int = world.roster.size() if offer_kind=="unit" else world.dice_cards.size()
	check(not map.overlay.confirm_button.disabled,"saved selection is ready for explicit reward confirmation")
	map.overlay.confirm_button.pressed.emit()
	var finished: bool = await until_ready(func(): return world.pending_reward.is_empty() and not is_instance_valid(map.overlay),30000)
	check(finished,"explicit reward button prepares, claims and closes real reward UI")
	check(world.reward_receipts.size()==initial_receipts+1 and reward_id in world.reward_receipts,"one durable unique reward receipt")
	var count_after: int = world.roster.size() if offer_kind=="unit" else world.dice_cards.size()
	check(count_after==count_before+1,"exactly one card entered the correct inventory")
	check(not session.open_treasure(destination),"same visit cannot reopen or duplicate claimed chest")
	map.queue_free()
	await process_frame
	var committed: Dictionary = world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==committed,"treasure card, receipt and closed dialog survive reload")
	check(not session.open_treasure(destination),"reloaded save still rejects duplicate treasure claim")

func test_home_and_next_lap(session: Node) -> void:
	var world = session.world
	# Fast-forward only the disposable approach; the final home step is rolled
	# through the real map method and all house buttons/stone animations run.
	var approach: int = MapState.HOME-1
	var basic: int = world.tiles.find("basic")
	if basic>=0 and basic!=approach:
		var previous: String = str(world.tiles[approach])
		world.tiles[approach] = "basic"
		world.tiles[basic] = previous
	world.position = approach
	world.roster[0].current_hp = maxi(1,int(world.roster[0].max_hp)-2)
	check(world.roster[0].current_hp<int(world.roster[0].max_hp),"test monster is injured before returning home")
	check(session.save_world(),"approach home and damaged monster saved")
	var initial_laps: int = world.laps
	var initial_contamination: int = world.contamination
	var initial_serial: int = world.map_serial
	var initial_rewards: Array = world.reward_receipts.duplicate(true)
	var map: Control = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	await map.roll_move()
	check(world.position==MapState.HOME and world.lap_ready,"real movement stops at house and marks lap ready")
	check(world.laps==initial_laps and world.contamination==initial_contamination,"arrival alone does not advance lap")
	var entrance: Button = panel_button(map,"들어가기")
	check(entrance!=null and panel_button(map,"나가기")!=null,"home exterior exposes real enter and exit controls")
	if entrance==null:
		map.queue_free()
		await process_frame
		return
	entrance.pressed.emit()
	var interior: bool = await until_ready(func(): return panel_button(map,"낙인 계승")!=null and panel_button(map,"순찰경로")!=null,12000)
	check(interior,"home entry opens real inheritance and patrol interior")
	check(world.roster.all(func(u): return int(u.current_hp)==int(u.max_hp)),"home fully restores surviving monsters")
	var exit_button: Button = panel_button(map,"나가기")
	check(exit_button!=null,"home interior supplies exit/shuffle control")
	if exit_button==null:
		map.queue_free()
		await process_frame
		return
	exit_button.pressed.emit()
	var regenerated: bool = await until_ready(func(): return not map.moving and world.map_serial==initial_serial+1,65000)
	check(regenerated,"real gather/rotation/scatter sequence finishes and board re-renders")
	check(world.laps==initial_laps+1 and world.contamination==mini(100,initial_contamination+7),"one lap and +7 contamination on leaving home")
	check(not world.lap_ready and world.cleared.is_empty() and world.tiles.size()==24,"new lap resets visit-ready/cleared state and keeps 24 tiles")
	check(world.tiles[0]=="fortune-teller-camp" and world.tiles[8]=="village" and world.tiles[MapState.HOME]=="home","fixed camp, village and home anchors survive shuffle")
	check(world.reward_receipts==initial_rewards,"map regeneration does not award, lose or duplicate inventory receipts")
	check(map.buttons.size()==24 and map.dice.visible and not map.dice.disabled and not is_instance_valid(map.overlay),"new board and die usable after exit")
	map.queue_free()
	await process_frame
	var committed: Dictionary = world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==committed,"new shuffled lap and fully healed inventory survive reload")
	check(session.world.laps==initial_laps+1 and not session.world.lap_ready,"reload cannot repeat completed lap boundary")

func _run() -> void:
	path = "user://p4_reward_home_lap_%d.json" % OS.get_process_id()
	clear_save()
	var session = root.get_node_or_null("RunSession")
	var created: bool = session==null
	if created:
		session = SessionScript.new()
		session.name = "RunSession"
		root.add_child(session)
	var original_path: String = session.save_file_path
	session.save_file_path = path
	await test_treasure(session)
	if session.world!=null and session.world.pending_reward.is_empty():
		await test_home_and_next_lap(session)
	else:
		check(false,"home sequence blocked by unresolved treasure transaction")
	session.save_file_path = original_path
	if created: session.queue_free()
	clear_save()
	check(not FileAccess.file_exists(path),"temporary save deleted; production save untouched")
	print("P4_REWARD_HOME_LAP_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
