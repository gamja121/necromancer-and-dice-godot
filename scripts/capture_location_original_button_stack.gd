extends SceneTree
## Graphical proof: original button sprites, callbacks and z-layers, newly
## positioned INSIDE the lower-right of the original location painting.
const MapScene = preload("res://map.tscn")
const Session = preload("res://systems/run_session.gd")
var passed: int = 0
var failed: int = 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, msg: String) -> void:
	if ok:
		passed += 1
		print("PASS location-button-stack: ", msg)
	else:
		failed += 1
		printerr("FAIL location-button-stack: ", msg)
func find_button(panel: Control, name: String) -> Button:
	for node in panel.find_children("*","Button",true,false):
		if node is Button and node.text == name: return node
	return null
func inspect(map: Control, labels: Array[String]) -> void:
	var panel: Control = map.overlay
	var art_rect: Rect2 = map.LOCATION_EVENT_SCENE_RECT
	var previous_y: float = -100.0
	for name in labels:
		var control: Button = find_button(panel,name)
		check(control != null, "original action exists: "+name)
		if control == null: continue
		check(art_rect.encloses(Rect2(control.position,control.size)),name+" is wholly inside painted scene")
		check(control.position.y > previous_y, name+" stacks below earlier button")
		previous_y=control.position.y
		var normal = control.get_theme_stylebox("normal") as StyleBoxTexture
		check(normal!=null and normal.texture.resource_path.begins_with("res://assets/map/ui/parchment_button_variant_"),name+" retains EXISTING UI bitmap (not a newly drawn button)")
		check(control.z_index>0 and not control.disabled, name+" remains visible/actionable in screenshot fixture")
func snap(tag: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var png: Image = root.get_texture().get_image()
	check(not png.is_empty() and png.get_size() == Vector2i(1280,720),"Godot rendered full frame "+tag)
	if png.is_empty(): return
	var capture_root:String=OS.get_environment("GRAVEYARD_CAPTURE_DIR")
	if capture_root.is_empty(): capture_root=ProjectSettings.globalize_path("res://")
	var path:String=capture_root.path_join("location_original_buttons_%s.webp"%tag)
	var err: Error=png.save_webp(path,false,0.89)
	check(err==OK and FileAccess.get_file_as_bytes(path).size()>45000,"native screenshot saved "+tag)
func _run() -> void:
	root.size=Vector2i(1280,720)
	var session: Node=root.get_node_or_null("RunSession")
	var owned: bool=session==null
	if owned:
		session=Session.new()
		session.name="RunSession"
		root.add_child(session)
	var previous: String=session.save_file_path
	var disposable: String="user://location_button_stack_capture_%d.json" % OS.get_process_id()
	session.save_file_path=disposable
	session.start_new_world()
	session.world.lap_ready=true
	session.world.leave_home()
	var grave: int=session.world.tiles.find("graveyard")
	var fortune: int=session.world.tiles.find("fortune-teller-camp")
	check(grave>=0 and fortune>=0,"real cemetery and fortune camp exist")
	if grave<0 or fortune<0: quit(1); return
	session.world.position=grave
	check(session.save_world(),"isolated location fixture saved")
	var map: Control=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	map.show_location(grave)
	inspect(map,["시체 파헤치기","맵으로 나가기"])
	await create_timer(0.6).timeout
	await snap("graveyard")
	map.close_overlay()
	map.show_location(fortune)
	inspect(map,["예언","맵으로 나가기"])
	await create_timer(0.45).timeout
	await snap("fortune")
	map.close_overlay()
	map.show_home(true)
	# Three original home buttons must also fit inside the painting.
	var house: Array[String]=["낙인 계승","순찰경로","다음 바퀴 출발"]
	# Inheritance can be disabled in a run until the next required condition;
	# only geometry/art, not eligibility, is tested for this screen.
	for i in range(house.size()):
		var btn: Button=find_button(map.overlay,house[i])
		check(btn!=null,"home original button exists "+house[i])
		if btn != null:
			check(map.LOCATION_EVENT_SCENE_RECT.encloses(Rect2(btn.position,btn.size)),"home original button fits inside painting "+house[i])
			var st=btn.get_theme_stylebox("normal") as StyleBoxTexture
			check(st!=null and st.texture.resource_path.begins_with("res://assets/map/ui/parchment_button_variant_"),"home original art preserved "+house[i])
	await create_timer(0.45).timeout
	await snap("home")
	map.close_overlay()
	map.queue_free()
	await process_frame
	var cleanup_deadline:int=Time.get_ticks_msec()+5000
	while not preload("res://systems/battle_resources.gd").PendingLoads.active.is_empty() and Time.get_ticks_msec()<cleanup_deadline: await process_frame
	var audio:Node=root.get_node_or_null("GameAudio")
	while audio!=null and not audio.voices.is_empty() and Time.get_ticks_msec()<cleanup_deadline: await process_frame
	if audio!=null: audio.queue_free()
	await create_timer(0.10).timeout
	session.world=null
	session.save_file_path=previous
	if owned: session.queue_free()
	for ext in ["",".tmp"]:
		if FileAccess.file_exists(disposable+ext): DirAccess.remove_absolute(ProjectSettings.globalize_path(disposable+ext))
	print("LOCATION_ORIGINAL_BUTTON_STACK: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
