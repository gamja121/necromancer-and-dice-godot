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
	var panel = map.modal()
	var frame = map.shared_story_frame(panel)
	var narrative = map.label_at(panel,"의식이 시작되자 폐허를 감싼 그림자들이 눈을 뜬다.",Vector2(285,573),Vector2(710,64),18)
	var speech = map.label_at(panel,"기사단장: 네 마물들이 정말 저 어둠을 물리칠 수 있겠나?",Vector2(285,619),Vector2(710,34),16)
	var action = map.location_button(panel,"계속",Vector2(463,653),Vector2(171,48),func():pass,1)
	var secondary = map.location_button(panel,"마을 기능",Vector2(651,653),Vector2(194,48),func():pass,4)
	var exit = map.location_button(panel,"나가기",Vector2(866,653),Vector2(171,48),func():pass,4)
	check(rect_for(frame) == Rect2(205,516,870,132),"parchment is identical for all story events")
	check(rect_for(narrative) == Rect2(275,535,730,51),"narration fixed upper ink lane")
	check(rect_for(speech) == Rect2(275,593,730,44),"dialogue fixed lower ink lane")
	check(not rect_for(narrative).intersects(rect_for(speech)),"description and spoken line do not overlap")
	check(not rect_for(narrative).intersects(rect_for(action)) and not rect_for(speech).intersects(rect_for(action)),"copy clear of primary action")
	check(not rect_for(frame).intersects(rect_for(action)) and not rect_for(frame).intersects(rect_for(secondary)) and not rect_for(frame).intersects(rect_for(exit)),"paper frame clear of all footer buttons")
	check(not rect_for(action).intersects(rect_for(secondary)) and not rect_for(secondary).intersects(rect_for(exit)),"footer buttons have independent click areas")
	var safe_scene: Rect2 = map.TILE_EVENT_SCENE_RECT
	var paper_y: float = map.SHARED_DIALOGUE_RECT.position.y
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
		check(bounds.position.x >= safe_scene.position.x and bounds.position.y >= safe_scene.position.y and bounds.end.x <= safe_scene.end.x and bounds.end.y <= paper_y - 2.0,"%s layer stays inside visible story art" % entry[0])
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
