extends SceneTree
## Stage 5P: live child story with the reconstructed exact source
## dialogue frame, explicit scene progression and saved reload.
const MAP=preload("res://map.tscn")
const SESSION=preload("res://systems/run_session.gd")
const ENTRY=preload("res://systems/story_event_entry.gd")
const BEATS=preload("res://systems/graveyard_story_beats.gd")
const FRAME="res://assets/map/events/graveyard-dialogue-frame.webp"
var passed: int=0
var failed: int=0
var save: String=""

func check(ok: bool,name: String) -> void:
	if ok:
		passed+=1
		print("PASS ui-grave-dialogue: ",name)
	else:
		failed+=1
		printerr("FAIL ui-grave-dialogue: ",name)

func find_button(parent: Control, caption: String) -> Button:
	if not is_instance_valid(parent): return null
	for child in parent.get_children():
		if child is Button and child.text==caption and child.visible: return child
	return null

func clear_save() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	save="user://ui_grave_dialogue_stage5p_%d.json" % OS.get_process_id()
	clear_save()
	var texture: Texture2D=load(FRAME)
	check(texture!=null,"reassembled 8-part canonical WebP imports into a Godot texture")
	if texture==null:
		print("UI_GRAVE_DIALOGUE_PARITY: %d passed, %d failed" % [passed,failed])
		quit(1)
		return
	check(texture.get_width()>=400 and texture.get_height()>=140,"source dialogue image has full-size dimensions, not the truncated 12k fallback")
	var pixels: Image=texture.get_image()
	check(pixels!=null and not pixels.is_empty(),"source parchment really decodes pixel content")
	var session=root.get_node_or_null("RunSession")
	var owns: bool=session==null
	if owns:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var original_path: String=session.save_file_path
	session.save_file_path=save
	session.start_new_world()
	var grave: int=session.world.tiles.find("graveyard")
	check(grave>=0,"canonical map includes graveyard location")
	if grave<0:
		session.save_file_path=original_path
		if owns:session.queue_free()
		clear_save()
		quit(1)
		return
	session.world.position=grave
	check(session.save_world(),"disposable test map saved at the graveyard")
	var map=MAP.instantiate()
	root.add_child(map)
	for i in 3: await process_frame
	check(not is_instance_valid(map.overlay),"unseen story never appears solely from reload")
	check(ENTRY.begin(session,grave),"real first-visit story discovery saves correctly")
	map.show_graveyard_child_intro(grave)
	check(is_instance_valid(map.overlay) and map.overlay.get_node_or_null("StoryDialogueFrame")==null,"story opening narration is not covered by an early dialogue frame")
	check(find_button(map.overlay,"계속")!=null,"first scene requires explicit continue")
	var rng_before: int=session.world.rng.state
	for step in 2:
		var b=find_button(map.overlay,"계속")
		check(b!=null,"source continue button exists for beat %d" % step)
		if b==null:break
		b.pressed.emit()
		await process_frame
		check(ENTRY.current_beat(session)==step+1,"clicked continuation saves beat %d" % (step+1))
		if step==0:
			check(map.overlay.get_node_or_null("StoryDialogueFrame")==null,"ghoul reveal alone does not show dialogue")
	check(ENTRY.current_beat(session)==2,"actual progression reaches spoken child scene")
	var panel=map.overlay
	var frame=panel.get_node_or_null("StoryDialogueFrame") as TextureRect
	check(frame!=null,"source dialogue frame appears for actual speaking beat")
	if frame!=null:
		check(frame.texture==texture and frame.stretch_mode==TextureRect.STRETCH_SCALE,"recovered original art is drawn without cropping")
		print("DIAG grave frame position=",frame.position," size=",frame.size," original desired position=",Vector2(102.4,489.6)," size=",Vector2(1075.2,216))
		check(frame.position.distance_to(Vector2(102.4,489.6))<0.5 and frame.size.distance_to(Vector2(1075.2,216))<0.5,"dialogue frame matches frozen HTML 8% inset / 30% height")
		check(frame.mouse_filter==Control.MOUSE_FILTER_IGNORE,"decorative artwork cannot intercept choice input")
	var speaker=panel.get_node_or_null("StoryDialogueName") as Label
	var speech=panel.get_node_or_null("StoryDialogueText") as Label
	var next=panel.get_node_or_null("StoryDialogueNext") as Label
	check(speaker!=null and speaker.text=="아이","speaker label positioned on the source frame")
	check(speech!=null and speech.text==str(BEATS.beat(2).dialogue),"spoken text stays exact instead of duplicating speaker in body")
	check(next!=null and next.text=="▼","original dialogue continuation marker displayed")
	if speech!=null:
		check(speech.mouse_filter==Control.MOUSE_FILTER_IGNORE and speech.get_theme_color("font_color")==Color("21150d"),"text remains readable and click-through on parchment")
	check(find_button(panel,"계속")!=null and find_button(panel,"나가기")!=null,"existing continue and close buttons remain above visual props")
	var progress_before: Dictionary=session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==progress_before,"save reload restores exactly same story beat, RNG and reward state")
	map=MAP.instantiate()
	root.add_child(map)
	for i in 4: await process_frame
	check(is_instance_valid(map.overlay) and ENTRY.current_beat(session)==2,"real map auto-resumes already-seen dialogue, not a new event")
	if is_instance_valid(map.overlay):
		check(map.overlay.get_node_or_null("StoryDialogueFrame") is TextureRect,"source parchment restored after process-style reload")
		var displayed=map.overlay.get_node_or_null("StoryDialogueText") as Label
		check(displayed!=null and displayed.text==str(BEATS.beat(2).dialogue),"reopened scene displays same original utterance")
		var b=find_button(map.overlay,"계속")
		check(b!=null,"reopened speaking beat retains explicit continue")
		if b!=null: b.pressed.emit()
		await process_frame
	check(ENTRY.current_beat(session)==3,"actual click moves to canonical choice scene")
	check(map.overlay.get_node_or_null("StoryDialogueFrame") is TextureRect,"choice scene retains source speech parchment")
	check(find_button(map.overlay,"아이를 구한다")!=null and find_button(map.overlay,"지나친다")!=null,"both original moral choices remain interactive")
	check(session.get_story_event(ENTRY.EVENT_ID).choice=="" and session.encounter.is_empty(),"speaking and artwork never auto-choose rescue or launch combat")
	check(session.world.rng.state==rng_before,"dialogue art never changes map dice RNG")
	check(not session.event_flag_is_set(ENTRY.COMPLETE_FLAG),"dialogue alone never completes child story")
	map.queue_free()
	await process_frame
	session.save_file_path=original_path
	if owns: session.queue_free()
	clear_save()
	check(not FileAccess.file_exists(save),"test JSON removed without modifying player save")
	print("UI_GRAVE_DIALOGUE_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
