extends SceneTree
## Visual-only event layout guard. No quest, reward, RNG or save mutations.
const MAP = preload("res://map.tscn")
const HUNTER = preload("res://systems/monster_hunter_layer_motion.gd")
const CULTIST = preload("res://systems/cultist_story_layer_motion.gd")
const COMMANDER = preload("res://systems/knight_commander_portrait_motion.gd")
const PORTAL = preload("res://systems/ritual_portal_layer_motion.gd")

var passed: int = 0
var failed: int = 0

func check(ok: bool, msg: String) -> void:
	if ok:
		passed += 1
		print("PASS story-event-layout: ",msg)
	else:
		failed += 1
		printerr("FAIL story-event-layout: ",msg)

func rect_for(node: Control) -> Rect2:
	return Rect2(node.position,node.size)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	check(session != null,"RunSession available")
	if session == null:
		quit(1)
		return
	var old_path: String = session.save_file_path
	var scratch: String = "user://story_event_layout_%d.json" % OS.get_process_id()
	session.save_file_path = scratch
	session.start_new_world()
	var map = MAP.instantiate()
	root.add_child(map)
	for i in range(3): await process_frame
	var before: Dictionary = session.world.snapshot().duplicate(true)
	var panel = map.story_modal()
	var art = map.image(panel,"res://assets/map/events/forest.jpg",map.TILE_EVENT_SCENE_RECT.position,map.TILE_EVENT_SCENE_RECT.size)
	var frame = map.shared_story_frame(panel)
	var title = map.label_at(panel,"사건 · 오래된 길",Vector2(350,84),Vector2(582,42),24)
	var narrative = map.label_at(panel,"의식이 시작되자 폐허를 감싼 그림자들이 눈을 뜬다.",Vector2(285,573),Vector2(710,64),18)
	check(panel.get_node_or_null("StorySplitSpeechFrame") == null,"silent beat has no separate character dialogue box")
	check(rect_for(frame) == Rect2(758,164,456,365),"silent narration expands to available right-hand height")
	check(rect_for(narrative) == Rect2(782,209,408,291),"silent narration uses full reading lane")
	var speech = map.label_at(panel,"기사단장: 네 마물들이 정말 저 어둠을 물리칠 수 있겠나?",Vector2(285,619),Vector2(710,34),16)
	var action = map.location_button(panel,"계속",Vector2(463,653),Vector2(171,48),func():pass,1)
	var secondary = map.location_button(panel,"마을 기능",Vector2(651,653),Vector2(194,48),func():pass,4)
	var exit = map.location_button(panel,"나가기",Vector2(866,653),Vector2(171,48),func():pass,4)
	check(panel.get_node_or_null("StorySplitSidebar") is Panel,"split story has its independent right information panel")
	check(rect_for(art) == Rect2(55,176,650,365.625),"existing 16:9 story illustration is placed left without stretching")
	check(is_equal_approx(art.size.x/art.size.y,16.0/9.0),"left scene preserves its 16:9 ratio")
	check(rect_for(title) == Rect2(772,103,427,48),"story heading lives above the right narration")
	check(rect_for(frame) == Rect2(758,164,456,233),"narration panel contracts only for spoken beats")
	check(rect_for(narrative) == Rect2(782,209,408,160),"narration is its own expanded upper right copy")
	check(rect_for(speech) == Rect2(782,434,408,79),"spoken dialogue is separate below the narration")
	check(rect_for(panel.get_node("StorySplitSpeechFrame")) == Rect2(758,403,456,132),"spoken line is backed by a separate parchment")
	check(not rect_for(narrative).intersects(rect_for(speech)),"narration and character text never overlap")
	check(not rect_for(speech).intersects(rect_for(action)),"speech does not intersect decisions")
	check(not rect_for(art).intersects(rect_for(frame)) and not rect_for(art).intersects(rect_for(panel.get_node("StorySplitSpeechFrame"))),"illustration never sits under reading zones")
	check(not rect_for(action).intersects(rect_for(secondary)) and not rect_for(action).intersects(rect_for(exit)) and not rect_for(secondary).intersects(rect_for(exit)),"story action and secondary choices have independent click areas")
	check(rect_for(action).position.x >= 758.0 and rect_for(secondary).position.x >= 758.0 and rect_for(exit).position.x >= 758.0,"all story action buttons are inside the right information region")
	check(action.position.y < secondary.position.y and exit.position.y == secondary.position.y,"choices occupy upper row and secondary exits lower row")
	var safe_scene: Rect2 = map.TILE_EVENT_SCENE_RECT
	for entry in [
		["commander",COMMANDER.source_rect(safe_scene,false)],
		["player",COMMANDER.source_rect(safe_scene,true)],
		["hunter beast",HUNTER.source_rect(safe_scene,false)],
		["hunter portrait",HUNTER.source_rect(safe_scene,true)],
		["cultist procession",CULTIST.source_rect(safe_scene,false)],
		["cultist altar",CULTIST.source_rect(safe_scene,true)],
		["portal energy",PORTAL.source_rect(safe_scene)]
	]:
		var bounds: Rect2 = entry[1]
		var transformed = map.StorySplit.map_art_rect(bounds)
		check(bounds.position.x >= safe_scene.position.x and bounds.position.y >= safe_scene.position.y and bounds.end.x <= safe_scene.end.x and bounds.end.y <= safe_scene.position.y + safe_scene.size.y,"%s source art is within its legacy scene" % entry[0])
		check(transformed.position.x >= art.position.x and transformed.position.y >= art.position.y and transformed.end.x <= art.position.x + art.size.x + 0.5 and transformed.end.y <= art.position.y + art.size.y + 0.5,"%s remapped art stays inside left scene" % entry[0])
	check(session.world.snapshot() == before,"presentation checks do not mutate current run")
	map.close_overlay()
	map.queue_free()
	await process_frame
	session.save_file_path = old_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("STORY_EVENT_LAYOUT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
