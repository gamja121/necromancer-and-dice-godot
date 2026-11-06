extends SceneTree
const Wormhole = preload("res://systems/king_portal_encounter.gd")
const KingPortalTile = preload("res://systems/king_portal_tile.gd")
const StoryBook = preload("res://systems/main_story_book.gd")
const MAP = preload("res://map.tscn")
const Fixture = preload("res://scripts/boss_story_test_fixture.gd")
const Progress = preload("res://systems/final_dragon_progress.gd")
const DieLayout = preload("res://systems/final_dragon_die_layout.gd")
const Book = preload("res://systems/final_chapter_screen.gd")
const BattleDeck = preload("res://systems/battle_deck.gd")
var passed := 0
var failed := 0
var screenshots := ""
var source_story := ""

func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	if value: passed += 1
	else: failed += 1
	print(("PASS " if value else "FAIL ")+label)

func until_ready(predicate: Callable, seconds: float = 25.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())

func capture(label: String) -> void:
	if screenshots.is_empty() or DisplayServer.get_name()=="headless": return
	if label in ["wormhole-scene-1","wormhole-scene-2"]: await create_timer(0.72).timeout
	if label=="wormhole-deck": await create_timer(0.88).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screenshots.path_join(label+".png"))==OK,"native image "+label)

func action(book: Control, title: String) -> Button:
	for child in book.get_children():
		if child is Button and child.text==title: return child
	return null

func press_story(map: Control, title: String) -> void:
	var panel: Control = map.overlay
	await until_ready(func(): return panel.typewriter!=null and panel.typewriter.is_inside_tree())
	map._reveal_story_text(panel)
	var button: Button=action(panel,title)
	check(button!=null,"story button "+title)
	if button!=null: button.pressed.emit()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): screenshots=arg.trim_prefix("--screenshots=")
		if arg.begins_with("--source-story="): source_story=arg.trim_prefix("--source-story=")
	var s: Node = root.get_node("RunSession")
	var original_path: String = s.save_file_path
	var scratch := "user://final_chapter_ui_%d.json" % OS.get_process_id()
	s.save_file_path = scratch
	for stage_value in [20,40,60]:
		s.start_new_world()
		s.world.contamination=stage_value
		s.world.generate()
		s.world.position=23
		check(s.save_world(),"stage %d approach persists" % stage_value)
		var stage_map: Control=MAP.instantiate()
		root.add_child(stage_map)
		current_scene=stage_map
		await process_frame
		check(await until_ready(func(): return is_instance_valid(stage_map.overlay) and stage_map.overlay is BattleDeck),"stage %d opens ordinary battle selection" % stage_value)
		check(not stage_map.overlay is StoryBook and not s.world.event_flags.get(Wormhole.SEEN,false),"stage %d never consumes the final book" % stage_value)
		stage_map.queue_free()
		await process_frame
	s.start_new_world()
	if source_story.is_empty():
		Fixture.seed_completed_final_hunt(s.world)
		s.world.contamination = 80
		s.world.generate()
	else:
		var completed_story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_story))
		check(s.world.restore(completed_story),"load actual full-story completion receipts")
	s.world.position = 15
	s.world.dice_visual_position = [811,274]
	s.world.dice_visual_face = 4
	s.world.dice_visual_rotation = 28
	s.world.refresh_final_wormhole()
	var target: int=s.world.final_dragon_location()
	check(target>=0 and s.save_world(),"existing final gate is ready")
	var map: Control = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	var before_preview: Dictionary=s.world.snapshot().duplicate(true)
	map.show_tile(target)
	map.show_tile(s.world.warp_destination(target))
	check(not is_instance_valid(map.overlay) and s.world.snapshot()==before_preview,"remote clicks on both warp stones cannot move the hero or start an encounter")
	await capture("wormhole-map")

	s.world.position=(target+23)%24
	var probe:=RandomNumberGenerator.new()
	for seed_value in range(100):
		probe.seed=seed_value
		if probe.randi_range(1,6)==1:
			s.world.rng.seed=seed_value
			break
	map.render()
	check(s.save_world(),"approach to the wormhole saved")
	var previous_move: int=s.world.move_serial
	await map.roll_move()
	check(s.world.position==target and s.world.move_serial==previous_move+1 and s.world.pending_move.is_empty(),"actual map die arrives directly at the marked warp")
	check(map.overlay is StoryBook and Wormhole.beat(s.world)==0 and s.encounter.is_empty(),"actual arrival opens the first story scene before combat")
	await until_ready(func(): return map.overlay.typewriter!=null)
	map._reveal_story_text(map.overlay)
	await capture("wormhole-scene-1")
	await press_story(map,"계속")
	check(Wormhole.beat(s.world)==1,"first explicit continue is saved")
	current_scene = null
	map.queue_free()
	await process_frame
	s.reload_world()
	map = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	check(await until_ready(func(): return map.overlay is StoryBook),"saved second scene reopens after restart")
	check(Wormhole.beat(s.world)==1 and map.tile_path(target)==KingPortalTile.PATHS.back(),"reload keeps the second scene and transformed stone")
	await until_ready(func(): return map.overlay.typewriter!=null)
	map._reveal_story_text(map.overlay)
	await capture("wormhole-scene-2")
	await press_story(map,"계속")
	check(Wormhole.beat(s.world)==2,"second explicit continue reaches the last scene")
	await until_ready(func(): return map.overlay.typewriter!=null)
	map._reveal_story_text(map.overlay)
	await capture("wormhole-scene-3")
	var before_deck: int=s.world.rng.state
	var last_book: Control=map.overlay
	s.save_file_path = "user://missing_final_chapter_directory/save.json"
	await press_story(map,"전투 준비")
	check(map.overlay==last_book and not s.event_flag_is_set(Wormhole.ACK),"failed acknowledgement remains retryable")
	s.save_file_path = scratch
	await press_story(map,"전투 준비")
	check(map.overlay is BattleDeck and s.event_flag_is_set(Wormhole.ACK) and s.encounter.is_empty() and s.world.rng.state==before_deck,"explicit confirmation opens deck without starting combat")
	check(map.stage.get_node_or_null("MainStoryBook")==null,"the story book closes before the deck can receive input")
	await capture("wormhole-deck")
	var deck: Control = map.overlay
	var real_die: TextureButton = map.dice
	var saved_face: int=s.world.dice_visual_face
	var saved_angle: float=real_die.rotation_degrees
	for unit in s.world.roster.slice(0,2): deck.toggle_unit(str(unit.id))
	deck.confirm_button.pressed.emit()
	check(await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.entry_summon_active),"selected deck summons into real boss battle")
	var battle: Control = map.embedded_battle
	if is_instance_valid(battle.brand_reference):
		battle.brand_reference.close()
		check(await until_ready(func(): return not is_instance_valid(battle.brand_reference)),"entry reference closes")
	check(battle.external_main_dice==real_die and battle.dice==real_die,"battle uses identical physical die")
	check(Progress.is_final_encounter(s.encounter) and s.encounter.get("entry","")==Wormhole.ENTRY,"one real dragon fight is saved at the wormhole")
	check(s.world.dice_visual_face==saved_face and is_equal_approx(real_die.rotation_degrees,saved_angle),"entry preserves die result and angle (face %d, angle %.8f)" % [s.world.dice_visual_face,real_die.rotation_degrees])
	var obstacle: Rect2 = map.final_dragon_die_exclusion()
	var radius: float = real_die.size.length()*0.55
	check(obstacle.has_area() and not obstacle.grow(radius).has_point(real_die.position+real_die.size*0.5),"saved overlap is moved outside dragon canvas")
	var visual_rng_before: int = s.world.rng.state
	for x in range(700,1080,60):
		for y in range(240,480,60):
			var safe: Vector2 = DieLayout.rest_position(Vector2(x,y),real_die.size,map.SHARED_DIE_AREA,obstacle)
			check(not obstacle.grow(radius).has_point(safe+real_die.size*0.5),"safe rest avoids dragon at %d,%d" % [x,y])
	check(s.world.rng.state==visual_rng_before,"pose correction does not consume gameplay RNG")
	await capture("final-battle-clear-view")
	# Deterministic completion fixture: boost allied stats only. Enemy HP70,
	# bone + undying, dice, action queue, death and harvest are production.
	for unit in battle.rules.units:
		if unit.team=="ally":
			unit.base_attack=999
			unit.attack=999
			unit.base_speed=999
			unit.speed=999
	battle.rules.refresh()
	s.encounter.checkpoint=battle.rules.snapshot()
	s.world.active_encounter=s.encounter.duplicate(true)
	check(s.save_world(),"test-only allied checkpoint saves")
	var encounter_id: String = s.encounter.id
	# Reload mid-battle must bypass book and restore the exact one encounter.
	current_scene = null
	map.queue_free()
	await process_frame
	s.reload_world()
	map = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	battle = map.embedded_battle
	check(is_instance_valid(battle) and s.encounter.id==encounter_id and not (map.overlay is Book),"battle restart restores encounter without replaying intro")
	for round_index in range(4):
		if not battle.rules.winner().is_empty(): break
		await battle.roll_round()
	check(battle.rules.winner()=="ally" and Progress.cleared(s.world),"actual boss combat commits clear")
	check(s.world.pending_reward.kind=="capture" and not is_instance_valid(map.final_chapter_screen) and not is_instance_valid(map.game_over_screen),"harvest precedes ending and never uses defeat screen")
	check(not map.final_dragon_die_exclusion().grow(radius).has_point(map.dice.position+map.dice.size*0.5),"rolled die also settles outside dragon")
	await capture("final-harvest")
	current_scene = null
	map.queue_free()
	await process_frame
	s.reload_world()
	map = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	battle = map.embedded_battle
	check(is_instance_valid(battle) and is_instance_valid(battle.capture_panel) and not is_instance_valid(map.final_chapter_screen),"restart after victory resumes pending harvest first")
	for attempt in range(3):
		if s.world.pending_reward.is_empty(): break
		await battle.capture_panel.roll()
	check(await until_ready(func(): return is_instance_valid(map.final_chapter_screen) and not map.battle_returning),"actual harvest returns cards and opens book ending")
	check(not map.dice.visible and map.dice.disabled and not is_instance_valid(map.game_over_screen),"ending hides and blocks shared die, no defeat shatter")
	check(not s.prepare_map_roll().ok,"ending cannot continue expedition")
	check(await until_ready(func(): return not map.final_chapter_screen.action_button.disabled,6.0),"ending book and illustration finish before closing")
	await capture("final-ending")
	var final_record: Dictionary = s.world.run_result.duplicate(true)
	var roster_count: int = s.world.roster.size()
	# Button goes to real title; Continue returns the same book and record.
	map.final_chapter_screen.action_button.pressed.emit()
	check(await until_ready(func(): return current_scene!=null and current_scene.scene_file_path=="res://title.tscn",4.0),"closing the physical book reaches title once" )
	check(current_scene!=null and current_scene.scene_file_path=="res://title.tscn","book close reaches title")
	var title: Control = current_scene
	title.continue_button.pressed.emit()
	await process_frame
	await process_frame
	map = current_scene
	check(map!=null and map.scene_file_path=="res://map.tscn","title Continue returns saved run")
	check(await until_ready(func(): return is_instance_valid(map.final_chapter_screen),5.0),"title Continue restores completed ending")
	check(s.world.run_result==final_record and s.world.roster.size()==roster_count and s.world.pending_reward.is_empty(),"title round trip does not duplicate reward or erase clear")
	await capture("final-ending-resumed")
	current_scene = null
	map.queue_free()
	await process_frame
	s.save_file_path = original_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	# Release this isolated run's active ending/book cues before SceneTree exit.
	var sound_service: Node = root.get_node_or_null("GameAudio")
	if sound_service != null: sound_service.queue_free()
	await create_timer(0.10).timeout
	print("FINAL_CHAPTER_UI: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
