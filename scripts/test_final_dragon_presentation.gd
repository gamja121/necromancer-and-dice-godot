extends SceneTree
const PRESENTATION = preload("res://systems/final_dragon_presentation.gd")
var passed := 0
var failed := 0
var intro_count := 0
var impact_count := 0
var completed: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
		print("PASS final-dragon: " + reason)
	else:
		failed += 1
		printerr("FAIL final-dragon: " + reason)

func run() -> void:
	var session: Node = root.get_node_or_null("RunSession")
	var save_path: String = str(session.get("save_file_path")) if session != null else ""
	var before_save := FileAccess.get_file_as_bytes(save_path) if not save_path.is_empty() and FileAccess.file_exists(save_path) else PackedByteArray()
	var stage := PRESENTATION.new()
	stage.auto_advance = false
	stage.size = Vector2(1280, 720)
	root.add_child(stage)
	stage.intro_finished.connect(func(): intro_count += 1)
	stage.attack_impact.connect(func(): impact_count += 1)
	stage.motion_finished.connect(func(motion: String): completed.append(motion))
	check(stage.assets_ready, "all 28 runtime frames can be loaded")
	for index in range(3):
		var soldier: TextureRect = stage.stage.get_node("ScaleSoldier%d" % index)
		check(soldier.size.y <= 100.1 and soldier.position.y + soldier.size.y < PRESENTATION.ART_RECT.size.y, "scale reference %d is fully visible at ordinary size" % index)
	check(not stage.playing and not stage.intro_active, "adding component does not start an encounter or presentation")
	var bytes := 0
	for motion in PRESENTATION.COUNTS:
		var previous_hash := ""
		for index in range(int(PRESENTATION.COUNTS[motion])):
			var path: String = PRESENTATION.frame_path(motion, index)
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			check(image != null and image.get_size() == PRESENTATION.FRAME_SIZE, "%s frame %d uses fixed canvas" % [motion, index + 1])
			if image == null:
				continue
			var bounds := image.get_used_rect()
			check(bounds.position.x > 6 and bounds.position.y > 6 and bounds.end.x < image.get_width() - 6 and bounds.end.y < image.get_height() - 6, "%s frame %d keeps complete silhouette inside canvas" % [motion, index + 1])
			var scale_to_page: Vector2 = PRESENTATION.DRAGON_RECT.size / Vector2(PRESENTATION.FRAME_SIZE)
			var mirrored_origin := Vector2(PRESENTATION.FRAME_SIZE.x - bounds.end.x, bounds.position.y)
			var visible_rect := Rect2(PRESENTATION.DRAGON_RECT.position + mirrored_origin * scale_to_page, Vector2(bounds.size) * scale_to_page)
			var safe_page := Rect2(Vector2(5, 5), PRESENTATION.ART_RECT.size - Vector2(10, 10))
			check(safe_page.encloses(visible_rect), "%s frame %d fits inside the actual book page with shake margin" % [motion, index + 1])
			var hash: String = FileAccess.get_sha256(path)
			if index > 0:
				check(hash != previous_hash, "%s frame %d contains motion" % [motion, index + 1])
			previous_hash = hash
			bytes += image.get_width() * image.get_height() * 4
	check(stage.play_intro(), "explicit intro starts")
	stage.advance(2.0)
	stage.set_paused(true)
	var frozen: Dictionary = stage.snapshot()
	stage.advance(99.0)
	check(stage.snapshot() == frozen, "pause freezes reveal, frame, caption and effects clock")
	stage.set_paused(false)
	stage.set_playback_speed(0.5)
	stage.advance(2.0)
	check(is_equal_approx(stage.intro_time, 3.0), "half speed advances one second in two wall seconds")
	stage.set_playback_speed(1.0)
	stage.advance(10.0)
	check(intro_count == 1 and not stage.intro_active and stage.current_motion == "idle", "intro completes once and returns to breathing idle")
	check(impact_count == 0, "intro roar never emits a combat impact")
	for repeat in range(3):
		stage.advance(3.0)
	check(intro_count == 1, "idle never retriggers intro")
	check(not stage.play_motion("unknown"), "unknown animation rejected")
	stage.play_motion("attack")
	stage.advance(PRESENTATION.impact_seconds() - 0.01)
	check(impact_count == 0, "windup produces no early impact")
	stage.set_paused(true)
	stage.advance(100.0)
	check(impact_count == 0, "paused attack produces no impact")
	stage.set_paused(false)
	stage.advance(0.02)
	check(impact_count == 1, "impact emitted at frame six")
	stage.advance(100.0)
	check(impact_count == 1 and completed.count("attack") == 1 and stage.current_motion == "idle", "large delta emits impact and completion only once")
	stage.play_motion("attack")
	stage.advance(100.0)
	check(impact_count == 2 and completed.count("attack") == 2, "a new attack has exactly one new impact")
	stage.play_motion("hit")
	stage.advance(5.0)
	check(completed.count("hit") == 1 and stage.current_motion == "idle", "hit recovers to idle")
	stage.play_motion("death")
	stage.advance(100.0)
	check(completed.count("death") == 1 and not stage.playing and is_zero_approx(stage.snapshot().alpha), "departure fades fully and stops processing")
	stage.advance(5.0)
	check(completed.count("death") == 1, "completed departure stays finished")
	check(stage.play_intro(true), "reduced motion intro can replay after departure")
	stage.advance(1.1)
	check(intro_count == 2 and not stage.intro_active and stage.stage.position == PRESENTATION.ART_RECT.position, "reduced motion completes without camera shake")
	stage.set_playback_speed(-5.0)
	check(is_equal_approx(stage.playback_speed, 0.25), "speed is bounded")
	stage.set_playback_speed(INF)
	check(is_equal_approx(stage.playback_speed, 0.25), "nonfinite speed rejected")
	for dimensions in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(720, 1280), Vector2(640, 360)]:
		stage.size = dimensions
		stage._layout()
		var end: Vector2 = stage.canvas.position + PRESENTATION.BASE_SIZE * stage.canvas.scale
		check(stage.canvas.position.x >= -0.01 and stage.canvas.position.y >= -0.01 and end.x <= dimensions.x + 0.01 and end.y <= dimensions.y + 0.01, "complete book fits viewport %s" % dimensions)
	for repeat in range(6):
		for motion in ["idle", "attack", "hit", "death"]:
			stage.play_motion(motion)
			stage.advance(PRESENTATION.duration(motion) * 0.5)
	check(stage.snapshot().cache_high_water <= PRESENTATION.CACHE_LIMIT and stage.snapshot().resident_upper_bytes <= 32 * 1024 * 1024, "repeated clips stay below 32 MiB frame residency bound")
	# Clip-clock advancement does not advance audio wall time. Let the
	# final 2.3-second death cue finish before tearing down this fixture.
	var audio: Node=root.get_node_or_null("GameAudio")
	var audio_deadline: int=Time.get_ticks_msec()+3500
	while audio!=null and not audio.voices.is_empty() and Time.get_ticks_msec()<audio_deadline:
		await process_frame
	check(audio==null or audio.voices.is_empty(), "queued audio finishes before fixture teardown")
	stage.stop()
	check(stage.snapshot().cached_frames == 0 and stage.dragon.texture == null and not stage.is_processing(), "stop releases all dragon frames and stops clock")
	var after_save := FileAccess.get_file_as_bytes(save_path) if not save_path.is_empty() and FileAccess.file_exists(save_path) else PackedByteArray()
	check(before_save == after_save, "presentation leaves personal save bytes unchanged")
	stage.queue_free()
	await process_frame
	# Release the isolated service before exit-time resource checks run.
	if audio!=null: audio.queue_free()
	await create_timer(0.10).timeout
	print("FINAL_DRAGON_ASSETS: %d frames, %.1f MiB decoded in total, bounded runtime cache" % [28, bytes / 1048576.0])
	print("FINAL_DRAGON_TESTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
