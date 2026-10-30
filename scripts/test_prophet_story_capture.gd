extends SceneTree
## Production abandoned route, shared book and disposable save only.
const MAP=preload("res://map.tscn")
const GRAVE=preload("res://systems/story_event_entry.gd")
const RUMOR=preload("res://systems/village_rumor_entry.gd")
const RUMOR_BEATS=preload("res://systems/village_rumor_beats.gd")
const COMMANDER=preload("res://systems/knight_commander_entry.gd")
const COMMANDER_BEATS=preload("res://systems/knight_commander_beats.gd")
const PROPHET=preload("res://systems/prophet_story_entry.gd")
const BEATS=preload("res://systems/prophet_story_beats.gd")
const CULTIST=preload("res://systems/cultist_rumor_entry.gd")
const CULTIST_BEATS=preload("res://systems/cultist_rumor_beats.gd")
const BOOK=preload("res://systems/main_story_book.gd")
const ACTIONS=preload("res://systems/place_actions.gd")
const LOADS=preload("res://systems/battle_resources.gd")
const EXPECTED_BASE="res://assets/map/events/manuscript_prophet_base.png"
const EXPECTED_ACTOR="res://assets/map/events/manuscript_prophet_actor.png"
var passed: int=0
var failed: int=0
var captures: int=0
var session: Node
var map: Control
var save: String

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> bool:
	if ok: passed+=1; print("PASS prophet-capture: ",message)
	else: failed+=1; printerr("FAIL prophet-capture: ",message)
	return ok
func until(predicate: Callable, limit: int=6000) -> bool:
	var deadline: int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func clean() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))
func new_map() -> Control:
	var next: Control=MAP.instantiate()
	root.add_child(next)
	next.map_music.stop()
	for frame in range(4): await process_frame
	return next
func dispose_map() -> void:
	if is_instance_valid(map):
		map.close_overlay()
		var reference: WeakRef=weakref(map)
		map.queue_free()
		check(await until(func():return reference.get_ref()==null),"map disposal")
	map=null
	check(await until(func():return LOADS.PendingLoads.active.is_empty()),"background loads drain")
func action(text: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for child in map.overlay.get_children():
		if child is Button and child.text==text: return child
	return null
func settle(label: String) -> bool:
	if not check(is_instance_valid(map.overlay) and map.overlay is BOOK,label+": shared story book"): return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(save)
	map.overlay.skip_opening()
	map.overlay.typewriter.reveal_all()
	await create_timer(0.75).timeout
	var panel: Control=map.overlay
	check(panel.scale==BOOK.DISPLAY_SCALE and panel.position==BOOK.DISPLAY_POSITION,"shared book transform")
	check(panel.art.position==BOOK.ART_RECT.position and panel.art.size==BOOK.ART_RECT.size and panel.art.clip_contents,"fixed clipped illustration")
	var prose: Array[Label]=[]
	var buttons: Array[Button]=[]
	for child in panel.get_children():
		if child is Label and child.has_meta("book_copy_role") and not child.has_meta("book_skip"):
			check(Rect2(690,124,490,475).encloses(Rect2(child.position,child.size)),"copy remains on right page")
			if child.get_meta("book_copy_role") in ["narration","speech"]:
				prose.append(child)
				check(child.visible_characters==-1 and child.get_theme_font_size("font_size")>=16,"readable settled body")
				check(child.get_line_count()*child.get_line_height()<=child.size.y+1.0,"body fits without clipping")
		if child is Button:
			buttons.append(child)
			check(Rect2(690,124,490,475).encloses(Rect2(child.position,child.size)),"action remains on right page")
	for copy in prose:
		check(not copy.get_global_rect().intersects(panel.art.get_global_rect()),"art and prose do not overlap")
		for button in buttons: check(not Rect2(copy.position,copy.size).intersects(Rect2(button.position,button.size)),"prose and actions do not overlap")
	for first in range(buttons.size()):
		for second in range(first+1,buttons.size()): check(not Rect2(buttons[first].position,buttons[first].size).intersects(Rect2(buttons[second].position,buttons[second].size)),"actions do not overlap")
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes,label+": rendering preserves saved state and RNG")
	return true
func snap(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var shot: Image=root.get_texture().get_image()
	check(shot.get_size()==Vector2i(1280,720),"native viewport "+tag)
	if check(shot.save_png("res://prophet_story_%s.png" % tag)==OK,"rendered screenshot "+tag): captures+=1

func inspect_art_sources() -> void:
	check(PROPHET.BASE_ART==EXPECTED_BASE and BEATS.BASE==EXPECTED_BASE,"uses repainted manuscript background, not the old woodcut")
	check(PROPHET.PORTRAIT_ART==EXPECTED_ACTOR and BEATS.PROPHET==EXPECTED_ACTOR,"uses repainted landscape manuscript actor")
	for path in [EXPECTED_BASE,EXPECTED_ACTOR]:
		var pixels: Image=Image.load_from_file(path)
		if not check(pixels!=null and not pixels.is_empty(),"read source artwork "+path): continue
		check(pixels.get_size()==Vector2i(1672,941),"same native resolution as existing main-event manuscripts")
		var imported: Texture2D=load(path) as Texture2D
		check(imported!=null and imported.get_image().has_mipmaps(),"mipmaps retain detail in the small storybook illustration")
		if path==EXPECTED_ACTOR:
			var visible: Rect2i=pixels.get_used_rect()
			check(visible.has_area() and pixels.get_pixel(1000,400).a>0.9 and pixels.get_pixel(1200,680).a>0.9,"visible character and orb retain landscape registration")
			for corner in [Vector2i(0,0),Vector2i(1671,0),Vector2i(0,940),Vector2i(1671,940),Vector2i(300,470)]:
				check(is_zero_approx(pixels.get_pixelv(corner).a),"foreground has real transparent exterior "+str(corner))

func scenario() -> void:
	inspect_art_sources()
	session.start_new_world()
	session.world.laps=1
	session.world.contamination=40
	session.world.generate()
	check(session.save_world(),"isolated generated board")
	var grave: int=session.world.tiles.find("graveyard")
	var village: int=session.world.tiles.find("village")
	var camp: int=session.world.tiles.find("fortune-teller-camp")
	if not check(grave>=0 and village>=0 and camp>=0,"generated story anchors"): return
	session.world.position=grave
	if not check(GRAVE.begin(session,grave) and GRAVE.choose(session,grave,"leave"),"actual child abandonment"): return
	session.world.position=village
	if not check(RUMOR.begin(session,village)==RUMOR.ABANDONED_ID,"actual abandoned rumor"): return
	for beat in range(RUMOR_BEATS.count(RUMOR.ABANDONED_ID)):
		if not check(RUMOR.advance(session,village,RUMOR.ABANDONED_ID,beat),"rumor checkpoint "+str(beat)): return
	if not check(COMMANDER.begin(session,village) and COMMANDER.route(session)=="prophet","actual prophet referral"): return
	for beat in range(3): check(COMMANDER.advance(session,village,beat),"commander checkpoint "+str(beat))
	map=await new_map()
	map.show_knight_commander_beat(village)
	if not await settle("commander referral"): return
	await snap("01_commander_prophet")
	for beat in range(3,COMMANDER_BEATS.count("prophet")): check(COMMANDER.advance(session,village,beat),"referral acknowledgement "+str(beat))
	map.close_overlay()
	var receipts: Array=session.world.reward_receipts.duplicate()
	session.world.position=camp
	check(session.save_world(),"actual camp arrival saved")
	var before: Dictionary=session.world.snapshot().duplicate(true)
	map.show_tile(camp,false)
	check(session.get_story_event(PROPHET.EVENT_ID).status=="unseen" and session.world.snapshot()==before,"preview cannot discover prophet")
	map.close_overlay()
	map.show_tile(camp,true)
	if not check(session.get_story_event(PROPHET.EVENT_ID).status=="seen","actual arrival discovers prophet"): return
	for beat in range(BEATS.count()):
		check(PROPHET.current_beat(session)==beat,"saved prophet checkpoint "+str(beat))
		if not await settle("prophet "+str(beat)): return
		var data: Dictionary=BEATS.beat(beat)
		var background: TextureRect=map.overlay.find_child("ProphetStoryBackground",true,false) as TextureRect
		var portrait: TextureRect=map.overlay.find_child("ProphetStoryPortrait",true,false) as TextureRect
		check(background!=null and background.texture.resource_path==PROPHET.BASE_ART,"approved background layer")
		if background!=null:
			check(background.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"background uses shared manuscript sampling")
		if str(data.get("visual","base"))=="portrait":
			check(portrait!=null and portrait.texture.resource_path==PROPHET.PORTRAIT_ART and portrait.get_parent()==map.overlay.art,"reference portrait in illustration")
			if portrait!=null:
				check(portrait.material is ShaderMaterial and portrait.mouse_filter==Control.MOUSE_FILTER_IGNORE and is_equal_approx(portrait.modulate.a,1.0),"orb shader and settled nonblocking portrait")
				check(portrait.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"actor uses shared manuscript sampling")
				if background!=null:
					check(portrait.position.is_equal_approx(background.position) and portrait.size.is_equal_approx(background.size) and portrait.stretch_mode==background.stretch_mode,"foreground and background share exact full-canvas registration")
		else: check(portrait==null,"no premature prophet portrait")
		if str(data.id)=="arrival": await snap("04_prophet_arrival")
		if str(data.id)=="player_reply": await snap("05_prophet_player_reply")
		if str(data.id)=="reveal":
			before=session.world.snapshot().duplicate(true)
			await dispose_map()
			session.reload_world()
			check(session.world.snapshot()==before and PROPHET.current_beat(session)==beat,"close and reload preserve exact midbeat")
			map=await new_map()
			if not await settle("automatically restored prophet"): return
			check(session.world.snapshot()==before,"restored portrait grants no clue")
			var camp_action: Button=action("예언자의 막사 기능")
			if not check(camp_action!=null and not camp_action.disabled,"ordinary camp action available"): return
			camp_action.pressed.emit()
			if not check(await until(func():return is_instance_valid(map.overlay) and map.overlay.get_script()==ACTIONS),"story opens ordinary camp"): return
			check(map.overlay.fortune_can_roll() and map.overlay.dice==map.dice and not map.dice.disabled,"ordinary camp retains real shared die")
			check(session.world.snapshot()==before,"ordinary camp preview does not consume story")
			map.close_overlay()
			map.show_tile(camp,false)
			if not await settle("return from ordinary camp"): return
		if BEATS.is_final(beat):
			check(session.get_story_event(PROPHET.EVENT_ID).status=="seen","clue waits for explicit Finish")
			await snap("02_prophet_clue")
		map.advance_prophet_story(camp,beat)
		await process_frame
	check(PROPHET.completed(session) and session.get_story_event("monster_hunter_encounter_01").status=="unseen","prophet complete without fake hunter")
	session.world.position=village
	check(session.save_world(),"following village arrival")
	map.show_tile(village,true)
	if not check(CULTIST.route(session)=="prophet" and session.get_story_event(CULTIST.EVENT_ID).status=="seen","actual next event follows prophet clue"): return
	for beat in range(CULTIST_BEATS.count()):
		if str(CULTIST_BEATS.beat(beat,"prophet").id)=="mark":
			map.show_cultist_rumor_beat(village)
			if not await settle("cultist prophet source"): return
			await snap("03_cultist_prophet_route")
		check(CULTIST.advance(session,village,beat),"cultist acknowledgement "+str(beat))
	check(session.event_flag_is_set(CULTIST.TRACKING_FLAG) and session.world.reward_receipts==receipts and session.encounter.is_empty(),"actual tracking and no invented rewards or battle")
	if DisplayServer.get_name()!="headless": check(captures==5,"five useful rendered captures including base-only and player reply")

func run() -> void:
	root.size=Vector2i(1280,720)
	save="user://prophet_story_capture_%d.json" % OS.get_process_id()
	clean()
	session=root.get_node("RunSession")
	var original: String=session.save_file_path
	session.save_file_path=save
	await scenario()
	await dispose_map()
	var audio: Node=root.get_node_or_null("GameAudio")
	check(await until(func():return audio==null or audio.voices.is_empty()),"audio drains before shutdown")
	# The last voice is removed before its queued AudioStreamPlayer is freed.
	# Flush deferred frees before terminating the short-lived capture process.
	for frame in range(3): await process_frame
	# --fixed-fps can advance these frames in only a few real milliseconds.
	# The audio mixer releases stopped WAV playback on its own real-time
	# thread, so give it a bounded wall-clock drain after the last stop.
	var mixer_deadline: int=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<mixer_deadline: await process_frame
	# This isolated process exits here; drop the test world before quitting,
	# rather than retaining a RefCounted world in a suspended run coroutine.
	session.world=null
	session.save_file_path=original
	clean()
	print("PROPHET_STORY_CAPTURE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
