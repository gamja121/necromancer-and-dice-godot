extends SceneTree

const Session = preload("res://systems/run_session.gd")
const Fixture = preload("res://scripts/witch_hunt_fixture.gd")
const Hunt = Fixture.Hunt
const HOME = Fixture.State.HOME
var session: Node
var save_path: String
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL riot: ", message)
	return ok


func seed_rolls(player: int, villagers: int = 0) -> void:
	var probe := RandomNumberGenerator.new()
	for seed in range(1, 200):
		probe.seed = seed
		if probe.randi_range(1, 6) != player: continue
		if villagers != 0 and probe.randi_range(1, 3) != villagers: continue
		session.world.rng.seed = seed
		return
	check(false, "controlled roll seed exists")


func prepare_turn(player_tile: int, crowd_tile: int, player: int, villagers: int = 0) -> bool:
	session.world.position = player_tile
	session.world.riot = {"state":"active", "index":crowd_tile, "face":1, "pending":{}}
	var destination: int = mini(player_tile + player, HOME)
	if destination != HOME: session.world.tiles[destination] = "basic"
	seed_rolls(player, villagers)
	var result: Dictionary = session.prepare_map_roll()
	return check(result.get("ok", false) and int(result.get("face", 0)) == player, "ordinary player roll schedules riot turn")


func run() -> void:
	session = Session.new()
	root.add_child(session)
	save_path = "user://witch_hunt_riot_%d.json" % OS.get_process_id()
	session.save_file_path = save_path
	if not check(Fixture.prepare(session) and Fixture.arrive(session, 0) and Fixture.finish_stage(session, 0, "confront"), "genuine witness event"):
		quit(1)
		return
	check(not Hunt.can_enter(session, 1, session.world.position), "same witness visit cannot start riot")
	session.world.position = 4
	session.world.move_serial += 1
	if not check(Fixture.finish_stage(session, 1, "alone"), "riot story can finish away from village"):
		quit(1)
		return
	var opening: Dictionary = session.world.riot.duplicate(true)
	check(opening.get("index", -1) == session.world.tiles.find("village"), "riot pawn starts at village")
	if not check(opening.get("pending", {}).get("face", 0) in [1, 2, 3], "saved opening roll is 1 to 3"):
		quit(1)
		return
	check(opening.pending.path.size() == opening.pending.face and session.world.position == 4, "opening movement follows the face and does not move player")
	var opening_rng: int = session.world.rng.state
	session.reload_world()
	check(session.world.riot == opening and session.world.rng.state == opening_rng, "restart reuses saved opening roll")
	session.save_file_path = "user://riot_missing_%d/save.json" % OS.get_process_id()
	check(not session.complete_riot_opening() and session.world.riot == opening, "failed opening commit preserves same plan")
	session.save_file_path = save_path
	check(session.complete_riot_opening() and session.world.riot.index == opening.pending.path.back(), "opening movement commits once")
	check(session.complete_riot_opening() and session.world.rng.state == opening_rng, "retry after commit draws no die")
	var active_snapshot: Dictionary = session.world.snapshot().duplicate(true)
	check(not session.leave_home() and session.notice == session.RIOT_REMOTE_HOME_REASON, "remote HOME cannot bypass the chase")
	check(not session.enter_home() and not session.home_services_allowed().ok, "remote HOME cannot heal during chase")
	check(session.world.snapshot() == active_snapshot, "blocked remote HOME changes neither progress nor RNG")
	session.world.position = HOME
	check(session.save_world() and session.reload_world() and session.world.riot.state == "stopped", "an older save already at HOME is recovered")

	if prepare_turn(10, 9, 1, 3):
		var plan: Dictionary = session.world.riot.pending.duplicate(true)
		check(plan.face == 3 and plan.path == [10, 11, 12] and plan.state == "active", "villagers passing the stationary player are not captured")
		var saved_rng: int = session.world.rng.state
		session.reload_world()
		check(session.world.riot.pending == plan and session.world.rng.state == saved_rng, "ordinary turn restores the same face and path")
		check(session.complete_map_move() and session.world.riot.index == 12 and session.world.riot.state == "active", "one player turn advances riot by committed 3")
	if prepare_turn(9, 11, 4):
		check(session.world.riot.pending.face == 0 and session.world.riot.pending.state == "stopped", "player crossing the riot pawn stops it before it rolls")
		check(session.complete_map_move() and session.home_services_allowed().ok and not Hunt.home_burned(session), "capture protects the house")
	if prepare_turn(HOME - 1, HOME - 2, 4):
		check(session.complete_map_move() and session.world.position == HOME and session.world.riot.state == "stopped", "hero first to HOME can defend it")
	if prepare_turn(2, HOME - 1, 1, 3):
		check(session.world.riot.pending.path == [HOME] and session.world.riot.pending.face == 3 and not Hunt.home_burned(session), "riot clips movement at HOME without changing face")
		var burn_plan: Dictionary = session.world.riot.duplicate(true)
		session.save_file_path = "user://riot_missing_%d/save.json" % OS.get_process_id()
		check(not session.complete_map_move() and session.world.riot == burn_plan and not session.world.pending_move.is_empty(), "failed turn commit cannot lose the movement or preemptively burn")
		session.save_file_path = save_path
		check(session.complete_map_move() and Hunt.home_burned(session) and not session.home_services_allowed().ok, "villagers first to HOME burn it immediately from another tile")
		session.reload_world()
		check(Hunt.home_burned(session) and not session.home_services_allowed().ok and session.world.position != HOME, "burn persists independently of player location")
		session.world.position = HOME
		session.world.lap_ready = true
		check(session.leave_home() and Hunt.home_burned(session), "next lap preserves the burnt house")

	if check(Fixture.prepare(session) and Fixture.arrive(session, 0) and Fixture.finish_stage(session, 0, "confront"), "escort fixture is a genuine story route"):
		session.world.position = 7
		session.world.move_serial += 1
		var rng_before_escort: int = session.world.rng.state
		var village: int = session.world.tiles.find("village")
		check(Fixture.finish_stage(session, 1, "escort"), "escort begins the riot")
		check(session.world.riot.index == village and session.world.riot.pending.is_empty() and session.world.rng.state == rng_before_escort, "guards hold the mob without an opening roll")
		check(session.reload_world() and session.world.riot.index == village and session.world.riot.pending.is_empty(), "restarting does not consume the player's head start")
		seed_rolls(2)
		check(session.prepare_map_roll().get("ok", false) and session.world.riot.pending.state == "stopped", "player can catch the mob on the first escorted roll")
		check(session.complete_map_move(), "escorted capture commits")

	session.free()
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("WITCH_HUNT_RIOT: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
