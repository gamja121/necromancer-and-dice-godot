extends SceneTree
## P4-01C: real map tile -> owned deck UI -> embedded battle round(s) ->
## victory/capture or defeat -> map return; save reload and no duplicate finish.
## Uses a disposable save and deterministic *test-only* unit-strength fixtures.
## Run: godot --headless --path . --script res://scripts/test_p4_combat_map_return_integration.gd

const MapScene = preload("res://map.tscn")
const SessionScript = preload("res://systems/run_session.gd")

var passed: int = 0
var failed: int = 0
var files: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-combat: ",label)
	else:
		failed += 1
		printerr("FAIL p4-combat: ",label)

func delete_save(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func until_ready(condition: Callable, limit_msec: int = 12000) -> bool:
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < limit_msec:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())

func _combat_fixture(battle: Control, victor: String) -> void:
	# Keep the authentic enemy roster, attack queue, dice and animation. Only
	# increase existing combatants' strength to make the test outcome reliable
	# across RNG seeds and future encounter balance changes.
	for unit in battle.rules.units:
		unit.passive = ""
		unit.brands = []
		unit.poison = []
		unit.frozen = false
		unit.undying_used = false
		unit.shields = 0
		unit.curse = {}
		unit.bless = {}
		var should_win: bool = unit.team == victor
		unit.base_attack = 999 if should_win else 0
		unit.attack = unit.base_attack
		unit.base_speed = 999 if should_win else 0
		unit.speed = unit.base_speed
		if not should_win: unit.hp = 1
	battle.rules.refresh()
	# Update the actual first-round checkpoint so that saved movement, battle
	# and the on-screen combat all describe the same world state.
	var snapshot: Dictionary = battle.rules.snapshot()
	battle.session.encounter.checkpoint = snapshot
	battle.session.world.active_encounter = battle.session.encounter.duplicate(true)
	check(battle.session.save_world(),"combat fixture stored as a valid ready checkpoint")

func _scenario(session: Node, victor: String) -> void:
	var label: String = "victory" if victor == "ally" else "defeat"
	var path: String = "user://p4_combat_return_%d_%s.json" % [OS.get_process_id(),label]
	files.append(path)
	delete_save(path)
	session.save_file_path = path
	session.start_new_world()
	var world = session.world
	var target: int = world.tiles.find("monster")
	check(target >= 0,label+": ordinary monster tile exists")
	if target < 0: return
	world.position = target
	world.contamination = 3
	check(session.save_world(),label+": disposable encounter approach saved")
	var original_units: int = world.roster.size()
	var map: Control = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(map.world == session.world and map.buttons.size()==24,label+": live map bound to saved encounter tile")
	map.select_tile(target)
	var deck: Control = map.overlay
	check(is_instance_valid(deck) and deck.get_script()!=null and deck.get_script().resource_path.ends_with("battle_deck.gd"),label+": actual monster tile opens deck selector")
	if not is_instance_valid(deck): map.queue_free(); return
	check(deck.confirm_button.disabled,label+": cannot start without selecting a monster")
	var selected_ids: Array = [str(world.roster[0].id),str(world.roster[1].id)]
	for id in selected_ids: deck.toggle_unit(id)
	check(deck.selected_ids == selected_ids and not deck.confirm_button.disabled,label+": two owned monsters selected and battle button enabled")
	deck.confirm_button.pressed.emit()
	var entered: bool = await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.rules.units.is_empty(),12000)
	check(entered,label+": confirmed deck starts the real embedded Battlefield scene")
	if not entered:
		map.queue_free()
		return
	var battle: Control = map.embedded_battle
	check(battle.embedded and battle.map_mode and battle.session == session,label+": battlefield is connected to current RunSession")
	check(session.encounter.type=="monster" and session.encounter.allies.size()==2,label+": generated normal encounter has selected owned unit")
	check(session.encounter.enemies.size()>=1 and session.encounter.enemies.size()<=4,label+": original encounter generator produced enemies")
	check(battle.map_return.disabled and battle.rules.winner().is_empty(),label+": cannot leave unfinished combat")
	var receipt_before: int = world.reward_receipts.size()
	var original_encounter_id: String = str(session.encounter.id)
	_combat_fixture(battle,victor)
	# Real on-screen battle dice and the original action queue, combat visuals
	# and RunSession checkpoints resolve the result (not a mocked Result object).
	var turns: int = 0
	while battle.rules.winner().is_empty() and turns < 8:
		turns += 1
		await battle.roll_round()
	check(battle.rules.winner()==victor,label+": actual dice/actions produce expected "+label+" in %d round(s)" % turns)
	check(not battle.busy,label+": combat unlocks after final hit")
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty(),label+": battle completion clears durable active checkpoint")
	if victor=="ally":
		check(target in world.cleared and world.contamination==2,label+": victory marks tile cleared and lowers contamination once")
		check(world.roster.size()==original_units,label+": no owned monster permanently lost on victory")
		check(not world.pending_reward.is_empty() and world.pending_reward.kind=="capture",label+": fallen enemies enter soul capture before map return")
		check(is_instance_valid(battle.capture_panel),label+": real soul-capture screen is shown")
		check(battle.map_return.disabled,label+": pending capture blocks premature map return")
		if is_instance_valid(battle.capture_panel):
			# Resolve through actual capture interface, regardless of random
			# success/failure. Exhaustion automatically returns to the map.
			for i in range(3):
				if not is_instance_valid(map.embedded_battle): break
				if session.world.pending_reward.is_empty(): break
				if not is_instance_valid(battle.capture_panel): break
				await battle.capture_panel.roll()
				if not session.world.pending_reward.is_empty() and session.world.pending_reward.get("phase","")=="retry":
					continue
				if session.world.pending_reward.is_empty(): break
	else:
		check(not target in world.cleared and world.contamination==3,label+": defeat neither clears tile nor changes contamination")
		check(world.pending_reward.is_empty() and world.reward_receipts.size()==receipt_before,label+": defeat produces no capture/reward")
		check(not battle.map_return.disabled,label+": defeat enables explicit return button")
		battle.map_return.pressed.emit()
	var returned: bool = await until_ready(func(): return map.embedded_battle == null and not map.battle_returning,16000)
	check(returned,label+": finished battle returns to the original live Map scene")
	check(map.world==session.world and map.buttons.size()==24 and map.dice.visible and not map.dice.disabled,label+": board and dice are interactive again")
	check(map.hero.visible and map.status.visible and map.map_audio.visible,label+": hero/HUD restored after battle")
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty() and session.world.pending_reward.is_empty(),label+": no active combat/capture retained after returning")
	var expected_receipts: int = world.reward_receipts.size()
	var committed: Dictionary = session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==committed,label+": result and player units persist across full reload")
	check(session.world.reward_receipts.size()==expected_receipts,label+": reopening map cannot duplicate capture receipt")
	check(session.world.cleared.has(target)==(victor=="ally"),label+": win/loss tile state survives reload")
	check(session.world.contamination==(2 if victor=="ally" else 3),label+": original once-only contamination result survives reload")
	check(not session.has_method("finish_encounter") or session.encounter.is_empty(),label+": no suspended combat on the reloaded run")
	check(original_encounter_id.begins_with("encounter-"),label+": tracked real encounter ID rather than a synthetic UI result")

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = SessionScript.new()
		session.name = "RunSession"
		root.add_child(session)
	var original_path: String = session.save_file_path
	await _scenario(session,"enemy")
	await _scenario(session,"ally")
	session.save_file_path = original_path
	if created: session.queue_free()
	for path in files: delete_save(path)
	check(files.all(func(p): return not FileAccess.file_exists(p)), "isolated test saves removed without touching production save")
	print("P4_COMBAT_MAP_RETURN_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
