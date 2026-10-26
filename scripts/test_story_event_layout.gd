extends SceneTree
## Book geometry and reveal safety; the full chain checks actual gameplay callbacks.
const MAP=preload("res://map.tscn")
const Book=preload("res://systems/main_story_book.gd")
const ART="res://assets/map/events/manuscript_commander_base.png"
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1
	else: failed+=1
	print(("PASS " if ok else "FAIL ")+message)
func _run() -> void:
	var session: Node=root.get_node("RunSession")
	var previous: String=session.save_file_path
	var scratch: String="user://book_layout_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var before: Dictionary=session.world.snapshot().duplicate(true)
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	var panel: Control=map.story_modal()
	var art: TextureRect=map.image(panel,ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	map.shared_story_frame(panel)
	map.label_at(panel,"사건 · 기사단장",Vector2(352,84),Vector2(575,42),24)
	var narration: Label=map.label_at(panel,"길목에서 무장한 기사가 당신을 기다리고 있었다.",Vector2(285,535),Vector2(710,66),17)
	var speech: Label=map.label_at(panel,"기사단장: 여기 있었구만.",Vector2(285,605),Vector2(710,50),16)
	var calls: Array[int]=[0]
	var action: Button=map.location_button(panel,"계속",Vector2(463,653),Vector2(171,48),func():calls[0]+=1,1)
	var secondary: Button=map.location_button(panel,"마을 기능",Vector2(651,653),Vector2(194,48),func():pass,4)
	var exit: Button=map.location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func():pass,4)
	await process_frame
	check(panel is Book and panel.opening,"actual story modal starts the approved cover opening")
	check(action.disabled and calls[0]==0,"opening cannot select or advance automatically")
	check(panel.page_frame.size==Vector2(1200,600),"page dimensions ignore source PNG minimum size")
	check(panel.art.size==Vector2(360,202.5) and art.size==panel.art.size,"background occupies the uniform 16:9 picture")
	check(panel.art.clip_contents and art.get_parent()==panel.art,"moving art is clipped to its book illustration")
	for progress in [0.0,0.25,0.5,0.75,1.0]:
		panel._set_progress(progress)
		check(panel.position==Book.DISPLAY_POSITION and panel.scale==Book.DISPLAY_SCALE and panel.page_frame.size==Vector2(1200,600),"book dimensions stay fixed at opening %.2f" % progress)
	panel.skip_opening()
	check(not panel.opening and not action.disabled and action.has_focus(),"opened book restores deliberate keyboard action")
	check(Rect2(narration.position,narration.size)==Rect2(702,233,432,78),"narration occupies its approved right-page lane")
	check(Rect2(speech.position,speech.size)==Rect2(702,358,432,112),"spoken text occupies a separate readable lane")
	check(speech.text=="여기 있었구만.","speaker label is separated without changing the dialogue")
	check(not Rect2(narration.position,narration.size).intersects(Rect2(speech.position,speech.size)),"narration and speech do not overlap")
	check(not Rect2(speech.position,speech.size).intersects(Rect2(action.position,action.size)),"dialogue does not overlap Continue")
	check(not Rect2(secondary.position,secondary.size).intersects(Rect2(exit.position,exit.size)),"location and return have distinct click areas")
	check(action.get_theme_stylebox("normal") is StyleBoxEmpty,"plain text choice uses an ink marker")
	action.pressed.emit()
	check(calls[0]==0,"first action reveals text without committing")
	action.pressed.emit()
	check(calls[0]==1,"second action invokes the original callback once")
	await create_timer(0.75).timeout
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots=") and DisplayServer.get_name()!="headless":
			var output: String=argument.trim_prefix("--screenshots=")
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("connected-book-smoke.png"))==OK,"native book layout capture")
	var next_panel: Control=map.story_modal()
	map.shared_story_frame(next_panel)
	map.label_at(next_panel,"습격받는 아이",Vector2(352,84),Vector2(575,42),24)
	var choice_copy: Label=map.label_at(next_panel,"아이: 도와주세요!",Vector2(285,605),Vector2(710,50),16)
	var first: Button=map.location_button(next_panel,"아이를 구한다",Vector2(284,653),Vector2(197,48),func():pass,1)
	var second: Button=map.location_button(next_panel,"지나친다",Vector2(494,653),Vector2(175,48),func():pass,2)
	await process_frame
	check(next_panel.instant and not next_panel.opening,"next scene keeps the book open")
	check(next_panel.scale==Book.DISPLAY_SCALE,"next scene does not enlarge the book")
	check(not Rect2(first.position,first.size).intersects(Rect2(second.position,second.size)),"two choices have separate rows")
	check(choice_copy.position.y+choice_copy.size.y<=first.position.y,"two-choice layout keeps text above decisions")
	check(session.world.snapshot()==before,"book presentation never changes progress, RNG or saved receipts")
	map.close_overlay()
	map.queue_free()
	await process_frame
	session.save_file_path=previous
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("STORY_EVENT_LAYOUT: %d passed, %d failed" % [passed,failed])
	# Let the audio service observe the freed book/map and drain stopped voices.
	await create_timer(0.10).timeout
	quit(0 if failed==0 else 1)
