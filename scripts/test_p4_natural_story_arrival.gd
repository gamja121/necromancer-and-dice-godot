extends SceneTree
## P4-02E-A: seeded POST-FIRST-LAP fixture (graveyard is absent from lap 0),
## then genuine map dice -> real child rescue -> naturally reached village.
## The fixture uses the real leave_home() shuffle once, but skips acting out
## the first uneventful lap; a separate natural-home test plays lap zero.
## No later tile permutations, teleports, forced dice or quest flags.
## Seed selection finds a naturally generated lap-1 graveyard next to home.
## Incidental location/deck panels are dismissed; generated treasure is
## claimed through its original UI if encountered. Windows visual/audio
## acceptance and all-stage unshortened whole-story play remain separate.
const MAP=preload("res://map.tscn")
const SESSION=preload("res://systems/run_session.gd")
const STATE=preload("res://systems/map_state.gd")
const CHILD=preload("res://systems/story_event_entry.gd")
const VILLAGE=preload("res://systems/village_rumor_entry.gd")
const VILLAGE_BEATS=preload("res://systems/village_rumor_beats.gd")

var passed: int=0
var failed: int=0
var path: String=""

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS p4-natural: ",label)
	else:
		failed+=1
		printerr("FAIL p4-natural: ",label)

func clear_path() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func until_ready(predicate: Callable, limit_ms: int=16000) -> bool:
	var start: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<limit_ms:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())

func button_at(map: Control, label: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for node in map.overlay.get_children():
		if node is Button and node.visible and node.text==label: return node
	return null

## A story press reveals text first; the next press advances its saved beat.
func press_story_action(action: Button) -> void:
	if action == null: return
	var panel = action.get_parent()
	var typewriter = panel.get_node_or_null("StoryTypewriter")
	if typewriter != null and typewriter.is_revealing():
		action.pressed.emit()
	action.pressed.emit()

func is_deck(map: Control) -> bool:
	return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("battle_deck.gd")

func real_generated_seed(world) -> int:
	var preview=RandomNumberGenerator.new()
	for seed in range(1,1600):
		var trial=STATE.new(world.definitions,seed,world.patrol_plan)
		trial.lap_ready=true
		trial.leave_home()
		preview.state=trial.rng.state
		var face: int=preview.randi_range(1,6)
		var destination: int=STATE.HOME+face
		if trial.tiles[destination]=="graveyard":
			# Return the seed, NOT a modified tile array or a forced die.
			return seed
	return -1

func create_run(session: Node) -> int:
	path="user://p4_natural_arrival_%d.json" % OS.get_process_id()
	clear_path()
	session.save_file_path=path
	session.start_new_world()
	var seed: int=real_generated_seed(session.world)
	check(seed>0,"found untouched, naturally shuffled second map with a genuine graveyard roll")
	if seed<=0: return -1
	session.world=STATE.new(session.world.definitions,seed,session.world.patrol_plan)
	var world=session.world
	check(world.laps==0 and world.tiles.count("graveyard")==0,"new expedition starts without the graveyard")
	# Test fixture: begin at lap-1 map after a genuine leave_home() shuffle;
	# the separate natural-home integration exercises the actual 1st lap.
	world.lap_ready=true
	world.leave_home()
	# Legacy travel/UI regression tests start with story gates unlocked; the
	# dedicated threshold test checks actual minimum contamination boundaries.
	world.contamination = 80
	world.reveal_boss_at_threshold()  # match real save-reload migration at >=20
	# The fixture forces pollution upward without the real prayer/home action;
	# mirror both automatic corruption thresholds before saving so reload
	# does not legitimately migrate and change the test's expected board.
	world.reveal_swamps_for_contamination()
	check(world.laps==1 and world.tiles.count("graveyard")==1 and world.map_serial==2,
		"one original first-lap exit unlocks one graveyard before the story")
	check(world.position==STATE.HOME and world.tiles.size()==24 and world.tiles[8]=="village" and world.tiles[15]=="home", "second 24-tile board has unchanged canonical fixed anchors")
	check(world.story_events.is_empty() and world.event_flags.is_empty() and world.move_serial==0,"fresh run has no manufactured story flags/movement")
	check(session.save_world(),"native generated seeded board persisted without permutation")
	return seed

func actual_graveyard_rescue(session: Node) -> bool:
	var world=session.world
	var first_tiles: Array=world.tiles.duplicate()
	var first_position: int=world.position
	var predictor=RandomNumberGenerator.new()
	predictor.state=world.rng.state
	var face: int=predictor.randi_range(1,6)
	var destination: int=first_position+face
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	check(not is_instance_valid(map.overlay),"fresh normal map starts without story overlay")
	await map.roll_move()
	check(world.tiles==first_tiles and world.map_serial==2,"first lap-1 die does not swap/rebuild generated tiles")
	check(world.position==destination and world.previous_map_roll==face and world.move_serial==1,"true source RNG face moves along genuine map path to graveyard")
	check(world.pending_move.is_empty() and session.get_story_event(CHILD.EVENT_ID).status=="seen","first genuine landing commits child discovery once")
	check(button_at(map,"계속")!=null,"graveyard child original UI presents scene 1")
	for i in range(3):
		var next: Button=button_at(map,"계속")
		if next==null:
			check(false,"graveyard scene %d missing real Continue" % i)
			return false
		press_story_action(next)
		await process_frame
	check(button_at(map,"아이를 구한다")!=null and button_at(map,"지나친다")!=null,"all four scenes allow canonical genuine rescue/leave choice")
	press_story_action(button_at(map,"아이를 구한다"))
	check(session.get_story_event(CHILD.EVENT_ID).choice=="protect_child" and session.get_story_event(CHILD.EVENT_ID).status=="active","rescue choice recorded without victory forgery")
	check(is_deck(map),"real deck UI follows original rescue choice")
	if not is_deck(map): return false
	var deck: Control=map.overlay
	for unit in world.roster: deck.toggle_unit(str(unit.id))
	check(deck.selected_ids.size()==2 and not deck.confirm_button.disabled,"both original monsters selected through deck cards")
	deck.confirm_button.pressed.emit()
	var started: bool=await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.rules.units.is_empty())
	check(started,"genuine battlefield opens from confirmed deck")
	if not started: return false
	var battle: Control=map.embedded_battle
	for unit in battle.rules.units:
		unit.passive=""
		unit.brands=[]
		unit.poison=[]
		unit.frozen=false
		unit.undying_used=false
		unit.shields=0
		unit.curse={}
		unit.bless={}
		var strong: bool=unit.team=="ally"
		unit.base_attack=999 if strong else 0
		unit.attack=unit.base_attack
		unit.base_speed=999 if strong else 0
		unit.speed=unit.base_speed
		if not strong: unit.hp=1
	battle.rules.refresh()
	battle.session.encounter.checkpoint=battle.rules.snapshot()
	battle.session.world.active_encounter=battle.session.encounter.duplicate(true)
	check(battle.session.save_world(),"test-only combat strength checkpoint saved; map RNG/tile/position untouched")
	# A fresh battlefield intentionally opens the real brand chart after
	# the last monster arrives. A player must close it before the first die
	# can roll; do not hang scripted natural-story tests on that UI signal.
	check(await until_ready(func(): return not battle.entry_summon_active,18000),
		"final allied monster arrival finishes before the brand overview")
	check(is_instance_valid(battle.brand_reference) and battle.entry_brand_auto_open,
		"initial combat brand chart appears after the last summoned monster")
	if is_instance_valid(battle.brand_reference):
		battle.brand_reference.close()
		check(await until_ready(func(): return not is_instance_valid(battle.brand_reference),13000),
			"player closes initial brand chart before real combat dice")

	var rounds: int=0
	while battle.rules.winner().is_empty() and rounds<8:
		rounds+=1
		await battle.roll_round()
	check(battle.rules.winner()=="ally","real dice/attack actions defeat the source ghoul")
	check(world.pending_reward.is_empty() and session.encounter.is_empty(),"source rescue battle creates no fake ordinary reward")
	battle.map_return.pressed.emit()
	var returned: bool=await until_ready(func(): return map.embedded_battle==null and button_at(map,"맵으로")!=null,20000)
	check(returned,"battle-to-map result UI returns without moving any tiles")
	if not returned: return false
	for i in range(3): await process_frame
	press_story_action(button_at(map,"맵으로"))
	check(session.get_story_event(CHILD.EVENT_ID).status=="complete" and session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"original acknowledgement commits authentic rescued-child receipt")
	check(world.tiles==first_tiles and world.map_serial==2 and world.position==destination,"genuine rescue victory never changes board or teleports hero")
	for i in range(4): await process_frame
	map.queue_free()
	await process_frame
	var saved: Dictionary=world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==saved,"natural graveyard combat and original tile order round-trip byte-equivalent world snapshot")
	return true

func incidental_overlay(session: Node, map: Control, label: String) -> bool:
	var world=session.world
	if not is_instance_valid(map.overlay): return true
	# A routine is a saved player choice, so closing its outer modal cannot
	# consume the visit: reload correctly reopens it. Use the real decline
	# control to finish this incidental event without collecting a reward.
	if world.pending_reward.get("kind","")=="routine":
		var decline: Button=map.overlay.find_child("RoutineDecline",true,false) as Button
		check(decline!=null and not decline.disabled,"incident "+label+": saved routine offers its original decline choice")
		if decline==null or decline.disabled: return false
		var rng_before: int=world.rng.state
		decline.pressed.emit()
		var resolved: bool=await until_ready(func(): return world.pending_reward.is_empty() and not is_instance_valid(map.overlay),10000)
		check(resolved,"incident "+label+": real routine decline consumes the saved visit before restart")
		check(world.rng.state==rng_before,"incident "+label+": declining the existing routine never rerolls the event")
		return resolved
	# Dismiss the actual ordinary discovery card before the next natural roll.
	var discovery_card:Control=map.find_child("EventDiscoveryCard",true,false) as Control
	if discovery_card!=null:
		var rng_before: int=world.rng.state
		discovery_card.dismiss()
		var revealed: bool=await until_ready(func(): return not is_instance_valid(map.overlay),2000)
		check(revealed and world.pending_reward.is_empty() and world.rng.state==rng_before,"incident "+label+": discovery dismissal does not change saved reward or RNG")
		return revealed
	# The game also allows closing an unconfirmed normal-encounter deck
	# without having chosen owned units: no battle result is granted.
	if is_deck(map):
		check(session.encounter.is_empty(),"incident "+label+": non-story deck didn't begin battle without confirmation")
		map.close_overlay()
		await process_frame
		return true
	if world.pending_reward.get("kind","")=="treasure":
		var ready: bool=await until_ready(func(): return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("treasure_reward.gd") and map.overlay.options.size()==3 and not map.overlay.busy,15000)
		check(ready,"incident "+label+": original 3-card treasure selection finishes chest animation")
		if not ready: return false
		# Prefer a consumable/non-unit offer so the normal inventory doesn't
		# require a separate overflow panel in this travel coverage scenario.
		var index: int=0
		for j in range(3):
			if str(world.pending_reward.offers[j].kind)!="unit":
				index=j
				break
		# Current treasure UI uses explicit choose -> claim confirmation.
		# A second card tap is idempotent and must not spend the reward.
		map.overlay.options[index].pressed.emit()
		check(int(world.pending_reward.get("selected",-1))==index and not map.overlay.confirm_button.disabled,
			"incident "+label+": selected offer enables the genuine claim confirmation")
		map.overlay.confirm_button.pressed.emit()
		var claimed: bool=await until_ready(func(): return world.pending_reward.is_empty() and not is_instance_valid(map.overlay),20000)
		check(claimed,"incident "+label+": natural chest claimed once through actual reward UI")
		return claimed
	if world.pending_reward.get("kind","")=="mimic":
		check(false,"incident "+label+": natural mimic requires separate combat/capture coverage")
		return false
	if world.tiles[world.position]=="home" and button_at(map,"나가기")!=null:
		var before_lap: int=world.laps
		var before_map: int=world.map_serial
		var lap_ready: bool=world.lap_ready
		press_story_action(button_at(map,"나가기"))
		var finished: bool=await until_ready(func(): return not map.moving and not is_instance_valid(map.overlay) and session.world.map_serial==before_map+1,20000)
		check(finished,"incident "+label+": natural house visit completes original stone reshuffle")
		check(world.laps==before_lap+(1 if lap_ready else 0),"incident "+label+": exact one new lap after real house crossing")
		return finished
	var exit: Button=button_at(map,"나가기")
	if exit==null: exit=button_at(map,"돌아가기")
	if exit!=null:
		press_story_action(exit)
		var removed: bool=await until_ready(func(): return not is_instance_valid(map.overlay),10000)
		check(removed,"incident "+label+": normal location allows actual player exit")
		return removed
	# No direct click available for a non-story panel, which can be dismissed
	# only through the existing map overlay cleanup (not a map teleport).
	map.close_overlay()
	await process_frame
	return true

func natural_village_rumor(session: Node) -> void:
	var world=session.world
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	var total_moves: int=0
	var natural_laps: int=0
	var initial_receipts: Array=world.reward_receipts.duplicate()
	var reached: bool=false
	# Random natural dice may pass the fixed village without landing on it
	# for several laps. After unlocking the graveyard later, allow enough
	# authentic (unforced) rolls rather than baking in the old seed's 30 limit.
	for turn in range(70):
		if is_instance_valid(map.overlay):
			check(false,"natural stage begins with an unhandled overlay")
			break
		var before: Dictionary=world.snapshot().duplicate(true)
		var dice=RandomNumberGenerator.new()
		dice.state=world.rng.state
		var expected_face: int=dice.randi_range(1,6)
		var expect_landing: int=world.position
		for step in range(expected_face):
			expect_landing=(expect_landing+1)%24
			if expect_landing==STATE.HOME: break
		await map.roll_move()
		total_moves+=1
		check(world.move_serial==int(before.move_serial)+1 and world.previous_map_roll==expected_face,"travel %d: native RNG roll %d increments one move" % [total_moves,expected_face])
		check(world.pending_move.is_empty() and world.map_serial==int(before.map_serial),"travel %d: original move commits without forced tile shuffle" % total_moves)
		check(world.tiles==before.tiles,"travel %d: entire ordinary 24-tile layout unmodified by move" % total_moves)
		check(world.position==expect_landing or world.tiles[expect_landing]=="warp","travel %d: arrival follows generated board or native warp" % total_moves)
		if session.get_story_event(VILLAGE.RESCUED_ID).status=="seen":
			check(world.tiles[world.position] in ["village","event"],"source rescued-child rumor arises only at natural village/event tile")
			check(button_at(map,"계속")!=null,"natural arrival opens actual saved-child village rumor UI")
			reached=true
			break
		if not await incidental_overlay(session,map,"travel-%d" % total_moves):
			break
		if world.map_serial!=int(before.map_serial):
			natural_laps+=1
		# Reload after ordinary moves, without fast-forwarding or re-rolling.
		if total_moves%4==0:
			for i in range(3): await process_frame
			map.queue_free()
			await process_frame
			var snapshot: Dictionary=world.snapshot().duplicate(true)
			session.reload_world()
			world=session.world
			check(world.snapshot()==snapshot,"travel %d: natural route state survives JSON reload" % total_moves)
			map=MAP.instantiate()
			root.add_child(map)
			await process_frame
	check(reached,"true natural dice travel reaches rescued-child village rumor within 70 rolls")
	check(total_moves>=1,"rumor route requires actual intervening natural dice moves")
	check(session.get_story_event(CHILD.EVENT_ID).status=="complete" and session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"prior rescued child remains complete through arbitrary natural map travel")
	if reached:
		for beat in range(VILLAGE_BEATS.count(VILLAGE.RESCUED_ID)):
			var caption: String="마치기" if beat==VILLAGE_BEATS.count(VILLAGE.RESCUED_ID)-1 else "계속"
			var next: Button=button_at(map,caption)
			if next==null:
				check(false,"natural village missing canonical %s at beat %d" % [caption,beat])
				break
			press_story_action(next)
			await process_frame
		check(session.get_story_event(VILLAGE.RESCUED_ID).status=="complete" and session.event_flag_is_set(VILLAGE.complete_flag(VILLAGE.RESCUED_ID)),"natural route completes correct rescued rumor via original user buttons")
		check(session.get_story_event(VILLAGE.ABANDONED_ID).status=="unseen","natural rescued rumor never invents abandoned storyline")
	check(world.reward_receipts.size()>=initial_receipts.size(),"normal travel never destroys earlier item receipts")
	for i in range(4): await process_frame
	map.queue_free()
	await process_frame
	var final_state: Dictionary=world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==final_state,"full unmodified generated map + natural travel + rumor result round-trips JSON")
	check(session.world.tiles[8]=="village" and session.world.tiles[15]=="home" and session.world.tiles[0]=="fortune-teller-camp","canonical anchored locations preserved throughout natural travel")
	print("P4_NATURAL_ROUTE_METRICS: %d genuine rolls, %d natural house shuffles" % [total_moves,natural_laps])

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	var seed: int=create_run(session)
	if seed>0 and await actual_graveyard_rescue(session):
		await natural_village_rumor(session)
	session.save_file_path=old_path
	if created: session.queue_free()
	clear_path()
	check(not FileAccess.file_exists(path),"disposable natural-run save removed; normal player save untouched")
	# Finish this isolated process only after queued UI audio has been freed.
	root.get_node("GameAudio").queue_free()
	await create_timer(0.10).timeout
	print("P4_NATURAL_STORY_ARRIVAL: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
