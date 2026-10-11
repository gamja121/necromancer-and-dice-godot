extends SceneTree
## Stage 5P: original 12KB frozen HTML graveyard dialogue WebP, real
## Continue controls, save/restart and no automatic choice or combat.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const STORY = preload("res://systems/story_event_entry.gd")
const BEATS = preload("res://systems/graveyard_story_beats.gd")
const SOURCE = "res://assets/map/ui/intro-dialogue-box.webp"
var passed: int = 0
var failed: int = 0
var save: String = ""

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-grave-dialogue: ",message)
	else:
		failed += 1
		printerr("FAIL ui-grave-dialogue: ",message)

func button(map: Control, caption: String) -> Button:
	if not is_instance_valid(map.overlay): return null
	for node in map.overlay.get_children():
		if node is Button and node.visible and node.text==caption: return node
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
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var original_path: String=session.save_file_path
	session.save_file_path=save
	session.start_new_world()
	var idx: int=session.world.tiles.find("graveyard")
	check(idx>=0,"real generated board contains graveyard tile")
	var source=load(SOURCE) as Texture2D
	check(source!=null,"source-based recovered dialogue WebP imports into Godot")
	if idx<0 or source==null:
		session.save_file_path=original_path
		if created: session.queue_free()
		clear_save()
		print("UI_GRAVE_DIALOGUE_FRAME_PARITY: %d passed, %d failed" % [passed,failed])
		quit(1)
		return
	check(source.get_width()>50 and source.get_height()>20,"source WebP decodes original nonempty frame")
	session.world.position=idx
	check(session.save_world(),"test-only graveyard position persisted")
	check(STORY.begin(session,idx),"canonical production graveyard story discovered by explicit action")
	var map=MAP.instantiate()
	root.add_child(map)
	for i in range(3): await process_frame
	check(button(map,"계속")!=null,"saved discovery opens first scene with explicit Continue")
	check(map.overlay.get_node_or_null("StoryDialogueFrame")==null,"story discovery has no false child dialogue")
	check(map.overlay.get_node_or_null("StoryCharacterLayer")==null,"ghoul never appears before canonical threat beat")
	var snapshot: Dictionary=session.world.snapshot().duplicate(true)
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty(),"art initialization does not automatically begin battle")
	var advance=button(map,"계속")
	advance.pressed.emit()
	await process_frame
	check(STORY.current_beat(session)==1 and session.world.snapshot()!=snapshot,"first Continue persists exactly next story beat")
	check(map.overlay.get_node_or_null("StoryDialogueFrame")==null,"threat beat without spoken words keeps frame absent")
	check(map.overlay.get_node_or_null("StoryCharacterLayer") is TextureRect,"threat beat displays existing ghoul artwork layer")
	advance=button(map,"계속")
	advance.pressed.emit()
	await process_frame
	check(STORY.current_beat(session)==2,"second Continue reaches child dialogue beat")
	var panel: Control=map.overlay
	var frame=panel.get_node_or_null("StoryDialogueFrame") as TextureRect
	check(frame!=null,"spoken child scene creates dedicated original dialogue artwork node")
	if frame!=null:
		check(frame.texture==source and frame.texture.resource_path==SOURCE,"frame references verified recovered source image")
		check(frame.stretch_mode==TextureRect.STRETCH_SCALE,"source frame stretches to map dialogue window without letterboxing")
		print("DIAG GRAVEYARD FRAME POS ",frame.position," SIZE ",frame.size," STRETCH ",frame.stretch_mode)
		check(frame.position.distance_to(Vector2(102.4,489.6))<0.5 and frame.size==Vector2(1075.2,216.0),"8%-margins/2%-bottom/30%-height source footprint")
		check(frame.mouse_filter==Control.MOUSE_FILTER_IGNORE,"visual-only dialogue frame cannot consume touch or mouse input")
	var name=panel.get_node_or_null("StoryDialogueName") as Label
	var words=panel.get_node_or_null("StoryDialogueText") as Label
	check(name!=null and name.text=="아이","speaker explicitly labels original child")
	check(words!=null and words.text==str(BEATS.beat(2).dialogue),"source child dialogue appears on parchment independently of narration")
	if words!=null:
		check(words.get_theme_color("font_color")==Color("21150d"),"child speech uses source dark ink on original frame")
	check(panel.get_node_or_null("StoryDialogueNext") is Label,"nonchoice dialogue hints explicit next action")
	check(button(map,"계속")!=null and button(map,"나가기")!=null,"source dialog preserves existing real Continue and Exit buttons")
	check(session.encounter.is_empty() and session.world.pending_reward.is_empty(),"visual-only dialogue does not start fight or reward")
	var before_reopen: Dictionary=session.world.snapshot().duplicate(true)
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==before_reopen,"reloading dialogue scene keeps every saved event and world field unchanged")
	map=MAP.instantiate()
	root.add_child(map)
	for i in range(4): await process_frame
	panel=map.overlay
	check(is_instance_valid(panel) and panel.get_node_or_null("StoryDialogueFrame") is TextureRect,"saved spoken scene automatically restores its parchment")
	check(STORY.current_beat(session)==2 and button(map,"계속")!=null,"restored parchment resumes same scene, not story beginning")
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty(),"reload alone never starts ghoul battle")
	advance=button(map,"계속")
	advance.pressed.emit()
	await process_frame
	check(STORY.current_beat(session)==3,"third Continue persists explicit final choice scene")
	panel=map.overlay
	check(panel.get_node_or_null("StoryDialogueFrame") is TextureRect and panel.get_node_or_null("StoryDialogueText")!=null,"final choice retains original speech parchment")
	check(panel.get_node_or_null("StoryDialogueNext")==null,"choice scene does not suggest skipping the decision")
	check(button(map,"아이를 구한다")!=null and button(map,"지나친다")!=null,"both original choice controls remain accessible above parchment")
	check(session.get_story_event(STORY.EVENT_ID).status=="seen" and session.encounter.is_empty(),"looking at final choice does not auto-pick rescue or battle")
	var before_choice: Dictionary=session.world.snapshot().duplicate(true)
	var rewards: int=session.world.reward_receipts.size()
	button(map,"지나친다").pressed.emit()
	for i in range(3): await process_frame
	check(session.get_story_event(STORY.EVENT_ID).choice=="leave" and session.get_story_event(STORY.EVENT_ID).status=="complete","explicit abandon choice persists through original story contract")
	check(session.world.reward_receipts.size()==rewards and session.encounter.is_empty(),"leaving scene grants no phantom reward or combat")
	check(session.world.roster==before_choice.roster,"visual art and abandon choice do not remove monsters")
	map.queue_free()
	await process_frame
	session.save_file_path=original_path
	if created: session.queue_free()
	clear_save()
	check(not FileAccess.file_exists(save),"only isolated test save removed, production save untouched")
	print("UI_GRAVE_DIALOGUE_FRAME_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
