extends SceneTree
## P4-02D: one fresh world per route, with no forged/pre-completed story
## states. Actual Map scenes, source event buttons and full battle flow
## establish all story/quest receipts in sequence. Only route approach is
## shortened by test-only positioning at HOME and swapping one ordinary tile
## ahead of a genuine 1-6 die, as in previous P4 integration tests.
## Rescued routes exercise both portal outcomes; abandoned has its own rumor
## and intentionally cannot unlock the commander/king-hunt chain.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const STATE = preload("res://systems/map_state.gd")
const CHILD = preload("res://systems/story_event_entry.gd")
const VILLAGE = preload("res://systems/village_rumor_entry.gd")
const VILLAGE_BEATS = preload("res://systems/village_rumor_beats.gd")
const COMMANDER = preload("res://systems/knight_commander_entry.gd")
const COMMANDER_BEATS = preload("res://systems/knight_commander_beats.gd")
const HUNTER = preload("res://systems/monster_hunter_entry.gd")
const HUNTER_BEATS = preload("res://systems/monster_hunter_beats.gd")
const CULTIST = preload("res://systems/cultist_rumor_entry.gd")
const CULTIST_BEATS = preload("res://systems/cultist_rumor_beats.gd")
const ALTAR = preload("res://systems/cultist_altar_entry.gd")
const PORTAL = preload("res://systems/ritual_portal_entry.gd")
const PORTAL_ENEMIES = preload("res://systems/ritual_portal_enemies.gd")
const HUNT = preload("res://systems/monster_king_hunt_entry.gd")
const HUNT_BEATS = preload("res://systems/monster_king_hunt_beats.gd")

var passed: int = 0
var failed: int = 0
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-chain: ",description)
	else:
		failed += 1
		printerr("FAIL p4-chain: ",description)

func clear_save(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func until_ready(condition: Callable, max_ms: int=17000) -> bool:
	var start: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<max_ms:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())

func ui_button(map: Control, caption: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for child in map.overlay.get_children():
		if child is Button and child.visible and child.text==caption: return child
	return null

func is_deck(map: Control) -> bool:
	return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("battle_deck.gd")

func is_unseen(session: Node, event_id: String) -> bool:
	return session.get_story_event(event_id).status=="unseen" and not session.event_flag_is_set("event:%s:seen" % event_id)

func fresh_world(session: Node, tag: String) -> void:
	var path: String="user://p4_full_chain_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	clear_save(path)
	session.save_file_path=path
	session.start_new_world()
	# Child rescue is unavailable until lap 1; start this synthetic source-
	# story branch fixture from the genuine home-shuffled second board.
	session.world.lap_ready=true
	session.world.leave_home()
	# Story-only fixture: keep all quest flags genuine while unlocking the
	# new contamination story thresholds for this existing journey test.
	session.world.contamination = 80
	session.world.reveal_boss_at_threshold()  # match real save-reload migration at >=20
	check(session.world.laps==1 and session.world.tiles.count("graveyard")==1,
		tag+": first home exit unlocks cemetery without pre-filling story flags")
	var ids: Array=[CHILD.EVENT_ID,VILLAGE.RESCUED_ID,VILLAGE.ABANDONED_ID,COMMANDER.EVENT_ID,HUNTER.EVENT_ID,CULTIST.EVENT_ID,ALTAR.EVENT_ID,PORTAL.EVENT_ID,HUNT.EVENT_ID]
	check(ids.all(func(id): return is_unseen(session,str(id))),tag+": every source story begins genuinely unseen, zero prefilled completions")
	check(session.world.event_flags.is_empty() and session.encounter.is_empty() and session.world.active_encounter.is_empty(),tag+": no quest/battle flags fabricated at start")
	check(session.save_world(),tag+": fresh game saved in isolated user:// file")

func prepare_dice_target(session: Node, kind: String, label: String) -> int:
	var world=session.world
	# Isolated fixture only: put the hero at the house between story legs,
	# preserving *every* receipt and battle/corpse history. The actual die,
	# save and production on-landing dispatcher are never short-circuited.
	world.position=STATE.HOME
	var candidate: int=-1
	var dice=RandomNumberGenerator.new()
	for seed_number in range(1,400):
		dice.seed=seed_number
		var target: int=STATE.HOME+dice.randi_range(1,6)
		if target not in [STATE.HOME,STATE.BOSS_TILE_INDEX] and world.tiles[target]!="home":
			world.rng.seed=seed_number
			candidate=target
			break
	if candidate<0: return -1
	var source_index: int=world.tiles.find(kind)
	# World tree and altar are intentionally absent from this progression
	# stage; their story branches are still reachable through event tiles.
	if source_index<0 and kind in ["unknown","altar"]:
		source_index=world.tiles.find("event")
	if source_index<0: return -1
	if source_index!=candidate:
		var old_kind: String=str(world.tiles[candidate])
		world.tiles[candidate]=str(world.tiles[source_index])
		world.tiles[source_index]=old_kind
	check(world.tiles.size()==24 and world.tiles[0]=="fortune-teller-camp" and world.tiles[8]=="village" and world.tiles[STATE.HOME]=="home",label+": all fixed map anchor tiles preserved")
	return candidate

func arrive(session: Node, kind: String, label: String, expected_first_button: String="계속") -> Dictionary:
	var world=session.world
	var destination: int=prepare_dice_target(session,kind,label)
	check(destination>=0,label+": source tile exists for test-only dice approach")
	if destination<0: return {}
	check(session.save_world(),label+": original world with next encounter tile persisted")
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	var before_serial: int=world.move_serial
	await map.roll_move()
	check(world.position==destination and world.move_serial==before_serial+1 and world.pending_move.is_empty(),label+": real die moves from house to required story location exactly once")
	check(ui_button(map,expected_first_button)!=null,label+": production map opens source event with \""+expected_first_button+"\"")
	return {"map":map,"destination":destination}

func close_and_reload(session: Node, map: Control, label: String) -> void:
	for i in range(4): await process_frame
	map.queue_free()
	await process_frame
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==before,label+": full-world JSON restart retains all actual story receipts/roster/rewards")

func finish_plain_event(session: Node, map: Control, count: int, event_id: String, label: String) -> bool:
	check(session.get_story_event(event_id).status=="seen",label+": first scene recorded as seen rather than complete")
	for beat in range(count):
		var caption: String="마치기" if beat==count-1 else "계속"
		var next: Button=ui_button(map,caption)
		if next==null:
			check(false,label+": missing original \""+caption+"\" at beat %d" % beat)
			return false
		check(session.get_story_event(event_id).status=="seen",label+": beat %d does not complete before final button" % beat)
		next.pressed.emit()
		await process_frame
	check(session.get_story_event(event_id).status=="complete" and session.event_flag_is_set("event:%s:complete" % event_id),label+": last original Finish saves one completed event")
	return true

func battle_checkpoint(battle: Control, victor: String, label: String) -> void:
	# Only the isolated checkpoint's combatant stats are amplified; actual
	# dice, attack order, victory/loss resolution and save path remain real.
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
	check(battle.session.save_world(),label+": real battle checkpoint saved with deterministic fixture combatants")

func fight_real(session: Node, map: Control, story_id: String, victor: String, label: String) -> bool:
	check(is_deck(map),label+": actual 1-4 owned-unit selection displayed")
	if not is_deck(map): return false
	var deck: Control=map.overlay
	var ids: Array=[str(session.world.roster[0].id)]
	# Portal's four hero-led opponents require the two original owned units
	# for deterministic test victory, as proven by the P4-02C battle fixture.
	if story_id==PORTAL.EVENT_ID and victor=="ally":
		ids.append(str(session.world.roster[1].id))
	for id in ids: deck.toggle_unit(str(id))
	check(deck.selected_ids.size()==ids.size() and not deck.confirm_button.disabled,label+": player selects truly owned monster cards")
	deck.confirm_button.pressed.emit()
	var started: bool=await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.rules.units.is_empty(),18000)
	check(started,label+": real embedded battlefield starts only after deck confirm")
	if not started: return false
	var battle: Control=map.embedded_battle
	check(session.encounter.get("event_id","")==story_id,label+": combat persisted with correct source story context")
	if story_id==PORTAL.EVENT_ID:
		var slugs: Array=[]
		for enemy in session.encounter.enemies: slugs.append(str(enemy.slug))
		check(PORTAL_ENEMIES.valid(session.world.definitions,slugs),label+": original four distinct hero-led ritual defenders spawned")
	else:
		check(session.encounter.enemies.size()==1 and str(session.encounter.enemies[0].slug)=="ghoul",label+": original graveyard ghoul spawned")
	battle_checkpoint(battle,victor,label)
	# Since the new battle introduction, real users see the original
	# full-unit brand chart once after the final summon. Natural story
	# tests must acknowledge it before awaiting the first roll.
	check(await until_ready(func(): return not battle.entry_summon_active,18000),
		label+": every ally has finished its entry animation")
	check(is_instance_valid(battle.brand_reference) and battle.entry_brand_auto_open,
		label+": mandatory first brand reference is visible")
	if is_instance_valid(battle.brand_reference):
		battle.brand_reference.close()
		check(await until_ready(func(): return not is_instance_valid(battle.brand_reference),13000),
			label+": first brand reference dismissed before combat starts")
	var rounds: int=0
	while battle.rules.winner().is_empty() and rounds<9:
		rounds+=1
		await battle.roll_round()
	check(battle.rules.winner()==victor,label+": actual die/attack queue produces %s in %d round(s)" % [victor,rounds])
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty() and session.world.pending_reward.is_empty(),label+": story combat clears checkpoint without ordinary corpse reward")
	battle.map_return.pressed.emit()
	var result_button: String="부활 확인" if story_id==PORTAL.EVENT_ID else "맵으로"
	var returned: bool=await until_ready(func(): return map.embedded_battle==null and not map.battle_returning and ui_button(map,result_button)!=null,21000)
	check(returned,label+": map uses actual original \""+result_button+"\" result modal")
	return returned

func graveyard_rescue(session: Node, label: String) -> bool:
	var a: Dictionary=await arrive(session,"graveyard",label+":child")
	if a.is_empty(): return false
	var map: Control=a.map
	for i in range(3):
		var next: Button=ui_button(map,"계속")
		if next==null:
			check(false,label+":child missing beat %d" % i)
			return false
		next.pressed.emit()
		await process_frame
	check(ui_button(map,"아이를 구한다")!=null and ui_button(map,"지나친다")!=null,label+":child original two branches displayed")
	ui_button(map,"아이를 구한다").pressed.emit()
	check(session.get_story_event(CHILD.EVENT_ID).choice=="protect_child" and session.get_story_event(CHILD.EVENT_ID).status=="active",label+":child commits rescue intent without false success")
	if not await fight_real(session,map,CHILD.EVENT_ID,"ally",label+":child"): return false
	check(session.story_battle_result_pending(CHILD.EVENT_ID) and not session.event_flag_is_set("event:graveyard_child_ambush_01:abandoned"),label+":child victory awaits user result acknowledgement")
	for i in range(3): await process_frame
	ui_button(map,"맵으로").pressed.emit()
	check(session.get_story_event(CHILD.EVENT_ID).status=="complete" and session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),label+":child actual result acknowledgement records saved rescue")
	check(not session.event_flag_is_set(COMMANDER.QUEST_ACTIVE_FLAG),label+":child victory alone cannot skip first village rumor")
	await close_and_reload(session,map,label+":child")
	return true

func abandoned_branch(session: Node) -> void:
	var label: String="abandoned"
	fresh_world(session,label)
	var a: Dictionary=await arrive(session,"graveyard",label+":child")
	if a.is_empty(): return
	var map: Control=a.map
	for i in range(3):
		var btn: Button=ui_button(map,"계속")
		if btn==null: return
		btn.pressed.emit()
		await process_frame
	check(ui_button(map,"지나친다")!=null,label+":child original leave button")
	ui_button(map,"지나친다").pressed.emit()
	var gone: bool=await until_ready(func(): return session.get_story_event(CHILD.EVENT_ID).status=="complete" and not is_instance_valid(map.overlay),14000)
	check(gone and session.event_flag_is_set("event:graveyard_child_ambush_01:abandoned"),label+":leave completes child without battle/ghoul reward")
	check(not session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),label+":leave never invents rescue receipt")
	await close_and_reload(session,map,label+":child")
	a=await arrive(session,"event",label+":village")
	if a.is_empty(): return
	map=a.map
	check(VILLAGE.eligible_event_id(session,session.world.position)==VILLAGE.ABANDONED_ID,label+":real map picks abandoned-specific source rumor")
	if not await finish_plain_event(session,map,VILLAGE_BEATS.count(VILLAGE.ABANDONED_ID),VILLAGE.ABANDONED_ID,label+":village"): return
	check(not COMMANDER.can_enter(session,session.world.position),label+":commander correctly locked after abandoning child")
	check(is_unseen(session,COMMANDER.EVENT_ID) and is_unseen(session,HUNTER.EVENT_ID) and is_unseen(session,CULTIST.EVENT_ID),label+":no fake rescue-only downstream story receipts")
	check(not session.event_flag_is_set(PORTAL.HUNT_FLAG) and not session.event_flag_is_set(PORTAL.REVIVED_FLAG),label+":abandoned rumor cannot silently revive king")
	await close_and_reload(session,map,label+":village")

func rescue_and_king(session: Node, victor: String) -> void:
	var label: String="weak" if victor=="ally" else "full"
	fresh_world(session,label)
	if not await graveyard_rescue(session,label): return

	var a: Dictionary=await arrive(session,"event",label+":rescued-village")
	if a.is_empty(): return
	var map: Control=a.map
	check(VILLAGE.eligible_event_id(session,session.world.position)==VILLAGE.RESCUED_ID,label+":source rescue rumor is selected by genuine child history")
	if not await finish_plain_event(session,map,VILLAGE_BEATS.count(VILLAGE.RESCUED_ID),VILLAGE.RESCUED_ID,label+":rescued-village"): return
	check(not session.event_flag_is_set(COMMANDER.QUEST_ACTIVE_FLAG),label+":village gossip alone grants no hunter quest")
	await close_and_reload(session,map,label+":rescued-village")

	a=await arrive(session,"event",label+":commander")
	if a.is_empty(): return
	map=a.map
	if not await finish_plain_event(session,map,COMMANDER_BEATS.count(),COMMANDER.EVENT_ID,label+":commander"): return
	check(session.event_flag_is_set(COMMANDER.QUEST_ACTIVE_FLAG) and session.event_flag_is_set(COMMANDER.RECOGNIZED_FLAG),label+":real commander authorizes monster-hunter investigation")
	await close_and_reload(session,map,label+":commander")

	a=await arrive(session,"unknown",label+":hunter")
	if a.is_empty(): return
	map=a.map
	if not await finish_plain_event(session,map,HUNTER_BEATS.count(),HUNTER.EVENT_ID,label+":hunter"): return
	check(session.event_flag_is_set(HUNTER.CULTIST_CLUE_FLAG) and session.event_flag_is_set(HUNTER.QUEST_COMPLETE_FLAG) and not session.event_flag_is_set(HUNTER.QUEST_ACTIVE_FLAG),label+":real hunter resolves investigation and discovers human involvement")
	await close_and_reload(session,map,label+":hunter")

	a=await arrive(session,"event",label+":cultist-rumor")
	if a.is_empty(): return
	map=a.map
	if not await finish_plain_event(session,map,CULTIST_BEATS.count(),CULTIST.EVENT_ID,label+":cultist-rumor"): return
	check(session.event_flag_is_set(CULTIST.TRACKING_FLAG) and session.event_flag_is_set(CULTIST.COMPLETE_FLAG),label+":real six-beat cultist rumor activates altar tracking")
	await close_and_reload(session,map,label+":cultist-rumor")

	a=await arrive(session,"altar",label+":altar")
	if a.is_empty(): return
	map=a.map
	for i in range(2):
		var next: Button=ui_button(map,"계속")
		if next==null:
			check(false,label+":altar missing Continue at beat %d" % i)
			return
		next.pressed.emit()
		await process_frame
	check(ui_button(map,"지나간다")!=null and ui_button(map,"싸운다")!=null,label+":altar two source choices genuinely unlocked")
	ui_button(map,"지나간다").pressed.emit()
	check(session.get_story_event(ALTAR.EVENT_ID).choice=="pass" and session.get_story_event(ALTAR.EVENT_ID).status=="active",label+":altar pass stored without premature tracking handoff")
	var altar_finish: Button=ui_button(map,"마치기")
	check(altar_finish!=null,label+":altar genuine aftermath requires explicit Finish")
	if altar_finish==null: return
	altar_finish.pressed.emit()
	check(ALTAR.completed(session) and session.event_flag_is_set(ALTAR.RITUAL_TRACKING_FLAG),label+":altar source Finish unlocks forest portal")
	check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG),label+":altar completion cannot itself revive king")
	await close_and_reload(session,map,label+":altar")

	a=await arrive(session,"forest",label+":portal")
	if a.is_empty(): return
	map=a.map
	for i in range(4):
		var next: Button=ui_button(map,"계속")
		if next==null:
			check(false,label+":portal missing Continue at beat %d" % i)
			return
		next.pressed.emit()
		await process_frame
		check(PORTAL.current_beat(session)==i+1,label+":portal sequential scene %d saved by original Continue" % (i+1))
	check(ui_button(map,"저지한다")!=null,label+":portal canonical fifth-beat Intervene offered")
	ui_button(map,"저지한다").pressed.emit()
	check(session.get_story_event(PORTAL.EVENT_ID).choice=="intervene" and not session.event_flag_is_set(PORTAL.HUNT_FLAG),label+":portal decision saved with no premature resurrection")
	var deck_ready: bool=await until_ready(func(): return is_deck(map),8000)
	check(deck_ready,label+":portal real deck appears after summoning delay")
	if not deck_ready: return
	if not await fight_real(session,map,PORTAL.EVENT_ID,victor,label+":portal"): return
	check(session.story_battle_result_pending(PORTAL.EVENT_ID) and not session.event_flag_is_set(PORTAL.REVIVED_FLAG),label+":portal outcome awaits result receipt; king still not revived")
	# Reload the real result UI before pressing the source confirmation.
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame
	session.reload_world()
	map=MAP.instantiate()
	root.add_child(map)
	var pending_ready: bool=await until_ready(func(): return ui_button(map,"부활 확인")!=null,12000)
	check(pending_ready,label+":portal result UI genuinely resumes from saved JSON")
	if not pending_ready: return
	ui_button(map,"부활 확인").pressed.emit()
	var aftermath: bool=await until_ready(func(): return ui_button(map,"마치기")!=null,12000)
	check(aftermath and PORTAL.aftermath_ready(session,session.world.position),label+":portal correct acknowledged ending visible before actual Finish")
	check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG),label+":portal result acknowledgment does not prematurely commit revival")
	if not aftermath: return
	ui_button(map,"마치기").pressed.emit()
	var won: bool=victor=="ally"
	check(PORTAL.completed(session) and session.event_flag_is_set(PORTAL.WEAKENED_FLAG)==won and session.event_flag_is_set(PORTAL.FULL_REVIVAL_FLAG)!=won,label+":portal actual Finish commits weakened win / full defeat")
	check(ALTAR.completed(session),label+":portal handoff does not erase historical completed altar receipt")
	var completed_world: Dictionary=session.world.snapshot().duplicate(true)
	check(ALTAR.finish(session,session.world.position) and session.world.snapshot()==completed_world,label+":repeating finished altar is read-only even after portal handoff")
	check(session.event_flag_is_set(PORTAL.HUNT_FLAG) and not session.event_flag_is_set(PORTAL.TRACKING_FLAG),label+":portal confirmation atomically transfers tracking quest to king hunt")
	await close_and_reload(session,map,label+":portal")

	a=await arrive(session,"unknown",label+":king-hunt")
	if a.is_empty(): return
	map=a.map
	check(HUNT.revival_mode(session)==("weakened" if won else "full"),label+":real king-hunt scene reads source portal outcome")
	for beat in range(4):
		var next: Button=ui_button(map,"계속")
		if next==null:
			check(false,label+":king-hunt missing Continue at beat %d" % beat)
			return
		if beat==2:
			check(HUNT_BEATS.beat(2,HUNT.revival_mode(session)).dialogue==HUNT_BEATS.beat(2,"weakened" if won else "full").dialogue,label+":hunter original revival-specific dialogue visible")
		next.pressed.emit()
		await process_frame
	check(HUNT.completed(session) and not session.event_flag_is_set(HUNT.FINAL_SCENE_ACK_FLAG),label+":king-hunt reveals sealed ruins but final acknowledgment still open")
	var last: Button=ui_button(map,"마치기")
	check(last!=null,label+":fifth canonical source beat requires final Finish")
	if last==null: return
	last.pressed.emit()
	check(session.event_flag_is_set(HUNT.FINAL_SCENE_ACK_FLAG) and HUNT.completed(session),label+":king-hunt final acknowledgement persists and cannot restart")
	check(session.event_flag_is_set(HUNT.FINAL_BATTLE_FLAG) and session.event_flag_is_set(HUNT.SEALED_RUINS_FLAG),label+":final battle *quest* available; no invented actual king fight")
	check(PORTAL.completed(session) and ALTAR.completed(session) and session.get_story_event(CHILD.EVENT_ID).status=="complete",label+":entire eight-event predecessor history survives end of chain")
	check(session.world.pending_reward.is_empty() and session.encounter.is_empty(),label+":full chain leaves no pending battle/reward/duplicate treasure")
	await close_and_reload(session,map,label+":king-hunt")
	check(PORTAL.completed(session) and HUNT.completed(session) and session.event_flag_is_set(HUNT.FINAL_SCENE_ACK_FLAG),label+":complete rescue-to-king story survives final restart")

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var previous_path: String=session.save_file_path
	await rescue_and_king(session,"ally")
	await rescue_and_king(session,"enemy")
	await abandoned_branch(session)
	session.save_file_path=previous_path
	if created: session.queue_free()
	for path in paths: clear_save(path)
	check(paths.all(func(path): return not FileAccess.file_exists(path)),"all PID-isolated full-chain save files removed; normal player save not touched")
	print("P4_FULL_SOURCE_STORY_CHAIN: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
