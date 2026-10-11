extends SceneTree
## P4-03C separate Godot-process interruption across map movement, treasure
## offer/selection/claim, and a genuinely resolved graveyard story battle.
## One independent process per phase in the CI order. Dedicated user:// saves.
const Session = preload("res://systems/run_session.gd")
const MapScene = preload("res://map.tscn")
const MapState = preload("res://systems/map_state.gd")
const StoryEntry = preload("res://systems/story_event_entry.gd")
const Registry = preload("res://systems/story_battle_registry.gd")
const Rules = preload("res://systems/battlefield_rules.gd")

const MOVE_SAVE = "user://p4_03c_process_move.json"
const CHEST_SAVE = "user://p4_03c_process_chest.json"
const STORY_SAVE = "user://p4_03c_process_story.json"

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-three-restarts: ", label)
	else:
		failed += 1
		printerr("FAIL p4-three-restarts: ", label)

func wipe(path: String) -> void:
	for ext in ["", ".tmp"]:
		if FileAccess.file_exists(path + ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ext))

func open_session(path: String, fresh: bool = false):
	# The Godot project autoloads /root/RunSession. Reuse that exact node,
	# otherwise Map._ready reads a second session's default player save.
	var s = root.get_node_or_null("RunSession")
	if s == null:
		s = Session.new()
		s.name = "RunSession"
		root.add_child(s)
	s.save_file_path = path
	if fresh:
		wipe(path)
		s.start_new_world()
	else:
		check(s.has_save(), "previous process saved this isolated transaction")
		s.reload_world()
	return s

func stable_snapshot(s) -> Dictionary:
	return s.world.snapshot().duplicate(true)

func assert_roundtrip(s, label: String) -> void:
	var expected: Dictionary = stable_snapshot(s)
	var path: String = s.save_file_path
	check(FileAccess.file_exists(path), label + ": committed disk save exists")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(parsed is Dictionary and parsed.get("version", -1) == 1, label + ": disk JSON is valid")
	s.reload_world()
	check(stable_snapshot(s) == expected, label + ": complete world snapshot survives explicit reload")

func move_seed(s) -> void:
	var w = s.world
	var preview = RandomNumberGenerator.new()
	preview.state = w.rng.state
	var face: int = preview.randi_range(1, 6)
	var landing: int = (MapState.HOME + face) % 24
	var swamp: int = w.tiles.find("swamp")
	check(swamp >= 0 and landing != MapState.HOME, "original 24-tile map has a valid swamp and destination")
	if swamp < 0: return
	# Test-only tile swap preserves counts and fixed map anchors. This forces
	# an observable once-only swamp HP effect without overriding the actual die.
	if swamp != landing:
		var former: String = str(w.tiles[landing])
		w.tiles[landing] = "swamp"
		w.tiles[swamp] = former
	w.roster[0].current_hp = 2
	w.roster[1].current_hp = 1
	check(s.save_world(), "fixture saved before real map roll")
	var outcome: Dictionary = s.prepare_map_roll()
	check(outcome.get("ok", false), "real movement die and transaction committed")
	check(int(outcome.get("face", 0)) == face, "authentic die RNG agrees with preview")
	check(w.position == landing and w.tiles[landing] == "swamp", "original path arrives at swamp")
	check(w.pending_move.get("landed", -1) == landing and w.move_serial == 1, "one pending move has its original serial and destination")
	check(w.roster[0].current_hp == 1 and w.roster[1].current_hp == 1, "swamp damage applies once at commit")
	check(w.pending_reward.is_empty() and s.encounter.is_empty(), "a pending move cannot trigger free encounter or treasure")

func move_resume(s) -> void:
	var w = s.world
	var serial: int = w.move_serial
	var dest: int = w.position
	var last_face: int = w.last_face
	check(not w.pending_move.is_empty() and serial == 1, "new process sees one unfinished, durable movement")
	check(not s.prepare_map_roll().get("ok", false), "restart cannot roll a second movement while first is pending")
	check(w.roster[0].current_hp == 1, "swamp injury remains applied exactly once before animation")
	# The real Map _ready resumes a pending movement and runs original hero
	# animation/arrival completion, not a direct test-only acknowledgement.
	var map = MapScene.instantiate()
	root.add_child(map)
	var begun: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - begun < 20000:
		if w.pending_move.is_empty() and not map.moving: break
		await process_frame
	for i in range(3): await process_frame
	check(w.pending_move.is_empty() and not map.moving, "real Map scene completes interrupted movement after process restart")
	check(w.position == dest and w.move_serial == serial and w.last_face == last_face, "map landing, die and serial are not rerolled")
	check(w.roster[0].current_hp == 1 and w.roster[1].current_hp == 1, "swamp damage remains once-only after Map animation")
	check(not map.dice.disabled, "original map controls unlock after restoring movement")
	check(w.pending_reward.is_empty() and s.encounter.is_empty(), "movement restoration never invents other transactions")
	map.queue_free()
	await process_frame
	assert_roundtrip(s, "completed Map move")

func move_verify(s) -> void:
	check(s.world.pending_move.is_empty() and s.world.move_serial == 1, "final process never replays resolved movement")
	check(s.world.roster[0].current_hp == 1 and s.world.roster[1].current_hp == 1, "swamp HP does not drain a second time")
	var before: Dictionary = stable_snapshot(s)
	check(s.complete_map_move(), "duplicate movement acknowledgement is safe")
	check(stable_snapshot(s) == before, "duplicate movement acknowledgement changes no saved fields")
	check(s.world.reward_receipts.is_empty() and s.encounter.is_empty(), "no phantom move reward or battle")
	assert_roundtrip(s, "final movement")

func chest_seed(s) -> void:
	var w = s.world
	var index: int = w.tiles.find("gem")
	check(index >= 0, "authentic treasure tile exists")
	if index < 0: return
	w.position = index
	# Select a deterministic non-mimic chest without introducing item/reward
	# shortcuts. The real open_treasure() generates and saves all three cards.
	var preview = RandomNumberGenerator.new()
	var chosen: int = -1
	for value in range(1, 150):
		preview.seed = value
		if preview.randf() >= 0.10:
			chosen = value
			break
	check(chosen > 0, "test RNG can generate an ordinary chest")
	w.rng.seed = chosen
	check(s.save_world(), "treasure approach persisted")
	check(s.open_treasure(index), "real chest opening persists three generated offers")
	check(w.pending_reward.get("kind", "") == "treasure" and w.pending_reward.get("offers", []).size() == 3, "saved chest has original three immutable offers")
	check(int(w.pending_reward.get("selected", -2)) == -1 and w.reward_receipts.is_empty(), "opening cannot claim reward before selection")
	check(not s.prepare_map_roll().get("ok", false), "open chest blocks travel")

func chest_choose(s) -> void:
	var w = s.world
	check(w.pending_reward.get("kind", "") == "treasure", "new process reloads unselected treasure offers")
	var offers: Array = w.pending_reward.get("offers", [])
	check(offers.size() == 3, "three original offers survive reload")
	if offers.size() != 3: return
	var choice: int = 0
	for i in range(offers.size()):
		if str(offers[i].kind) == "brand":
			choice = i
			break
	var original_offers: Array = offers.duplicate(true)
	check(s.select_treasure(choice), "first click saves chosen treasure card but grants no item")
	check(w.pending_reward.offers == original_offers and int(w.pending_reward.selected) == choice, "selection does not regenerate random offers")
	check(not w.pending_reward.has("reward") and w.reward_receipts.is_empty(), "choosing a card is not claiming a reward")
	check(not s.claim_reward().get("ok", false), "premature claim is rejected")

func chest_prepare(s) -> void:
	var w = s.world
	var pending: Dictionary = w.pending_reward
	check(pending.get("kind", "") == "treasure" and int(pending.get("selected", -1)) >= 0, "third process restores selected card before preparation")
	var choice: int = int(pending.get("selected", -1))
	var offers: Array = pending.get("offers", [])
	if choice < 0 or choice >= offers.size(): return
	check(s.prepare_treasure_reward(choice), "real chosen item prepared and persisted")
	check(w.pending_reward.has("reward") and str(w.pending_reward.reward.kind) == str(offers[choice].kind), "prepared reward matches chosen kind")
	var item: Dictionary = w.pending_reward.reward.item.duplicate(true)
	var id: String = str(item.get("id", ""))
	check(not id.is_empty(), "prepared item has stable unique id")
	check(s.prepare_treasure_reward(choice), "repeat prepare is idempotent")
	check(w.pending_reward.reward.item == item and w.reward_receipts.is_empty(), "repeat prepare generates no second item or early receipt")
	check(not s.select_treasure((choice + 1) % 3), "cannot switch selection after item is prepared")

func chest_claim(s) -> void:
	var w = s.world
	var pending: Dictionary = w.pending_reward
	check(pending.get("kind", "") == "treasure" and pending.has("reward"), "fourth process restores prepared unclaimed reward")
	if not pending.has("reward"): return
	var reward: Dictionary = pending.reward.duplicate(true)
	var receipt: String = str(pending.id)
	var kind: String = str(reward.kind)
	var inventory: Array = w.roster if kind == "unit" else (w.dice_cards if kind == "dice" else w.brand_cards)
	var before_count: int = inventory.size()
	var item_id: String = str(reward.item.id)
	var result: Dictionary = s.claim_reward()
	check(result.get("ok", false) and result.get("kept", false), "exactly one prepared reward claimed into inventory")
	var after: Array = w.roster if kind == "unit" else (w.dice_cards if kind == "dice" else w.brand_cards)
	check(after.size() == before_count + 1 and after.any(func(x): return str(x.id) == item_id), "same item ID, without reroll, enters correct inventory")
	check(w.pending_reward.is_empty() and w.reward_receipts.count(receipt) == 1, "pending transaction clears with unique receipt")
	check(not s.claim_reward().get("ok", false), "duplicate claim immediately rejected")
	check(not s.open_treasure(w.position), "claimed chest cannot reopen this visit")

func chest_verify(s) -> void:
	var w = s.world
	check(w.pending_reward.is_empty() and w.reward_receipts.size() == 1, "claimed chest is still finalized after another process start")
	var receipt: String = str(w.reward_receipts[0]) if not w.reward_receipts.is_empty() else ""
	check(receipt.begins_with("treasure-visit:") and w.reward_receipts.count(receipt) == 1, "same once-only visit receipt persisted")
	var before: Dictionary = stable_snapshot(s)
	check(not s.open_treasure(w.position), "restarted session cannot roll chest rewards twice")
	check(not s.claim_reward().get("ok", false), "restarted session cannot claim chest again")
	check(stable_snapshot(s) == before, "rejected duplicates do not mutate inventory or RNG")
	assert_roundtrip(s, "final treasure")

func story_seed(s) -> void:
	var w = s.world
	var index: int = w.tiles.find("graveyard")
	check(index >= 0, "original graveyard story location exists")
	if index < 0: return
	w.position = index
	check(s.save_world(), "graveyard approach saved")
	check(StoryEntry.begin(s, index) and StoryEntry.choose(s, index, "protect_child"), "real child story discovery and rescue decision committed")
	check(s.start_story_encounter(Registry.GRAVEYARD_ID, index, [str(w.roster[0].id), str(w.roster[1].id)]), "selected owned cards start real story combat")
	if s.encounter.is_empty(): return
	var r = Rules.new(w.definitions)
	check(r.restore(s.encounter.checkpoint), "real story combat rules loaded")
	# Deterministic fixture affects only combatant stats; the registry,
	# original ghoul, die, action queue and result handler remain intact.
	for u in r.units:
		u.passive = ""
		u.brands = []
		u.poison = []
		u.frozen = false
		u.shields = 0
		var ally: bool = u.team == "ally"
		u.base_attack = 999 if ally else 0
		u.attack = u.base_attack
		u.base_speed = 999 if ally else 0
		u.speed = u.base_speed
		if not ally: u.hp = 1
	r.refresh()
	s.encounter.checkpoint = r.snapshot()
	w.active_encounter = s.encounter.duplicate(true)
	check(s.save_world(), "ready checkpoint saved with genuine story encounter ID")
	check(s.prepare_battle_roll(r).get("ok", false) and s.encounter.phase == "rolled", "story fight's real die is saved before exit")
	check(not s.event_flag_is_set(StoryEntry.COMPLETE_FLAG) and not s.graveyard_battle_result_pending(), "rescue reward/result cannot appear at story-battle entry")

func story_action(s) -> void:
	var w = s.world
	check(s.encounter.get("event_id", "") == Registry.GRAVEYARD_ID and s.encounter.get("phase", "") == "rolled", "next process restores original story combat and die phase")
	if s.encounter.is_empty(): return
	var r = Rules.new(w.definitions)
	check(r.restore(s.encounter.checkpoint), "battle's saved Rules checkpoint restores")
	check(not s.prepare_battle_roll(r).get("ok", false), "story die cannot reroll during mid-turn recovery")
	r.begin_round(int(s.encounter.roll.face))
	check(s.checkpoint_battle(r, "actions"), "story battle action turn checkpoint persisted")
	var attempts: int = 0
	while r.winner().is_empty() and attempts < 20:
		var action: Dictionary = r.next_action()
		check(s.checkpoint_battle(r, "actions"), "each story action saved before presentation")
		if action.is_empty(): break
		attempts += 1
	check(r.winner() == "ally", "genuine ghoul fight ends in real Rules victory")
	check(not s.graveyard_battle_result_pending() and s.get_story_event(Registry.GRAVEYARD_ID).status == "active", "terminal action is not prematurely marked rescue")

func story_commit(s) -> void:
	check(s.encounter.get("phase", "") == "actions", "new process returns at terminal action checkpoint")
	if s.encounter.is_empty(): return
	var r = Rules.new(s.world.definitions)
	check(r.restore(s.encounter.checkpoint), "terminal story Rules state restores")
	check(r.winner() == "ally", "victory persisted before result commit")
	check(s.finish_encounter(r), "story result and rescue flags committed atomically")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(), "story fight is closed exactly once")
	check(s.graveyard_battle_result_pending(), "unacknowledged story result receipt survives result commit")
	check(s.get_story_event(Registry.GRAVEYARD_ID).battle_result == "won" and s.get_story_event(Registry.GRAVEYARD_ID).status == "complete", "rescued child outcome is final and stored")
	check(s.event_flag_is_set("event:graveyard_child_ambush_01:rescued") and s.event_flag_is_set(StoryEntry.COMPLETE_FLAG), "canonical rescued and complete flags saved together")
	check(s.world.pending_reward.is_empty() and s.world.reward_receipts.is_empty(), "story rescue cannot also award an unrelated treasure")
	check(not s.start_story_encounter(Registry.GRAVEYARD_ID, s.world.position, [str(s.world.roster[0].id)]), "victory cannot start a second story battle")

func story_ack(s) -> void:
	check(s.pending_story_battle_event_id() == Registry.GRAVEYARD_ID, "Map startup will find the saved pending child result")
	var view: Dictionary = s.story_battle_presentation(Registry.GRAVEYARD_ID)
	check(str(view.get("title", "")) == "아이 구조 성공", "original result dialogue and screen are available after process restart")
	check(s.graveyard_battle_result_pending(), "mere presentation must not consume receipt")
	check(s.acknowledge_graveyard_battle_result(), "explicit user acknowledgement persists receipt dismissal")
	check(not s.graveyard_battle_result_pending(), "confirmed result no longer pending")
	check(not s.acknowledge_graveyard_battle_result(), "same story result cannot be acknowledged twice")
	check(s.event_flag_is_set("event:graveyard_child_ambush_01:rescued"), "ack does not erase rescue")

func story_verify(s) -> void:
	var ev: Dictionary = s.get_story_event(Registry.GRAVEYARD_ID)
	check(ev.status == "complete" and ev.battle_result == "won", "final story outcome survives another process")
	check(not s.graveyard_battle_result_pending() and s.pending_story_battle_event_id().is_empty(), "already closed result is not replayed")
	check(s.event_flag_is_set("event:graveyard_child_ambush_01:rescued"), "child remains rescued exactly once")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty() and s.world.pending_reward.is_empty(), "no phantom battle or harvest")
	var before: Dictionary = stable_snapshot(s)
	check(s.finish_encounter(null), "second result-finalization request is a no-op")
	check(stable_snapshot(s) == before, "no additional story reward, roster change or RNG mutation")
	assert_roundtrip(s, "final story")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var phase: String = args[0] if not args.is_empty() else ""
	if phase == "cleanup":
		for path in [MOVE_SAVE, CHEST_SAVE, STORY_SAVE]: wipe(path)
		check([MOVE_SAVE, CHEST_SAVE, STORY_SAVE].all(func(path): return not FileAccess.file_exists(path)), "all isolated P4-03C saves cleaned, player files untouched")
	else:
		var path: String = STORY_SAVE if phase.begins_with("story_") else (CHEST_SAVE if phase.begins_with("chest_") else MOVE_SAVE)
		var fresh: bool = phase in ["move_seed", "chest_seed", "story_seed"]
		var s = open_session(path, fresh)
		if s.world == null:
			check(false, "could not load saved world for " + phase)
		else:
			match phase:
				"move_seed": move_seed(s)
				"move_resume": await move_resume(s)
				"move_verify": move_verify(s)
				"chest_seed": chest_seed(s)
				"chest_choose": chest_choose(s)
				"chest_prepare": chest_prepare(s)
				"chest_claim": chest_claim(s)
				"chest_verify": chest_verify(s)
				"story_seed": story_seed(s)
				"story_action": story_action(s)
				"story_commit": story_commit(s)
				"story_ack": story_ack(s)
				"story_verify": story_verify(s)
				_: check(false, "unknown phase " + phase)
		# Autoload remains owned by the SceneTree until this process exits.
	print("P4_THREE_PROCESS_RESTART_%s: %d passed, %d failed" % [phase, passed, failed])
	quit(0 if failed == 0 else 1)
