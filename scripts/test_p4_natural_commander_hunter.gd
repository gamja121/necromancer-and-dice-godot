extends "res://scripts/test_p4_natural_story_arrival.gd"
## P4-02E-C: extend the existing untouched-map real-die child rescue and
## rescued village rumor to the next TWO actual story encounters.
## No tile swaps, forced dice faces, HOME teleports or injected quest flags.
## Only the fresh world RNG seed and graveyard combat fixture are inherited
## from P4-02E-A. An incomplete commander/hunter scene is reloaded mid-beat.
## Godot: --script res://scripts/test_p4_natural_commander_hunter.gd

const COMMANDER = preload("res://systems/knight_commander_entry.gd")
const COMMANDER_BEATS = preload("res://systems/knight_commander_beats.gd")
const HUNTER = preload("res://systems/monster_hunter_entry.gd")
const HUNTER_BEATS = preload("res://systems/monster_hunter_beats.gd")

func restore_story_midbeat(session: Node, map: Control, story_id: String, expected_beat: int, label: String) -> Control:
	var saved: Dictionary = session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot() == saved, label + ": mid-dialogue disk snapshot restored without mutations")
	check(session.get_story_event(story_id).status == "seen", label + ": reload does not complete story or grant quest")
	map = MAP.instantiate()
	root.add_child(map)
	var reopened: bool = await until_ready(func(): return button_at(map, "계속") != null, 14000)
	check(reopened, label + ": original unfinished scene restored into actual map UI")
	check(map.world == session.world and session.world.pending_move.is_empty(), label + ": restored UI attached to canonical saved world")
	if story_id == COMMANDER.EVENT_ID:
		check(COMMANDER.current_beat(session) == expected_beat, label + ": original commander dialogue beat restored")
	else:
		check(HUNTER.current_beat(session) == expected_beat, label + ": original hunter dialogue beat restored")
	return map

func finish_story(session: Node, map: Control, story_id: String, beat_count: int, interrupt_after: int, label: String) -> Control:
	check(session.get_story_event(story_id).status == "seen", label + ": natural landing discovered authentic story, not pre-completed")
	check(button_at(map, "계속") != null, label + ": first actual story button visible")
	for beat in range(beat_count):
		var current: int = COMMANDER.current_beat(session) if story_id == COMMANDER.EVENT_ID else HUNTER.current_beat(session)
		check(current == beat, label + ": current original dialogue beat is %d" % beat)
		var final_beat: bool = beat == beat_count - 1
		var title: String = "마치기" if final_beat else "계속"
		var advance: Button = button_at(map, title)
		if advance == null:
			check(false, label + ": missing genuine %s button at beat %d" % [title, beat])
			break
		check(session.get_story_event(story_id).status == "seen", label + ": no premature story completion before beat %d" % beat)
		advance.pressed.emit()
		await process_frame
		if beat == interrupt_after and not final_beat:
			map = await restore_story_midbeat(session, map, story_id, beat + 1, label)
	check(session.get_story_event(story_id).status == "complete", label + ": final real button closes and persists complete story")
	check(session.event_flag_is_set("event:%s:complete" % story_id), label + ": durable completion receipt recorded")
	check(not is_instance_valid(map.overlay), label + ": completed story scene dismissed and map usable")
	return map

func travel_to_commander_and_hunter(session: Node) -> void:
	check(session.get_story_event(CHILD.EVENT_ID).status == "complete" and session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"), "source graveyard rescue remains complete after natural village route")
	check(session.get_story_event(VILLAGE.RESCUED_ID).status == "complete", "source village rumor completed by real original buttons before next journey")
	check(session.get_story_event(COMMANDER.EVENT_ID).status == "unseen" and session.get_story_event(HUNTER.EVENT_ID).status == "unseen", "no commander/hunter event manufactured before natural travel")
	check(not session.event_flag_is_set(COMMANDER.QUEST_ACTIVE_FLAG) and not session.event_flag_is_set(HUNTER.CULTIST_CLUE_FLAG), "no downstream quest reward exists before discovery")
	if session.get_story_event(VILLAGE.RESCUED_ID).status != "complete":
		return
	var world = session.world
	var map: Control = MAP.instantiate()
	root.add_child(map)
	await process_frame
	var starting_snapshot: Dictionary = world.snapshot().duplicate(true)
	var completed_commander: bool = false
	var completed_hunter: bool = false
	var first_leg_rolls: int = 0
	var second_leg_rolls: int = 0
	var home_shuffles: int = 0
	for turn in range(55):
		if is_instance_valid(map.overlay):
			check(false, "natural follow-up starts with no unresolved panel")
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
		if completed_commander:
			second_leg_rolls += 1
		else:
			first_leg_rolls += 1
		check(world.move_serial == int(before.move_serial) + 1 and world.previous_map_roll == expected_face, "follow-up roll %d: original die face %d and one committed movement" % [turn + 1, expected_face])
		check(world.pending_move.is_empty() and world.map_serial == int(before.map_serial), "follow-up roll %d: no synthetic map rebuild or unresolved move" % (turn + 1))
		check(world.position == expected_position or world.tiles[expected_position] == "warp", "follow-up roll %d: natural generated map arrival or built-in warp" % (turn + 1))
		check(session.world.event_flags.get("event:graveyard_child_ambush_01:rescued", false) == true, "follow-up roll %d: original child rescue remains durable" % (turn + 1))
		check(session.world.reward_receipts.size() >= before.reward_receipts.size(), "follow-up roll %d: no previous rewards lost" % (turn + 1))
		if not completed_commander and session.get_story_event(COMMANDER.EVENT_ID).status == "seen":
			check(world.tiles[world.position] in ["village", "event"], "commander begins only on actually reached eligible tile")
			check(not session.event_flag_is_set(COMMANDER.QUEST_ACTIVE_FLAG), "discovering commander does not pre-grant hunter quest")
			map = await finish_story(session, map, COMMANDER.EVENT_ID, COMMANDER_BEATS.count(), 2, "commander")
			world = session.world
			completed_commander = session.get_story_event(COMMANDER.EVENT_ID).status == "complete"
			check(completed_commander and session.event_flag_is_set(COMMANDER.RECOGNIZED_FLAG), "commander's final UI click records recognition")
			check(session.event_flag_is_set(COMMANDER.QUEST_ACTIVE_FLAG) and not session.event_flag_is_set(COMMANDER.QUEST_COMPLETE_FLAG), "commander activates hunter quest but does not complete it")
			check(session.get_story_event(HUNTER.EVENT_ID).status == "unseen", "hunter never discovered merely by accepting commander quest")
			continue
		if completed_commander and session.get_story_event(HUNTER.EVENT_ID).status == "seen":
			check(world.tiles[world.position] in ["unknown", "event"], "hunter begins only on actual world-tree or wildcard landing")
			check(not session.event_flag_is_set(HUNTER.CULTIST_CLUE_FLAG), "discovering hunter does not pre-grant cultist clue")
			map = await finish_story(session, map, HUNTER.EVENT_ID, HUNTER_BEATS.count(), 3, "hunter")
			world = session.world
			completed_hunter = session.get_story_event(HUNTER.EVENT_ID).status == "complete"
			check(completed_hunter and session.event_flag_is_set(HUNTER.CULTIST_CLUE_FLAG), "hunter's final real UI click grants cultist human-involvement clue")
			check(session.event_flag_is_set(HUNTER.QUEST_COMPLETE_FLAG) and not session.event_flag_is_set(HUNTER.QUEST_ACTIVE_FLAG), "hunter quest completed exactly once without repeated active flag")
			break
		if not await incidental_overlay(session, map, "follow-up-%d" % (turn + 1)):
			break
		if world.map_serial != int(before.map_serial):
			home_shuffles += 1
		# Close and restore a genuine travel boundary too, not only story beats.
		if (turn + 1) % 5 == 0:
			var snapshot: Dictionary = world.snapshot().duplicate(true)
			map.queue_free()
			await process_frame
			session.reload_world()
			world = session.world
			check(world.snapshot() == snapshot, "follow-up roll %d: fully saved natural travel survives restart" % (turn + 1))
			map = MAP.instantiate()
			root.add_child(map)
			await process_frame
			check(not is_instance_valid(map.overlay) and not map.dice.disabled, "follow-up roll %d: original map accepts next die after restart" % (turn + 1))
	check(completed_commander and first_leg_rolls > 0, "commander discovered by at least one genuine post-rumor die roll")
	check(completed_hunter and second_leg_rolls > 0, "hunter discovered by genuine post-commander die travel")
	check(session.get_story_event(VILLAGE.ABANDONED_ID).status == "unseen", "rescue branch never grants abandoned-village rumor")
	check(world.story_events.has(COMMANDER.EVENT_ID) and world.story_events.has(HUNTER.EVENT_ID), "both events live in original world save; no injected completion")
	check(world.move_serial > int(starting_snapshot.move_serial) and world.laps >= int(starting_snapshot.laps), "all follow-up travel counts are saved rather than teleported")
	for frame in range(4):
		await process_frame
	map.queue_free()
	await process_frame
	var ending: Dictionary = session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot() == ending, "entire child rescue to hunter clue sequence round-trips complete JSON save")
	check(session.event_flag_is_set(HUNTER.CULTIST_CLUE_FLAG) and session.event_flag_is_set(HUNTER.QUEST_COMPLETE_FLAG), "hunter outcome still unique after final reload")
	print("P4_NATURAL_COMMANDER_HUNTER_ROUTE: %d commander rolls, %d hunter rolls, %d original house shuffles" % [first_leg_rolls, second_leg_rolls, home_shuffles])

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var old_path: String = session.save_file_path
	var seed: int = create_run(session)
	if seed > 0 and await actual_graveyard_rescue(session):
		await natural_village_rumor(session)
		await travel_to_commander_and_hunter(session)
	session.save_file_path = old_path
	if created:
		session.queue_free()
	clear_path()
	check(not FileAccess.file_exists(path), "only isolated natural-story save deleted; player save remains untouched")
	print("P4_NATURAL_COMMANDER_HUNTER: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
