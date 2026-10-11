extends SceneTree
## P4-03B: separate Godot-process battle interruption regression.
## Invoke phases in CI order. All files use dedicated disposable user:// names.
## Tests the real RunSession + BattlefieldRules state machines, not fake outcomes.
const Session = preload("res://systems/run_session.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const WIN_SAVE = "user://p4_03b_combat_restart_win_v1.json"
const LOSS_SAVE = "user://p4_03b_combat_restart_loss_v1.json"

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS p4-combat-restart: ",label)
	else:
		failed += 1
		printerr("FAIL p4-combat-restart: ",label)

func wipe(path: String) -> void:
	for ending in ["", ".tmp"]:
		if FileAccess.file_exists(path + ending):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ending))

func open_session(path: String, fresh: bool = false):
	var s = Session.new()
	root.add_child(s)
	s.save_file_path = path
	if fresh:
		wipe(path)
		s.start_new_world()
	else:
		check(s.has_save(), "previous process wrote the expected isolated save")
		s.ensure_world()
	return s

func read_rules(s):
	var r = Rules.new(s.world.definitions)
	check(not s.encounter.is_empty(), "saved active encounter exists")
	if s.encounter.is_empty(): return r
	check(r.restore(s.encounter.checkpoint), "real BattlefieldRules restores persisted checkpoint")
	return r

func configure_fixture(r, victor: String) -> void:
	# Test-only deterministic stats, with genuine generated enemies and action queue.
	# One fast winner kills exactly one target per action; three enemies ensure
	# that there is a non-terminal, partially processed action checkpoint.
	for u in r.units:
		u.passive = ""
		u.brands = []
		u.poison = []
		u.frozen = false
		u.undying_used = false
		u.shields = 0
		u.bless = {}
		u.curse = {}
		var strong: bool = str(u.team) == victor
		u.base_attack = 999 if strong else 0
		u.attack = u.base_attack
		u.base_speed = 999 if strong else 0
		u.speed = u.base_speed
		if not strong: u.hp = 1
	r.refresh()

func seed_encounter(s, victor: String) -> void:
	var w = s.world
	var tile: int = w.tiles.find("monster")
	check(tile >= 0 and tile != 23, "real ordinary monster tile selected")
	if tile < 0: return
	# Contamination/lap count only constrain this disposable combat fixture
	# to three genuine enemies so a saved action is not already the last one.
	w.position = tile
	w.laps = 4
	w.contamination = 60
	w.reveal_boss_at_threshold()
	check(s.save_world(), "disposable approach checkpoint persisted")
	var selected: Array = [str(w.roster[0].id), str(w.roster[1].id)]
	check(s.start_encounter(tile, selected), "normal monster encounter generated through RunSession")
	if s.encounter.is_empty(): return
	check(s.encounter.enemies.size() >= 3, "normal generator yields three or more actual enemies")
	var r = read_rules(s)
	configure_fixture(r, victor)
	s.encounter.checkpoint = r.snapshot()
	w.active_encounter = s.encounter.duplicate(true)
	check(s.save_world(), "deterministic combat-only fixture persisted at ready phase")
	var rolled: Dictionary = s.prepare_battle_roll(r)
	check(rolled.get("ok", false) and s.encounter.phase == "rolled", "genuine battle die rolled and saved before first process exits")
	check(int(s.encounter.roll.face) >= 1 and int(s.encounter.roll.face) <= 6, "persisted die result is legal")
	check(s.encounter == s.world.active_encounter, "memory and disk encounter state share one authoritative checkpoint")
	check(s.world.pending_reward.is_empty() and s.world.graveyard_corpses.is_empty(), "no reward or death before battle result")

func begin_actions(s, victor: String) -> void:
	if s.encounter.is_empty(): return
	check(s.encounter.phase == "rolled", "new process reopens exact rolled phase")
	var saved_roll: int = int(s.encounter.roll.face)
	var roll_id: String = str(s.encounter.id)
	var r = read_rules(s)
	check(not s.prepare_battle_roll(r).get("ok", false), "reopened battle cannot roll the same turn twice")
	r.begin_round(saved_roll)
	check(s.checkpoint_battle(r, "actions"), "battle round committed after restoring original die face")
	check(s.encounter.id == roll_id and int(s.encounter.roll.face) == saved_roll, "same encounter and die retained")
	var first: Dictionary = r.next_action()
	check(not first.is_empty(), "first authentic actor action executed")
	check(s.checkpoint_battle(r, "actions"), "one finished action checkpoint saved before exiting process")
	check(r.winner().is_empty(), "first action is deliberately nonterminal")
	check(r.queue.size() > 0, "remaining actions must resume, not replay the first one")
	var gone: int = r.units.filter(func(u): return u.team != victor and not u.alive).size()
	check(gone == 1, "exactly one opposing combatant defeated before second process exit")
	check(s.encounter.checkpoint == r.snapshot(), "durable action queue and HP match Rules state")
	check(s.world.pending_reward.is_empty() and s.world.graveyard_corpses.is_empty(), "mid-actions interruption awards and removes nothing")

func settle(s, victor: String, commit_result: bool) -> void:
	if s.encounter.is_empty(): return
	check(s.encounter.phase == "actions", "fresh process resumes actions, not another roll")
	var r = read_rules(s)
	var already_defeated: int = r.units.filter(func(u): return u.team != victor and not u.alive).size()
	check(already_defeated == 1, "first action was not replayed after reload")
	var steps: int = 0
	var turns: int = 0
	while r.winner().is_empty() and steps < 100 and turns < 12:
		var action: Dictionary = r.next_action()
		if action.is_empty():
			# A finished action queue is not necessarily a victory. Return to the
			# normal ready -> rolled -> actions state machine for the next turn.
			check(s.checkpoint_battle(r, "ready"), "completed nonterminal turn saved")
			var rolled: Dictionary = s.prepare_battle_roll(r)
			check(rolled.get("ok", false), "subsequent real combat die rolled through session")
			if not rolled.get("ok", false): break
			r.begin_round(int(rolled.face))
			check(s.checkpoint_battle(r, "actions"), "subsequent turn begins with durable action queue")
			turns += 1
			continue
		check(s.checkpoint_battle(r, "actions"), "each subsequent action saves before presentation")
		steps += 1
	check(r.winner() == victor, "original combat rules resolve deterministic " + victor + " winner")
	check(steps > 0 and steps < 100 and turns < 12, "restarted action queue completes without infinite loop")
	check(s.encounter.phase == "actions" and s.world.pending_reward.is_empty(), "terminal action checkpoint exists before committing final result")
	if not commit_result: return
	var original_encounter: String = str(s.encounter.id)
	check(s.finish_encounter(r), "final result, roster change and capture are one durable transaction")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(), "completed battle cannot be processed again")
	if victor == "ally":
		check(s.world.pending_reward.get("kind", "") == "capture", "victory's original enemy corpses become saved soul capture")
		check(s.world.roster.size() == 2 and s.world.graveyard_corpses.is_empty(), "winning owned monsters are not lost")
	else:
		check(s.world.pending_reward.is_empty(), "defeat cannot create soul-capture rewards")
		check(s.world.roster.is_empty() and s.world.graveyard_corpses.size() == 2, "two defeated owned monsters permanently removed once")
	check(original_encounter.begins_with("encounter-"), "normal encounter receipt has original serial")

func finish_terminal_loss(s) -> void:
	if s.encounter.is_empty(): return
	check(s.encounter.phase == "actions", "process restores terminal action before result commit")
	var r = read_rules(s)
	check(r.winner() == "enemy", "loss winner persists between terminal action and reward decision")
	check(s.finish_encounter(r), "loss commits once, after reload from pre-result checkpoint")
	check(s.encounter.is_empty() and s.world.roster.is_empty(), "all dead owned monsters removed atomically")
	check(s.world.graveyard_corpses.size() == 2, "both corpses retained, no accidental resurrection")
	check(s.world.pending_reward.is_empty(), "loss has no phantom soul harvest")

func capture_roll(s) -> void:
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(), "victory result still settled on a new process")
	check(s.world.pending_reward.get("kind", "") == "capture", "soul capture is restored rather than regenerated")
	var corpse_ids: Array = s.world.pending_reward.corpses.map(func(c): return str(c.id))
	check(corpse_ids.size() >= 3, "capturable defeated opponents retain their identities")
	var tries: int = 0
	while s.world.pending_reward.get("phase", "") in ["choose", "retry"] and tries < 3:
		var roll: Dictionary = s.roll_capture()
		check(roll.get("ok", false), "actual soul-harvest die roll committed to disk")
		tries += 1
	check(s.world.pending_reward.get("phase", "") in ["success", "failed"], "capture reaches stable persisted terminal phase")
	check(s.world.pending_reward.corpses.map(func(c): return str(c.id)) == corpse_ids, "same fallen enemies persist throughout capture")
	check(not s.roll_capture().get("ok", false), "terminal capture cannot re-roll for extra outcome")
	check(s.world.reward_receipts.is_empty(), "capture result is not prematurely claimed")

func claim_capture(s) -> void:
	var pending: Dictionary = s.world.pending_reward
	check(pending.get("kind", "") == "capture", "new process restores saved capture before acknowledgement")
	var id: String = str(pending.get("id", ""))
	var succeeded: bool = pending.get("phase", "") == "success"
	check(pending.get("phase", "") in ["success", "failed"], "capture result unchanged across process exit")
	if succeeded:
		var result: Dictionary = s.claim_reward()
		check(result.get("ok", false), "one genuine captured monster claimed")
		check(s.world.roster.size() == 3, "one captured unit added to surviving roster")
	else:
		check(s.dismiss_failed_capture(), "failed harvest dismissed exactly once")
		check(s.world.roster.size() == 2, "failed harvest does not generate a unit")
	check(s.world.pending_reward.is_empty(), "capture transaction fully cleared")
	check(s.world.reward_receipts.count(id) == 1, "unique reward receipt committed precisely once")
	check(not s.claim_reward().get("ok", false), "duplicate claim after receipt rejected")
	check(not s.dismiss_failed_capture(), "duplicate failed harvest dismissal rejected")

func verify_win(s) -> void:
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(), "closed victory cannot reopen phantom battle")
	check(s.world.pending_reward.is_empty(), "reloaded capture is not offered twice")
	check(s.world.reward_receipts.size() == 1, "exactly one soul capture receipt survives restart")
	check(s.world.roster.size() in [2, 3], "captured or failed final roster survives")
	check(s.world.graveyard_corpses.is_empty(), "no permanent deaths invented after win")
	check(s.world.contamination == 59, "victory reduces contamination only once")
	check(s.world.cleared.size() == 1, "one ordinary tile cleared, never duplicated")
	check(not s.claim_reward().get("ok", false), "restart cannot re-claim a resolved reward")
	check(not s.roll_capture().get("ok", false), "restart cannot reroll concluded capture")
	check(s.finish_encounter(null), "closed battle has harmless idempotent finish")
	check(s.world.reward_receipts.size() == 1, "idempotent finish changes no reward receipts")

func verify_loss(s) -> void:
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(), "loss has no resumed phantom combat")
	check(s.world.roster.is_empty() and s.world.graveyard_corpses.size() == 2, "permanent death persists without double removal")
	check(s.world.reward_receipts.is_empty() and s.world.pending_reward.is_empty(), "loss grants no duplicate rewards")
	check(s.world.contamination == 60 and s.world.cleared.is_empty(), "defeat cannot clear map or alter contamination")
	check(s.finish_encounter(null), "repeated loss finalization does nothing")
	check(s.world.graveyard_corpses.size() == 2, "idempotent loss does not duplicate corpses")
	check(s.world.graveyard_corpses.all(func(c): return typeof(c.current_hp) == TYPE_INT), "stored dead unit stats remain integer after JSON reload")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var phase: String = args[0] if args.size() > 0 else ""
	if phase == "cleanup":
		wipe(WIN_SAVE)
		wipe(LOSS_SAVE)
		check(not FileAccess.file_exists(WIN_SAVE) and not FileAccess.file_exists(LOSS_SAVE), "all isolated combat saves removed")
	else:
		var path: String = LOSS_SAVE if phase.begins_with("loss_") else WIN_SAVE
		var s = open_session(path, phase in ["win_seed", "loss_seed"])
		if s.world == null:
			check(false, "session world missing")
		else:
			match phase:
				"win_seed": seed_encounter(s, "ally")
				"win_actions": begin_actions(s, "ally")
				"win_settle": settle(s, "ally", true)
				"win_capture": capture_roll(s)
				"win_claim": claim_capture(s)
				"win_verify": verify_win(s)
				"loss_seed": seed_encounter(s, "enemy")
				"loss_actions": begin_actions(s, "enemy")
				"loss_terminal": settle(s, "enemy", false)
				"loss_finish": finish_terminal_loss(s)
				"loss_verify": verify_loss(s)
				_: check(false, "unknown phase: " + phase)
		s.free()
	print("P4_COMBAT_PROCESS_RESTART_%s: %d passed, %d failed" % [phase, passed, failed])
	quit(0 if failed == 0 else 1)
