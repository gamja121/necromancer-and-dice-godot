extends SceneTree
## Hosted Windows actual graphical screenshots at three contamination values.
## Presentation-only preview; never changes a saved gameplay value.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
var failures: int = 0
var captures: int = 0
var output: String = ""
var prior_hashes: Dictionary = {}

func check(ok: bool, message: String) -> void:
	if ok: print("PASS contamination-native-gui: ",message)
	else:
		failures += 1
		printerr("FAIL contamination-native-gui: ",message)

func _initialize() -> void:
	call_deferred("_run")

func _capture(map: Control, level: int) -> void:
	var hud: Control = map.presentation.gauge
	hud.set_value(level,true)
	for _i in range(8): await process_frame
	var image: Image = root.get_texture().get_image()
	check(image!=null and not image.is_empty(),"level %d: real Windows graphical framebuffer exists" % level)
	if image==null or image.is_empty(): return
	check(image.get_width()==1280 and image.get_height()==720,"level %d: native game 1280x720" % level)
	var crop: Image = image.get_region(Rect2i(351,379,578,192))
	var hash_context: HashingContext = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(crop.get_data())
	var fingerprint: String = hash_context.finish().hex_encode()
	check(not prior_hashes.has(fingerprint),"level %d: visual pixels differ from every prior fill state" % level)
	prior_hashes[fingerprint]=true
	var dest: String=output.path_join("contamination_%03d_of_100.png" % level)
	check(image.save_png(dest)==OK and FileAccess.file_exists(dest),"level %d: screen PNG recorded" % level)
	if FileAccess.file_exists(dest): captures+=1

func _run() -> void:
	check(OS.get_name()=="Windows","test runs on actual native Windows, not Linux headless")
	check(DisplayServer.get_name().to_lower()=="windows","native graphical driver selected")
	output = OS.get_environment("CONTAMINATION_PREVIEW_DIR")
	check(not output.is_empty(),"Windows artifact output folder configured")
	if failures>0:
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(output)==OK,"frame screenshot directory exists")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	var session: Node = root.get_node_or_null("RunSession")
	var created: bool = session==null
	if created:
		session = SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	var disposable: String="user://contamination_preview_%d.json" % OS.get_process_id()
	session.save_file_path=disposable
	session.start_new_world()
	var map: Control=MAP.instantiate()
	root.add_child(map)
	current_scene=map
	await process_frame
	check(map.presentation.gauge.uses_user-selected_art,"real board HUD uses new user-selected art")
	var snapshot: Dictionary=session.world.snapshot().duplicate(true)
	for level in [0,12,100]:
		await _capture(map,level)
	check(session.world.snapshot()==snapshot,"all screenshots are preview-only; no gameplay state changed")
	current_scene=null
	map.queue_free()
	await process_frame
	session.save_file_path=old_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		var p: String=disposable+suffix
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("CONTAMINATION_NATIVE_GUI: %d captured, %d failed" % [captures,failures])
	quit(0 if captures==3 and failures==0 else 1)
