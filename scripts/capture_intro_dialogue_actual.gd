extends SceneTree
## Capture real rendered pixels from the game's actual Intro scene.
## No mocked UI, generated art, gameplay changes, or player save writes.
const INTRO = preload("res://intro.tscn")
const BEAT_INDEX = 10 # Knight commander: "살아서 돌아와라."
var passed: int = 0
var failed: int = 0

func check(ok: bool, description: String) -> bool:
	if ok:
		passed += 1
		print("PASS intro-gui: ",description)
	else:
		failed += 1
		printerr("FAIL intro-gui: ",description)
	return ok

func _initialize() -> void:
	call_deferred("_run")

func capture(intro: Control, directory: String, filename: String, beat_index: int) -> void:
	check(intro.line_index == beat_index,"real intro is displaying scripted beat " + str(beat_index))
	check(not intro.dialogue_typewriter.is_revealing(),"actual scripted text is fully revealed for capture")
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var screen: Image = root.get_texture().get_image()
	if not check(screen != null and not screen.is_empty(),"Godot graphical renderer produced pixels"): return
	check(screen.get_size()==Vector2i(1280,720),"native game viewport 1280x720")
	var samples: Dictionary = {}
	for row in range(7):
		for column in range(14):
			var pixel: Color = screen.get_pixel(int((column+0.5)*screen.get_width()/14.0),int((row+0.5)*screen.get_height()/7.0))
			samples[pixel.to_html(false)] = true
	check(samples.size()>12,"screen contains nonblank, varied real game pixels")
	var target: String=directory.path_join(filename)
	check(screen.save_png(target)==OK,"saved genuine in-engine frame as " + filename)
	print("INTRO_REAL_GUI_SCREENSHOT: ",target)

func _run() -> void:
	if not check(DisplayServer.get_name()!="headless","running graphical Godot driver, not headless"): quit(1); return
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	AudioServer.set_bus_mute(0,true)
	var directory: String = OS.get_environment("INTRO_CAPTURE_DIR")
	if directory.is_empty(): directory=ProjectSettings.globalize_path("user://intro-gui-capture")
	if not check(DirAccess.make_dir_recursive_absolute(directory)==OK,"screenshot directory exists"): quit(1); return
	var intro: Control=INTRO.instantiate()
	root.add_child(intro)
	current_scene=intro
	for frame in range(6): await process_frame
	check(intro.lines.size()>BEAT_INDEX,"original intro has all scripted dialogue beats")
	check(intro.dialogue_stage.get_node_or_null("IntroDialogueBox")!=null,"upgraded in-game dialogue exists")
	for index in range(BEAT_INDEX+1):
		intro.dialogue_typewriter.reveal_all()
		intro.advance()
		intro.dialogue_typewriter.reveal_all()
		if index==0:
			await create_timer(0.2).timeout
			await capture(intro,directory,"01_knight_commander_first_line.png",0)
	check(intro.speaker_label.text=="기사단장" and intro.text_label.text=="살아서 돌아와라.",
		"real final commander text and speaker match authored game script")
	await create_timer(0.8).timeout
	await capture(intro,directory,"02_knight_commander_last_line.png",BEAT_INDEX)
	current_scene=null
	intro.queue_free()
	await process_frame
	print("INTRO_GUI_CAPTURE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
