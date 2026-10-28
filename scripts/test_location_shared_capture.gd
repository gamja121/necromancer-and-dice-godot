extends SceneTree
const MAP=preload("res://map.tscn")
const STATE=preload("res://systems/map_state.gd")
const LOADS=preload("res://systems/battle_resources.gd")
var session:Node
var map:Control
var master:Dictionary
var out:String
var passed:int=0
var failed:int=0
var records:Array=[]
var original_path:String
var isolated:String
func _initialize() -> void: call_deferred("run")
func check(ok:bool,message:String) -> void:
	if ok: passed+=1;print("PASS uniformity: ",message)
	else: failed+=1;printerr("FAIL uniformity: ",message)
func until(predicate:Callable,limit:int=10000) -> bool:
	var deadline:int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func snap(tag:String,settle_frames:int=8) -> void:
	for frame in range(settle_frames): await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(1280,720),"actual viewport "+tag)
	check(image.save_png(out.path_join("location_shared_"+tag+".png"))==OK,"native screenshot "+tag)
	var panel:Control=map.overlay
	var info:Dictionary={"screen":tag,"script":panel.get_script().resource_path if panel.get_script()!=null else "Control","buttons":[],"labels":[],"parchments":[]}
	for child in panel.get_children():
		if child is ColorRect and child.get_meta("ui_backdrop",false): info["backdrop_alpha"]=child.color.a
	for child in panel.find_children("*","Label",true,false):
		info.labels.append({"text":child.text,"rect":str(child.get_global_rect()),"alignment":child.horizontal_alignment,"font":child.get_theme_font_size("font_size"),"visible":child.is_visible_in_tree()})
	for child in panel.find_children("*","Button",true,false):
		var style:StyleBox=child.get_theme_stylebox("normal")
		info.buttons.append({"text":child.text,"rect":str(child.get_global_rect()),"visible":child.is_visible_in_tree(),"disabled":child.disabled,"art":style.texture.resource_path if style is StyleBoxTexture else ""})
	for child in panel.find_children("*","TextureRect",true,false):
		if child.texture!=null and child.texture.resource_path.ends_with("fortune_parchment_strip.webp"): info.parchments.append(str(child.get_global_rect()))
	info["map_status"]={"text":map.status.text,"visible":map.status.is_visible_in_tree()}
	check(is_equal_approx(float(info.get("backdrop_alpha",0.0)),Color("030201d9").a),tag+": common dim background")
	check(info.parchments.size()==1 and info.parchments[0]==str(Rect2(340,423,600,150)),tag+": unchanged shared lower parchment")
	var headings:int=0
	for child in panel.find_children("*","Label",true,false):
		if child.is_visible_in_tree() and not child.text.is_empty() and child.get_global_rect().position.y<220: headings+=1
	check(headings==0,tag+": no upper title or separate instructions")
	if tag=="05_graveyard_found":
		check(Rect2(panel.action_button.position,panel.action_button.size)==map.TILE_EVENT_EXIT_RECT,tag+": collection uses lower exit slot")
	records.append(info)
func open(kind:String) -> void:
	check(session.world.restore(master),"shared valid world restored "+kind)
	var index:int=session.world.tiles.find(kind)
	check(index>=0,"real tile exists "+kind)
	session.world.position=index
	if kind=="fortune-teller-camp":
		var rng:=RandomNumberGenerator.new()
		for seed in range(1,1000):
			rng.seed=seed
			if rng.randi_range(1,6)==6:
				session.world.rng.seed=seed
				break
	check(session.save_world(),"isolated source fixture saves "+kind)
	map=MAP.instantiate()
	root.add_child(map)
	map.map_music.stop()
	map.map_music.stream=null
	AudioServer.set_bus_mute(0,true)
	for frame in range(3): await process_frame
	map.show_location(index)
	await create_timer(0.8).timeout
func dispose() -> void:
	var ref:WeakRef=weakref(map)
	map.queue_free()
	check(await until(func(): return ref.get_ref()==null),"scene exits")
	check(await until(func(): return LOADS.PendingLoads.active.is_empty()),"scene requests drain")
func action_named(text:String) -> Button:
	for child in map.overlay.find_children("*","Button",true,false):
		if child.text==text: return child
	return null
func run() -> void:
	root.size=Vector2i(1280,720)
	out=OS.get_environment("LOCATION_SHARED_CAPTURE_DIR")
	if out.is_empty(): out=ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(out)
	session=root.get_node("RunSession")
	original_path=session.save_file_path
	isolated="user://uniformity_%d.json"%OS.get_process_id()
	session.save_file_path=isolated
	session.start_new_world()
	session.world.lap_ready=true
	session.world.leave_home()
	for kind in ["forest","rest"]:
		if session.world.tiles.find(kind)>=0: continue
		for index in range(1,23):
			if index in [8,STATE.HOME]: continue
			if session.world.tiles[index]=="basic":
				session.world.tiles[index]=kind
				break
	for kind in ["graveyard","rest","forest"]:
		for phase in ["tile_pending","action_pending"]:
			session.world.event_flags["ui:unlock:%s:%s"%[kind,phase]]=false
	for unit in session.world.roster: unit.current_hp=maxi(1,int(unit.max_hp)-1)
	session.world.event_flags["discovery:ever_injured"]=true
	master=session.world.snapshot().duplicate(true)
	var restored=STATE.new(session.world.definitions,1)
	check(restored.restore(master),"common fixture preserves canonical schema anchors and warp pair")
	await open("graveyard")
	await snap("01_graveyard_ready")
	map.overlay.action_button.pressed.emit()
	check(await until(func(): return map.overlay.graveyard_phase=="ready"),"actual dig reveals a card")
	await snap("05_graveyard_found")
	map.overlay.action_button.pressed.emit()
	check(await until(func(): return not is_instance_valid(map.overlay)),"actual collection returns to map")
	map.show_location(session.world.position)
	await create_timer(1.6).timeout
	await snap("06_graveyard_used")
	await dispose()
	await open("rest")
	await snap("02_rest_ready")
	var heal:Button=action_named("전체 회복")
	check(heal!=null and not heal.disabled,"actual rest recovery enabled")
	heal.pressed.emit()
	await create_timer(0.08).timeout
	await snap("10_rest_heal_flash",0)
	await create_timer(2.4).timeout
	await snap("07_rest_used")
	check(session.world.roster.all(func(unit): return unit.current_hp==unit.max_hp),"actual rest healing commits")
	await dispose()
	await open("forest")
	await snap("03_hill_ready")
	map.overlay.hill_choice_buttons[3].pressed.emit()
	await snap("08_hill_selected")
	await dispose()
	await open("fortune-teller-camp")
	await snap("04_prophecy_ready")
	map.dice.pressed.emit()
	check(await until(func(): return not map.overlay.busy),"actual prophecy finishes")
	await snap("09_prophecy_used")
	await dispose()
	var audio:Node=root.get_node_or_null("GameAudio")
	if audio!=null: audio.queue_free()
	var deadline:int=Time.get_ticks_msec()+5000
	while is_instance_valid(audio) and Time.get_ticks_msec()<deadline: await process_frame
	await process_frame
	session.world=null
	session.save_file_path=original_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(isolated+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated+suffix))
	var file:=FileAccess.open(out.path_join("location_shared_native_audit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"screens":records},"  "))
	file.close()
	print("LOCATION_SHARED_CAPTURE: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
