extends SceneTree
## Stage 5V: seven real saved knight-commander beats, original portrait positioning,
## mirror, 0.52s / 0.48s entrance and restoration after interrupted dialogue.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const GRAVE = preload("res://systems/story_event_entry.gd")
const RUMOR = preload("res://systems/village_rumor_entry.gd")
const RUMOR_BEATS = preload("res://systems/village_rumor_beats.gd")
const COMMANDER = preload("res://systems/knight_commander_entry.gd")
const BEATS = preload("res://systems/knight_commander_beats.gd")
const MOTION = preload("res://systems/knight_commander_portrait_motion.gd")
var passed: int = 0
var failed: int = 0
var save: String = ""

class Victory:
	extends RefCounted
	func winner() -> String: return "ally"
	func find_id(_id: String) -> Dictionary: return {}

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-commander-portrait: ",message)
	else:
		failed += 1
		printerr("FAIL ui-commander-portrait: ",message)

func clean() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))

func portrait(map: Control, player_reply: bool) -> TextureRect:
	if not is_instance_valid(map.overlay): return null
	return map.overlay.get_node_or_null("PlayerStoryPortrait" if player_reply else "CommanderStoryPortrait") as TextureRect

func near(a: float,b: float,tolerance: float = 0.2) -> bool:
	return absf(a-b)<tolerance

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	save = "user://ui_commander_stage5v_%d.json" % OS.get_process_id()
	clean()
	var session = root.get_node_or_null("RunSession")
	var created: bool = session==null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var former: String = session.save_file_path
	session.save_file_path=save
	session.start_new_world()
	var grave: int=session.world.tiles.find("graveyard")
	var village: int=session.world.tiles.find("village")
	check(grave>=0 and village>=0,"real generated world contains child and commander story tiles")
	if grave<0 or village<0:
		session.save_file_path=former
		if created: session.queue_free()
		clean()
		quit(1)
		return
	var map = MAP.instantiate()
	root.add_child(map)
	for i in range(4): await process_frame

	# Use the real source storyline gates, not injected story flags.
	session.world.position=grave
	check(GRAVE.begin(session,grave),"actual graveyard story discovery persisted")
	check(GRAVE.choose(session,grave,"protect_child"),"original child-rescue decision persisted")
	check(session.start_story_encounter(GRAVE.EVENT_ID,grave,[session.world.roster[0].id]),"source rescue encounter started from owned monster")
	check(session.finish_encounter(Victory.new()),"story victory genuinely resolved")
	check(session.acknowledge_graveyard_battle_result(),"saved child rescue outcome acknowledged")
	session.world.position=village
	check(RUMOR.begin(session,village)==RUMOR.RESCUED_ID,"saved village rumor follows actual child rescue")
	for i in range(RUMOR_BEATS.count(RUMOR.RESCUED_ID)):
		check(RUMOR.advance(session,village,RUMOR.RESCUED_ID,i),"authentic rescued-rumor beat %d saved" % i)
	check(COMMANDER.begin(session,village),"source knight commander story unlock saved")
	check(COMMANDER.current_beat(session)==0,"seven-beat commander scene starts at arrival")

	var scene_rect: Rect2=map.TILE_EVENT_SCENE_RECT
	var commander_bounds: Rect2=MOTION.source_rect(scene_rect,false)
	var player_bounds: Rect2=MOTION.source_rect(scene_rect,true)
	check(commander_bounds.position.distance_to(scene_rect.position+scene_rect.size*Vector2(0.45,0.01))<0.01,"original right 3%, bottom 25%, width 52%, height 74%")
	check(player_bounds.position.distance_to(scene_rect.position+scene_rect.size*Vector2(0.04,0.12))<0.01,"original left 4%, bottom 25%, width 41%, height 63%")
	check(commander_bounds.size.distance_to(scene_rect.size*Vector2(0.52,0.74))<0.01 and player_bounds.size.distance_to(scene_rect.size*Vector2(0.41,0.63))<0.01,"independent commander/player artwork size matches source CSS")
	check(commander_bounds.position.x>player_bounds.position.x and commander_bounds.size.x>player_bounds.size.x,"source alternates visually between opposite sides")
	check(near(MOTION.COMMANDER_ENTRY_SECONDS,0.52,0.001) and near(MOTION.PLAYER_ENTRY_SECONDS,0.48,0.001),"separate CSS .52/.48 second entrance durations")
	var visual_start: Dictionary=session.world.snapshot().duplicate(true)
	var receipts: Array=session.world.reward_receipts.duplicate()

	for i in range(BEATS.count()):
		var beat: Dictionary=BEATS.beat(i)
		var is_player: bool=str(beat.id)=="player_reply"
		var animated: bool=beat.id in ["arrival","recognition","player_reply"]
		var expected: Rect2=player_bounds if is_player else commander_bounds
		var expected_name: String="PlayerStoryPortrait" if is_player else "CommanderStoryPortrait"
		check(COMMANDER.current_beat(session)==i,"visible commander beat %d is the actual saved progress" % i)
		map.show_knight_commander_beat(village)
		var art=portrait(map,is_player)
		check(art is TextureRect and art.name==expected_name,"beat %d displays only expected named portrait" % i)
		check(portrait(map,not is_player)==null,"beat %d hides portrait from the other side" % i)
		if art != null:
			var intended: String=str(beat.portrait)
			check(art.texture==map.texture(intended) and art.texture.resource_path==intended,"beat %d retains original recovered WebP resource" % i)
			check(art.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and art.mouse_filter==Control.MOUSE_FILTER_IGNORE,"beat %d portrait stays aspect-correct, click-through" % i)
			check(art.flip_h==not is_player,"beat %d only commander is horizontally mirrored" % i)
			check(art.get_meta("ui_custom_open_motion",false),"beat %d disables competing generic portrait motion only" % i)
			check(art.size.distance_to(expected.size)<0.02 and art.pivot_offset.distance_to(Vector2(art.size.x/2.0,art.size.y))<0.02,"beat %d source footprint and foot pivot" % i)
			if animated:
				check(art.position.distance_to(expected.position+art.size*MOTION.START_OFFSET_FRACTION)<0.1,"beat %d enters from 7% left and 2% down" % i)
				check(near(art.scale.x,0.96,0.01) and near(art.modulate.a,0.0,0.01),"beat %d animated entrance starts at 96% size and transparent" % i)
				await create_timer(0.64).timeout
			else:
				check(art.position.distance_to(expected.position)<0.1 and near(art.modulate.a,1,0.01),"beat %d never invents an entry animation" % i)
			check(art.position.distance_to(expected.position)<0.8 and near(art.modulate.a,1,0.02) and art.scale.distance_to(Vector2.ONE)<0.03,"beat %d portrait settles exactly at source CSS position" % i)
			check(art.visible and art.position.x>=0 and art.position.y>=0 and art.position.x+art.size.x<1280 and art.position.y+art.size.y<720,"beat %d stays within 1280x720 screen" % i)
		check(map.overlay.get_children().any(func(n): return n is Button and n.text==("마치기" if BEATS.is_final(i) else "계속")),"beat %d retains real explicit Continue/Finish" % i)
		check(session.world.snapshot()==visual_start,"beat %d artwork creates no saved flags, items or RNG updates" % i)
		map.close_overlay()
		check(not is_instance_valid(map.overlay),"beat %d closes old portrait scene" % i)
		if i<BEATS.count()-1:
			check(COMMANDER.advance(session,village,i),"only genuine button contract advances beat %d" % i)
			visual_start=session.world.snapshot().duplicate(true)

	check(session.world.reward_receipts==receipts and session.encounter.is_empty(),"all original dialogue portraits leave battle and reward data unchanged")
	# Cancel tweens midflight; reopening same saved beat must not consume it.
	map.show_knight_commander_beat(village)
	map.close_overlay()
	await create_timer(0.68).timeout
	check(not is_instance_valid(map.overlay),"rapid close during saved final beat frees image node and tweens")
	var before_reload: Dictionary=session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==before_reload and COMMANDER.current_beat(session)==BEATS.count()-1,"reload retains final saved commander beat and no visual state")
	map=MAP.instantiate()
	root.add_child(map)
	for i in range(4): await process_frame
	check(COMMANDER.current_beat(session)==BEATS.count()-1,"reconnected game maintains same story choice point")
	map.show_knight_commander_beat(village)
	var final_portrait=portrait(map,false)
	check(is_instance_valid(final_portrait) and final_portrait.flip_h and final_portrait.position.distance_to(commander_bounds.position)<0.2,"saved final beat restores static mirrored commander")
	check(session.get_story_event(COMMANDER.EVENT_ID).status=="seen","opening artwork alone does not finish story or activate quest")
	map.close_overlay()
	map.queue_free()
	await process_frame
	session.save_file_path=former
	if created: session.queue_free()
	clean()
	check(not FileAccess.file_exists(save),"temporary isolated save removed, player save untouched")
	print("UI_COMMANDER_PORTRAITS_STAGE5V: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
