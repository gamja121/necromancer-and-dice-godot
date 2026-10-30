extends SceneTree
const MAP=preload("res://map.tscn")
const BOOK=preload("res://systems/main_story_book.gd")
const FIXTURE=preload("res://scripts/cultist_mistrust_fixture.gd")
const ALTAR=preload("res://systems/cultist_altar_entry.gd")
const BEATS=preload("res://systems/cultist_altar_beats.gd")
const RUMOR=preload("res://systems/village_mistrust_entry.gd")
const RUMOR_BEATS=preload("res://systems/village_mistrust_beats.gd")
const LOADS=preload("res://systems/battle_resources.gd")
const ENGLISH=preload("res://systems/english_translation.gd")
var passed: int=0
var failed: int=0
var captures: int=0
var session: Node
var map: Control
var save: String
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> bool:
	if ok: passed+=1; print("PASS mistrust-capture: ",label)
	else: failed+=1; printerr("FAIL mistrust-capture: ",label)
	return ok
func until(predicate: Callable, limit: int=6000) -> bool:
	var deadline: int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func clean() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))
func dispose() -> void:
	if is_instance_valid(map):
		map.close_overlay()
		var reference: WeakRef=weakref(map)
		map.queue_free()
		check(await until(func():return reference.get_ref()==null),"map disposal")
	map=null
	check(await until(func():return LOADS.PendingLoads.active.is_empty()),"background loads drain")
func create_map() -> void:
	map=MAP.instantiate()
	root.add_child(map)
	map.map_music.stop()
	for frame in range(4): await process_frame
func button(caption: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for child in map.overlay.get_children():
		if child is Button and child.text==caption: return child
	return null
func settle(locale: String) -> bool:
	if not check(is_instance_valid(map.overlay) and map.overlay is BOOK,"production shared book"): return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(save)
	map.overlay.skip_opening()
	map.overlay.typewriter.reveal_all()
	await create_timer(0.56).timeout
	var panel: Control=map.overlay
	check(panel.art.position==BOOK.ART_RECT.position and panel.art.size==BOOK.ART_RECT.size and panel.art.clip_contents,"same fixed manuscript illustration")
	var actions: Array[Button]=[]
	var copy: Array[Label]=[]
	for child in panel.get_children():
		if child is Button:
			actions.append(child)
			check(Rect2(690,124,490,475).encloses(Rect2(child.position,child.size)),"action inside page")
			var text: String=child.tr(child.text)
			var width: float=child.get_theme_font("font").get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,child.get_theme_font_size("font_size")).x
			check(width<=child.size.x-33,"full button caption fits "+locale)
			if locale=="en": check(not ENGLISH.has_korean(text),"button translated")
		if child is Label and child.has_meta("book_copy_role") and not child.has_meta("book_skip"):
			check(child.get_line_count()*child.get_line_height()<=child.size.y+1,"complete text fits "+locale)
			if locale=="en": check(not ENGLISH.has_korean(child.tr(child.text)),"copy translated")
			if child.get_meta("book_copy_role") in ["narration","speech"]: copy.append(child)
	for label in panel.find_children("*","Label",true,false):
		if label.is_visible_in_tree() and not label.has_meta("book_skip"):
			check(label.get_line_count()*label.get_line_height()<=label.size.y+1,"all labels including seal fit")
	for first in range(actions.size()):
		for second in range(first+1,actions.size()):
			check(not Rect2(actions[first].position,actions[first].size).intersects(Rect2(actions[second].position,actions[second].size)),"primary choices and footer never overlap")
	for label in copy:
		for action in actions: check(not Rect2(label.position,label.size).intersects(Rect2(action.position,action.size)),"copy and actions do not overlap")
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes,"rendering preserves exact world, file and RNG")
	return true
func snap(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var shot: Image=root.get_texture().get_image()
	if check(shot.get_size()==Vector2i(1280,720) and shot.save_png("res://cultist_mistrust_%s.png" % tag)==OK,"actual framebuffer "+tag): captures+=1
func press(caption: String) -> bool:
	var action: Button=button(caption)
	if not check(action!=null and not action.disabled,"available action "+caption): return false
	action.pressed.emit()
	await process_frame
	return true
func scenario(locale: String) -> void:
	root.get_node("GameLanguage").set_language(locale,false)
	if not check(FIXTURE.prepare(session),"genuine prophet-to-altar source chain"): return
	await create_map()
	if not await settle(locale): return
	var primary: int=0
	for child in map.overlay.get_children():
		if child is Button and child.get_meta("story_button_primary",false): primary+=1
	check(primary==3,"three deliberate choices in prophet branch")
	await snap("choice_"+locale)
	if not await press(BEATS.INVESTIGATE_CHOICE): return
	for beat in range(BEATS.infiltration_count()):
		if not await settle(locale): return
		check(ALTAR.infiltration_beat(session)==beat,"saved investigation checkpoint")
		check(map.overlay.find_child("CultistSummonLayer",true,false)==null,"covert route never displays summoned battle")
		if beat==2:
			var picture: TextureRect=map.overlay.find_child("CultistInquiryScene",true,false) as TextureRect
			check(picture!=null and picture.texture.resource_path=="res://assets/map/events/manuscript_cultist_inquiry_scene.png" and picture.texture.get_size()==Vector2(1672,941) and picture.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"cart and witness use matching high-detail manuscript artwork")
			await snap("witness_"+locale)
			var before: Dictionary=session.world.snapshot().duplicate(true)
			await dispose()
			session.reload_world()
			await create_map()
			check(session.world.snapshot()==before and ALTAR.infiltration_beat(session)==beat,"restart restores exact performed act")
			if not await settle(locale): return
		if not await press("마치기" if beat==BEATS.infiltration_count()-1 else "계속"): return
	check(ALTAR.completed(session) and session.event_flag_is_set(RUMOR.PENDING_FLAG),"actual UI Finish queues future rumor")
	var village: int=session.world.tiles.find("village")
	session.world.position=village
	check(session.save_world(),"next village arrival saved")
	var before: Dictionary=session.world.snapshot().duplicate(true)
	map.show_tile(village,false)
	check(session.get_story_event(RUMOR.EVENT_ID).status=="unseen" and session.world.snapshot()==before,"current village preview cannot discover rumor")
	map.close_overlay()
	await dispose()
	session.reload_world()
	await create_map()
	check(session.get_story_event(RUMOR.EVENT_ID).status=="unseen","loading alone cannot discover pending rumor")
	map.show_tile(village,true)
	for beat in range(RUMOR_BEATS.count()):
		if not await settle(locale): return
		check(RUMOR.current_beat(session)==beat and not session.event_flag_is_set(RUMOR.DISTRUST_FLAG),"rumor waits for explicit final acknowledgement")
		if beat==3:
			before=session.world.snapshot().duplicate(true)
			await dispose()
			session.reload_world()
			await create_map()
			check(session.world.snapshot()==before and RUMOR.current_beat(session)==beat,"exact mid-rumor restart")
			if not await settle(locale): return
		if beat==4: await snap("rumor_"+locale)
		if RUMOR_BEATS.is_final(beat): await snap("final_"+locale)
		if not await press("마치기" if RUMOR_BEATS.is_final(beat) else "계속"): return
	check(RUMOR.completed(session) and not session.event_flag_is_set(RUMOR.PENDING_FLAG),"actual UI commits distrust once")
	await dispose()
func run() -> void:
	root.size=Vector2i(1280,720)
	session=root.get_node("RunSession")
	var original: String=session.save_file_path
	save="user://cultist_mistrust_capture_%d.json" % OS.get_process_id()
	session.save_file_path=save
	clean()
	for locale in ["ko","en"]: await scenario(locale)
	await dispose()
	var audio: Node=root.get_node_or_null("GameAudio")
	check(await until(func():return audio==null or audio.voices.is_empty()),"audio drains before shutdown")
	for frame in range(3): await process_frame
	var deadline: int=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<deadline: await process_frame
	if DisplayServer.get_name()!="headless": check(captures==8,"eight Korean and English rendered captures")
	session.world=null
	session.save_file_path=original
	clean()
	print("CULTIST_MISTRUST_CAPTURE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
