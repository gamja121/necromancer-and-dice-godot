extends SceneTree
## Stage 5U: canonical web graveyard story board-drop/next-cue motion.
## Headless scene assertions only; real visual approval remains separate.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const STORY = preload("res://systems/story_event_entry.gd")
const BEATS = preload("res://systems/graveyard_story_beats.gd")
const MOTION = preload("res://systems/graveyard_story_entry_motion.gd")
var passed: int = 0
var failed: int = 0
var save: String = ""

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-story-entry: ",message)
	else:
		failed += 1
		printerr("FAIL ui-story-entry: ",message)

func near_number(a: float,b: float,delta: float = 0.5) -> bool:
	return absf(a-b) < delta

func clear_save() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))

func get_art(map: Control) -> TextureRect:
	if not is_instance_valid(map.overlay): return null
	return map.overlay.get_node_or_null("StorySceneImage") as TextureRect

func get_hint(map: Control) -> Label:
	if not is_instance_valid(map.overlay): return null
	return map.overlay.get_node_or_null("StoryDialogueNext") as Label

func has_button(map: Control, title: String) -> bool:
	if not is_instance_valid(map.overlay): return false
	for child in map.overlay.get_children():
		if child is Button and child.text == title and child.visible: return true
	return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	save="user://ui_story_entry_stage5u_%d.json" % OS.get_process_id()
	clear_save()
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var previous_path: String=session.save_file_path
	session.save_file_path=save
	session.start_new_world()
	# The original ghoul scene becomes accessible after one home reshuffle.
	session.world.lap_ready=true
	session.world.leave_home()
	var index: int=session.world.tiles.find("graveyard")
	check(index>=0,"real board contains graveyard tile")
	if index<0:
		session.save_file_path=previous_path
		if created: session.queue_free()
		clear_save()
		quit(1)
		return
	session.world.position=index
	check(session.save_world(),"temporary graveyard location saved")
	check(STORY.begin(session,index),"canonical explicit child story discovery recorded")
	var map=MAP.instantiate()
	root.add_child(map)
	for i in range(4): await process_frame
	var initial: Dictionary=session.world.snapshot().duplicate(true)
	var initial_rng: int=session.world.rng.state
	var initial_receipts: Array=session.world.reward_receipts.duplicate()

	map.show_graveyard_child_beat(index,0)
	var art=get_art(map)
	check(is_instance_valid(art),"original discovery picture shown in real story overlay")
	if art!=null:
		var expected: Vector2=Vector2(243.2,136.8)
		var dimensions: Vector2=Vector2(793.6,446.4)
		var entry_position: Vector2=expected + dimensions*Vector2(-0.048,-0.19)
		check(art.texture != null and art.texture.resource_path==BEATS.BASE_ART,"user original child WebP remains unmodified")
		check(art.get_meta("ui_custom_open_motion",false),"board image opts out of conflicting generic 6px entrance")
		check(art.position.distance_to(entry_position)<0.1,"CSS initial -4.8% / -19% position is applied")
		check(near_number(art.rotation_degrees,-7,0.01) and near_number(art.scale.x,0.94,0.01),"board art initially tilted -7 degrees and scaled to 94%")
		check(near_number(art.modulate.a,0.48,0.01) and art.pivot_offset.distance_to(dimensions*Vector2(0.5,0.54))<0.1,"48% alpha and 50%/54% rotation origin")
		check(MOTION.DROP_KEYS.size()==6 and near_number(MOTION.DROP_SECONDS,0.66,0.001),"source six keyframes cover 660ms")
		await create_timer(0.77).timeout
		check(art.position.distance_to(expected)<0.8,"art lands at original scene rect after bounce")
		check(art.scale.distance_to(Vector2.ONE)<0.01 and absf(art.rotation_degrees)<0.1 and near_number(art.modulate.a,1,0.01),"end of drop restores natural scale, rotation and opacity")
		check(is_instance_valid(map.overlay.get_node_or_null("PanelEffectsModule")),"normal modal fades still exist while art uses custom motion")
	check(not has_button(map,"아이를 구한다") and has_button(map,"계속"),"initial story never grants a choice without clicks")
	check(map.overlay.get_node_or_null("StoryCharacterLayer")==null,"first frame does not pre-reveal ghoul")

	map.show_graveyard_child_beat(index,1)
	art=get_art(map)
	check(is_instance_valid(art) and not art.has_meta("ui_custom_open_motion"),"threat beat does not replay original entrance effect")
	check(map.overlay.get_node_or_null("StoryCharacterLayer") is TextureRect,"existing Stage T ghoul threat remains")
	await create_timer(0.28).timeout
	check(art.position.distance_to(map.TILE_EVENT_SCENE_RECT.position)<0.8,"ordinary modal entrance still settles after 200ms")
	map.show_graveyard_child_beat(index,2)
	var hint=get_hint(map)
	check(hint is Label and hint.text=="▼","child parchment next indicator still exists with original glyph")
	check(map.overlay.get_node_or_null("StoryDialogueFrame") is TextureRect,"Stage 5P original dialogue frame remains")
	if hint!=null:
		check(hint.get_meta("ui_custom_open_motion",false) and hint.mouse_filter==Control.MOUSE_FILTER_IGNORE,"next indicator animates without blocking input or competing modal motion")
		check(near_number(hint.position.y,653,0.1) and near_number(hint.modulate.a,0.45,0.01),"first CSS cue frame starts at rest and 45% opacity")
		await create_timer(0.29).timeout
		check(hint.position.y>654.2 and hint.position.y<657.5,"900ms cue moves down by up to 4px")
		check(hint.modulate.a>0.6 and hint.modulate.a<=1.01,"cue gains opacity over first half cycle")
		await create_timer(0.50).timeout
		check(hint.position.y<656.2 and hint.position.y>=653.0,"next cue returns toward original base in the same loop")
		check(hint.modulate.a<0.9 and hint.modulate.a>=0.44,"next cue opacity falls again in second half")

	map.show_graveyard_child_beat(index,3)
	check(get_hint(map)==null,"explicit decision scene does not display a misleading Continue cue")
	check(has_button(map,"아이를 구한다") and has_button(map,"지나친다"),"choice buttons remain unchanged and accessible")
	check(session.world.snapshot()==initial and session.world.rng.state==initial_rng,"visual-only opening/closing across four beats never changes save or RNG")
	check(session.world.reward_receipts==initial_receipts and session.encounter.is_empty(),"animation awards nothing and does not start a fight")
	map.close_overlay()
	check(not is_instance_valid(map.overlay) and map.presentation.gauge.visible,"closing the story clears animated nodes and restores map chrome")
	map.show_graveyard_child_beat(index,0)
	map.close_overlay()
	await create_timer(0.74).timeout
	check(not is_instance_valid(map.overlay),"rapid close during board drop cannot resurrect its tween")
	map.show_graveyard_child_beat(index,2)
	map.close_overlay()
	await create_timer(1.00).timeout
	check(not is_instance_valid(map.overlay),"rapid close during infinite next-cue loop leaves no overlay")

	check(STORY.advance(session,index,0),"only real Continue state operation persists next beat")
	var snapshot: Dictionary=session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==snapshot and STORY.current_beat(session)==1,"reload resumes saved threat beat with no animation state stored")
	map=MAP.instantiate()
	root.add_child(map)
	for i in range(4): await process_frame
	check(is_instance_valid(get_art(map)) and is_instance_valid(map.overlay.get_node_or_null("StoryCharacterLayer")),"resume restores original threat picture and ghoul, no fake initial bounce")
	check(not get_art(map).get_meta("ui_custom_open_motion",false),"reconnected threat scene does not replay discovery bounce")
	map.queue_free()
	await process_frame
	session.save_file_path=previous_path
	if created: session.queue_free()
	clear_save()
	check(not FileAccess.file_exists(save),"isolated test save removed, player save preserved")
	print("UI_STORY_ENTRY_STAGE5U: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
