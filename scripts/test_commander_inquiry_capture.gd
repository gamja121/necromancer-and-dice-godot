extends SceneTree
const MAP=preload("res://map.tscn")
const BOOK=preload("res://systems/main_story_book.gd")
const FIXTURE=preload("res://scripts/cultist_mistrust_fixture.gd")
const INQUIRY=preload("res://systems/commander_inquiry_entry.gd")
const BEATS=preload("res://systems/commander_inquiry_beats.gd")
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
	if ok: passed+=1; print("PASS inquiry-capture: ",label)
	else: failed+=1; printerr("FAIL inquiry-capture: ",label)
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
	if not check(is_instance_valid(map.overlay) and map.overlay is BOOK,"production shared story book"): return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(save)
	map.overlay.skip_opening()
	map.overlay.typewriter.reveal_all()
	await create_timer(0.56).timeout
	var panel: Control=map.overlay
	check(panel.art.position==BOOK.ART_RECT.position and panel.art.size==BOOK.ART_RECT.size and panel.art.clip_contents,"fixed manuscript illustration bounds")
	var picture: TextureRect=panel.find_child("CommanderInquiryScene",true,false) as TextureRect
	check(picture!=null and picture.texture.resource_path==BEATS.ART and picture.texture.get_size()==Vector2(1672,941) and picture.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"matching high-detail manuscript and mipmap filter")
	var actions: Array[Button]=[]
	var copy: Array[Label]=[]
	for child in panel.get_children():
		if child is Button:
			actions.append(child)
			check(Rect2(690,124,490,475).encloses(Rect2(child.position,child.size)),"action inside page")
			var shown: String=child.tr(child.text)
			var width: float=child.get_theme_font("font").get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,child.get_theme_font_size("font_size")).x
			check(width<=child.size.x-33,"full button caption fits "+locale)
			if locale=="en": check(not ENGLISH.has_korean(shown),"button translated")
		if child is Label and child.has_meta("book_copy_role") and not child.has_meta("book_skip"):
			check(child.get_line_count()*child.get_line_height()<=child.size.y+1,"complete text fits "+locale)
			if locale=="en": check(not ENGLISH.has_korean(child.tr(child.text)),"copy translated")
			if child.get_meta("book_copy_role") in ["narration","speech"]: copy.append(child)
	for label in panel.find_children("*","Label",true,false):
		if label.is_visible_in_tree() and not label.has_meta("book_skip"):
			check(label.get_line_count()*label.get_line_height()<=label.size.y+1,"all visible labels including seal fit")
			if label.text in ["유보","감시"]:
				var width: float=label.get_theme_font("font").get_string_size(label.tr(label.text),HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
				check(width<=label.size.x,"seal caption remains an unbroken word")
	for first in range(actions.size()):
		for second in range(first+1,actions.size()):
			check(not Rect2(actions[first].position,actions[first].size).intersects(Rect2(actions[second].position,actions[second].size)),"choices and footer do not overlap")
	for label in copy:
		for action in actions: check(not Rect2(label.position,label.size).intersects(Rect2(action.position,action.size)),"copy and actions do not overlap")
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes,"rendering preserves exact state, file and RNG")
	return true
func snap(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var shot: Image=root.get_texture().get_image()
	if check(shot.get_size()==Vector2i(1280,720) and shot.save_png("res://commander_inquiry_%s.png" % tag)==OK,"actual framebuffer "+tag): captures+=1
func press(caption: String) -> bool:
	var action: Button=button(caption)
	if not check(action!=null and not action.disabled,"available action "+caption): return false
	action.pressed.emit()
	await process_frame
	return true
func scenario(locale: String, decision: String) -> void:
	root.get_node("GameLanguage").set_language(locale,false)
	if not check(FIXTURE.prepare_mistrust(session),"genuine first mistrust complete"): return
	var at: int=session.world.position
	await create_map()
	var before: Dictionary=session.world.snapshot().duplicate(true)
	map.show_tile(at,true)
	check(session.get_story_event(INQUIRY.EVENT_ID).status=="unseen" and session.world.snapshot()==before,"same visit cannot chain discovery even on actual arrival callback")
	map.close_overlay()
	session.world.move_serial+=1
	check(session.save_world(),"later village arrival saved")
	before=session.world.snapshot().duplicate(true)
	map.show_tile(at,false)
	check(session.get_story_event(INQUIRY.EVENT_ID).status=="unseen" and session.world.snapshot()==before,"preview never discovers inquiry")
	await dispose()
	session.reload_world()
	await create_map()
	check(session.get_story_event(INQUIRY.EVENT_ID).status=="unseen","loading alone never discovers inquiry")
	map.show_tile(at,true)
	for beat in range(3):
		if not await settle(locale): return
		check(INQUIRY.current_beat(session)==beat,"exact opening beat")
		if beat==2:
			if decision=="explain": await snap("choice_"+locale)
		else:
			if not await press("계속"): return
	var caption: String=BEATS.EXPLAIN_CHOICE if decision=="explain" else BEATS.WITHHOLD_CHOICE
	if not await press(caption): return
	if not await settle(locale): return
	if not await press("선택 변경"): return
	if not await settle(locale): return
	check(INQUIRY.current_beat(session)==2,"actual reconsider button restores choice")
	if not await press(caption): return
	for beat in range(3,BEATS.count()):
		if not await settle(locale): return
		check(INQUIRY.current_beat(session)==beat and not session.event_flag_is_set(INQUIRY.COMPLETE_FLAG),"outcome waits for Finish")
		if beat==4:
			check(button("선택 변경")==null,"acknowledged account locks choice")
			before=session.world.snapshot().duplicate(true)
			await dispose()
			session.reload_world()
			await create_map()
			check(session.world.snapshot()==before and INQUIRY.current_beat(session)==beat,"mid-response restart restores exact chosen account")
			if not await settle(locale): return
			if decision=="withhold": await snap("watch_"+locale)
		if BEATS.is_final(beat): await snap(decision+"_"+locale)
		if not await press("마치기" if BEATS.is_final(beat) else "계속"): return
	check(INQUIRY.completed(session) and session.get_story_event(INQUIRY.EVENT_ID).choice==decision,"actual Finish commits distinct response")
	before=session.world.snapshot().duplicate(true)
	map.show_tile(at,true)
	check(session.world.snapshot()==before,"later actual visit cannot repeat completed inquiry")
	await dispose()
func run() -> void:
	root.size=Vector2i(1280,720)
	session=root.get_node("RunSession")
	var original: String=session.save_file_path
	save="user://commander_inquiry_capture_%d.json" % OS.get_process_id()
	session.save_file_path=save
	clean()
	for locale in ["ko","en"]:
		for decision in ["explain","withhold"]: await scenario(locale,decision)
	await dispose()
	var audio: Node=root.get_node_or_null("GameAudio")
	check(await until(func():return audio==null or audio.voices.is_empty()),"audio drains before shutdown")
	for frame in range(3): await process_frame
	var deadline: int=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<deadline: await process_frame
	if DisplayServer.get_name()!="headless": check(captures==8,"eight actual Korean and English captures")
	session.world=null
	session.save_file_path=original
	clean()
	print("COMMANDER_INQUIRY_CAPTURE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
