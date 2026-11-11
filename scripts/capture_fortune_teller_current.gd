extends SceneTree
## Visual-only graphical capture of the actual current Map -> PlaceActions
## fortune-teller location and its real shared-die prophecy action.
## Disposable run; never modifies real player saves, artwork or game UI.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")

var saved_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func grab(label: String) -> bool:
	for i in range(7):
		await process_frame
	await RenderingServer.frame_post_draw
	var view: ViewportTexture = root.get_texture()
	if view == null:
		printerr("FORTUNE_CAPTURE_FAILURE: missing viewport ",label)
		return false
	var bitmap: Image = view.get_image()
	if bitmap == null or bitmap.is_empty():
		printerr("FORTUNE_CAPTURE_FAILURE: no pixels ",label)
		return false
	if bitmap.get_size() != Vector2i(1280,720):
		printerr("FORTUNE_CAPTURE_FAILURE: wrong image size ",bitmap.get_size())
		return false
	var hues: Dictionary = {}
	for y in range(18):
		for x in range(25):
			hues[bitmap.get_pixel((x * 49 + 15) % 1280, (y * 37 + 15) % 720).to_html(false)] = true
	if hues.size() < 45:
		printerr("FORTUNE_CAPTURE_FAILURE: frame looks blank ",label," colors=",hues.size())
		return false
	var output: String = ProjectSettings.globalize_path("res://fortune_actual_%s.webp" % label)
	var error: Error = bitmap.save_webp(output,false,0.88)
	if error != OK:
		printerr("FORTUNE_CAPTURE_FAILURE: could not save ",label," error=",error)
		return false
	var size: int = FileAccess.get_file_as_bytes(output).size()
	if size < 50000:
		printerr("FORTUNE_CAPTURE_FAILURE: too few bytes ",label," bytes=",size)
		return false
	print("FORTUNE_CAPTURE_SAVED: ",label," ",output," bytes=",size," distinct=",hues.size())
	saved_count += 1
	return true

func _run() -> void:
	root.size = Vector2i(1280,720)
	var existing: Node = root.get_node_or_null("RunSession")
	var is_new: bool = existing == null
	var session: Node = SESSION.new() if is_new else existing
	if is_new:
		session.name = "RunSession"
		root.add_child(session)
	var previous_save: String = session.save_file_path
	var disposable: String = "user://fortune_capture_%d.json" % OS.get_process_id()
	session.save_file_path = disposable
	session.start_new_world()
	var camp: int = session.world.tiles.find("fortune-teller-camp")
	if camp < 0:
		printerr("FORTUNE_CAPTURE_FAILURE: no fortune teller in the real map tiles")
		quit(1)
		return
	session.world.position = camp
	var seeded: bool = false
	var rng := RandomNumberGenerator.new()
	for seed in range(1,300):
		rng.seed = seed
		if rng.randi_range(1,6) == 4:
			session.world.rng.seed = seed
			seeded = true
			break
	if not seeded or not session.save_world():
		printerr("FORTUNE_CAPTURE_FAILURE: disposable map setup")
		quit(1)
		return
	var map: Control = MAP.instantiate()
	root.add_child(map)
	current_scene = map
	if not is_instance_valid(map.dice):
		printerr("FORTUNE_CAPTURE_FAILURE: real map die missing")
		quit(1)
		return
	map.show_location(camp)
	await create_timer(1.4).timeout
	if not await grab("00_location"):
		quit(1)
		return
	map.close_overlay()
	map.show_place_actions(camp)
	await create_timer(0.7).timeout
	var panel: Control = map.overlay
	if panel == null or panel.get_script().resource_path != "res://systems/place_actions.gd":
		printerr("FORTUNE_CAPTURE_FAILURE: production PlaceActions panel not open")
		quit(1)
		return
	if panel.get_node_or_null("FortuneProphecyCrystal") != null or panel.get_node_or_null("FortuneCrystalAura") != null:
		printerr("FORTUNE_CAPTURE_FAILURE: old crystal+table still present")
		quit(1)
		return
	if map.dice.disabled:
		printerr("FORTUNE_CAPTURE_FAILURE: shared die unexpectedly disabled before roll")
		quit(1)
		return
	if not await grab("01_before_roll"):
		quit(1)
		return
	# This is the actual shared die button signal path (not a synthetic text label).
	map.dice.pressed.emit()
	await process_frame
	if not panel.busy:
		printerr("FORTUNE_CAPTURE_FAILURE: actual die did not trigger prophecy")
		quit(1)
		return
	var began: int = Time.get_ticks_msec()
	while panel.busy and Time.get_ticks_msec() - began < 18000:
		await process_frame
	if panel.busy or not panel.fortune_result.visible:
		printerr("FORTUNE_CAPTURE_FAILURE: prophecy did not complete / result missing")
		quit(1)
		return
	await create_timer(0.7).timeout
	if not await grab("02_after_roll"):
		quit(1)
		return
	print("FORTUNE_ACTUAL_SCREENSHOT: %d rendered, 1280x720, live map and prophecy, 0 failures" % saved_count)
	current_scene = null
	root.remove_child(map)
	map.queue_free()
	await process_frame
	session.save_file_path = previous_save
	if is_new:
		session.queue_free()
	for extension in ["",".tmp"]:
		if FileAccess.file_exists(disposable+extension):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(disposable+extension))
	quit(0)
