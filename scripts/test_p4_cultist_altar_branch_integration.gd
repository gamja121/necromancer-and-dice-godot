extends SceneTree
## P4-02B: genuine Map die -> altar three beats -> pass/fight -> real
## 4-enemy battle win/loss/retry -> explicit tracking-quest final scene.
## All fixtures are isolated PID user:// saves. Only the test's starting
## rumor receipts, tile permutation and battle strengths are deterministic.
const MAP_SCENE = preload("res://map.tscn")
const SESSION_SCRIPT = preload("res://systems/run_session.gd")
const STATE = preload("res://systems/map_state.gd")
const ALTAR = preload("res://systems/cultist_altar_entry.gd")
const RUMOR = preload("res://systems/cultist_rumor_entry.gd")
const ENEMIES = preload("res://systems/cultist_altar_enemies.gd")
const BEATS = preload("res://systems/cultist_altar_beats.gd")

var passed: int = 0
var failed: int = 0
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-altar: ",label)
	else:
		failed += 1
		printerr("FAIL p4-altar: ",label)

func clear_save(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func until_ready(predicate: Callable, limit_ms: int = 18000) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < limit_ms:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())

func panel_button(map: Control, caption: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for child in map.overlay.get_children():
		if child is Button and child.visible and child.text==caption:
			return child
	return null

func is_deck(map: Control) -> bool:
	return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("battle_deck.gd")

func eligible_tile(world) -> int:
	# Fix only the next roll (not the original map movement routine).
	var preview = RandomNumberGenerator.new()
	var target: int = -1
	for seed_value in range(1,400):
		preview.seed = seed_value
		var next_tile: int = (STATE.HOME+preview.randi_range(1,6))%24
		if next_tile not in [0,8,STATE.HOME]:
			world.rng.seed = seed_value
			target = next_tile
			break
	if target<0: return -1
	var old_altar: int = world.tiles.find("altar")
	if old_altar<0:
		# Isolated storyline regression still tests original altar artwork and
		# pass/fight buttons: synthesize ONE altar in this disposable test only.
		old_altar=world.tiles.find("basic")
		if old_altar>=0: world.tiles[old_altar]="altar"
	if old_altar<0: return -1
	if old_altar!=target:
		var previous: String = str(world.tiles[target])
		world.tiles[target]="altar"
		world.tiles[old_altar]=previous
	return target

func fresh_altar(session: Node, tag: String) -> Dictionary:
	var path: String = "user://p4_altar_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	clear_save(path)
	session.save_file_path=path
	session.start_new_world()
	var world=session.world
	# Only canonical *already completed* prerequisite rumor; no free quest
	# progress from this test and no modifications to live source logic.
	world.story_events[RUMOR.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	world.event_flags[RUMOR.SEEN_FLAG]=true
	world.event_flags[RUMOR.COMPLETE_FLAG]=true
	world.event_flags[RUMOR.TRACKING_FLAG]=true
	var target: int=eligible_tile(world)
	check(target>=0,tag+": original map has a repositionable altar tile")
	if target<0: return {}
	check(session.save_world(),tag+": staged rumor prerequisite and altar approach saved")
	var map: Control=MAP_SCENE.instantiate()
	root.add_child(map)
	await process_frame
	var serial: int=world.move_serial
	await map.roll_move()
	check(world.position==target and world.move_serial==serial+1 and world.pending_move.is_empty(),tag+": actual die lands at altar exactly once")
	check(session.get_story_event(ALTAR.EVENT_ID).status=="seen" and session.event_flag_is_set(ALTAR.SEEN_FLAG),tag+": original map starts real altar story")
	check(panel_button(map,"계속")!=null,tag+": first altar scene shows actual Continue button")
	return {"map":map,"target":target}

func enter_choice(map: Control, label: String) -> bool:
	for beat in range(2):
		var advance: Button=panel_button(map,"계속")
		if advance==null:
			check(false,label+": missing Continue at beat %d" % beat)
			return false
		advance.pressed.emit()
		await process_frame
	var buttons: bool=panel_button(map,"싸운다")!=null and panel_button(map,"지나간다")!=null
	check(buttons,label+": 3 original illustrated beats reach both fight/pass buttons")
	return buttons

func deterministic_round(battle: Control, victor: String, label: String) -> void:
	# Actual dice, attack queue, battle visuals and end-of-battle save run.
	# The test adjusts only these temporary combatants' strengths.
	for unit in battle.rules.units:
		unit.passive=""
		unit.brands=[]
		unit.poison=[]
		unit.frozen=false
		unit.undying_used=false
		unit.shields=0
		unit.curse={}
		unit.bless={}
		var strong: bool=unit.team==victor
		unit.base_attack=999 if strong else 0
		unit.attack=unit.base_attack
		unit.base_speed=999 if strong else 0
		unit.speed=unit.base_speed
		if not strong: unit.hp=1
	battle.rules.refresh()
	battle.session.encounter.checkpoint=battle.rules.snapshot()
	battle.session.world.active_encounter=battle.session.encounter.duplicate(true)
	check(battle.session.save_world(),label+": test strengths committed to original battle checkpoint")

func fight_to_result(session: Node, map: Control, ids: Array, victor: String, label: String) -> bool:
	check(is_deck(map),label+": real 1-4 unit BattleDeck is visible")
	if not is_deck(map): return false
	var deck: Control=map.overlay
	for id in ids: deck.toggle_unit(str(id))
	check(deck.selected_ids.size()==ids.size() and not deck.confirm_button.disabled,label+": selected owned cards enable original battle button")
	deck.confirm_button.pressed.emit()
	var ready: bool=await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.rules.units.is_empty())
	check(ready,label+": deck confirmation opens embedded battlefield")
	if not ready: return false
	var battle: Control=map.embedded_battle
	check(session.encounter.get("event_id","")==ALTAR.EVENT_ID and session.encounter.type=="event-cultist-altar",label+": checkpoint uses real altar encounter ID/type")
	var names: Array=[]
	for enemy in session.encounter.enemies: names.append(str(enemy.slug))
	check(ENEMIES.valid(session.world.definitions,names),label+": exactly 4 unique enemies with correct elite lead")
	check(not session.event_flag_is_set(ALTAR.COMPLETE_FLAG) and not session.event_flag_is_set(ALTAR.RITUAL_TRACKING_FLAG),label+": entering fight doesn't prematurely grant quest")
	deterministic_round(battle,victor,label)
	var turns: int=0
	while battle.rules.winner().is_empty() and turns<8:
		turns+=1
		await battle.roll_round()
	check(battle.rules.winner()==victor,label+": actual battle actions resolve %s in %d round(s)" % [victor,turns])
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty(),label+": battle result clears saved encounter")
	check(session.world.pending_reward.is_empty(),label+": story fight cannot generate ordinary corpse capture")
	check(not battle.map_return.disabled,label+": result enables actual battle return button")
	battle.map_return.pressed.emit()
	var returned: bool=await until_ready(func(): return map.embedded_battle==null and not map.battle_returning and panel_button(map,"흔적 확인")!=null,21000)
	check(returned,label+": map displays original altar result screen")
	return returned

func verify_final(session: Node, map: Control, label: String, choice: String, result: String, prior_receipts: Array) -> void:
	check(ALTAR.followup_ready(session,session.world.position),label+": original aftermath ready before final confirmation")
	check(session.get_story_event(ALTAR.EVENT_ID).status=="active",label+": result/choice alone never completes story")
	check(session.event_flag_is_set(ALTAR.TRACKING_FLAG) and not session.event_flag_is_set(ALTAR.RITUAL_TRACKING_FLAG),label+": previous tracking still active, next quest locked")
	var finish: Button=panel_button(map,"마치기")
	check(finish!=null,label+": final narration has explicit Finish button")
	if finish==null: return
	finish.pressed.emit()
	var state: Dictionary=session.get_story_event(ALTAR.EVENT_ID)
	check(ALTAR.completed(session) and state.status=="complete" and state.choice==choice and state.battle_result==result,label+": finish atomically completes correct route")
	check(session.event_flag_is_set(ALTAR.RITUAL_CONFIRMED_FLAG) and session.event_flag_is_set(ALTAR.RITUAL_TRACKING_FLAG) and not session.event_flag_is_set(ALTAR.TRACKING_FLAG),label+": ritual clues and new quest commit only on Finish")
	check(not session.event_flag_is_set("event:ritual_portal_trace_01:complete") and not session.event_flag_is_set("quest:monster_king_hunt:active"),label+": future story stays locked")
	check(session.world.reward_receipts==prior_receipts and session.world.pending_reward.is_empty(),label+": story completion grants no phantom treasure/capture")
	check(not ALTAR.can_enter(session,session.world.position),label+": completed altar event cannot restart")
	var source_state: Dictionary=session.world.snapshot().duplicate(true)
	check(ALTAR.finish(session,session.world.position) and session.world.snapshot()==source_state,label+": second Finish idempotent")
	# The altar's ordinary location actions remain usable after closing plot.
	check(panel_button(map,"나가기")!=null,label+": original altar location panel remains after plot")
	for i in range(4): await process_frame
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==source_state,label+": full completed quest, monsters and receipts persist across JSON reload")
	check(ALTAR.completed(session),label+": source-compatible completed flag set survives reload")

func scenario_pass(session: Node) -> void:
	var entry: Dictionary=await fresh_altar(session,"pass")
	if entry.is_empty(): return
	var map: Control=entry.map
	if not await enter_choice(map,"pass"): return
	var original_units: Array=session.world.roster.duplicate(true)
	var receipts: Array=session.world.reward_receipts.duplicate(true)
	panel_button(map,"지나간다").pressed.emit()
	check(session.get_story_event(ALTAR.EVENT_ID).choice=="pass" and ALTAR.followup_ready(session,session.world.position),"pass: actual button saves pass and opens follow-up")
	check(panel_button(map,"마치기")!=null and panel_button(map,"선택 변경")!=null,"pass: Finish and deliberate Change buttons available")
	check(session.encounter.is_empty() and not session.event_flag_is_set(ALTAR.COMPLETE_FLAG),"pass: no battle and no instant completion")
	panel_button(map,"선택 변경").pressed.emit()
	check(panel_button(map,"싸운다")!=null and panel_button(map,"지나간다")!=null and session.get_story_event(ALTAR.EVENT_ID).choice=="","pass: reversible choice returns to same original beat")
	panel_button(map,"지나간다").pressed.emit()
	check(ALTAR.followup_ready(session,session.world.position),"pass: second deliberate pass recreates one follow-up")
	# Close/reopen with the choice committed but quest still unfinished.
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==before,"pass: interrupted follow-up reopens without replay or extra choice")
	map=MAP_SCENE.instantiate()
	root.add_child(map)
	var resumed: bool=await until_ready(func(): return panel_button(map,"마치기")!=null)
	check(resumed,"pass: saved quest follow-up is actually visible on reloaded Map")
	check(session.world.roster==original_units and session.world.reward_receipts==receipts,"pass: no roster loss or reward before completion")
	if resumed: await verify_final(session,map,"pass","pass","",receipts)

func begin_fight(session: Node, tag: String) -> Dictionary:
	var entry: Dictionary=await fresh_altar(session,tag)
	if entry.is_empty(): return {}
	var map: Control=entry.map
	if not await enter_choice(map,tag): return {}
	panel_button(map,"싸운다").pressed.emit()
	check(session.get_story_event(ALTAR.EVENT_ID).status=="active" and session.get_story_event(ALTAR.EVENT_ID).choice=="fight",tag+": fight choice saved but battle not yet resolved")
	check(not session.event_flag_is_set(ALTAR.RITUAL_TRACKING_FLAG),tag+": intent alone cannot advance next quest")
	var started: bool=await until_ready(func(): return is_deck(map),8000)
	check(started,tag+": original summoned-monster reveal automatically opens BattleDeck")
	return entry if started else {}

func acknowledge_to_followup(session: Node, map: Control, label: String, expected: String) -> bool:
	check(session.get_story_event(ALTAR.EVENT_ID).battle_result==expected,label+": real battle recorded correct won/lost result")
	check(session.story_battle_result_pending(ALTAR.EVENT_ID),label+": result must be acknowledged before quest handoff")
	check(not ALTAR.followup_ready(session,session.world.position),label+": hidden aftermath cannot bypass pending result")
	# Map re-render under result overlay creates AudioSettings, which awaits
	# two process frames in _ready; human button timing naturally allows it.
	for i in range(3): await process_frame
	var confirm: Button=panel_button(map,"흔적 확인")
	check(confirm!=null,label+": actual story result confirmation button present")
	if confirm==null: return false
	confirm.pressed.emit()
	check(not session.story_battle_result_pending(ALTAR.EVENT_ID),label+": player button acknowledges battle result once")
	var ready: bool=await until_ready(func(): return panel_button(map,"마치기")!=null,10000)
	check(ready,label+": original aftermath narration appears after acknowledgement")
	return ready

func scenario_win(session: Node) -> void:
	var entry: Dictionary=await begin_fight(session,"win")
	if entry.is_empty(): return
	var map: Control=entry.map
	var receipts: Array=session.world.reward_receipts.duplicate(true)
	var ids: Array=[str(session.world.roster[0].id),str(session.world.roster[1].id)]
	if not await fight_to_result(session,map,ids,"ally","win"): return
	check(session.event_flag_is_set(ALTAR.BATTLE_WON_FLAG) and not session.event_flag_is_set(ALTAR.BATTLE_LOST_FLAG),"win: exactly victory receipt saved")
	if await acknowledge_to_followup(session,map,"win","won"):
		await verify_final(session,map,"win","fight","won",receipts)

func scenario_loss_finish(session: Node) -> void:
	var entry: Dictionary=await begin_fight(session,"loss_finish")
	if entry.is_empty(): return
	var map: Control=entry.map
	var receipts: Array=session.world.reward_receipts.duplicate(true)
	var lost: String=str(session.world.roster[0].id)
	if not await fight_to_result(session,map,[lost],"enemy","loss"): return
	check(session.event_flag_is_set(ALTAR.BATTLE_LOST_FLAG) and not session.event_flag_is_set(ALTAR.BATTLE_WON_FLAG),"loss: actual failure receipt saved")
	check(session.world.graveyard_corpses.any(func(c): return str(c.id)==lost),"loss: deployed owned monster is permanently dead")
	check(panel_button(map,"다시 도전")!=null and panel_button(map,"흔적 확인")!=null,"loss: player can either retry or acknowledge failure")
	if await acknowledge_to_followup(session,map,"loss","lost"):
		await verify_final(session,map,"loss","fight","lost",receipts)

func scenario_retry(session: Node) -> void:
	var entry: Dictionary=await begin_fight(session,"retry")
	if entry.is_empty(): return
	var map: Control=entry.map
	var receipts: Array=session.world.reward_receipts.duplicate(true)
	var lost: String=str(session.world.roster[0].id)
	var reserve: String=str(session.world.roster[1].id)
	if not await fight_to_result(session,map,[lost],"enemy","retry-loss"): return
	check(session.get_story_event(ALTAR.EVENT_ID).battle_result=="lost" and not ALTAR.followup_ready(session,session.world.position),"retry: loss saved, no premature quest")
	check(session.world.roster.size()==1 and session.world.graveyard_corpses.any(func(c): return str(c.id)==lost),"retry: one permanent casualty and intact reserve")
	var retry: Button=panel_button(map,"다시 도전")
	check(retry!=null,"retry: original result exposes retry button")
	if retry==null: return
	for i in range(3): await process_frame
	retry.pressed.emit()
	check(not session.story_battle_result_pending(ALTAR.EVENT_ID) and is_deck(map),"retry: button acknowledges prior loss and reopens authentic deck")
	if not await fight_to_result(session,map,[reserve],"ally","retry-win"): return
	check(session.get_story_event(ALTAR.EVENT_ID).battle_result=="won" and not session.event_flag_is_set(ALTAR.BATTLE_LOST_FLAG),"retry: new victory replaces active loss result")
	check(session.world.graveyard_corpses.any(func(c): return str(c.id)==lost) and session.world.roster.size()==1,"retry: winning never revives permanently dead combatant")
	if await acknowledge_to_followup(session,map,"retry","won"):
		await verify_final(session,map,"retry","fight","won",receipts)

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION_SCRIPT.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	await scenario_pass(session)
	await scenario_win(session)
	await scenario_loss_finish(session)
	await scenario_retry(session)
	session.save_file_path=old_path
	if created: session.queue_free()
	for path in paths: clear_save(path)
	check(paths.all(func(path): return not FileAccess.file_exists(path)),"test-only saves removed; original user data untouched")
	print("P4_CULTIST_ALTAR_BRANCH_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
