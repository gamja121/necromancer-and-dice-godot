extends SceneTree
## Historical Stage 4B right-side information panel was intentionally
## superseded by the frozen source 1280x720 centered board at Stage 5S.
## Revalidate actual current modal, story art, narration and actions;
## never call the retired style_standard_story_panel helper.
const MapScene=preload("res://map.tscn")
var passed:int=0
var failed:int=0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, title: String) -> void:
	if value:
		passed+=1
		print("PASS ui-story-event: ",title)
	else:
		failed+=1
		printerr("FAIL ui-story-event: ",title)

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload available")
		quit(1)
		return
	var old_path:String=session.save_file_path
	var path:String="user://ui_story_event_%d.json"%OS.get_process_id()
	session.save_file_path=path
	session.start_new_world()
	var map:Control=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	var source:Rect2=map.TILE_EVENT_SCENE_RECT
	check(source==Rect2(243.2,136.8,793.6,446.4),"stage 5S source 62% width 16:9 image frame")
	for count in [1,2,3,4]:
		var calls:Array=[0]
		var panel:Control=map.modal()
		var art:TextureRect=map.image(panel,"res://assets/map/events/graveyard-child-base-v3.webp",source.position,source.size)
		var heading:Label=map.label_at(panel,"사건 · 테스트",Vector2(350,84),Vector2(582,42),24)
		var effect:Label=map.label_at(panel,"상황 설명",Vector2(285,548),Vector2(710,60),17)
		var dialogue:Label=map.label_at(panel,"안내: 대화",Vector2(285,616),Vector2(710,30),16)
		for index in range(count):
			map.location_button(panel,"선택 %d"%index,Vector2(320+index*181,653),Vector2(167,48),func():calls[0]+=1,1)
		var backdrops:Array=panel.get_children().filter(func(n):return n is ColorRect and n.get_meta("ui_backdrop",false))
		check(backdrops.size()==1 and backdrops[0].color.a>0.7,"story modal darkens the board with one backdrop for %d choices"%count)
		check(art.position==source.position and art.size==source.size and art.texture!=null,"original event image uses source centered frame for %d choices"%count)
		check(art.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and art.mouse_filter==Control.MOUSE_FILTER_IGNORE,"event art preserves aspect and never captures clicks")
		check(heading.position.y<source.position.y and effect.position.y>=540 and dialogue.position.y>=600,"source heading, narration and speech remain visible")
		var btns:Array=panel.get_children().filter(func(n):return n is Button)
		check(btns.size()==count and btns.all(func(b):return b.position.x>=0 and b.position.x+b.size.x<=1280 and b.position.y+b.size.y<=720),"all %d story action buttons fit within viewport"%count)
		var overlap:bool=false
		for i in range(btns.size()):
			for j in range(i+1,btns.size()):
				if Rect2(btns[i].position,btns[i].size).intersects(Rect2(btns[j].position,btns[j].size)):
					overlap=true
		check(not overlap,"story action buttons do not overlap for %d choices"%count)
		btns[0].pressed.emit()
		check(calls[0]==1,"story callback still requires one explicit click for %d choices"%count)
		map.close_overlay()
		await process_frame
		check(not is_instance_valid(map.overlay),"story modal closes cleanly for %d choices"%count)
	# Seven actual story families were ported in 4B, then re-laid out with
	# centered artwork in 5S. Enforce live implementation, not deleted API.
	var code:String=FileAccess.get_file_as_string("res://map.gd")
	for event in ["show_village_rumor_beat","show_knight_commander_beat","show_monster_hunter_beat","show_cultist_rumor_beat","show_monster_king_hunt_beat","show_ritual_portal_beat","show_cultist_altar_beat"]:
		var start:int=code.find("func "+event+"(")
		var end:int=code.find("\nfunc ",start+5) if start>=0 else -1
		var body:String=code.substr(start,end-start) if start>=0 and end>start else ""
		check(body.contains("var panel=modal()") and body.contains("image(panel,") and body.contains("location_button(panel,"),"source modal and image/action wiring present: "+event)
		check(not body.contains("style_standard_story_panel("),"retired Stage 4B panel is not revived: "+event)
	map.queue_free()
	await process_frame
	session.save_file_path=old_path
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("UI_ALL_STORY_EVENT_PARITY: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
