extends SceneTree
## Stage 5T frozen-web ghoul layer geometry, first reveal and saved-scene idle.
## Real 4-beat scene and temporary session save; no new story, RNG or rewards.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const STORY = preload("res://systems/story_event_entry.gd")
const GH = preload("res://systems/graveyard_ghoul_motion.gd")
const BEATS = preload("res://systems/graveyard_story_beats.gd")
var passed: int = 0
var failed: int = 0
var scratch: String = ""

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-ghoul-motion: ",message)
	else:
		failed += 1
		printerr("FAIL ui-ghoul-motion: ",message)

func near(actual: float, expected: float, tolerance: float = 0.15) -> bool:
	return absf(actual-expected) <= tolerance

func clear_save() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))

func get_ghoul_frame(map: Control) -> TextureRect:
	if not is_instance_valid(map.overlay): return null
	return map.overlay.find_child("StoryCharacterLayer",true,false) as TextureRect

func get_ghoul(map: Control) -> TextureRect:
	var frame = get_ghoul_frame(map)
	return frame.get_node_or_null("GhoulSprite") as TextureRect if frame != null else null

func has_button(panel: Control, title: String) -> bool:
	for node in panel.get_children():
		if node is Button and node.text == title and node.visible: return true
	return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	scratch = "user://ui_ghoul_motion_stage5t_%d.json" % OS.get_process_id()
	clear_save()
	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var previous_path: String = session.save_file_path
	session.save_file_path = scratch
	session.start_new_world()
	# Prepare the existing post-home story gates for this isolated visual fixture.
	session.world.laps=1
	session.world.contamination=int(preload("res://systems/story_contamination_gate.gd").MINIMUMS.values().max())
	session.world.generate()
	var index: int = session.world.tiles.find("graveyard")
	check(index >= 0,"real map includes a graveyard story tile")
	if index < 0:
		session.save_file_path = previous_path
		if created: session.queue_free()
		clear_save()
		quit(1)
		return
	session.world.position = index
	check(session.save_world(),"isolated graveyard tile position saved")
	check(STORY.begin(session,index),"canonical user-triggered story entry saved")
	var map = MAP.instantiate()
	root.add_child(map)
	for i in range(4): await process_frame
	var first: Dictionary = session.world.snapshot().duplicate(true)
	var initial_rng: int = session.world.rng.state
	var initial_receipts: Array = session.world.reward_receipts.duplicate()
	map.show_graveyard_child_beat(index,0)
	check(is_instance_valid(map.overlay),"discovery scene opens")
	check(get_ghoul_frame(map) == null,"discovery has no false ghoul sprite")

	map.show_graveyard_child_beat(index,1)
	var frame = get_ghoul_frame(map)
	var ghoul = get_ghoul(map)
	check(frame is TextureRect and ghoul is TextureRect,"threat scene creates story character frame and separately animated sprite")
	if ghoul != null:
		var source := Rect2(Vector2.ZERO,map.StoryBook.ART_RECT.size)
		var expected = Rect2(source.position+source.size*Vector2(0.55,0.18),source.size*Vector2(0.30,0.64))
		check(frame.position.distance_to(expected.position)<0.1 and frame.size.distance_to(expected.size)<0.1,"ghoul occupies CSS left 55%, top 18%, 30% width, 64% height")
		check(frame.position.x+frame.size.x<source.end.x and frame.position.y+frame.size.y<source.end.y,"ghoul art stays on the scene right, not full-screen stretched")
		check(frame.mouse_filter==Control.MOUSE_FILTER_IGNORE and ghoul.mouse_filter==Control.MOUSE_FILTER_IGNORE,"decorative layers never capture touch or mouse")
		check(ghoul.texture != null and ghoul.texture.resource_path == BEATS.GHOUL_ART,"unaltered original ghoul WebP loaded as visible sprite")
		check(ghoul.position.distance_to(ghoul.size*GH.ENTRY_OFFSET)<0.1 and near(ghoul.scale.x,0.86),"first threat reveal starts 18% right, 4% down, at 86% scale")
		check(near(ghoul.modulate.a,0.0,0.001) and near(ghoul.rotation_degrees,2.0),"first threat starts transparent with 2-degree tilt")
		check(ghoul.pivot_offset.distance_to(ghoul.size*Vector2(0.58,0.82))<0.1,"CSS 58% 82% ghoul transform origin restored")
		await create_timer(0.95).timeout
		check(ghoul.position.distance_to(Vector2.ZERO)<0.4 and ghoul.scale.distance_to(Vector2.ONE)<0.01,"0.82-second threat reveal settles inside its stationary frame")
		check(near(ghoul.modulate.a,0.96,0.01),"source ghoul rests at 96% opacity")
		check(frame.position.distance_to(expected.position)<0.1,"PanelEffects entrance never fights the nested sprite motion")
		await create_timer(0.74).timeout
		check(ghoul.position.x < -0.2 and ghoul.position.y < -0.1,"3.2-second idle drifts left/up after reveal")
		check(ghoul.position.x > -ghoul.size.x*0.012-0.3 and ghoul.position.y > -ghoul.size.y*0.006-0.3,"idle stays within source 1.2%/0.6% travel")

	map.show_graveyard_child_beat(index,2)
	frame = get_ghoul_frame(map)
	ghoul = get_ghoul(map)
	check(is_instance_valid(ghoul) and near(ghoul.modulate.a,0.96,0.01),"child dialogue uses immediate ghoul visibility, not a second reveal")
	check(map.overlay.find_child("StoryDialogueFrame",true,false) is TextureRect,"original spoken dialogue parchment survives")
	check(has_button(map.overlay,"계속") and has_button(map.overlay,"나가기"),"story buttons remain explicit interaction")
	map.show_graveyard_child_beat(index,3)
	check(is_instance_valid(get_ghoul(map)),"choice phase keeps the ghoul in the correct area")
	check(has_button(map.overlay,"아이를 구한다") and has_button(map.overlay,"지나친다"),"rescues and leave controls stay available")
	check(session.world.snapshot()==first and session.world.rng.state==initial_rng and session.world.reward_receipts==initial_receipts,"animating every beat does not modify the world, RNG or rewards")
	check(session.encounter.is_empty() and session.world.pending_reward.is_empty(),"ghoul entrance never auto-starts a battle or reward")
	map.close_overlay()
	check(not is_instance_valid(map.overlay) and map.presentation.gauge.visible,"closing scene cancels child tweens and restores map HUD")
	map.show_graveyard_child_beat(index,1)
	map.close_overlay()
	await create_timer(0.85).timeout
	check(not is_instance_valid(map.overlay),"rapid close during reveal does not revive freed artwork")

	check(STORY.advance(session,index,0),"explicit Continue, not visual animation, saves the threat beat")
	check(STORY.current_beat(session)==1,"correct beat saved before reload")
	var saved: Dictionary = session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==saved,"scene reload preserves the original saved beat")
	map = MAP.instantiate()
	root.add_child(map)
	for i in range(5): await process_frame
	ghoul = get_ghoul(map)
	check(is_instance_valid(ghoul),"reloading an active threat restores real source ghoul artwork")
	if ghoul != null:
		check(ghoul.texture.resource_path == BEATS.GHOUL_ART and ghoul.scale.x<1.01,"replayed threat uses original art and transient motion only")
	check(STORY.current_beat(session)==1 and session.encounter.is_empty(),"reveal after reload never advances a beat or starts combat")
	map.queue_free()
	await process_frame
	session.save_file_path = previous_path
	if created: session.queue_free()
	clear_save()
	check(not FileAccess.file_exists(scratch),"temporary save removed without touching player data")
	print("UI_GHOUL_MOTION_STAGE5T: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
