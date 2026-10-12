extends SceneTree
## P4-02C: real Map die -> source five-scene portal -> hero-led four-enemy
## embedded battle -> outcome acknowledgement -> explicit weak/full revival
## -> saved first world-tree king-hunt scene (both independent outcomes).
## Disposable user:// save per scenario, with deterministic test-only battle
## combatants, and swaps of ordinary (non-anchor) tiles for die landings.
const MAP_SCENE = preload("res://map.tscn")
const SESSION_SCRIPT = preload("res://systems/run_session.gd")
const MAP_STATE = preload("res://systems/map_state.gd")
const RUMOR = preload("res://systems/cultist_rumor_entry.gd")
const ALTAR = preload("res://systems/cultist_altar_entry.gd")
const PORTAL = preload("res://systems/ritual_portal_entry.gd")
const PORTAL_BEATS = preload("res://systems/ritual_portal_beats.gd")
const PORTAL_ENEMIES = preload("res://systems/ritual_portal_enemies.gd")
const HUNT = preload("res://systems/monster_king_hunt_entry.gd")
const HUNT_BEATS = preload("res://systems/monster_king_hunt_beats.gd")

var passed: int = 0
var failed: int = 0
var files: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS p4-portal: ",label)
	else:
		failed+=1
		printerr("FAIL p4-portal: ",label)

func clear_save(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func until_ready(predicate: Callable, limit_ms: int=18000) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<limit_ms:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())

func button_in(map: Control, caption: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for child in map.overlay.get_children():
		if child is Button and child.visible and child.text==caption:
			return child
	return null

func has_deck(map: Control) -> bool:
	return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("battle_deck.gd")

func seed_next_tile(world, kind: String) -> int:
	# Keep all source anchor tiles and the genuine die path intact. Only the
	# intended test encounter tile is moved to the next rolled destination.
	world.position=MAP_STATE.HOME
	var generator=RandomNumberGenerator.new()
	var target: int=-1
	for seed_value in range(1,600):
		generator.seed=seed_value
		var at: int=(MAP_STATE.HOME+generator.randi_range(1,6))%24
		if at not in [0,8,MAP_STATE.HOME] and world.tiles[at]!=kind:
			world.rng.seed=seed_value
			target=at
			break
	if target<0: return -1
	var original: int=world.tiles.find(kind)
	if original<0: return -1
	if original!=target:
		var old: String=str(world.tiles[target])
		world.tiles[target]=kind
		world.tiles[original]=old
	return target

func prereq(session: Node, tag: String) -> Dictionary:
	var path: String="user://p4_portal_%d_%s.json" % [OS.get_process_id(),tag]
	files.append(path)
	clear_save(path)
	session.save_file_path=path
	session.start_new_world()
	var world=session.world
	# The preceding rumor is completed in this fixture, then the REAL altar
	# entry/three beats/pass/Finish commits the ritual-tracking prerequisite.
	world.story_events[RUMOR.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	world.event_flags[RUMOR.SEEN_FLAG]=true
	world.event_flags[RUMOR.COMPLETE_FLAG]=true
	world.event_flags[RUMOR.TRACKING_FLAG]=true
	# The altar no longer exists on the first map. The production ritual
	# may be discovered at a normal event tile after the cultist rumor.
	world.position=world.tiles.find("altar")
	if world.position<0: world.position=world.tiles.find("event")
	check(world.position>=0 and session.save_world(),tag+": prerequisite cultist rumor saved")
	var altar_at: int=world.position
	check(ALTAR.begin(session,altar_at),tag+": previous altar arrival saved through production state machine")
	check(ALTAR.advance(session,altar_at,0) and ALTAR.advance(session,altar_at,1),tag+": previous altar reveals real choice")
	check(ALTAR.choose(session,altar_at,2,"pass") and ALTAR.finish(session,altar_at),tag+": previous altar passes and commits legitimate portal unlock")
	check(ALTAR.completed(session) and session.event_flag_is_set(PORTAL.TRACKING_FLAG),tag+": source quest prerequisite verified")
	var target: int=seed_next_tile(world,"forest")
	check(target>=0,tag+": test-only forest landing prepared outside fixed tile anchors")
	if target<0: return {}
	check(session.save_world(),tag+": future portal landing persisted in isolated save")
	var map: Control=MAP_SCENE.instantiate()
	root.add_child(map)
	await process_frame
	var before_move: int=world.move_serial
	await map.roll_move()
	check(world.position==target and world.move_serial==before_move+1 and world.pending_move.is_empty(),tag+": real map die arrives at forest once")
	check(session.get_story_event(PORTAL.EVENT_ID).status=="seen" and session.event_flag_is_set(PORTAL.SEEN_FLAG),tag+": first portal arrival discovers exact source event")
	check(button_in(map,"계속")!=null,tag+": genuine first ruined portal scene and Continue displayed")
	return {"map":map,"tile":target}

func advance_five_scenes(session: Node, map: Control, label: String) -> bool:
	for beat in range(4):
		var next: Button=button_in(map,"계속")
		if next==null:
			check(false,label+": missing Continue at canonical portal beat %d" % beat)
			return false
		next.pressed.emit()
		await process_frame
		check(PORTAL.current_beat(session)==beat+1 and session.event_flag_is_set(PORTAL.progress_flag(beat+1)),label+": source story beat %d committed by actual scene button" % (beat+1))
	var ready: bool=button_in(map,"저지한다")!=null
	check(ready and PORTAL_BEATS.beat(4).id=="intervene",label+": fifth portal beat provides original explicit Intervene button")
	check(session.get_story_event(PORTAL.EVENT_ID).choice.is_empty() and not session.event_flag_is_set(PORTAL.REVIVED_FLAG),label+": simply viewing omen cannot launch king revival")
	return ready

func deterministic_battle(battle: Control, victor: String, label: String) -> void:
	# Uses normal battle dice/actions/checkpoints; only this disposable
	# encounter's strengths are exaggerated for a reproducible outcome.
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
	check(battle.session.save_world(),label+": only test units' deterministic checkpoint saved through original session")

func actual_story_battle(session: Node, map: Control, victor: String, label: String) -> bool:
	check(has_deck(map),label+": fifth beat opens the standard owned-unit deck")
	if not has_deck(map): return false
	var deck: Control=map.overlay
	var ids: Array=[str(session.world.roster[0].id)] if victor=="enemy" else [str(session.world.roster[0].id),str(session.world.roster[1].id)]
	for id in ids: deck.toggle_unit(str(id))
	check(deck.selected_ids.size()==ids.size() and not deck.confirm_button.disabled,label+": actual owned cards selected for portal battle")
	deck.confirm_button.pressed.emit()
	var ready: bool=await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.rules.units.is_empty(),14000)
	check(ready,label+": real embedded battlefield launches from selected roster")
	if not ready: return false
	var battle: Control=map.embedded_battle
	check(session.encounter.get("event_id","")==PORTAL.EVENT_ID and session.encounter.type=="event-ritual-portal",label+": genuine saved portal encounter and event context")
	var slugs: Array=[]
	for enemy in session.encounter.enemies: slugs.append(str(enemy.slug))
	check(PORTAL_ENEMIES.valid(session.world.definitions,slugs),label+": exactly four distinct original hero-led source enemies")
	check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG) and not session.event_flag_is_set(PORTAL.HUNT_FLAG),label+": entering fight does not revive king or unlock hunt")
	deterministic_battle(battle,victor,label)
	var rounds: int=0
	while battle.rules.winner().is_empty() and rounds<9:
		rounds+=1
		await battle.roll_round()
	check(battle.rules.winner()==victor,label+": real dice/actions settle %s in %d round(s)" % [victor,rounds])
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty(),label+": portal outcome clears both battle checkpoints")
	check(session.world.pending_reward.is_empty(),label+": event battle cannot issue normal soul capture")
	check(not battle.map_return.disabled,label+": battle end unlocks return control")
	battle.map_return.pressed.emit()
	var shown: bool=await until_ready(func(): return map.embedded_battle==null and not map.battle_returning and button_in(map,"부활 확인")!=null,21000)
	check(shown,label+": actual original portal battle result UI opens on map")
	check(button_in(map,"다시 도전")==null,label+": portal defeat is final, with no uncanonical retry option")
	return shown

func enter_epilogue(session: Node, map: Control, result: String, label: String) -> Dictionary:
	check(session.story_battle_result_pending(PORTAL.EVENT_ID),label+": battle outcome awaits explicit result confirmation")
	check(session.get_story_event(PORTAL.EVENT_ID).status=="active" and session.get_story_event(PORTAL.EVENT_ID).battle_result==result,label+": exact battle result saved without premature quest completion")
	check(not PORTAL.aftermath_ready(session,session.world.position) and not session.event_flag_is_set(PORTAL.REVIVED_FLAG),label+": pending result cannot bypass epilogue or revive king")
	# Reload before confirming to verify durable pending result and real
	# Map._ready recovery rather than merely reading a saved flag.
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==before,label+": interrupted result screen preserves full JSON world")
	map=MAP_SCENE.instantiate()
	root.add_child(map)
	var restored: bool=await until_ready(func(): return button_in(map,"부활 확인")!=null,12000)
	check(restored,label+": original result view reopens on Map after process-style restart")
	if not restored: return {}
	button_in(map,"부활 확인").pressed.emit()
	check(not session.story_battle_result_pending(PORTAL.EVENT_ID),label+": original result button consumes confirmation exactly once")
	var ready: bool=await until_ready(func(): return button_in(map,"마치기")!=null,12000)
	check(ready and PORTAL.aftermath_ready(session,session.world.position),label+": correct canonical weak/full revival epilogue appears")
	check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG) and not session.event_flag_is_set(PORTAL.HUNT_FLAG),label+": displayed ending still awaits distinct explicit Finish")
	# The caller needs the new map instance, not the freed map.
	if ready: return {"map":map,"ready":true}
	return {}

func complete_revive(session: Node, map: Control, won: bool, label: String) -> bool:
	var receipts: Array=session.world.reward_receipts.duplicate(true)
	var original_casualties: int=session.world.graveyard_corpses.size()
	var finish: Button=button_in(map,"마치기")
	check(finish!=null,label+": final resurrection acknowledgement has original Finish button")
	if finish==null: return false
	finish.pressed.emit()
	var event: Dictionary=session.get_story_event(PORTAL.EVENT_ID)
	check(PORTAL.completed(session) and event.status=="complete" and event.battle_result==("won" if won else "lost"),label+": revival completes only at deliberate Finish")
	check(session.event_flag_is_set(PORTAL.REVIVED_FLAG) and session.event_flag_is_set(PORTAL.HUNT_FLAG),label+": king revival and hunt quest activated atomically")
	check(session.event_flag_is_set(PORTAL.WEAKENED_FLAG)==won and session.event_flag_is_set(PORTAL.FULL_REVIVAL_FLAG)!=won,label+": weakened on win, full on defeat, mutually exclusive")
	check(not session.event_flag_is_set(PORTAL.TRACKING_FLAG) and session.event_flag_is_set(PORTAL.TRACKING_COMPLETE_FLAG),label+": previous ritual tracking completed and deactivated")
	check(session.world.reward_receipts==receipts and session.world.graveyard_corpses.size()==original_casualties,label+": story completion neither resurrects the dead nor grants phantom rewards")
	check(not session.event_flag_is_set(PORTAL.FINAL_BATTLE_FLAG) and not session.event_flag_is_set(PORTAL.HUNT_EVENT_COMPLETE_FLAG),label+": final king battle and hunt completion remain locked")
	var committed: Dictionary=session.world.snapshot().duplicate(true)
	check(PORTAL.finish(session,session.world.position) and session.world.snapshot()==committed,label+": duplicate Finish is read-only and cannot grant rewards")
	for i in range(4): await process_frame
	map.close_overlay()
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==committed and PORTAL.completed(session),label+": final weakened/full revival survives full restart unchanged")
	return true

func follow_king_hunt(session: Node, tag: String, weak: bool) -> void:
	var world=session.world
	var tree: int=seed_next_tile(world,"unknown")
	check(tree>=0,tag+": source world-tree tile prepared for real next die")
	if tree<0: return
	check(session.save_world(),tag+": hunter approach saved after completed portal")
	var map: Control=MAP_SCENE.instantiate()
	root.add_child(map)
	await process_frame
	var before_move: int=world.move_serial
	await map.roll_move()
	check(world.position==tree and world.move_serial==before_move+1 and world.pending_move.is_empty(),tag+": real map die opens follow-up world tree")
	check(session.get_story_event(HUNT.EVENT_ID).status=="seen" and session.event_flag_is_set(HUNT.SEEN_FLAG),tag+": actual hunter first discovery committed only after portal ending")
	check(HUNT.revival_mode(session)==("weakened" if weak else "full"),tag+": hunter dialogue reads prior battle outcome, not an invented mode")
	check(button_in(map,"계속")!=null,tag+": original king-hunt investigation panel is visible")
	check(not session.event_flag_is_set(HUNT.FINAL_BATTLE_FLAG) and not session.event_flag_is_set(HUNT.HUNT_COMPLETE_FLAG),tag+": following the king does not start unimplemented final fight")
	for i in range(2):
		var next: Button=button_in(map,"계속")
		if next==null: break
		next.pressed.emit()
		await process_frame
	check(HUNT.current_beat(session)==2 and HUNT_BEATS.beat(2,HUNT.revival_mode(session)).dialogue==HUNT_BEATS.beat(2,"weakened" if weak else "full").dialogue,tag+": original hunter weak/full branch dialogue saved at third beat")
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame
	var copy: Dictionary=session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==copy and HUNT.current_beat(session)==2,tag+": revived king branch and hunter scene survive one more full reload")

func scenario(session: Node, victor: String) -> void:
	var tag: String="win" if victor=="ally" else "loss"
	var entry: Dictionary=await prereq(session,tag)
	if entry.is_empty(): return
	var map: Control=entry.map
	if not await advance_five_scenes(session,map,tag): return
	button_in(map,"저지한다").pressed.emit()
	check(session.get_story_event(PORTAL.EVENT_ID).choice=="intervene" and session.get_story_event(PORTAL.EVENT_ID).status=="active",tag+": explicit Intervene button saves decision without starting battle")
	check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG),tag+": selecting Intervene is not king revival")
	var deck: bool=await until_ready(func(): return has_deck(map),8000)
	check(deck,tag+": omen reveal opens original deck only after decision")
	if not deck: return
	if not await actual_story_battle(session,map,victor,tag): return
	var aftermath: Dictionary=await enter_epilogue(session,map,"won" if victor=="ally" else "lost",tag)
	if aftermath.is_empty(): return
	map=aftermath.map
	if not await complete_revive(session,map,victor=="ally",tag): return
	await follow_king_hunt(session,tag,victor=="ally")

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION_SCRIPT.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	await scenario(session,"ally")
	await scenario(session,"enemy")
	session.save_file_path=old_path
	if created: session.queue_free()
	for path in files: clear_save(path)
	check(files.all(func(path): return not FileAccess.file_exists(path)),"all disposable saves removed, never wrote player's normal progress")
	print("P4_RITUAL_PORTAL_LIVE_INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
