extends SceneTree
## P4-01E: one persisted run, with real Title -> Intro -> Map -> dice ->
## embedded battle -> capture -> treasure -> home -> next shuffled lap.
## Test-only deterministic RNG and one relocation close to home avoid unrelated
## map events; NEVER restart a run or alter production assets/rules.
## Run: godot --headless --path . --script res://scripts/test_p4_single_run_end_to_end.gd

const TITLE_SCENE = preload("res://title.tscn")
const MAP_SCENE = preload("res://map.tscn")
const SessionScript = preload("res://systems/run_session.gd")
const MapState = preload("res://systems/map_state.gd")

var passed: int = 0
var failed: int = 0
var save_path: String = ""
var audio_path: String = ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-single-run: ",label)
	else:
		failed += 1
		printerr("FAIL p4-single-run: ",label)

func clear_path(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func until_ready(condition: Callable, limit_msec: int = 18000) -> bool:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < limit_msec:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())

func wait_for_scene(scene_name: String, limit_msec: int = 10000) -> Control:
	var ok: bool = await until_ready(func(): return current_scene != null and current_scene.name == scene_name,limit_msec)
	return current_scene as Control if ok else null

func panel_button(map: Control, label: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for child in map.overlay.get_children():
		if child is Button and child.text == label and child.visible:
			return child
	return null

func start_from_title(session: Node) -> Control:
	var title: Control = TITLE_SCENE.instantiate()
	title.set("audio_save_path",audio_path)
	root.add_child(title)
	current_scene = title
	await process_frame
	var start: Button = title.get_node_or_null("TitleUI/MenuPanel/Menu/NewRun")
	check(start != null and not start.disabled,"real title has enabled New Run")
	if start == null: return null
	start.pressed.emit()
	check(session.world != null and session.has_save(),"title creates and persists one new expedition")
	var intro: Control = await wait_for_scene("Intro")
	check(intro != null,"new run enters actual Intro scene")
	if intro == null: return null
	var lines: Array = intro.get("lines")
	var advance: Button = intro.get("advance_button")
	check(lines.size()==12 and advance!=null,"all 12 original dialogue beats and click target exist")
	if advance==null: return null
	for i in range(lines.size()): advance.pressed.emit()
	check(intro.get("line_index")==11,"intro advanced through all 12 dialogue beats")
	intro.set("ending_duration",0.1)
	advance.pressed.emit()
	var map: Control = await wait_for_scene("Map",12000)
	check(map!=null and map.world==session.world,"intro finishes in the real saved 24-tile map")
	if map!=null:
		check(map.buttons.size()==24 and map.dice.visible and not map.dice.disabled,"original board and die usable after intro")
		check(session.world.roster.size()==2 and session.world.laps==0,"one run starts with two monsters and no completed laps")
	return map

## Reorder only a pair of tiles in the one disposable saved world. Actual
## in-game map die, map arrival dispatcher, deck and encounter remain original.
func swap_next_landing(world, kind: String, normal_chest: bool = false) -> int:
	var preview = RandomNumberGenerator.new()
	if normal_chest:
		var chosen: bool = false
		for seed_value in range(1,2000):
			preview.seed = seed_value
			var next_face: int = preview.randi_range(1,6)
			var next_index: int = (int(world.position)+next_face)%24
			if next_index in [0,8,MapState.HOME]: continue
			if preview.randf()<0.10: continue
			world.rng.seed = seed_value
			chosen = true
			break
		if not chosen: return -1
	preview.state = world.rng.state
	var face: int = preview.randi_range(1,6)
	var target: int = (int(world.position)+face)%24
	if target in [0,8,MapState.HOME]: return -1
	if world.tiles[target]!=kind:
		var source: int = -1
		for i in range(world.tiles.size()):
			if i not in [0,8,MapState.HOME,target] and world.tiles[i]==kind:
				source = i
				break
		if source<0: return -1
		var replaced: String = str(world.tiles[target])
		world.tiles[target] = kind
		world.tiles[source] = replaced
	return target

func force_allied_victory(battle: Control) -> void:
	# Test-only combat strengths: the production attack queue, dice and
	# animations still decide the encounter outcome on the actual battlefield.
	for unit in battle.rules.units:
		unit.passive = ""
		unit.brands = []
		unit.poison = []
		unit.frozen = false
		unit.undying_used = false
		unit.shields = 0
		unit.curse = {}
		unit.bless = {}
		var ally: bool = unit.team=="ally"
		unit.base_attack = 999 if ally else 0
		unit.attack = unit.base_attack
		unit.base_speed = 999 if ally else 0
		unit.speed = unit.base_speed
		if not ally: unit.hp = 1
	battle.rules.refresh()
	battle.session.encounter.checkpoint = battle.rules.snapshot()
	battle.session.world.active_encounter = battle.session.encounter.duplicate(true)
	check(battle.session.save_world(),"deterministic combat fixture uses genuine saved checkpoint")

func fight_and_capture(session: Node, map: Control) -> bool:
	var world = session.world
	var target: int = swap_next_landing(world,"monster")
	check(target>=0,"same run can target an ordinary encounter with real map die")
	if target<0: return false
	check(session.save_world(),"encounter tile permutation persisted")
	map.render()
	await map.roll_move()
	check(world.position==target and world.pending_move.is_empty(),"first real die lands on monster and finalizes movement")
	var deck: Control = map.overlay
	check(is_instance_valid(deck) and deck.get_script()!=null and deck.get_script().resource_path.ends_with("battle_deck.gd"),"monster arrival opens actual battle deck")
	if not is_instance_valid(deck): return false
	deck.toggle_unit(str(world.roster[0].id))
	deck.toggle_unit(str(world.roster[1].id))
	check(not deck.confirm_button.disabled and deck.selected_ids.size()==2,"owned monster cards selected in battle deck")
	deck.confirm_button.pressed.emit()
	var started: bool = await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.rules.units.is_empty(),15000)
	check(started,"real embedded battlefield starts from deck button")
	if not started: return false
	var battle: Control = map.embedded_battle
	var previous_receipts: int = world.reward_receipts.size()
	force_allied_victory(battle)
	var turns: int = 0
	while battle.rules.winner().is_empty() and turns<8:
		turns += 1
		await battle.roll_round()
	check(battle.rules.winner()=="ally","real battle dice/actions resolve allied victory")
	check(world.cleared.has(target) and session.encounter.is_empty(),"victory clears encounter tile and durable active checkpoint")
	check(world.pending_reward.get("kind","")=="capture" and is_instance_valid(battle.capture_panel),"fallen enemies open genuine soul capture")
	if not is_instance_valid(battle.capture_panel): return false
	for i in range(3):
		if not is_instance_valid(map.embedded_battle) or world.pending_reward.is_empty(): break
		if not is_instance_valid(battle.capture_panel): break
		await battle.capture_panel.roll()
	var returned: bool = await until_ready(func(): return map.embedded_battle == null and not map.battle_returning and world.pending_reward.is_empty(),18000)
	check(returned,"capture ends and original map/die return, without a new world")
	check(world.reward_receipts.size()==previous_receipts+1,"one capture receipt, successful or failed")
	check(map.world==session.world and map.buttons.size()==24 and map.dice.visible,"battle return preserves the very same world and board")
	return returned

func claim_treasure_and_resume(session: Node, map: Control) -> Control:
	var world = session.world
	var destination: int = swap_next_landing(world,"gem",true)
	check(destination>=0,"same expedition can roll to deterministic ordinary treasure")
	if destination<0: return null
	check(session.save_world(),"treasure approach persisted")
	map.render()
	await map.roll_move()
	check(world.position==destination and world.pending_move.is_empty(),"second real die lands on chest in same run")
	var open: bool = await until_ready(func(): return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("treasure_reward.gd") and map.overlay.options.size()==3 and not map.overlay.busy,20000)
	check(open,"animated chest displays original three reward cards")
	if not open: return null
	var receipts: int = world.reward_receipts.size()
	var reward_id: String = str(world.pending_reward.id)
	map.overlay.options[0].pressed.emit()
	check(world.pending_reward.get("selected",-1)==0 and not world.pending_reward.has("reward"),"first card press selects without granting")
	var interrupted: Dictionary = world.pending_reward.duplicate(true)
	current_scene = null
	map.queue_free()
	await process_frame
	session.reload_world()
	world = session.world
	check(world.pending_reward==interrupted,"same run restores interrupted card choice from saved JSON")
	map = MAP_SCENE.instantiate()
	root.add_child(map)
	current_scene = map
	var restored: bool = await until_ready(func(): return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("treasure_reward.gd") and map.overlay.options.size()==3 and not map.overlay.busy,20000)
	check(restored,"reopened Map restores selected chest and original inventory")
	if not restored: return null
	var kind: String = str(world.pending_reward.offers[0].kind)
	var count_before: int = world.roster.size() if kind=="unit" else (world.dice_cards.size() if kind=="dice" else world.brand_cards.size())
	map.overlay.options[0].pressed.emit()
	var claimed: bool = await until_ready(func(): return world.pending_reward.is_empty() and not is_instance_valid(map.overlay),30000)
	check(claimed,"second press claims actual card and closes reward panel")
	var count_after: int = world.roster.size() if kind=="unit" else (world.dice_cards.size() if kind=="dice" else world.brand_cards.size())
	check(count_after==count_before+1,"one new inventory card in correct collection")
	check(world.reward_receipts.size()==receipts+1 and reward_id in world.reward_receipts,"one unique treasure receipt, no duplicate capture")
	check(not session.open_treasure(destination),"same chest visit cannot be claimed twice")
	return map if claimed else null

func return_home_and_advance(session: Node, map: Control) -> bool:
	var world = session.world
	var before_laps: int = world.laps
	var before_contamination: int = world.contamination
	var before_serial: int = world.map_serial
	var receipts: Array = world.reward_receipts.duplicate(true)
	# Shorten only the uneventful travel between reward and home; the
	# final home arrival remains an actual user-facing map die action.
	world.position = MapState.HOME-1
	world.roster[0].current_hp = maxi(1,int(world.roster[0].max_hp)-2)
	check(world.roster[0].current_hp<world.roster[0].max_hp,"surviving roster can enter home injured")
	check(session.save_world(),"same run stores near-home approach after rewards")
	map.render()
	await map.roll_move()
	check(world.position==MapState.HOME and world.lap_ready,"third real die enters home and sets end-of-lap readiness")
	check(world.laps==before_laps and world.contamination==before_contamination,"home arrival alone cannot advance lap or contamination")
	var enter: Button = panel_button(map,"들어가기")
	check(enter!=null,"home arrival shows original enter button")
	if enter==null: return false
	enter.pressed.emit()
	var interior: bool = await until_ready(func(): return panel_button(map,"낙인 계승")!=null and panel_button(map,"순찰경로")!=null)
	check(interior,"same run opens real house interior with inheritance and patrol actions")
	check(world.roster.all(func(u): return int(u.current_hp)==int(u.max_hp)),"house heals all surviving monsters without reviving the dead")
	var leave: Button = panel_button(map,"나가기")
	if leave==null: return false
	leave.pressed.emit()
	var completed: bool = await until_ready(func(): return not map.moving and world.map_serial==before_serial+1,65000)
	check(completed,"original stone gather/rotation/scatter and new board complete")
	check(world.laps==before_laps+1 and world.contamination==mini(100,before_contamination+4),"exactly one next lap and +4 contamination")
	check(world.tiles.size()==24 and world.cleared.is_empty() and not world.lap_ready,"next lap clears previous cleared tiles without changing board count")
	check(world.tiles[0]=="fortune-teller-camp" and world.tiles[8]=="village" and world.tiles[MapState.HOME]=="home","all three anchored locations stay fixed")
	check(world.reward_receipts==receipts,"battle and treasure reward receipts survive next-lap reshuffle")
	check(session.encounter.is_empty() and world.pending_move.is_empty() and world.pending_reward.is_empty(),"no pending battle, movement or reward blocks next turn")
	check(not map.dice.disabled and map.buttons.size()==24 and not is_instance_valid(map.overlay),"user can continue from refreshed map")
	return completed

func verify_saved_next_lap(session: Node, map: Control) -> void:
	var original_world = session.world
	var committed: Dictionary = original_world.snapshot().duplicate(true)
	var last_lap: int = original_world.laps
	var last_move: int = original_world.move_serial
	current_scene = null
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==committed,"the ONE full run saves and reloads without state loss or duplicate rewards")
	check(session.world.laps==last_lap and session.world.move_serial==last_move,"reload never replays home exit or any prior dice move")
	var reopened: Control = MAP_SCENE.instantiate()
	root.add_child(reopened)
	current_scene = reopened
	await process_frame
	check(reopened.world==session.world and reopened.dice.visible and not reopened.dice.disabled,"reloaded next lap exposes playable original Map scene")
	if reopened.dice!=null:
		await reopened.roll_move()
		check(session.world.move_serial==last_move+1 and session.world.laps==last_lap,"first movement on next lap advances only one die, not the lap")
		check(session.world.pending_move.is_empty(),"next-lap movement commits successfully")

func _run() -> void:
	save_path = "user://p4_single_run_%d.json" % OS.get_process_id()
	audio_path = "user://p4_single_audio_%d.cfg" % OS.get_process_id()
	clear_path(save_path)
	clear_path(audio_path)
	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = SessionScript.new()
		session.name = "RunSession"
		root.add_child(session)
	var old_path: String = session.save_file_path
	session.save_file_path = save_path
	var map: Control = await start_from_title(session)
	if map!=null:
		if await fight_and_capture(session,map):
			map = await claim_treasure_and_resume(session,map)
			if map!=null and await return_home_and_advance(session,map):
				await verify_saved_next_lap(session,map)
	current_scene = null
	for child in root.get_children():
		if child != session and child is Control:
			child.queue_free()
	await process_frame
	session.save_file_path = old_path
	if created: session.queue_free()
	clear_path(save_path)
	clear_path(audio_path)
	check(not FileAccess.file_exists(save_path) and not FileAccess.file_exists(audio_path),"isolated one-run save and audio files removed; real data untouched")
	print("P4_SINGLE_RUN_END_TO_END: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
