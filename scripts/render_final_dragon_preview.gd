extends SceneTree
## Safe standalone gallery. No encounter, stats, reward or save operations.
const PRESENTATION = preload("res://systems/final_dragon_presentation.gd")
var display: Control
var presentation: Control
var status: Label
var output := ""
var record := false

func _initialize() -> void:
	call_deferred("run")

func _button(text: String, x: float, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x, 740)
	button.size = Vector2(145, 40)
	button.add_theme_font_override("font", load("res://assets/fonts/NanumBarunGothic.ttf"))
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	display.add_child(button)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			output = argument.trim_prefix("--capture=")
		if argument == "--record":
			record = true
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1280, 800)
	root.size = Vector2i(1280, 800)
	display = Control.new()
	display.size = Vector2(1280, 800)
	root.add_child(display)
	presentation = PRESENTATION.new()
	presentation.size = Vector2(1280, 720)
	presentation.auto_advance = output.is_empty()
	display.add_child(presentation)
	_button("등장 다시보기", 36, func(): presentation.play_intro())
	_button("공격", 198, func(): presentation.play_motion("attack"))
	_button("피격", 360, func(): presentation.play_motion("hit"))
	_button("퇴장", 522, func(): presentation.play_motion("death"))
	_button("일시정지 / 재생", 684, func(): presentation.set_paused(not presentation.paused))
	_button("0.5 / 1 / 2 배속", 846, func(): presentation.set_playback_speed(0.5 if presentation.playback_speed == 2.0 else presentation.playback_speed * 2.0))
	_button("잔잔한 연출", 1008, func(): presentation.play_intro(true))
	if not presentation.play_intro():
		push_error("Final dragon assets are missing. Import the project first.")
		quit(1)
		return
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		await capture_gallery()
		presentation.stop()
		display.queue_free()
		await process_frame
		print("FINAL_DRAGON_GALLERY: native screenshots and " + ("recording" if record else "stills") + " saved to " + output)
		quit(0)

func save_picture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.save_png(output.path_join(name)) != OK:
		push_error("Cannot save dragon preview " + name)

func capture_gallery() -> void:
	var frame := 0
	var milestones := [8, 25, 45, 64]
	for index in range(65):
		presentation.advance(1.0 / 12.0)
		if record:
			await save_picture("frame-%04d.png" % frame)
			frame += 1
		elif milestones.has(index):
			await save_picture("intro-%02d.png" % index)
	presentation.play_motion("attack")
	for index in range(15):
		presentation.advance(1.0 / 12.0)
		if record:
			await save_picture("frame-%04d.png" % frame)
			frame += 1
		elif index == 6:
			await save_picture("attack.png")
	presentation.play_motion("hit")
	for index in range(5):
		presentation.advance(1.0 / 12.0)
		if record:
			await save_picture("frame-%04d.png" % frame)
			frame += 1
	presentation.play_motion("death")
	for index in range(24):
		presentation.advance(1.0 / 12.0)
		if record:
			await save_picture("frame-%04d.png" % frame)
			frame += 1
		elif index == 13:
			await save_picture("departure.png")
	print("FINAL_DRAGON_RECORD: %d frames at 12 fps" % frame)
