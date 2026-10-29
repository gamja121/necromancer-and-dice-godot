extends SceneTree
## Real menu transitions, including their first rendered frames.
const MAP=preload("res://map.tscn")
const DISCOVERY=preload("res://systems/location_discoveries.gd")
const LOADS=preload("res://systems/battle_resources.gd")
var passed:int=0
var failed:int=0
var map:Control
var session:Node
var out:String=""

func _initialize() -> void: call_deferred("run")
func check(ok:bool,message:String) -> void:
	if ok: passed+=1;print("PASS location-continuity: ",message)
	else: failed+=1;printerr("FAIL location-continuity: ",message)
func until(predicate:Callable) -> bool:
	var deadline:int=Time.get_ticks_msec()+10000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func action(text:String) -> Button:
	for child in map.overlay.find_children("*","Button",true,false):
		if child.text==text: return child
	return null
func rect_is(control:Control,bounds:Rect2) -> bool:
	return control!=null and control.position.distance_to(bounds.position)<0.2 and control.size.distance_to(bounds.size)<0.2
func capture(tag:String) -> void:
	if out.is_empty(): return
	await RenderingServer.frame_post_draw
	var shot:Image=root.get_texture().get_image()
	check(shot.save_png(out.path_join(tag+".png"))==OK,"native capture "+tag)
func sample(tag:String) -> void:
	for i in range(4):
		var panel:Control=map.overlay
		var art:TextureRect=panel.get_node_or_null("LocationSceneImage")
		var frame:Control=panel.get_node_or_null("LocationBattleFrame")
		check(rect_is(art,map.LOCATION_EVENT_SCENE_RECT) and frame!=null and frame.position.distance_to(map.LOCATION_EVENT_FRAME_RECT.position)<0.2,tag+": painting and frame stay fixed frame "+str(i))
		check(is_equal_approx(panel.modulate.a,1.0) and art!=null and is_equal_approx(art.modulate.a,1.0) and art.material==null,tag+": no repeated fade or ink frame "+str(i))
		if i==0 or i==3: await capture(tag+"_"+str(i))
		await process_frame
func leave_to_board() -> void:
	map.close_overlay()
	await process_frame
	await process_frame
func return_from(source:Control,tag:String) -> void:
	var source_id:int=source.get_instance_id()
	check(await until(func():return is_instance_valid(map.overlay) and map.overlay.get_instance_id()!=source_id),tag+": actual close returns to location")
	await sample(tag)

func run() -> void:
	root.size=Vector2i(1280,720)
	out=OS.get_environment("LOCATION_CONTINUITY_CAPTURE_DIR")
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	session=root.get_node("RunSession")
	var original_path:String=session.save_file_path
	var isolated:String="user://location_continuity_%d.json"%OS.get_process_id()
	session.save_file_path=isolated
	session.start_new_world()
	map=MAP.instantiate()
	root.add_child(map)
	map.map_music.stop()
	map.map_music.stream=null
	AudioServer.set_bus_mute(0,true)
	await process_frame
	var village:int=session.world.tiles.find("village")
	var altar:int=session.world.tiles.find("basic")
	session.world.tiles[altar]="altar"
	var before:Dictionary=session.world.snapshot().duplicate(true)
	var before_rng:int=session.world.rng.state
	map.show_location(village)
	check(map.overlay.get_node("LocationSceneImage").material!=null,"first village entry retains its ink reveal")
	await create_timer(0.8).timeout
	await capture("01_village")
	check(rect_is(action("마물 상점"),map.TILE_EVENT_ACTION_RECT) and rect_is(action("맵으로 나가기"),map.TILE_EVENT_EXIT_RECT),"village uses common action and exit slots")
	action("마물 상점").pressed.emit()
	await sample("02_shop_enter")
	var shop:Control=map.overlay
	shop.close_button.pressed.emit()
	await return_from(shop,"03_shop_return")
	await leave_to_board()
	map.show_location(village)
	check(map.overlay.get_node("LocationSceneImage").material!=null,"board return resets continuity for a fresh entry")
	await leave_to_board()
	map.show_location(altar)
	check(map.overlay.get_node("LocationSceneImage").material!=null,"different artwork keeps first entrance")
	await create_timer(0.8).timeout
	action("의식").pressed.emit()
	await sample("04_altar_enter")
	var ritual:Control=map.overlay
	await create_timer(1.0).timeout
	check(ritual.altar_slots.modulate.a>0.99 and ritual.altar_info.modulate.a>0.99 and ritual.hand.modulate.a>0.99,"altar custom entrance remains visible")
	ritual.close_button.pressed.emit()
	await return_from(ritual,"05_altar_return")
	await leave_to_board()
	map.show_home(true)
	await create_timer(0.3).timeout
	await capture("06_home")
	check(rect_is(action("낙인 계승"),map.TILE_EVENT_INHERITANCE_RECT) and rect_is(action("순찰경로"),map.TILE_EVENT_ACTION_RECT) and rect_is(action("다음 바퀴 출발"),map.TILE_EVENT_EXIT_RECT),"home uses same right-side button column")
	action("낙인 계승").pressed.emit()
	await sample("07_inheritance_enter")
	var inheritance:Control=map.overlay
	await create_timer(0.8).timeout
	check(inheritance.inheritance_frame.modulate.a>0.99 and inheritance.hand.modulate.a>0.99,"inheritance custom panels and cards remain visible")
	action("닫기").pressed.emit()
	await return_from(inheritance,"08_inheritance_return")
	action("순찰경로").pressed.emit()
	await sample("09_patrol_enter")
	var patrol:Control=map.overlay
	patrol.close_button.pressed.emit()
	await return_from(patrol,"10_patrol_return")
	check(session.world.snapshot()==before and session.world.rng.state==before_rng,"menu navigation never changes saves rewards or RNG")
	await leave_to_board()
	session.world.laps=1
	for kind in DISCOVERY.ORDER:
		session.world.event_flags[DISCOVERY.unlock_flag(kind)]=true
		session.world.event_flags[DISCOVERY.home_flag(kind)]=true
	session.world.event_flags["ui:unlock:graveyard:home_pending"]=true
	map.show_home(true)
	await create_timer(0.3).timeout
	var scroll:ScrollContainer=map.overlay.get_node("HomeUnlockScroll")
	var rows:VBoxContainer=scroll.find_child("HomeUnlockRows",true,false)
	check(map.LOCATION_EVENT_SCENE_RECT.encloses(Rect2(scroll.position,scroll.size)),"all-unlocks viewport fits original painting")
	check(scroll.position.x+scroll.size.x<map.TILE_EVENT_ACTION_RECT.position.x,"all-unlocks viewport avoids every right-side button")
	check(rows.get_child_count()==6,"first-lap and all five discovery notices retained")
	var first_badge:Control=rows.get_child(0).find_child("UnlockNewBadge",true,false)
	check(first_badge!=null and first_badge.get_global_rect().position.y>=scroll.get_global_rect().position.y,"first NEW badge fits clipped viewport")
	await capture("11_home_all_unlocks")
	scroll.scroll_vertical=10000
	await process_frame
	await process_frame
	var last:Control=rows.get_child(rows.get_child_count()-1)
	check(scroll.get_global_rect().encloses(last.get_global_rect()),"last unlock can be scrolled fully into view")
	await capture("12_home_unlocks_scrolled")
	await leave_to_board()
	map.show_home(false)
	check(map.overlay.get_node("LocationSceneImage").material!=null,"home exterior keeps first ink reveal")
	await create_timer(0.8).timeout
	await capture("13_home_exterior")
	await leave_to_board()
	map.queue_free()
	check(await until(func():return not is_instance_valid(map)),"map closes cleanly")
	check(await until(func():return LOADS.PendingLoads.active.is_empty()),"threaded loads drained")
	var audio:Node=root.get_node_or_null("GameAudio")
	if audio!=null: audio.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	session.world=null
	session.save_file_path=original_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(isolated+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated+suffix))
	print("LOCATION_ART_CONTINUITY: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
