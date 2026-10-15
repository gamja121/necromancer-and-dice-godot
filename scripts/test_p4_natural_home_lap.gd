extends SceneTree
## P4-01G: complete a real unmodified 24-tile lap using only original
## map-die rolls, visit UI, home recovery, original shuffle and fresh save.
## Unlike P4-01D/E this never swaps tiles, teleports, fast-forwards the hero
## or forces a die. Only the initial deterministic generated-board seed and
## a wounded disposable monster are test fixtures.
## godot --headless --path . --script res://scripts/test_p4_natural_home_lap.gd

const MAP = preload("res://map.tscn")
const STATE = preload("res://systems/map_state.gd")
const SESSION = preload("res://systems/run_session.gd")
const BattleDeck = preload("res://systems/battle_deck.gd")
const SAFE = ["rest", "forest", "altar", "unknown", "basic", "swamp", "monster", "rare-monster"]

var passed: int = 0
var failed: int = 0
var path: String = ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-natural-home: ", label)
	else:
		failed += 1
		printerr("FAIL p4-natural-home: ", label)

func clean_save() -> void:
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

func until_ready(predicate: Callable, timeout_ms: int = 70000) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout_ms:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())

func panel_button(map: Control, title: String) -> Button:
	if not is_instance_valid(map.overlay):
		return null
	for node in map.overlay.get_children():
		if node is Button and node.text == title and node.visible:
			return node
	return null

func is_deck(map: Control) -> bool:
	return is_instance_valid(map.overlay) and map.overlay.get_script() != null and map.overlay.get_script().resource_path.ends_with("battle_deck.gd")

func next_landing(world) -> Dictionary:
	var preview = RandomNumberGenerator.new()
	preview.state = world.rng.state
	var face: int = preview.randi_range(1, 6)
	var destination: int = world.position
	for step in range(face):
		destination = (destination + 1) % 24
		if destination == STATE.HOME:
			break
	return {"face":face, "position":destination}

func select_natural_seed(world) -> int:
	# Find a native seed with a quiet, non-event route. This changes neither
	# generated tiles nor any actual die or story state while playing.
	for seed in range(1, 6001):
		var trial = STATE.new(world.definitions, seed, world.patrol_plan)
		var preview = RandomNumberGenerator.new()
		preview.state = trial.rng.state
		var position: int = STATE.HOME
		var visits: Dictionary = {}
		var turns: int = 0
		var valid: bool = true
		for turn in range(14):
			var face: int = preview.randi_range(1, 6)
			for step in range(face):
				position = (position + 1) % 24
				if position == STATE.HOME:
					break
			turns += 1
			if position == STATE.HOME:
				break
			var tile: String = str(trial.tiles[position])
			if not tile in SAFE:
				valid = false
				break
			visits[tile] = true
		if valid and position == STATE.HOME and turns >= 5 and visits.size() >= 3 and (visits.has("forest") or visits.has("basic")):
			return seed
	return -1

func dismiss_normal_location(map: Control, kind: String, turn: int) -> bool:
	if kind in ["monster", "rare-monster"]:
		check(is_deck(map), "roll %d: real encounter deck opens before confirmation" % turn)
		check(map.session.encounter.is_empty(), "roll %d: no battle without confirmed deck" % turn)
	elif kind in ["rest", "forest", "altar", "unknown"]:
		check(is_instance_valid(map.overlay) and panel_button(map, "나가기") != null, "roll %d: original %s panel opens" % [turn, kind])
	else:
		check(not is_instance_valid(map.overlay), "roll %d: passive %s tile has no blocking panel" % [turn, kind])
	if is_instance_valid(map.overlay):
		# Closing an uncommitted action is an existing player interaction,
		# not a test-only reward, teleport or quest completion.
		map.close_overlay()
		await process_frame
	return not is_instance_valid(map.overlay)

func reload_during_route(session: Node, map: Control, turn: int) -> Control:
	var saved: Dictionary = session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	var reloaded_snapshot: Dictionary = session.world.snapshot()
	if reloaded_snapshot!=saved:
		for field in saved:
			if saved[field]!=reloaded_snapshot.get(field):
				print("DEBUG_DIE_SNAPSHOT_DIFF roll=",turn," key=",field,
					" prior=",str(saved[field]).substr(0,220),
					" loaded=",str(reloaded_snapshot.get(field)).substr(0,220))
	check(reloaded_snapshot == saved, "roll %d: entire natural map snapshot survives JSON reload" % turn)
	map = MAP.instantiate()
	root.add_child(map)
	await process_frame
	check(map.world == session.world and not map.moving and not map.dice.disabled, "roll %d: actual reopened map accepts the next die" % turn)
	return map

func perform_lap(session: Node) -> void:
	var world = session.world
	var seed: int = select_natural_seed(world)
	check(seed > 0, "native deterministic generated board with non-event natural lap exists")
	if seed < 0:
		return
	session.world = STATE.new(world.definitions, seed, world.patrol_plan)
	world = session.world
	var initial_tiles: Array = world.tiles.duplicate(true)
	var initial_receipts: Array = world.reward_receipts.duplicate(true)
	var original_hp: int = int(world.roster[0].max_hp)
	world.roster[0].current_hp = maxi(1, original_hp - 2)
	check(world.roster[0].current_hp < original_hp, "only disposable owned unit starts wounded for home-healing proof")
	check(session.save_world(), "genuine seeded 24-tile board persisted without tile permutations")
	check(world.position == STATE.HOME and world.map_serial == 1 and world.move_serial == 0, "fresh original board and starting house")
	check(world.tiles.count("basic")==10 and world.tiles.count("monster")==5 and world.tiles.count("event")==2 and world.tiles.count("rest")==0 and world.tiles.count("swamp")==0 and world.tiles.count("graveyard")==0 and world.tiles.count("altar")==0
		and world.tiles.count("unknown")==0 and world.tiles.count("rare-monster")==0,
		"first expedition guarantees five monsters, two events and no swamp/rest with 10 empty roads")
	var map: Control = MAP.instantiate()
	root.add_child(map)
	await process_frame
	var turns: int = 0
	var places: Dictionary = {}
	var home_reached: bool = false
	for i in range(14):
		if is_instance_valid(map.overlay):
			check(false, "no unresolved overlay before next original die")
			break
		var before_hp: int = int(world.roster[0].current_hp)
		var expected: Dictionary = next_landing(world)
		var previous_moves: int = world.move_serial
		var original_position: int = world.position
		await map.roll_move()
		turns += 1
		var destination: int = int(expected.position)
		var kind: String = str(world.tiles[destination])
		check(world.position == destination and world.previous_map_roll == int(expected.face), "roll %d: original RNG face %d moves %d to %d" % [turns, int(expected.face), original_position, destination])
		check(world.move_serial == previous_moves + 1 and world.pending_move.is_empty(), "roll %d: exactly one finalized movement transaction" % turns)
		check(world.tiles == initial_tiles and world.map_serial == 1, "roll %d: all 24 tile types and ordering stay original" % turns)
		# The original battle-deck editor deliberately HIDES the die so
		# deck cards remain unobstructed. Its input is still disabled until
		# the player decides to fight. New starter counts expose this path
		# in the first natural lap much more often than the old rest-heavy map.
		var die_should_show: bool=not (is_instance_valid(map.overlay) and map.overlay is BattleDeck)
		check(map.selected == world.position and not map.moving
			and map.dice.is_visible_in_tree()==die_should_show
			and map.dice.disabled==is_instance_valid(map.overlay),
			"roll %d: shared die respects original battle-deck visibility and modal input lock" % turns)
		check(session.encounter.is_empty() and world.pending_reward.is_empty() and world.reward_receipts == initial_receipts, "roll %d: no fabricated encounter or reward" % turns)
		check(int(world.roster[0].current_hp) == (maxi(1, before_hp - 1) if kind == "swamp" else before_hp), "roll %d: natural HP change occurs only on swamp" % turns)
		if destination == STATE.HOME:
			home_reached = true
			break
		places[kind] = true
		if not await dismiss_normal_location(map, kind, turns):
			check(false, "roll %d: normal location can be dismissed to resume travel" % turns)
			break
		if turns % 3 == 0:
			map = await reload_during_route(session, map, turns)
			world = session.world
	check(home_reached and turns >= 5, "one original unshortened lap naturally returns home in %d die rolls" % turns)
	check(places.size() >= 3, "natural lap visits at least three distinct tile types")
	check(world.position == STATE.HOME and world.lap_ready and world.laps == 0, "home landing only arms one future lap; does not advance prematurely")
	check(panel_button(map, "들어가기") != null and panel_button(map, "나가기") != null, "actual home entrance and exit displayed")
	if home_reached and panel_button(map, "들어가기") != null:
		panel_button(map, "들어가기").pressed.emit()
		var interior: bool = await until_ready(func(): return panel_button(map, "낙인 계승") != null and panel_button(map, "순찰경로") != null, 14000)
		check(interior, "actual house interior opens inheritance and patrol UI")
		check(world.roster.all(func(u): return int(u.current_hp) == int(u.max_hp)), "home entrance restores all surviving monster HP")
		var exit: Button = panel_button(map, "나가기")
		check(exit != null, "home interior exposes original shuffle exit")
		if exit != null:
			var receipts_before_exit: Array = world.reward_receipts.duplicate(true)
			exit.pressed.emit()
			var shuffled: bool = await until_ready(func(): return not map.moving and world.map_serial == 2, 80000)
			check(shuffled, "actual gather/rotation/scatter completes one saved natural shuffle")
			check(world.laps == 1 and world.contamination == 7 and not world.lap_ready, "home exit commits exactly one lap and +7 contamination")
			check(world.position == STATE.HOME and world.tiles.size() == 24 and world.tiles[0] == "fortune-teller-camp" and world.tiles[8] == "village" and world.tiles[STATE.HOME] == "home", "reshuffled board preserves all three fixed anchors")
			check(world.tiles.count("graveyard")==1 and world.tiles.count("basic")==9 and world.tiles.count("event")==2,
				"first completed lap unlocks exactly one graveyard in place of one road")
			check(world.tiles.count("unknown")==0 and world.tiles.count("altar")==0 and world.tiles.count("rare-monster")==0,
				"world tree, altar, rare monster remain excluded after the first lap")
			check(world.reward_receipts == receipts_before_exit and session.encounter.is_empty() and world.pending_reward.is_empty(), "shuffle cannot create phantom rewards or encounters")
			check(not is_instance_valid(map.overlay) and not map.dice.disabled, "fresh lap restores playable map and enabled die")
			var shuffled_snapshot: Dictionary = world.snapshot().duplicate(true)
			map = await reload_during_route(session, map, turns)
			world = session.world
			check(world.snapshot() == shuffled_snapshot and world.laps == 1, "reloaded saved lap cannot shuffle or increment twice")
			var followup: Dictionary = next_landing(world)
			var move_before: int = world.move_serial
			await map.roll_move()
			check(world.position == int(followup.position) or world.tiles[int(followup.position)] == "warp", "second lap begins with genuine RNG movement")
			check(world.move_serial == move_before + 1 and world.pending_move.is_empty()
				and map.dice.disabled==is_instance_valid(map.overlay), "second lap move commits once and respects modal input lock")
			print("P4_NATURAL_HOME_ROUTE: seed %d, %d genuine first-lap rolls, %d encountered tile types" % [seed, turns, places.size()])
	map.queue_free()
	await process_frame

func _run() -> void:
	path = "user://p4_natural_home_lap_%d.json" % OS.get_process_id()
	clean_save()
	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var old_save: String = session.save_file_path
	session.save_file_path = path
	session.start_new_world()
	await perform_lap(session)
	session.save_file_path = old_save
	if created:
		session.queue_free()
	clean_save()
	check(not FileAccess.file_exists(path), "isolated disposable save removed without touching player data")
	print("P4_NATURAL_HOME_LAP: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
