extends SceneTree
## Separate the genuine random-chest mimic from random story traversal.
## A production chest (10% roll) produces a real deck, battlefield, and
## persistable capture/game-over outcome. No production game rules are edited.
const SESSION = preload("res://systems/run_session.gd")
const MAP = preload("res://map.tscn")
const ENCOUNTERS = preload("res://systems/encounter_generator.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS mimic-isolated: ", description)
	else:
		failed += 1
		printerr("FAIL mimic-isolated: ", description)

func until_ready(predicate: Callable, limit_ms: int = 18000) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < limit_ms:
		if bool(predicate.call()): return true
		await process_frame
	return bool(predicate.call())

func choose_real_mimic_rng(session: Node) -> void:
	# The exact original 10% RNG branch, with a reproducible test seed.
	var probe := RandomNumberGenerator.new()
	for seed in range(1,500):
		probe.seed = seed
		if probe.randf() < 0.10:
			session.world.rng.seed = seed
			return
	check(false,"found an eligible mimic RNG seed")

func strong_side(battle: Control, victor: String) -> void:
	# Deterministic combatant fixture ONLY, never real game balance.
	for unit in battle.rules.units:
		unit.passive = ""
		unit.brands = []
		unit.poison = []
		unit.frozen = false
		unit.undying_used = false
		unit.shields = 0
		unit.curse = {}
		unit.bless = {}
		var strong: bool = unit.team == victor
		unit.base_attack = 999 if strong else 0
		unit.attack = unit.base_attack
		unit.base_speed = 999 if strong else 0
		unit.speed = unit.base_speed
		if not strong: unit.hp = 1
	battle.rules.refresh()
	battle.session.encounter.checkpoint = battle.rules.snapshot()
	battle.session.world.active_encounter = battle.session.encounter.duplicate(true)
	check(battle.session.save_world(),"real combat checkpoint saves fixed fixture stats")

func run_case(session: Node, victor: String, corruption: int, laps: int) -> void:
	var scratch: String = "user://mimic_isolated_%d_%s.json" % [OS.get_process_id(),victor]
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	session.save_file_path = scratch
	session.start_new_world()
	var world = session.world
	world.contamination = corruption
	world.laps = laps
	world.generate()
	var gem: int = world.tiles.find("gem")
	check(gem >= 0, victor+": existing original treasure board tile exists")
	if gem < 0: return
	choose_real_mimic_rng(session)
	check(session.open_treasure(gem),victor+": genuine chest RNG saved")
	check(world.pending_reward.get("kind","")=="mimic",victor+": chest became mimic through unchanged 10% production rule")
	var expected_count: int = ENCOUNTERS.mimic_count(corruption,laps+1)
	check(int(world.pending_reward.get("count",0))==expected_count,victor+": native corruption-based mimic count %d" % expected_count)
	check(session.encounter.is_empty() and world.active_encounter.is_empty(),victor+": opening chest never silently starts battle")
	var mimic_id: String = str(world.pending_reward.get("id",""))
	var pending: Dictionary = world.pending_reward.duplicate(true)
	session.reload_world()
	world = session.world
	check(world.pending_reward==pending and world.active_encounter.is_empty(),victor+": unopened mimic is exactly preserved after save/reload")
	var map: Control = MAP.instantiate()
	root.add_child(map)
	# The existing _ready resume path opens the chest from the saved pending reward.
	var has_deck: bool = await until_ready(func(): return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("battle_deck.gd"),24000)
	check(has_deck,victor+": original chest reveal reaches real selected-monster deck")
	if not has_deck:
		map.queue_free()
		await process_frame
		return
	var deck: Control = map.overlay
	var id: String = str(world.roster[0].id)
	deck.toggle_unit(id)
	check(deck.selected_ids.size()==1 and not deck.confirm_button.disabled,victor+": true owned card selected before mimic battle")
	deck.confirm_button.pressed.emit()
	var entered: bool = await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.rules.units.is_empty(),22000)
	check(entered,victor+": original battlefield starts after deck confirmation")
	if not entered:
		map.queue_free()
		await process_frame
		return
	var battle: Control = map.embedded_battle
	check(session.encounter.get("type","")=="mimic" and session.encounter.enemies.size()==expected_count,victor+": true mimic encounter with correct number of enemies")
	check(world.pending_reward.is_empty() and world.reward_receipts.has(mimic_id),victor+": entering battle consumes only the chest's pending reward once")
	var before_restart: Dictionary = world.snapshot().duplicate(true)
	# Runtime remains able to resume the genuine mimic fight after a crash.
	check(session.save_world(),victor+": mimic encounter save checkpoint committed")
	# Examine the disk save with an independent restored model. Do NOT
	# hot-reload the live session while its real battlefield is running.
	var file_data = JSON.parse_string(FileAccess.get_file_as_string(scratch))
	var shadow = session.MapState.new(world.definitions,123)
	check(file_data is Dictionary and shadow.restore(file_data) and shadow.snapshot()==before_restart,
		victor+": mimic fight and RNG restore from disk without replacing live battlefield")
	check(session.encounter.get("type","")=="mimic",victor+": original encounter remains playable after checkpoint")
	strong_side(battle,victor)
	check(await until_ready(func(): return not battle.entry_summon_active,20000),victor+": monster entry animation ends")
	if is_instance_valid(battle.brand_reference):
		battle.brand_reference.close()
		check(await until_ready(func(): return not is_instance_valid(battle.brand_reference),14000),victor+": brand chart closed before real dice")
	var rounds: int = 0
	while battle.rules.winner().is_empty() and rounds < 9:
		rounds += 1
		await battle.roll_round()
	check(battle.rules.winner()==victor,victor+": original dice and attack order resolved battle")
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty(),victor+": battle completion clears active encounter")
	if victor=="ally":
		check(world.run_result.is_empty() and world.pending_reward.get("kind","")=="capture", "victory keeps the expedition running and grants the existing capture reward")
		check(world.pending_reward.get("id","")!=mimic_id and world.reward_receipts.count(mimic_id)==1,"victory creates only one capture reward and no duplicate chest")
	else:
		check(world.run_result.get("ended",false)==true and world.run_result.get("reason","")=="battle_defeat","loss ends the run immediately without retry")
		check(await until_ready(func(): return is_instance_valid(map.game_over_screen),15000),"loss displays original terminal game-over UI")
	var outcome: Dictionary = world.snapshot().duplicate(true)
	session.reload_world()
	world = session.world
	check(world.snapshot()==outcome,victor+": final result survives JSON save/restart without extra rewards")
	if victor=="enemy": check(not world.run_result.is_empty() and not session.start_encounter(gem,[id]),"ended run refuses any further battles")
	map.queue_free()
	await process_frame
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var own: bool = session == null
	if own:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var prior_path: String = session.save_file_path
	await run_case(session,"ally",0,0)
	await run_case(session,"enemy",80,2)
	session.save_file_path = prior_path
	if own: session.queue_free()
	print("MIMIC_ISOLATED: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
