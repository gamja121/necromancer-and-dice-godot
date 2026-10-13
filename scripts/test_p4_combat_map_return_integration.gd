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

func _scenario(session: Node, victor: String, force_capture_failure: bool = false) -> void:
	var label: String = ("victory-capture-failed" if force_capture_failure else "victory") if victor == "ally" else "defeat"
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
	check(battle.dice==map.dice and map.dice.get_parent()==map.stage and map.dice.is_visible_in_tree(),
		label+": original stage die is the battle die, with no recreated center button")
	var entry_die_pos: Vector2=map.dice.position
	check(map.dice.z_index>map.overlay.z_index and not map.dice.disabled,
		label+": movable shared die remains visible and clickable above battlefield frame")
	check(session.encounter.type=="monster" and session.encounter.allies.size()==2,label+": generated normal encounter has selected owned unit")
	check(session.encounter.enemies.size()>=1 and session.encounter.enemies.size()<=4,label+": original encounter generator produced enemies")
	check(battle.map_return.disabled and battle.rules.winner().is_empty(),label+": cannot leave unfinished combat")
	# Real map book and deck must remain in their ORIGINAL positions throughout
	# embedded battle; do not make a duplicate in the clipped BattleViewport.
	check(map.book_button.visible and map.book_button.is_visible_in_tree() and map.book_lock.locked,
		label+": original bottom-left book stays visible and chain-locks in combat")
	check(map.book_button.position==Vector2(13,550)
		and map.book_button.disabled,label+": chained map book retains original position and blocks clicks")
	check(map.deck_button.visible and map.deck_button.is_visible_in_tree()
		and map.deck_button.position==Vector2(1134,563) and not map.deck_button.disabled,
		label+": original bottom-right deck stays at the map position and remains clickable")
	check(battle.dice_cards_button==null and battle.external_dice_deck_button==map.deck_button,
		label+": no duplicate deck button exists within the battlefield")
	# A monster card must exist ON the lower map tile row, not just below
	# the battle art inside BattleViewport or hovering above the tile row.
	var lower_tile_y: float = map.center(12).y
	var border_bottom: float = map.overlay.position.y+map.overlay.size.y
	var external_cards_ok: bool = battle.uses_map_tile_dock() and battle.cards.size()==battle.rules.units.size()
	var every_card_overlaps_tile: bool = true
	for card in battle.cards.values():
		external_cards_ok = external_cards_ok and (card.get_parent()==map.stage
			and card.position.y>=border_bottom and absf((card.position.y+card.size.y*0.5)-lower_tile_y)<12.0)
		var overlaps_bottom_tile: bool = false
		for tile_index in range(12,19):
			var tile: TextureButton = map.buttons[tile_index]
			if Rect2(card.position,card.size).intersects(Rect2(tile.position,tile.size)):
				overlaps_bottom_tile = true
				break
		every_card_overlaps_tile = every_card_overlaps_tile and overlaps_bottom_tile
	check(external_cards_ok,label+": every battle monster card renders on map stage outside battle frame")
	check(every_card_overlaps_tile,label+": monster portraits cover actual bottom map tile rectangles")
	battle.set_card_phase(true)
	await create_timer(0.25).timeout
	var cards_stay_while_acting: bool = true
	for card in battle.cards.values():
		cards_stay_while_acting = cards_stay_while_acting and card.disabled and absf(card.position.y-battle.MAP_BOTTOM_TILE_CARD_Y)<0.5
	check(cards_stay_while_acting,label+": action phase keeps monster cards on bottom tiles, disabled not moved into arena")
	battle.set_card_phase(false)
	await create_timer(0.25).timeout
	var cards_stay_when_ready: bool = true
	for card in battle.cards.values():
		cards_stay_when_ready = cards_stay_when_ready and not card.disabled and absf(card.position.y-battle.MAP_BOTTOM_TILE_CARD_Y)<0.5
	check(cards_stay_when_ready,label+": next ready phase restores clickable cards on same bottom tiles")
	await create_timer(0.5).timeout
	check(map.book_lock.locked and not map.book_lock.transitioning
		and map.book_button.texture_disabled==map.book_lock.frames[3],
		label+": chained book finishes its four-frame locking animation visibly")
	map.deck_button.pressed.emit()
	await process_frame
	check(is_instance_valid(battle.dice_hand) and battle.dice_hand.battle_mode
		and battle.dice_hand.size.y==720,
		label+": original map deck opens full-height battle dice hand")
	battle.close_dice_hand()
	check(not is_instance_valid(battle.dice_hand)
		and map.deck_button.texture_normal==load("res://assets/map/ui/map-card-deck.png"),
		label+": closing battle dice hand restores original deck icon")
	var receipt_before: int = world.reward_receipts.size()
	var original_encounter_id: String = str(session.encounter.id)
	_combat_fixture(battle,victor)
	# Real on-screen battle dice and the original action queue, combat visuals
	# and RunSession checkpoints resolve the result (not a mocked Result object).
	var turns: int = 0
	while battle.rules.winner().is_empty() and turns < 8:
		turns += 1
		await battle.roll_round()
		check(map.dice==battle.dice and map.dice.position==map.shared_dice_position(),
			label+": round %d shared die stops on stage and saves that exact position" % turns)
		if turns==1:
			check(map.dice.position!=entry_die_pos,
				label+": the die physically bounces instead of returning to its battle center")
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
			var candidates: Array = battle.capture_panel.choices
			check(candidates.size()==world.pending_reward.corpses.size() and not candidates.is_empty(),
				label+": each fallen enemy has a selectable capture card")
			var candidates_on_tiles: bool = true
			for candidate in candidates:
				var card: TextureButton = candidate.card
				var enemy: Dictionary = battle.rules.find_id(str(world.pending_reward.corpses[int(candidate.index)].id))
				candidates_on_tiles = candidates_on_tiles and (card.get_parent()==map.stage and enemy.team=="enemy"
					and card.position==battle.cards[enemy.id].position
					and card.position.y==battle.MAP_BOTTOM_TILE_CARD_Y)
			check(candidates_on_tiles,label+": defeated enemy capture cards stay on exact lower map tiles")
			if force_capture_failure:
				# Emulate a legitimately exhausted capture phase in an isolated save.
				# The real UI then commits failure before the permanent-death effect.
				world.pending_reward.phase = "failed"
				world.pending_reward.attempts = 0
				world.pending_reward.locked = true
				check(session.save_world(),label+": final failed capture state persisted before presenting result")
				var failed_id: String = str(world.pending_reward.id)
				await battle.capture_panel.complete_failure()
				check(world.pending_reward.is_empty() and world.reward_receipts.count(failed_id)==1,
					label+": final failed capture creates exactly one receipt and no monster reward")
			else:
				# First capture is triggered via the REAL shared die button, not
				# directly through the capture panel. Verify the stage die moves
				# while the previously saved capture face stays authoritative.
				var capture_start: Vector2=map.dice.position
				check(not map.dice.disabled,label+": soul capture unlocks shared die button after victory")
				map.dice.pressed.emit()
				await create_timer(0.26).timeout
				check(map.shared_die_busy and map.dice.position.distance_to(capture_start)>5.0,
					label+": pressing postbattle reward die triggers actual map bounce, not frozen in-place wobble")
				check(is_instance_valid(battle.capture_panel) and battle.capture_panel.busy,
					label+": capture phase locks repeated die presses while it rolls")
				var capture_finished: bool=await until_ready(func():
					return not is_instance_valid(map.embedded_battle) or (is_instance_valid(battle.capture_panel) and not battle.capture_panel.busy),25000)
				check(capture_finished,label+": real capture button finishes its animation and result")
				# A second saved capture attempt is valid only when the first
				# attempt missed and the result explicitly allows a retry.
				for i in range(2):
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
	check(map.dice.position==map.shared_dice_position(),
		label+": battle exit preserves last dice stopping pose on map, including render rebuild")
	check(map.hero.visible and map.status.visible and map.map_audio.visible,label+": hero/HUD restored after battle")
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty() and session.world.pending_reward.is_empty(),label+": no active combat/capture retained after returning")
	var expected_receipts: int = world.reward_receipts.size()
	var committed: Dictionary = session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	var loaded: Dictionary = session.world.snapshot()
	if loaded != committed:
		for key in committed:
			if committed[key] != loaded.get(key):
				var before_text: String = JSON.stringify(committed[key])
				var after_text: String = JSON.stringify(loaded.get(key))
				print("P4_DIAG ",label," field=",key," before=",before_text.substr(0,480)," after=",after_text.substr(0,480))
	check(loaded==committed,label+": result and player units persist across full reload")
	check(session.world.reward_receipts.size()==expected_receipts,label+": reopening map cannot duplicate capture receipt")
	if victor=="enemy":
		check(not session.world.graveyard_corpses.is_empty(),label+": permanently lost owned monsters retained in graveyard after reload")
		var stats_are_int: bool = session.world.graveyard_corpses.all(func(c):
			if not c is Dictionary: return false
			for key in ["max_hp","attack","speed","current_hp"]:
				if c.has(key) and typeof(c[key]) != TYPE_INT: return false
			for b in c.get("brands",[]):
				if not b is Dictionary: return false
				for face in b.get("bless",[]) + b.get("curse",[]):
					if typeof(face) != TYPE_INT: return false
			return true)
		check(stats_are_int,label+": graveyard corpse stats and dice-brand faces restore as integers")
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
	await _scenario(session,"ally",true)
	session.save_file_path = original_path
	if created: session.queue_free()
	for path in files: delete_save(path)
	check(files.all(func(p): return not FileAccess.file_exists(p)), "isolated test saves removed without touching production save")
	print("P4_COMBAT_MAP_RETURN_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
