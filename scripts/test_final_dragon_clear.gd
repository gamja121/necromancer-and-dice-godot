extends SceneTree
const Session = preload("res://systems/run_session.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const MapState = preload("res://systems/map_state.gd")
const Progress = preload("res://systems/final_dragon_progress.gd")
const Fixture = preload("res://scripts/boss_story_test_fixture.gd")
const Hunt = preload("res://systems/monster_king_hunt_entry.gd")
const Portal = preload("res://systems/ritual_portal_entry.gd")
var passed := 0
var failed := 0
var scratch: String

func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1
	print(("PASS " if value else "FAIL ") + message)

func prepare_encounter(s: Node, boss: bool = true) -> void:
	s.start_new_world()
	var w = s.world
	if boss:
		Fixture.seed_completed_final_hunt(w)
		w.contamination = 80
		w.generate()
	w.position = 23 if boss else w.tiles.find("monster")
	check(s.save_world(),"fixture persists real board")
	var rng_before: int = w.rng.state
	if boss:
		check(not s.acknowledge_final_dragon_intro(0),"preview cannot acknowledge book")
		check(s.acknowledge_final_dragon_intro(23),"actual boss arrival can acknowledge book")
		check(w.rng.state==rng_before and s.encounter.is_empty(),"book acknowledgement creates no combat or RNG")
	check(s.start_encounter(w.position,[w.roster[0].id,w.roster[1].id]),"actual encounter starts")

func defeated_rules(s: Node, win: bool = true):
	var rules = Rules.new(s.world.definitions)
	check(rules.restore(s.encounter.checkpoint),"actual encounter checkpoint restores")
	for unit in rules.units:
		if unit.team==("enemy" if win else "ally"):
			rules.damage(unit,9999)
			if unit.alive: rules.damage(unit,9999)
	check(rules.winner()==("ally" if win else "enemy"),"real damage produces intended winner")
	return rules

func capture_seed(s: Node, success: bool) -> void:
	var target: int = int(s.world.pending_reward.corpses[0].target)
	var rng := RandomNumberGenerator.new()
	for value in range(100):
		rng.seed = value
		if (rng.randi_range(1,6)>=target)==success:
			s.world.rng.seed = value
			return
	check(false,"deterministic capture fixture exists")

func check_legacy_boss_board(s: Node) -> void:
	s.start_new_world()
	var w = s.world
	var index: int = MapState.BOSS_TILE_INDEX
	w.contamination=60
	w.generate()
	w.contamination=80
	w.generate()
	check(w.tiles[index]=="boss" and w.tiles.count("warp")==2 and w.current_boss_stage()==60,"legacy fixed board contains a real stage-60 boss and two warps")
	Fixture.seed_completed_final_hunt(w)
	w.cleared.append(index)
	var before: Dictionary = w.snapshot().duplicate(true)
	check(s.save_world(),"legacy cleared boss board written to disk")
	s.reload_world()
	w=s.world
	check(w.event_flags.get(MapState.BossStages.stage_flag(60),false),"legacy clear retains the stage-60 victory")
	check(not w.event_flags.get(MapState.BossStages.stage_flag(80),false) and not Progress.cleared(w),"legacy cleared cell does not imply a final victory")
	check(w.final_dragon_location()==index and not index in w.cleared,"newly eligible final dragon can use the shared boss cell")
	check(w.tiles==before.tiles and w.rng.state==int(before.rng_state) and w.map_serial==int(before.map_serial) and w.position==int(before.position),"boss migration preserves board, warp pair, RNG and position")
	var migrated: String = FileAccess.get_file_as_string(scratch)
	s.reload_world()
	w=s.world
	check(FileAccess.get_file_as_string(scratch)==migrated,"boss migration is idempotent on restart")

	var selected: Array = [w.roster[0].id]
	check(not s.start_encounter(index,selected),"final combat cannot start from HOME")
	var false_entrance: int = w.tiles.find("monster")
	w.tiles[false_entrance]="boss"
	w.position=false_entrance
	check(not s.acknowledge_final_dragon_intro(false_entrance) and not s.start_encounter(false_entrance,selected),"a duplicate boss tile cannot open a second final entrance")

	check(w.restore(before),"reload the board for the old explicit defeat receipt")
	w.event_flags[MapState.BossStages.stage_flag(80)]=true
	w.tiles[index]="monster"
	check(s.save_world(),"old explicit final defeat without ending saves")
	s.reload_world()
	w=s.world
	check(w.final_dragon_location()==-1 and w.event_flags.get(MapState.BossStages.stage_flag(80),false) and w.run_result.is_empty(),"ambiguous explicit old defeat remains retired without inventing an ending")

func check_pre_ending_harvest(s: Node) -> void:
	prepare_encounter(s)
	check(s.finish_encounter(defeated_rules(s)),"real dragon victory supplies the old harvest fixture")
	var legacy: Dictionary = s.world.snapshot().duplicate(true)
	legacy.erase("boss_assignments")
	legacy.run_result={}
	for flag in [Progress.COMPLETE,Progress.DEFEATED,MapState.BossStages.revealed_flag(80),MapState.BossStages.stage_flag(80)]:
		legacy.event_flags.erase(flag)
	legacy.event_flags[Progress.ACTIVE]=true
	legacy.pending_reward.corpses[0].erase("unit")
	var file := FileAccess.open(scratch,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var old_harvest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scratch)).pending_reward
	s.reload_world()
	var w = s.world
	check(JSON.parse_string(JSON.stringify(w.pending_reward))==old_harvest and w.run_result.get("reason","")==Progress.REASON,"original pre-ending soul harvest survives and restores its proven victory")
	check(w.final_dragon_location()==-1 and w.run_result.get("encounter_id","")==str(old_harvest.id).trim_prefix("capture-"),"legacy final harvest has one encounter and no replay")
	capture_seed(s,true)
	check(s.roll_capture().get("success",false) and s.claim_reward().get("ok",false),"old harvest can be claimed through the normal transaction")
	s.reload_world()
	check(Progress.cleared(s.world) and s.world.pending_reward.is_empty(),"ending remains after closing the historical harvest")

	legacy.pending_reward={}
	legacy.contamination=80
	if not MapState.BOSS_TILE_INDEX in legacy.cleared: legacy.cleared.append(MapState.BOSS_TILE_INDEX)
	legacy.tiles[MapState.BOSS_TILE_INDEX]="boss"
	file=FileAccess.open(scratch,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	s.reload_world()
	w=s.world
	check(w.final_dragon_location()==-1 and w.event_flags.get(MapState.BossStages.stage_flag(80),false) and w.run_result.is_empty(),"already-harvested sole boss stays retired without creating an ending")

func check_legacy_wounded_dragon(s: Node) -> void:
	prepare_encounter(s)
	var rules = Rules.new(s.world.definitions)
	check(rules.restore(s.encounter.checkpoint) and s.prepare_battle_roll(rules).ok,"old final battle has a rolled checkpoint")
	rules.damage(rules.find_id("enemy-0"),9999)
	check(s.checkpoint_battle(rules,"actions"),"wounded final dragon checkpoint saves")
	var w = s.world
	w.contamination=0
	w.event_flags.erase(MapState.BossStages.revealed_flag(80))
	w.event_flags[MapState.BossStages.revealed_flag(40)]=true
	w.active_encounter.erase("boss_stage")
	check(s.save_world(),"legacy checkpoint without the final stage receipt saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scratch))
	s.reload_world()
	w=s.world
	check(s.encounter==saved.active_encounter and w.active_encounter==saved.active_encounter,"checkpoint identity, roll and phase survive migration")
	check(w.final_dragon_location()==MapState.BOSS_TILE_INDEX and w.event_flags.get(MapState.BossStages.revealed_flag(80),false),"actual saved final dragon restores the appearance below threshold")
	check(rules.restore(s.encounter.checkpoint) and rules.find_id("enemy-0").hp==1 and rules.find_id("enemy-0").undying_used,"resumed dragon retains its wound and spent undying ability")
	check(s.finish_encounter(defeated_rules(s)) and Progress.cleared(w) and w.event_flags.get(MapState.BossStages.stage_flag(80),false),"resumed victory settles the actual final stage")
	check(w.pending_reward.get("id","")=="capture-"+str(saved.active_encounter.id),"resumed victory grants the original encounter's soul harvest")

func check_boss_warp_pair(s: Node) -> void:
	s.start_new_world()
	var w = s.world
	var index: int = MapState.BOSS_TILE_INDEX
	w.contamination=19
	w.generate()
	if w.tiles[index]!="warp":
		var first: int = w.tiles.find("warp")
		w.tiles[first]=w.tiles[index]
		w.tiles[index]="warp"
	var survivor: int = w.tiles.find("warp")
	check(s.save_world(),"pre-reveal warp at the boss coordinate is saved")
	s.reload_world()
	w=s.world
	w.contamination=20
	w.position=index
	check(not w.reveal_boss_at_threshold() and w.tiles[index]=="warp","boss waits while the hero occupies the warp")
	w.position=MapState.HOME
	w.pending_move={"origin":index,"path":[survivor],"landed":survivor}
	check(not w.reveal_boss_at_threshold() and w.tiles[index]=="warp","boss waits for committed movement to finish")
	w.pending_move={}
	var before: Dictionary = w.snapshot().duplicate(true)
	check(s.persist_change(before) and w.tiles[index]=="boss" and w.tiles.count("warp")==2,"boss reveal preserves a complete warp pair")
	check(w.tiles[survivor]=="warp" and w.rng.state==int(before.rng_state) and w.map_serial==int(before.map_serial) and w.position==int(before.position),"displacement preserves the other warp, RNG, board serial and position")

	var displaced: int = w.tiles.find("warp") if w.tiles.find("warp")!=survivor else w.tiles.rfind("warp")
	w.tiles[displaced]="monster"
	check(s.save_world(),"legacy save with a swallowed warp is written")
	s.reload_world()
	w=s.world
	check(w.tiles[survivor]=="warp" and w.tiles.count("warp")==2 and w.tiles[index]=="boss","reload repairs the missing warp without replacing its surviving endpoint")
	check(w.rng.state==int(before.rng_state) and w.map_serial==int(before.map_serial),"warp repair consumes no RNG or map generation")
	var repaired: String = FileAccess.get_file_as_string(scratch)
	s.reload_world()
	check(FileAccess.get_file_as_string(scratch)==repaired,"warp repair is idempotent on restart")

func _run() -> void:
	var s: Node = root.get_node("RunSession")
	var prior: String = s.save_file_path
	scratch = "user://final_clear_%d.json" % OS.get_process_id()
	s.save_file_path = scratch
	check_legacy_boss_board(s)
	check_pre_ending_harvest(s)
	check_legacy_wounded_dragon(s)
	check_boss_warp_pair(s)
	prepare_encounter(s)
	var rules = defeated_rules(s)
	var before: Dictionary = s.world.snapshot().duplicate(true)
	var disk_before: String = FileAccess.get_file_as_string(scratch)
	s.save_file_path = "user://missing_final_clear_directory/save.json"
	check(not s.finish_encounter(rules),"failed victory save rejected")
	check(s.world.snapshot()==before and not s.encounter.is_empty(),"failed victory restores encounter, roster, flags and RNG")
	check(FileAccess.get_file_as_string(scratch)==disk_before,"failed save leaves previous disk bytes")
	s.save_file_path = scratch
	check(s.finish_encounter(rules),"victory commits")
	check(Progress.cleared(s.world) and s.world.run_result.reason==Progress.REASON,"final victory becomes terminal clear")
	check(s.world.event_flags.get(Progress.COMPLETE,false) and not s.world.event_flags.get(Progress.ACTIVE,true),"final quest completed, no active quest")
	check(Hunt.completed(s) and Portal.completed(s),"earlier story remains historically complete")
	check(s.world.pending_reward.kind=="capture" and s.encounter.is_empty(),"same save retains last soul harvest and retires battle")
	var committed: Dictionary = s.world.snapshot().duplicate(true)
	check(s.finish_encounter(rules) and s.world.snapshot()==committed,"duplicate settlement cannot reward or count twice")
	check(not s.prepare_map_roll().ok and not s.enter_home() and not s.leave_home(),"terminal expedition cannot move or regenerate")
	check(not s.open_treasure() and not s.place_allowed(s.world.position,"monster").ok,"terminal expedition cannot start place actions")
	check(not s.start_encounter(23,[s.world.roster[0].id]),"terminal expedition cannot replay fight")
	s.reload_world()
	check(s.world.run_result==committed.run_result and s.world.pending_reward.id==committed.pending_reward.id,"reload keeps clear and same pending harvest")
	check(Hunt.completed(s) and Portal.completed(s),"story remains complete after reload")
	var restored = MapState.new(s.world.definitions)
	var incomplete: Dictionary = committed.duplicate(true)
	incomplete.event_flags.erase(Progress.DEFEATED)
	check(not restored.restore(incomplete),"inconsistent terminal clear is rejected")
	var legacy: Dictionary = committed.duplicate(true)
	legacy.run_result = {}
	legacy.pending_reward = {}
	legacy.event_flags.erase(Progress.DEFEATED)
	legacy.event_flags.erase(Progress.COMPLETE)
	legacy.event_flags[Progress.ACTIVE] = true
	check(restored.restore(legacy) and not Progress.cleared(restored),"legacy tile clear alone is not misclassified as final victory")
	check(restored.restore(committed),"valid terminal save restores")
	restored.contamination = 100
	restored.position = MapState.HOME
	restored.lap_ready = true
	restored.leave_home()
	check(not restored.boss_available() and not "boss" in restored.tiles,"even direct next-lap generation cannot respawn defeated dragon")
	# Both possible harvest outcomes must retain the clear across interruption.
	for success in [true,false]:
		check(s.world.restore(committed),"restore pending final harvest branch")
		s.encounter = {}
		capture_seed(s,success)
		check(s.save_world(),"deterministic capture RNG saved")
		var capture_before: Dictionary = s.world.snapshot().duplicate(true)
		s.save_file_path = "user://missing_final_clear_directory/save.json"
		check(not s.roll_capture().ok and s.world.snapshot()==capture_before,"capture save failure rolls back final reward and RNG")
		s.save_file_path = scratch
		var outcome: Dictionary = s.roll_capture()
		check(outcome.ok and outcome.success==success,"real harvest resolves expected outcome")
		s.reload_world()
		check(Progress.cleared(s.world) and s.world.pending_reward.phase==("success" if success else "failed"),"harvest outcome survives reload")
		var resolved: Dictionary = s.world.snapshot().duplicate(true)
		s.save_file_path = "user://missing_final_clear_directory/save.json"
		if success: check(not s.claim_reward().ok,"failed reward claim remains retryable")
		else: check(not s.dismiss_failed_capture(),"failed harvest dismissal remains retryable")
		check(s.world.snapshot()==resolved,"failed harvest finish preserves entire state")
		s.save_file_path = scratch
		if success:
			check(s.claim_reward().ok,"final dragon reward remains claimable after run ends")
			var unit: Dictionary = s.world.roster.back()
			check(unit.slug=="dragon" and unit.max_hp==20 and unit.passive=="bone" and not unit.has("final_boss"),"existing 20/4/3 recruit normalization preserved")
		else: check(s.dismiss_failed_capture(),"failed harvest closes")
		check(not s.claim_reward().ok and not s.dismiss_failed_capture(),"harvest cannot be claimed twice")
		s.reload_world()
		check(Progress.cleared(s.world) and s.world.pending_reward.is_empty(),"completed harvest resumes at ending")
		check(s.world.reward_receipts.count(committed.pending_reward.id)==1,"exactly one harvest receipt")
	# Shared main now has three intermediate bosses. Each win must remain
	# a resumable expedition with its own stage receipt and ordinary harvest.
	for stage_value in [20,40,60]:
		s.start_new_world()
		s.world.contamination=stage_value
		s.world.generate()
		s.world.position=MapState.BOSS_TILE_INDEX
		check(s.save_world(),"intermediate boss approach persists")
		check(not s.acknowledge_final_dragon_intro(MapState.BOSS_TILE_INDEX),"intermediate boss cannot acknowledge the final book")
		check(s.start_encounter(MapState.BOSS_TILE_INDEX,[s.world.roster[0].id,s.world.roster[1].id]),"intermediate boss encounter starts")
		check(s.finish_encounter(defeated_rules(s)) and not Progress.cleared(s.world) and s.world.run_result.is_empty(),"intermediate victory keeps expedition active")
		check(s.world.event_flags.get(MapState.BossStages.stage_flag(stage_value),false) and not s.world.event_flags.get(Progress.COMPLETE,false),"only the intermediate stage is completed")
		check(s.world.pending_reward.get("kind","")=="capture","intermediate victory retains ordinary soul harvest")
	prepare_encounter(s,false)
	check(s.finish_encounter(defeated_rules(s)) and s.world.run_result.is_empty(),"ordinary victory does not clear expedition")
	prepare_encounter(s)
	check(s.finish_encounter(defeated_rules(s,false)),"final dragon loss commits")
	check(s.world.run_result.reason=="battle_defeat" and not Progress.cleared(s.world),"dragon loss retains original defeat ending")
	s.reload_world()
	check(s.world.run_result.reason=="battle_defeat","defeat save backward compatibility")
	s.start_new_world()
	check(s.world.run_result.is_empty() and not Progress.cleared(s.world),"explicit new expedition resets its own completion")
	s.save_file_path = prior
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("FINAL_DRAGON_CLEAR: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
