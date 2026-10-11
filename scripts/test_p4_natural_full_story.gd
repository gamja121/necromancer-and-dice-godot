extends "res://scripts/test_p4_natural_commander_hunter.gd"
## P4-02E-D: continue ONE naturally generated, unpermuted map/run through
## rescued child, village, commander, hunter, cultist rumor, altar PASS,
## actual portal intervention battle, and the original king-hunt conclusion.
## No injected quests, story completions, map tiles, forced dice or teleports.
## The two mandatory story fights use only isolated fixture battle statistics.

const CULTIST = preload("res://systems/cultist_rumor_entry.gd")
const CULTIST_BEATS = preload("res://systems/cultist_rumor_beats.gd")
const ALTAR = preload("res://systems/cultist_altar_entry.gd")
const PORTAL = preload("res://systems/ritual_portal_entry.gd")
const HUNT = preload("res://systems/monster_king_hunt_entry.gd")
const HUNT_BEATS = preload("res://systems/monster_king_hunt_beats.gd")

func restore_actual_panel(session: Node, map: Control, wanted: String, description: String) -> Control:
	var snapshot: Dictionary = session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot() == snapshot, description + ": actual saved world reloads with no award/move")
	map = MAP.instantiate()
	root.add_child(map)
	var present: bool = await until_ready(func(): return button_at(map, wanted) != null, 14000)
	check(present, description + ": saved modal returns with original " + wanted + " control")
	check(session.world.pending_move.is_empty() and map.world == session.world, description + ": reopened modal belongs to canonical save")
	return map

func finish_cultist_rumor(session: Node, map: Control) -> Control:
	check(session.get_story_event(CULTIST.EVENT_ID).status == "seen", "cultist rumor discovered at natural village or event tile")
	check(not session.event_flag_is_set(CULTIST.TRACKING_FLAG), "discovering rumor alone cannot grant cultist tracking")
	for beat in range(CULTIST_BEATS.count()):
		check(CULTIST.current_beat(session) == beat, "cultist rumor original beat %d saved in order" % beat)
		var caption: String = "마치기" if beat == CULTIST_BEATS.count() - 1 else "계속"
		var btn: Button = button_at(map, caption)
		if btn == null:
			check(false, "cultist rumor has actual %s at beat %d" % [caption, beat])
			return map
		check(session.get_story_event(CULTIST.EVENT_ID).status == "seen" and not session.event_flag_is_set(CULTIST.TRACKING_FLAG), "cultist rumor can't pay quest before last click, beat %d" % beat)
		btn.pressed.emit()
		await process_frame
		if beat == 2:
			map = await restore_actual_panel(session, map, "계속", "cultist rumor beat 3")
			check(CULTIST.current_beat(session) == 3, "cultist rumor resumes third saved advance")
	check(session.get_story_event(CULTIST.EVENT_ID).status == "complete" and session.event_flag_is_set(CULTIST.COMPLETE_FLAG), "cultist rumor confirms six scene story")
	check(session.event_flag_is_set(CULTIST.TRACKING_FLAG) and not session.event_flag_is_set(ALTAR.RITUAL_TRACKING_FLAG), "cultist tracking activates only after rumor finish, ritual still locked")
	check(not is_instance_valid(map.overlay), "completed cultist rumor closes without reopening an event")
	return map

func finish_altar_pass(session: Node, map: Control) -> Control:
	check(session.get_story_event(ALTAR.EVENT_ID).status == "seen", "altar discovered by natural altar/event arrival")
	check(not session.event_flag_is_set(ALTAR.RITUAL_TRACKING_FLAG), "altar arrival does not grant portal tracking")
	for beat in range(2):
		check(ALTAR.current_beat(session) == beat, "altar original narrative beat %d" % beat)
		var btn: Button = button_at(map, "계속")
		if btn == null:
			check(false, "altar missing original Continue at beat %d" % beat)
			return map
		btn.pressed.emit()
		await process_frame
		if beat == 0:
			map = await restore_actual_panel(session, map, "계속", "altar ritual reveal")
			check(ALTAR.current_beat(session) == 1, "altar unfinished ritual layer restores at beat 1")
	check(ALTAR.current_beat(session) == 2 and button_at(map, "지나간다") != null and button_at(map, "싸운다") != null, "altar shows both genuine decisions after third narrative frame")
	var bypass: Button = button_at(map, "지나간다")
	if bypass == null:
		return map
	bypass.pressed.emit()
	await process_frame
	check(session.get_story_event(ALTAR.EVENT_ID).choice == "pass" and session.get_story_event(ALTAR.EVENT_ID).status == "active", "altar pass is durable intent without fake battle")
	check(not session.event_flag_is_set(ALTAR.RITUAL_TRACKING_FLAG) and not session.event_flag_is_set(PORTAL.REVIVED_FLAG), "altar pass alone cannot complete portal, revive king or grant followup")
	map = await restore_actual_panel(session, map, "마치기", "altar pass follow-up")
	check(ALTAR.followup_ready(session, session.world.position), "altar final original narrative remains ready after restart")
	var finish: Button = button_at(map, "마치기")
	if finish == null:
		return map
	finish.pressed.emit()
	await process_frame
	check(ALTAR.completed(session) and session.event_flag_is_set(ALTAR.RITUAL_TRACKING_FLAG), "altar actual Finish gives portal tracking once")
	check(not session.event_flag_is_set(PORTAL.HUNT_FLAG), "altar finish never starts hunt before portal")
	if is_instance_valid(map.overlay):
		check(await incidental_overlay(session, map, "altar-completed"), "altar original location panel closes after completing story")
	return map

func settle_portal_battle(session: Node, map: Control) -> Control:
	check(is_deck(map), "actual source portal intervention asks for owned-unit deck before fighting")
	if not is_deck(map):
		return map
	var deck: Control = map.overlay
	var ids: Array = [str(session.world.roster[0].id), str(session.world.roster[1].id)]
	for id in ids:
		deck.toggle_unit(id)
	check(deck.selected_ids.size() == 2 and not deck.confirm_button.disabled, "portal chooses exactly two truly owned monsters using original deck UI")
	deck.confirm_button.pressed.emit()
	var started: bool = await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.rules.units.is_empty(), 16000)
	check(started, "portal original embedded battlefield begins only after deck confirmation")
	if not started:
		return map
	var battle: Control = map.embedded_battle
	check(str(session.encounter.get("event_id", "")) == PORTAL.EVENT_ID and session.encounter.enemies.size() == 4, "canonical 4-enemy ritual event stored, not normal monster encounter")
	# Test-only combat checkpoint. No quest flags, dice faces, map tiles,
	# rewards or actual victory outcomes are injected.
	for unit in battle.rules.units:
		unit.passive = ""
		unit.brands = []
		unit.poison = []
		unit.frozen = false
		unit.undying_used = false
		unit.shields = 0
		unit.curse = {}
		unit.bless = {}
		var ally: bool = unit.team == "ally"
		unit.base_attack = 999 if ally else 0
		unit.attack = unit.base_attack
		unit.base_speed = 999 if ally else 0
		unit.speed = unit.base_speed
		if not ally:
			unit.hp = 1
	battle.rules.refresh()
	battle.session.encounter.checkpoint = battle.rules.snapshot()
	battle.session.world.active_encounter = battle.session.encounter.duplicate(true)
	check(battle.session.save_world(), "isolated portal test combat fixture saved before real battlefield dice")
	var rounds: int = 0
	while battle.rules.winner().is_empty() and rounds < 9:
		rounds += 1
		await battle.roll_round()
	check(battle.rules.winner() == "ally", "actual portal dice and attack turns defeat defenders in %d rounds" % rounds)
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty() and session.world.pending_reward.is_empty(), "portal encounter clears exactly once without phantom corpse reward")
	battle.map_return.pressed.emit()
	var returned: bool = await until_ready(func(): return map.embedded_battle == null and not map.battle_returning and button_at(map, "부활 확인") != null, 20000)
	check(returned, "actual portal victory returns to original pending-revival confirmation UI")
	if not returned:
		return map
	check(session.story_battle_result_pending(PORTAL.EVENT_ID) and not session.event_flag_is_set(PORTAL.REVIVED_FLAG), "saved portal victory cannot auto-revive king")
	map = await restore_actual_panel(session, map, "부활 확인", "portal pending battle result")
	var acknowledge: Button = button_at(map, "부활 확인")
	if acknowledge == null:
		return map
	acknowledge.pressed.emit()
	var afterward: bool = await until_ready(func(): return button_at(map, "마치기") != null, 12000)
	check(afterward and PORTAL.aftermath_ready(session, session.world.position), "original weakened-revival ending appears only after explicit result acknowledgment")
	check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG), "acknowledgment alone cannot finalize king revival")
	if not afterward:
		return map
	map = await restore_actual_panel(session, map, "마치기", "portal confirmed battle aftermath")
	var finish: Button = button_at(map, "마치기")
	if finish == null:
		return map
	finish.pressed.emit()
	await process_frame
	check(PORTAL.completed(session) and session.event_flag_is_set(PORTAL.WEAKENED_FLAG) and not session.event_flag_is_set(PORTAL.FULL_REVIVAL_FLAG), "portal actual Finish commits exactly one weakened king revival")
	check(session.event_flag_is_set(PORTAL.HUNT_FLAG) and not session.event_flag_is_set(PORTAL.TRACKING_FLAG), "portal Finish transfers tracking quest to hunt once")
	check(ALTAR.completed(session), "completed altar is still valid after portal's tracking handoff")
	if is_instance_valid(map.overlay):
		check(await incidental_overlay(session, map, "portal-completed"), "forest/portal original location panel closes after resolved battle")
	return map

func finish_portal(session: Node, map: Control) -> Control:
	check(session.get_story_event(PORTAL.EVENT_ID).status == "seen", "real forest/event roll discovers uncompleted portal event")
	for beat in range(4):
		check(PORTAL.current_beat(session) == beat, "portal original saved scene %d" % beat)
		var btn: Button = button_at(map, "계속")
		if btn == null:
			check(false, "portal missing Continue on scene %d" % beat)
			return map
		btn.pressed.emit()
		await process_frame
		if beat == 1:
			map = await restore_actual_panel(session, map, "계속", "portal summoned-cultists revelation")
			check(PORTAL.current_beat(session) == 2, "portal reopens actual saved visual layer 2")
	check(PORTAL.current_beat(session) == 4 and button_at(map, "저지한다") != null, "portal fifth original scene offers explicit intervention")
	check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG), "portal fifth scene cannot auto-revive king")
	var intervene: Button = button_at(map, "저지한다")
	if intervene == null:
		return map
	intervene.pressed.emit()
	check(session.get_story_event(PORTAL.EVENT_ID).choice == "intervene" and not session.event_flag_is_set(PORTAL.REVIVED_FLAG), "intervention choice saved before battle without fake result")
	var deck_ready: bool = await until_ready(func(): return is_deck(map), 12000)
	check(deck_ready, "original intervention summons deck selector after real omen delay")
	if not deck_ready:
		return map
	return await settle_portal_battle(session, map)

func finish_king_hunt(session: Node, map: Control) -> Control:
	check(session.get_story_event(HUNT.EVENT_ID).status == "seen", "actual world tree/event tile discovered original king hunt")
	check(HUNT.revival_mode(session) == "weakened", "king hunt reads only real portal victory outcome")
	for beat in range(4):
		check(HUNT.current_beat(session) == beat, "king-hunt original story beat %d persisted" % beat)
		var continue_button: Button = button_at(map, "계속")
		if continue_button == null:
			check(false, "king-hunt missing Continue at original beat %d" % beat)
			return map
		check(not session.event_flag_is_set(HUNT.FINAL_BATTLE_FLAG), "king final battle quest not unlocked before proper beat %d" % beat)
		continue_button.pressed.emit()
		await process_frame
		if beat == 1:
			map = await restore_actual_panel(session, map, "계속", "king-hunt revival dialogue")
			check(HUNT.current_beat(session) == 2, "king hunt correctly restores revival-specific dialogue beat 2")
	check(HUNT.completed(session) and not session.event_flag_is_set(HUNT.FINAL_SCENE_ACK_FLAG), "king sealed-ruins quest recorded but fifth scene remains unacknowledged")
	map = await restore_actual_panel(session, map, "마치기", "king-hunt final scene before acknowledgment")
	var finish: Button = button_at(map, "마치기")
	if finish == null:
		return map
	finish.pressed.emit()
	await process_frame
	check(HUNT.completed(session) and session.event_flag_is_set(HUNT.FINAL_SCENE_ACK_FLAG), "fifth original king-hunt scene explicitly acknowledged")
	check(session.event_flag_is_set(HUNT.SEALED_RUINS_FLAG) and session.event_flag_is_set(HUNT.FINAL_BATTLE_FLAG), "sealed-ruins destination known, only final-battle QUEST available (no invented battle)")
	check(PORTAL.completed(session) and ALTAR.completed(session), "original altar and portal stories remain historically completed after king hunt")
	if is_instance_valid(map.overlay):
		check(await incidental_overlay(session, map, "king-hunt-completed"), "world-tree original location panel can close after hunt")
	return map

func natural_cultist_portal_king(session: Node) -> void:
	check(session.get_story_event(HUNTER.EVENT_ID).status == "complete" and session.event_flag_is_set(HUNTER.CULTIST_CLUE_FLAG), "previous actual hunter clue and quest completed before next natural stage")
	check(session.get_story_event(CULTIST.EVENT_ID).status == "unseen" and session.get_story_event(ALTAR.EVENT_ID).status == "unseen", "no cultist/altar events fabricated by earlier natural travel")
	check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG) and not session.event_flag_is_set(HUNT.FINAL_BATTLE_FLAG), "king not revived and sealed-ruins quest locked before authentic ritual")
	var world = session.world
	var map: Control = MAP.instantiate()
	root.add_child(map)
	await process_frame
	var entered: Dictionary = {"cultist":false, "altar":false, "portal":false, "hunt":false}
	var counts: Dictionary = {"cultist":0, "altar":0, "portal":0, "hunt":0}
	var natural_shuffles: int = 0
	for turn in range(85):
		if is_instance_valid(map.overlay):
			check(false, "natural late-story roll blocked by unhandled UI")
			break
		var before: Dictionary = world.snapshot().duplicate(true)
		var dice = RandomNumberGenerator.new()
		dice.state = world.rng.state
		var expected_face: int = dice.randi_range(1, 6)
		var expected_position: int = world.position
		for step in range(expected_face):
			expected_position = (expected_position + 1) % 24
			if expected_position == STATE.HOME:
				break
		await map.roll_move()
		var phase: String = "cultist"
		if bool(entered.cultist):
			phase = "altar"
		if bool(entered.altar):
			phase = "portal"
		if bool(entered.portal):
			phase = "hunt"
		counts[phase] = int(counts[phase]) + 1
		check(world.move_serial == int(before.move_serial) + 1 and world.previous_map_roll == expected_face, "late roll %d: actual map die consumed once with face %d" % [turn + 1, expected_face])
		check(world.pending_move.is_empty() and world.map_serial == int(before.map_serial), "late roll %d: no unfinished move or forced shuffle" % (turn + 1))
		check(world.position == expected_position or world.tiles[expected_position] == "warp", "late roll %d: original board arrival or canonical warp" % (turn + 1))
		check(session.get_story_event(HUNTER.EVENT_ID).status == "complete" and session.event_flag_is_set(HUNTER.CULTIST_CLUE_FLAG), "late roll %d: prior hunter narrative/history remains durable" % (turn + 1))
		check(session.world.reward_receipts.size() >= before.reward_receipts.size(), "late roll %d: no earlier rewards destroyed" % (turn + 1))
		if not bool(entered.cultist) and session.get_story_event(CULTIST.EVENT_ID).status == "seen":
			check(world.tiles[world.position] in ["village", "event"], "actual cultist rumor discovered on eligible village/event")
			map = await finish_cultist_rumor(session, map)
			world = session.world
			entered.cultist = session.get_story_event(CULTIST.EVENT_ID).status == "complete"
			continue
		if bool(entered.cultist) and not bool(entered.altar) and session.get_story_event(ALTAR.EVENT_ID).status == "seen":
			check(world.tiles[world.position] in ["altar", "event"], "actual altar reached without swapping map tiles")
			map = await finish_altar_pass(session, map)
			world = session.world
			entered.altar = ALTAR.completed(session)
			continue
		if bool(entered.altar) and not bool(entered.portal) and session.get_story_event(PORTAL.EVENT_ID).status == "seen":
			check(world.tiles[world.position] in ["forest", "event"], "actual ritual portal discovered at native forest/event landing")
			map = await finish_portal(session, map)
			world = session.world
			entered.portal = PORTAL.completed(session)
			continue
		if bool(entered.portal) and not bool(entered.hunt) and session.get_story_event(HUNT.EVENT_ID).status == "seen":
			check(world.tiles[world.position] in ["unknown", "event"], "original world tree/event roll unlocks king-hunt location")
			map = await finish_king_hunt(session, map)
			world = session.world
			entered.hunt = HUNT.completed(session) and session.event_flag_is_set(HUNT.FINAL_SCENE_ACK_FLAG)
			break
		if not await incidental_overlay(session, map, "late-story-%d" % (turn + 1)):
			break
		if world.map_serial != int(before.map_serial):
			natural_shuffles += 1
		if (turn + 1) % 5 == 0:
			var snapshot: Dictionary = world.snapshot().duplicate(true)
			map.queue_free()
			await process_frame
			session.reload_world()
			world = session.world
			check(world.snapshot() == snapshot, "late roll %d: save reload preserves entire journey" % (turn + 1))
			map = MAP.instantiate()
			root.add_child(map)
			await process_frame
			check(not is_instance_valid(map.overlay) and not map.dice.disabled, "late roll %d: saved map playable after reopening" % (turn + 1))
	for key in ["cultist", "altar", "portal", "hunt"]:
		check(bool(entered[key]) and int(counts[key]) > 0, "natural complete expedition reaches and confirms source %s without teleports" % key)
	check(session.event_flag_is_set(HUNT.FINAL_SCENE_ACK_FLAG) and session.event_flag_is_set(PORTAL.WEAKENED_FLAG), "only weakened king-hunt outcome earned through original battle and fifth scene")
	check(session.get_story_event(CHILD.EVENT_ID).status == "complete" and session.get_story_event(HUNTER.EVENT_ID).status == "complete", "initial child rescue through hunter receipts retained at end of original chain")
	map.queue_free()
	await process_frame
	var last_save: Dictionary = session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot() == last_save, "all eight canonical source events and route state survive final JSON reload")
	check(HUNT.completed(session) and session.event_flag_is_set(HUNT.FINAL_SCENE_ACK_FLAG), "reloaded king hunt cannot duplicate finale or lose sealed ruins quest")
	print("P4_NATURAL_FULL_STORY_ROUTE: %d rumor, %d altar, %d portal, %d hunt real rolls, %d late house shuffles" % [int(counts.cultist), int(counts.altar), int(counts.portal), int(counts.hunt), natural_shuffles])

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var old_save: String = session.save_file_path
	var seed: int = create_run(session)
	if seed > 0 and await actual_graveyard_rescue(session):
		await natural_village_rumor(session)
		await travel_to_commander_and_hunter(session)
		if session.get_story_event(HUNTER.EVENT_ID).status == "complete":
			await natural_cultist_portal_king(session)
		else:
			check(false, "natural story cannot skip a missing hunter completion")
	session.save_file_path = old_save
	if created:
		session.queue_free()
	clear_path()
	check(not FileAccess.file_exists(path), "temporary full natural story save removed; normal player data untouched")
	print("P4_NATURAL_FULL_STORY: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
