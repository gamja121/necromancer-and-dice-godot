extends SceneTree
## Shared original event-lab layout for the seven additional story families.
const MapScene=preload("res://map.tscn")
var passed=0
var failed=0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, title: String) -> void:
	if value:
		passed+=1
		print("PASS ui-story-event: ",title)
	else:
		failed+=1
		printerr("FAIL ui-story-event: ",title)
func node_by_name(parent: Node, name: String) -> Node:
	return parent.get_node_or_null(name)
func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload available")
		quit(1)
		return
	var old_path: String=session.save_file_path
	var path: String="user://ui_story_event_%d.json" % OS.get_process_id()
	session.save_file_path=path
	session.start_new_world()
	var map: Control=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	for count in [1,2,3,4]:
		var calls: Array=[0]
		var panel: Control=map.modal()
		var art: TextureRect=map.image(panel,"res://assets/map/events/graveyard-child-base-v3.webp",Vector2(243.2,136.8),Vector2(793.6,446.4))
		var title: Label=map.label_at(panel,"사건 · 테스트",Vector2(350,84),Vector2(582,42),24)
		var effect: Label=map.label_at(panel,"상황 설명",Vector2(285,548),Vector2(710,60),17)
		var dialogue: Label=map.label_at(panel,"안내: 대화",Vector2(285,616),Vector2(710,30),16)
		for index in range(count):
			map.location_button(panel,"선택 %d" % index,Vector2(320+index*181,653),Vector2(167,48),func(): calls[0]+=1,1)
		map.style_standard_story_panel(panel)
		check(node_by_name(panel,"StoryInfoPanel") is Panel,"parchment information panel at %d choices" % count)
		check(art.position==Vector2(88,86) and art.size==Vector2(715,532),"scene artwork on left without missing texture")
		check(title.position.x>=816 and effect.position.x>=816 and dialogue.position.x>=816,"title, description and dialogue remain in right column")
		var btns: Array=panel.get_children().filter(func(n): return n is Button)
		check(btns.size()==count and btns.all(func(b): return b.position.x>=816 and b.position.x+b.size.x<=1200),"all %d action buttons fit right column" % count)
		var overlap: bool=false
		for i in range(btns.size()):
			for j in range(i+1,btns.size()):
				if Rect2(btns[i].position,btns[i].size).intersects(Rect2(btns[j].position,btns[j].size)): overlap=true
		check(not overlap,"action buttons have no overlap, count %d" % count)
		btns[0].pressed.emit()
		check(calls[0]==1,"retained original onClick callback for %d choices" % count)
		map.close_overlay()
		await process_frame
	var code: String=FileAccess.get_file_as_string("res://map.gd")
	for event in ["show_village_rumor_beat","show_knight_commander_beat","show_monster_hunter_beat","show_cultist_rumor_beat","show_monster_king_hunt_beat","show_ritual_portal_beat","show_cultist_altar_beat"]:
		var begin: int=code.find("func "+event+"(")
		var end: int=code.find("\nfunc ",begin+5)
		check(begin>=0 and end>begin and code.substr(begin,end-begin).contains("style_standard_story_panel(panel)"),"original story layout connected: "+event)
	map.queue_free()
	await process_frame
	session.save_file_path=old_path
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("UI_ALL_STORY_EVENT_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
