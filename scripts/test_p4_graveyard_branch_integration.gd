extends SceneTree
## P4-02A: actual map die -> graveyard child four-beat scene -> both choice
## buttons -> real deck/battle/results -> defeat acknowledgement/retry.
## Test-only tile permutation and deterministic combat strength. Every scenario
## has an isolated PID user:// save; the frozen web repo is never altered.

const MAP_SCENE = preload("res://map.tscn")
const SESSION_SCRIPT = preload("res://systems/run_session.gd")
const STATE = preload("res://systems/map_state.gd")
const STORY = preload("res://systems/story_event_entry.gd")

var passed: int = 0
var failed: int = 0
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-graveyard: ",label)
	else:
		failed += 1
		printerr("FAIL p4-graveyard: ",label)

func clear_path(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func until_ready(predicate: Callable, limit_ms: int = 18000) -> bool:
	var begun: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-begun < limit_ms:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())

func panel_button(map: Control, button_text: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for child in map.overlay.get_children():
		if child is Button and child.text == button_text and child.visible:
			return child
	return null

func is_battle_deck(map: Control) -> bool:
	return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("battle_deck.gd")

func prepare_graveyard_landing(session: Node) -> int:
	var world = session.world
	var preview = RandomNumberGenerator.new()
	var landing: int = -1
	for seed_value in range(1,400):
		preview.seed = seed_value
		var destination: int = (STATE.HOME+preview.randi_range(1,6))%24
		if destination not in [0,8,STATE.HOME]:
			world.rng.seed = seed_value
			landing = destination
			break
	if landing<0: return -1
	var source: int = world.tiles.find("graveyard")
	if source<0: return -1
	if source!=landing:
		var old: String = str(world.tiles[landing])
		world.tiles[landing] = "graveyard"
		world.tiles[source] = old
	return landing

func prepare_run(session: Node, label: String) -> Dictionary:
	var path: String = "user://p4_graveyard_%d_%s.json" % [OS.get_process_id(),label]
	paths.append(path)
	clear_path(path)
	session.save_file_path = path
	session.start_new_world()
	var target: int = prepare_graveyard_landing(session)
	check(target>=0,label+": test-only permutation preserves ordinary 24-tile board")
	if target<0: return {}
	check(session.save_world(),label+": original map layout change saved only to isolated save")
	var map: Control = MAP_SCENE.instantiate()
	root.add_child(map)
	await process_frame
	var serial: int = session.world.move_serial
	await map.roll_move()
	check(session.world.move_serial==serial+1 and session.world.position==target and session.world.pending_move.is_empty(),label+": actual die stops on graveyard and finalizes movement")
	check(session.get_story_event(STORY.EVENT_ID).status=="seen" and session.event_flag_is_set(STORY.SEEN_FLAG),label+": live map discovers first child scene exactly once")
	check(panel_button(map,"계속")!=null and not is_battle_deck(map),label+": original first scene uses a Continue button, no premature battle")
	return {"map":map,"target":target}

func reach_choice(map: Control, label: String) -> bool:
	for beat in range(3):
		var advance: Button = panel_button(map,"계속")
		if advance==null:
			check(false,label+": missing Continue before beat %d" % beat)
			return false
		advance.pressed.emit()
		await process_frame
	var choice: bool = panel_button(map,"아이를 구한다")!=null and panel_button(map,"지나친다")!=null
	check(choice,label+": four-beat scene exposes both actual choice buttons")
	return choice

func fixture(battle: Control, victor: String, label: String) -> void:
	# The genuine battlefield rolls dice and executes attacks/animations. Only
	# test combatants' stats are changed, making victory/defeat deterministic.
	for unit in battle.rules.units:
		unit.passive = ""
		unit.brands = []
		unit.poison = []
		unit.frozen = false
		unit.undying_used = false
		unit.shields = 0
		unit.curse = {}
		unit.bless = {}
		var powerful: bool = unit.team==victor
		unit.base_attack = 999 if powerful else 0
		unit.attack = unit.base_attack
		unit.base_speed = 999 if powerful else 0
		unit.speed = unit.base_speed
		if not powerful: unit.hp = 1
	battle.rules.refresh()
	battle.session.encounter.checkpoint = battle.rules.snapshot()
	battle.session.world.active_encounter = battle.session.encounter.duplicate(true)
	check(battle.session.save_world(),label+": authentic checkpoint saved for test fixture")

func choose_deck_and_fight(session: Node, map: Control, ids: Array, victor: String, label: String) -> bool:
	var deck: Control = map.overlay
	check(is_battle_deck(map),label+": child rescue/retry enters production battle deck")
	if not is_battle_deck(map): return false
	for id in ids: deck.toggle_unit(str(id))
	check(deck.selected_ids.size()==ids.size() and not deck.confirm_button.disabled,label+": owned monster lineup chosen using actual card controls")
	deck.confirm_button.pressed.emit()
	var started: bool = await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.rules.units.is_empty())
	check(started,label+": real embedded Battlefield starts from confirmed deck")
	if not started: return false
	var battle: Control = map.embedded_battle
	check(str(session.encounter.get("event_id",""))==STORY.EVENT_ID and session.encounter.type=="event-graveyard-child",label+": battle checkpoint retains graveyard story ID")
	check(session.encounter.enemies.size()==1 and str(session.encounter.enemies[0].slug)=="ghoul",label+": canonical ghoul battle, not regular encounter")
	fixture(battle,victor,label)
	var rounds: int = 0
	while battle.rules.winner().is_empty() and rounds<8:
		rounds += 1
		await battle.roll_round()
	check(battle.rules.winner()==victor,label+": original die/attack queue resolves intended outcome in %d round(s)" % rounds)
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty(),label+": completed fight atomically releases active checkpoint")
	check(session.world.pending_reward.is_empty(),label+": story battle never grants ordinary corpse capture")
	check(not battle.map_return.disabled,label+": finished fight enables map return button")
	battle.map_return.pressed.emit()
	var returned: bool = await until_ready(func(): return map.embedded_battle==null and not map.battle_returning and is_instance_valid(map.overlay) and panel_button(map,"맵으로")!=null,21000)
	check(returned,label+": actual map return displays result panel")
	return returned

func scenario_leave(session: Node) -> void:
	var entry: Dictionary = await prepare_run(session,"leave")
	if entry.is_empty(): return
	var map: Control = entry.map
	var target: int = int(entry.target)
	if not await reach_choice(map,"leave"):
		map.queue_free()
		await process_frame
		return
	var roster: Array = session.world.roster.duplicate(true)
	var receipts: Array = session.world.reward_receipts.duplicate(true)
	panel_button(map,"지나친다").pressed.emit()
	var done: bool = await until_ready(func(): return session.get_story_event(STORY.EVENT_ID).status=="complete" and not is_instance_valid(map.overlay),12000)
	check(done,"leave: button finishes child scene without battle")
	var state: Dictionary = session.get_story_event(STORY.EVENT_ID)
	check(state.choice=="leave" and state.battle_result.is_empty(),"leave: persistent abandon branch without fabricated combat")
	check(session.event_flag_is_set("event:graveyard_child_ambush_01:abandoned") and not session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"leave: abandonment true and rescue false")
	check(session.world.roster==roster and session.world.reward_receipts==receipts and session.encounter.is_empty(),"leave: no roster loss, combat or phantom reward")
	check(not STORY.can_enter(session,target),"leave: consumed event cannot reopen or select another branch")
	map.queue_free()
	await process_frame
	var committed: Dictionary = session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==committed,"leave: complete world state restores without duplicate choice")
	map = MAP_SCENE.instantiate()
	root.add_child(map)
	await process_frame
	check(not is_instance_valid(map.overlay) and not session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"leave: map reload cannot re-trigger abandoned child scene")
	map.queue_free()
	await process_frame

func start_rescue(session: Node, label: String) -> Dictionary:
	var entry: Dictionary = await prepare_run(session,label)
	if entry.is_empty(): return {}
	var map: Control = entry.map
	if not await reach_choice(map,label): return {}
	panel_button(map,"아이를 구한다").pressed.emit()
	check(session.get_story_event(STORY.EVENT_ID).status=="active" and session.get_story_event(STORY.EVENT_ID).choice=="protect_child",label+": rescue selection persisted without premature success")
	check(is_battle_deck(map),label+": rescue choice opens real deck immediately")
	return entry

func scenario_win(session: Node) -> void:
	var entry: Dictionary = await start_rescue(session,"win")
	if entry.is_empty(): return
	var map: Control = entry.map
	var ids: Array = [str(session.world.roster[0].id),str(session.world.roster[1].id)]
	var receipts: Array = session.world.reward_receipts.duplicate(true)
	if not await choose_deck_and_fight(session,map,ids,"ally","win"): return
	var state: Dictionary = session.get_story_event(STORY.EVENT_ID)
	check(state.status=="complete" and state.battle_result=="won","win: rescue only completes after real battle victory")
	check(session.event_flag_is_set("event:graveyard_child_ambush_01:rescued") and not session.event_flag_is_set("event:graveyard_child_ambush_01:abandoned"),"win: rescue true, abandonment false")
	check(session.world.reward_receipts==receipts and session.story_battle_result_pending(STORY.EVENT_ID),"win: no ordinary reward; story result remains pending confirmation")
	# Close the game with the result still unacknowledged; restore the original
	# map through its real _ready() recovery dispatcher.
	map.queue_free()
	await process_frame
	session.reload_world()
	map = MAP_SCENE.instantiate()
	root.add_child(map)
	var restored: bool = await until_ready(func(): return panel_button(map,"맵으로")!=null)
	check(restored,"win: unacknowledged result UI reappears after process-style reload")
	if restored:
		panel_button(map,"맵으로").pressed.emit()
		check(not session.story_battle_result_pending(STORY.EVENT_ID),"win: actual result button acknowledges exactly once")
		check(not session.acknowledge_graveyard_battle_result(),"win: repeated acknowledgement rejected")
	# Confirmation re-renders the board, which creates an AudioSettings node
	# awaiting two frames in _ready; don't destroy that node immediately.
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.get_story_event(STORY.EVENT_ID).battle_result=="won" and not session.story_battle_result_pending(STORY.EVENT_ID),"win: completed rescue history survives second reload")

func scenario_loss_and_retry(session: Node) -> void:
	var entry: Dictionary = await start_rescue(session,"loss_retry")
	if entry.is_empty(): return
	var map: Control = entry.map
	var lost_id: String = str(session.world.roster[0].id)
	var survivor_id: String = str(session.world.roster[1].id)
	var receipts: Array = session.world.reward_receipts.duplicate(true)
	if not await choose_deck_and_fight(session,map,[lost_id],"enemy","loss"): return
	var result: Dictionary = session.get_story_event(STORY.EVENT_ID)
	check(result.status=="active" and result.battle_result=="lost","loss: the story remains active and not rescued")
	check(not session.event_flag_is_set("event:graveyard_child_ambush_01:complete") and not session.event_flag_is_set("event:graveyard_child_ambush_01:rescued") and not session.event_flag_is_set("event:graveyard_child_ambush_01:abandoned"),"loss: no false success, abandonment or event completion")
	check(session.world.roster.size()==1 and str(session.world.roster[0].id)==survivor_id and session.world.graveyard_corpses.any(func(c): return str(c.id)==lost_id),"loss: deployed monster permanently dies, unselected reserve survives")
	check(panel_button(map,"다시 도전")!=null,"loss: result panel enables retry with reserve monster")
	check(session.world.reward_receipts==receipts and session.story_battle_result_pending(STORY.EVENT_ID),"loss: no reward, acknowledgement still required")
	# The user presses the result modal retry, which must acknowledge defeat
	# before opening the same actual deck again.
	panel_button(map,"다시 도전").pressed.emit()
	check(not session.story_battle_result_pending(STORY.EVENT_ID) and is_battle_deck(map),"retry: actual retry button acknowledges loss then opens reserved deck")
	if not is_battle_deck(map): return
	if not await choose_deck_and_fight(session,map,[survivor_id],"ally","retry"): return
	check(session.get_story_event(STORY.EVENT_ID).status=="complete" and session.get_story_event(STORY.EVENT_ID).battle_result=="won","retry: subsequent real win rescues child")
	check(session.world.graveyard_corpses.any(func(c): return str(c.id)==lost_id) and session.world.roster.size()==1,"retry: winning does not resurrect permanently dead monster")
	check(session.world.reward_receipts==receipts,"retry: no ghost reward after multiple attempts")
	var confirm: Button = panel_button(map,"맵으로")
	if confirm!=null: confirm.pressed.emit()
	check(not session.story_battle_result_pending(STORY.EVENT_ID),"retry: final victory confirmed via UI")
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame
	var committed: Dictionary = session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==committed,"retry: graveyard corpse, saved success and receipts survive reload")

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var created: bool = session==null
	if created:
		session = SESSION_SCRIPT.new()
		session.name = "RunSession"
		root.add_child(session)
	var previous_path: String = session.save_file_path
	await scenario_leave(session)
	await scenario_win(session)
	await scenario_loss_and_retry(session)
	session.save_file_path = previous_path
	if created: session.queue_free()
	for path in paths: clear_path(path)
	check(paths.all(func(path): return not FileAccess.file_exists(path)),"all temporary saves removed; production save untouched")
	print("P4_GRAVEYARD_BRANCH_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
