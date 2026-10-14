extends SceneTree
## Stage 5W: source 11-beat monster hunter actual saved quest path,
## scene/portrait/player placements, selective timing, close and restart.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const GRAVE = preload("res://systems/story_event_entry.gd")
const RUMOR = preload("res://systems/village_rumor_entry.gd")
const RUMOR_BEATS = preload("res://systems/village_rumor_beats.gd")
const COMMANDER = preload("res://systems/knight_commander_entry.gd")
const COMMANDER_BEATS = preload("res://systems/knight_commander_beats.gd")
const HUNTER = preload("res://systems/monster_hunter_entry.gd")
const HUNTER_BEATS = preload("res://systems/monster_hunter_beats.gd")
const MOTION = preload("res://systems/monster_hunter_layer_motion.gd")
const PLAYER_MOTION = preload("res://systems/knight_commander_portrait_motion.gd")
var passed: int = 0
var failed: int = 0
var save_path: String = ""

class Victory:
	extends RefCounted
	func winner() -> String: return "ally"
	func find_id(_id: String) -> Dictionary: return {}

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ui-hunter-layers: ",label)
	else:
		failed += 1
		printerr("FAIL ui-hunter-layers: ",label)

func approx(a: float,b: float,epsilon: float = 0.1) -> bool:
	return absf(a-b)<epsilon

func wipe() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))

func layer(map: Control, name: String) -> TextureRect:
	if not is_instance_valid(map.overlay): return null
	return map.overlay.get_node_or_null(name) as TextureRect

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	save_path="user://ui_hunter_stage5w_%d.json" % OS.get_process_id()
	wipe()
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var former: String=session.save_file_path
	session.save_file_path=save_path
	session.start_new_world()
	# Test-only story gallery: newly gated locations do not all exist on
	# the opening board. Seed only missing places onto ordinary roads, leaving
	# production map generation, fixed anchors and story APIs untouched.
	for place in ["graveyard","unknown"]:
		if not session.world.tiles.has(place):
			var ordinary: int = session.world.tiles.find("basic")
			if ordinary >= 0: session.world.tiles[ordinary] = place
	# This historical complete-chain presentation fixture is deliberately
	# evaluated after the real contamination gate has become eligible.
	session.world.contamination = 100
	check(session.save_world(),"isolated visual-story fixture saved")
	var grave: int=session.world.tiles.find("graveyard")
	var village: int=session.world.tiles.find("village")
	var worldtree: int=session.world.tiles.find("unknown")
	check(grave>=0 and village>=0 and worldtree>=0,"visual fixture contains graveyard, village and world tree")
	if grave<0 or village<0 or worldtree<0:
		session.save_file_path=former
		if created: session.queue_free()
		wipe()
		quit(1)
		return
	var map=MAP.instantiate()
	root.add_child(map)
	for k in range(4): await process_frame
	session.world.position=grave
	check(GRAVE.begin(session,grave),"real child ambush discovered")
	check(GRAVE.choose(session,grave,"protect_child"),"genuine child rescue choice recorded")
	check(session.start_story_encounter(GRAVE.EVENT_ID,grave,[session.world.roster[0].id]),"real rescue fight starts with owned monster")
	check(session.finish_encounter(Victory.new()),"real rescue result recorded")
	check(session.acknowledge_graveyard_battle_result(),"rescue acknowledgement unlocks rumor")
	session.world.position=village
	check(RUMOR.begin(session,village)==RUMOR.RESCUED_ID,"genuine saved child rumor opened")
	for i in range(RUMOR_BEATS.count(RUMOR.RESCUED_ID)):
		check(RUMOR.advance(session,village,RUMOR.RESCUED_ID,i),"saved village rumor beat %d" % i)
	check(COMMANDER.begin(session,village),"commander story begins only after rescue rumor")
	for i in range(COMMANDER_BEATS.count()):
		check(COMMANDER.advance(session,village,i),"saved commander beat %d via genuine entry progression" % i)
	check(session.get_story_event(COMMANDER.EVENT_ID).status=="complete","commander quest finished before hunter story")
	session.world.position=worldtree
	check(HUNTER.begin(session,worldtree),"monster hunter encounter genuinely opened")
	check(HUNTER.current_beat(session)==0,"hunter is unseen until accepted, then first of 11 saved beats")

	var scene_rect: Rect2=map.TILE_EVENT_SCENE_RECT
	var beast_rect: Rect2=MOTION.source_rect(scene_rect,false)
	var portrait_rect: Rect2=MOTION.source_rect(scene_rect,true)
	var player_rect: Rect2=PLAYER_MOTION.source_rect(scene_rect,true)
	check(beast_rect.position.distance_to(scene_rect.position+scene_rect.size*Vector2(0.13,0.04))<0.01,"beast scene: left 13%, bottom 2%, width 74%, height 92%")
	check(portrait_rect.position.distance_to(scene_rect.position+scene_rect.size*Vector2(0.40,0.01))<0.01,"hunter portrait: right 2%, bottom 25%, width 58%, height 78%")
	check(player_rect.position.distance_to(scene_rect.position+scene_rect.size*Vector2(0.04,0.12))<0.01,"player reply reuses V stage left 4%/bottom 25% geometry")
	check(approx(MOTION.SCENE_ENTRY_SECONDS,0.52,0.001) and approx(MOTION.PORTRAIT_ENTRY_SECONDS,0.48,0.001),"beast/portrait respective 520ms and 480ms source durations")

	var expected_state: Dictionary=session.world.snapshot().duplicate(true)
	var original_receipts: Array=session.world.reward_receipts.duplicate()
	for beat_i in range(HUNTER_BEATS.count()):
		var beat: Dictionary=HUNTER_BEATS.beat(beat_i)
		var visual: String=str(beat.visual)
		var name: String="HunterSceneLayer" if visual=="scene" else ("HunterPortrait" if visual=="portrait" else "HunterPlayerPortrait")
		var is_scene: bool=visual=="scene"
		var is_portrait: bool=visual=="portrait"
		var animates: bool=beat.id in ["warning_reveal","unnatural","clue"] if is_scene else (beat.id in ["identify","sent_by_commander"] if is_portrait else beat.id=="player_reply")
		var expected_rect: Rect2=beast_rect if is_scene else (portrait_rect if is_portrait else player_rect)
		check(HUNTER.current_beat(session)==beat_i,"hunter beat %d is its real persisted source index" % beat_i)
		map.show_monster_hunter_beat(worldtree)
		check(is_instance_valid(map.overlay),"hunter beat %d creates a live source event overlay" % beat_i)
		var scene_layer: TextureRect=layer(map,"HunterSceneLayer")
		var hunter_layer: TextureRect=layer(map,"HunterPortrait")
		var player_layer: TextureRect=layer(map,"HunterPlayerPortrait")
		if visual=="base":
			check(scene_layer==null and hunter_layer==null and player_layer==null,"base-only arrival has no prematurely visible actors")
		else:
			var art: TextureRect=layer(map,name)
			check(art!=null,"beat %d shows correct distinct source layer" % beat_i)
			check([scene_layer,hunter_layer,player_layer].filter(func(n): return n!=null).size()==1,"beat %d shows exactly one actor/scene layer" % beat_i)
			if art!=null:
				var art_path: String=HUNTER_BEATS.visual_art(visual)
				check(art.texture==map.texture(art_path) and art.texture.resource_path==art_path,"beat %d preserves original unedited WebP" % beat_i)
				check(art.size.distance_to(expected_rect.size)<0.01 and art.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"beat %d uses safe layer footprint with aspect-preserving original art" % beat_i)
				check(art.get_meta("ui_custom_open_motion",false) and art.mouse_filter==Control.MOUSE_FILTER_IGNORE,"beat %d avoids generic 6px slide and does not capture touch" % beat_i)
				var final_alpha: float=MOTION.PORTRAIT_OPACITY if is_portrait else 1.0
				if animates:
					var offset: Vector2=MOTION.SCENE_START_OFFSET if is_scene else (MOTION.PORTRAIT_START_OFFSET if is_portrait else PLAYER_MOTION.START_OFFSET_FRACTION)
					var scale_start: float=MOTION.SCENE_START_SCALE if is_scene else (MOTION.PORTRAIT_START_SCALE if is_portrait else PLAYER_MOTION.START_SCALE)
					check(art.position.distance_to(expected_rect.position+art.size*offset)<0.15,"beat %d starts at correct entering layer offset" % beat_i)
					check(approx(art.scale.x,scale_start,0.01) and approx(art.modulate.a,0.0,0.01),"beat %d starts at source faded/shrunken state" % beat_i)
					await create_timer(0.62).timeout
				else:
					check(art.position.distance_to(expected_rect.position)<0.15 and approx(art.modulate.a,final_alpha,0.01),"beat %d does not replay source-only reveal effect" % beat_i)
				check(art.position.distance_to(expected_rect.position)<0.8 and art.scale.distance_to(Vector2.ONE)<0.02 and approx(art.modulate.a,final_alpha,0.02),"beat %d settles to CSS geometry and final alpha" % beat_i)
				check(art.position.x>=0 and art.position.y>=0 and art.position.x+art.size.x<=1280 and art.position.y+art.size.y<=720,"beat %d fits source composition inside 1280x720 viewport" % beat_i)
		check(map.overlay.get_children().any(func(n): return n is Button and n.text==("마치기" if HUNTER_BEATS.is_final(beat_i) else "계속")),"beat %d keeps real explicit continue/finish action" % beat_i)
		check(session.world.snapshot()==expected_state,"beat %d image does not change save/RNG or progression flags" % beat_i)
		map.close_overlay()
		check(not is_instance_valid(map.overlay),"beat %d destroys old visual layer" % beat_i)
		if beat_i<HUNTER_BEATS.count()-1:
			check(HUNTER.advance(session,worldtree,beat_i),"user-initiated event contract advances hunter beat %d" % beat_i)
			expected_state=session.world.snapshot().duplicate(true)

	check(session.world.reward_receipts==original_receipts and session.encounter.is_empty(),"hunter story imagery does not grant rewards or start another battle")
	map.show_monster_hunter_beat(worldtree)
	map.close_overlay()
	await create_timer(0.56).timeout
	check(not is_instance_valid(map.overlay),"close during hunter story does not revive stale visual tween")
	var snapshot: Dictionary=session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==snapshot and HUNTER.current_beat(session)==HUNTER_BEATS.count()-1,"last saved hunter beat remains intact after restart")
	map=MAP.instantiate()
	root.add_child(map)
	for k in range(4): await process_frame
	map.show_monster_hunter_beat(worldtree)
	var restored: TextureRect=layer(map,"HunterSceneLayer")
	check(restored!=null and restored.texture.resource_path==HUNTER_BEATS.SCENE,"saved clue scene restores source art")
	check(session.get_story_event(HUNTER.EVENT_ID).status=="seen" and session.world.event_flags.get(HUNTER.COMPLETE_FLAG,false)!=true,"opening final scene never auto-completes quest")
	map.close_overlay()
	map.queue_free()
	await process_frame
	session.save_file_path=former
	if created: session.queue_free()
	wipe()
	check(not FileAccess.file_exists(save_path),"only isolated test save removed")
	print("UI_HUNTER_LAYERS_STAGE5W: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
