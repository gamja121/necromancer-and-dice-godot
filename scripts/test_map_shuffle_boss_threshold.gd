extends SceneTree
## Stage 20 and 40 bosses once; stage 80 only after final story.
const MapState = preload("res://systems/map_state.gd")
const MapScene = preload("res://map.tscn")
const StoryFixture = preload("res://scripts/boss_story_test_fixture.gd")
var passed=0
var failed=0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, description: String) -> void:
	if ok:
		passed+=1
		print("PASS boss-threshold: ",description)
	else:
		failed+=1
		printerr("FAIL boss-threshold: ",description)

func _run() -> void:
	var defs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var state=MapState.new(defs,1201)
	check(MapState.FIRST_BOSS_CONTAMINATION==20 and MapState.SECOND_BOSS_CONTAMINATION==40 and MapState.BOSS_CONTAMINATION==80,"separate thresholds are 20, 40, 80")
	check(MapState.BOSS_TILE_INDEX==23 and ResourceLoader.exists("res://assets/map/tiles/boss.png"),"existing 24th boss tile artwork remains")
	for pollution in [0,16,19]:
		state.contamination=pollution
		state.generate()
		check(state.tiles[23]!="boss","stage below20 has no boss")
	state.contamination=20
	state.generate()
	check(state.boss_stage()==20 and state.tiles[23]=="boss","stage20 unlocked")
	state.boss_progress.defeated=[20]
	state.contamination=39
	state.generate()
	check(state.tiles[23]!="boss" and state.boss_stage()==0,"cleared stage20 cannot respawn before40")
	state.contamination=40
	state.generate()
	check(state.boss_stage()==40 and state.tiles[23]=="boss","stage40 unlocks next boss")
	state.boss_progress.defeated.append(40)
	state.contamination=80
	state.generate()
	check(state.tiles[23]!="boss","stage80 requires genuine final story")
	StoryFixture.seed_completed_final_hunt(state,false)
	state.generate()
	check(state.tiles[23]!="boss","fifth story scene must be acknowledged")
	state.event_flags["event:monster_king_hunt_trace_01:final_acknowledged"]=true
	state.generate()
	check(state.boss_stage()==80 and state.tiles[23]=="boss","stage80 dragon unlocks after explicit story finish")
	var before: Array=state.tiles.slice(0,23).duplicate()
	state.contamination=79
	check(state.conceal_boss_below_threshold() and state.tiles[23]=="monster","purification hides final boss")
	check(state.tiles.slice(0,23)==before,"purification preserves all other places")
	state.contamination=80
	check(state.reveal_boss_at_threshold(),"return to80 reveals pending dragon again")
	var saved: Dictionary=state.snapshot().duplicate(true)
	var restored=MapState.new(defs,999)
	check(restored.restore(saved) and restored.boss_progress.defeated==[20,40] and restored.tiles[23]=="boss","clears and final story survive save roundtrip")
	state.boss_progress.defeated.append(80)
	state.generate()
	check(state.tiles[23]!="boss","all defeated bosses stay removed at100 percent contamination")
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession registered")
		quit(1)
		return
	var prior: String=session.save_file_path
	var temp: String="user://boss_stage_map_%d.json" % OS.get_process_id()
	session.save_file_path=temp
	session.start_new_world()
	session.world.contamination=40
	session.world.boss_progress.defeated=[20]
	session.world.generate()
	check(session.save_world(),"stage40 map persisted")
	var map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(map.buttons.size()==24 and map.buttons[23].texture_normal==map.texture("res://assets/map/tiles/boss.png"),"actual map displays second-stage boss tile")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.boss_stage()==40 and session.world.tiles[23]=="boss","stage40 persists over full session reload")
	session.world.boss_progress.defeated.append(40)
	var previous_state: Dictionary=session.world.snapshot().duplicate(true)
	session.save_file_path="user://missing_boss_stage_directory/no_write.json"
	check(not session.persist_change(previous_state),"storage failure reported")
	check(session.world.snapshot()==previous_state,"storage rollback preserves stage data")
	session.save_file_path=temp
	if FileAccess.file_exists(temp): DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	session.save_file_path=prior
	print("MAP_SHUFFLE_BOSS_THRESHOLD: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
