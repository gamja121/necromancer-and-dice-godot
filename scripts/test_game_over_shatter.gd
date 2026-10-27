extends SceneTree
## End-to-end saved defeat + die shatter, using a disposable world and actual
## map/battle runtime, with no screenshot or detached mock gameplay state.
const MAP=preload("res://map.tscn")
const SESSION=preload("res://systems/run_session.gd")
const RULES=preload("res://systems/battlefield_rules.gd")
var passed: int=0
var failed: int=0

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS game-over: ",label)
	else:
		failed+=1
		printerr("FAIL game-over: ",label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var s: Node=root.get_node_or_null("RunSession")
	var created: bool=s==null
	if created:
		s=SESSION.new()
		s.name="RunSession"
		root.add_child(s)
	var old_path: String=s.save_file_path
	var path: String="user://game_over_shatter_%d.json" % OS.get_process_id()
	s.save_file_path=path
	s.start_new_world()
	var w=s.world
	var target: int=w.tiles.find("monster")
	w.position=target
	w.laps=27
	w.contamination=76
	check(target>=0,"real monster tile supports terminal battle fixture")
	check(s.save_world(),"durable run progress saved")
	var ids: Array=[str(w.roster[0].id),str(w.roster[1].id)]
	check(s.start_encounter(target,ids),"actual encounter uses selected owned units")
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	var b: Control=map.embedded_battle
	check(is_instance_valid(b),"map restores real encounter battle")
	var previous_face: int=w.dice_visual_face
	var previous_position: Vector2=map.dice.position
	var rules=RULES.new(w.definitions)
	check(rules.restore(s.encounter.checkpoint),"battle rules restored from persisted encounter")
	for unit in rules.units:
		if unit.team=="ally":
			unit.alive=false
			unit.hp=0
		elif unit.team=="enemy":
			unit.alive=true
			unit.hp=maxi(1,int(unit.hp))
	check(rules.winner()=="enemy","combat state is an actual enemy victory")
	check(s.finish_encounter(rules),"defeat commits before starting cinematic")
	var result: Dictionary=w.run_result
	check(result.ended and result.reason=="battle_defeat","run marked terminal only after committed loss")
	check(result.laps==27 and result.contamination==76,"lap and contamination are real saved values")
	check(result.enemies_defeated==0 and result.surviving_monsters==0 and result.lost_monsters>=2,"enemy kills and permanently fallen monsters recorded accurately")
	check(s.encounter.is_empty() and w.active_encounter.is_empty(),"terminal encounter cannot replay")
	check(not s.start_encounter(target,ids),"terminal run disallows new fights")
	var committed: Dictionary=w.snapshot().duplicate(true)
	map.show_game_over()
	var game: Control=map.game_over_screen
	check(is_instance_valid(game) and game.cinematic and game.get_node_or_null("DoomedDie")!=null,"game over draws a replica of original stage die")
	check(not map.dice.visible and map.dice.position==previous_position and w.dice_visual_face==previous_face,"true die's saved location and pip are not mutated by shatter")
	game._crack_die()
	check(game.shards.size()==8 and game.cracking,"game over die breaks into eight individual shards")
	var all_textured: bool=true
	for i in range(game.shards.size()):
		var piece=game.shards[i]
		all_textured=all_textured and piece is Polygon2D and piece.texture!=null and piece.polygon.size()==3 and piece.uv.size()==3
	check(all_textured,"shards preserve actual original dice texture, not generic geometric replacements")
	game.finish_now()
	check(game.finished and game.get_node_or_null("FinalExpeditionRecord")!=null,"skipping cinematic immediately reveals final record")
	check(game.get_node_or_null("NewExpedition")!=null and game.get_node_or_null("ReturnToTitle")!=null,"new-run and return-to-title actions are available")
	check(w.snapshot()==committed,"all visuals leave the stored endgame snapshot unchanged")
	map.queue_free()
	await process_frame
	s.reload_world()
	check(s.world.run_result==committed.run_result and s.world.active_encounter.is_empty()
		and s.world.roster.size()==committed.roster.size()
		and s.world.graveyard_corpses.size()==committed.graveyard_corpses.size()
		and s.world.enemies_defeated==int(committed.enemies_defeated),
		"restarting the process preserves the terminal result, permanent dead, and kill tally")
	var resumed: Control=MAP.instantiate()
	root.add_child(resumed)
	await process_frame
	await process_frame
	check(is_instance_valid(resumed.game_over_screen) and resumed.game_over_screen.finished and resumed.embedded_battle==null,
		"reloading terminal save shows immediate result, not an interactive board or replay")
	resumed.queue_free()
	await process_frame
	s.start_new_world()
	check(s.world.run_result.is_empty() and s.world.enemies_defeated==0 and s.encounter.is_empty(),"starting a fresh expedition clears ONLY the prior run")
	s.save_file_path=old_path
	if created: s.queue_free()
	for extension in ["",".tmp"]:
		if FileAccess.file_exists(path+extension): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+extension))
	# The disposed embedded battle may still own threaded texture requests.
	# Let its normal scene-exit drain collect them before stopping the engine.
	var loads = preload("res://systems/battle_resources.gd")
	var drain_end: int=Time.get_ticks_msec()+5000
	while not loads.PendingLoads.active.is_empty() and Time.get_ticks_msec()<drain_end: await process_frame
	check(loads.PendingLoads.active.is_empty(),"exited battle resource requests drain before shutdown")
	# Deferred rendering-resource releases follow collection on the next frames.
	await process_frame
	await process_frame
	print("GAME_OVER_SHATTER: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
