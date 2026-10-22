extends SceneTree
## Real Windows renderer / real process clock. No personal save mutations.
const PRESENTATION = preload("res://systems/final_dragon_presentation.gd")
var finished := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var stage := PRESENTATION.new()
	stage.size = Vector2(1280, 720)
	root.add_child(stage)
	stage.intro_finished.connect(func(): finished += 1)
	if not stage.play_intro():
		push_error("Dragon intro failed to start")
		quit(1)
		return
	var deltas: Array[float] = []
	var elapsed := 0.0
	while elapsed < 6.5:
		await process_frame
		var delta: float = stage.get_process_delta_time()
		elapsed += delta
		deltas.append(delta * 1000.0)
	var valid := finished == 1 and not stage.intro_active and stage.current_motion == "idle"
	deltas.sort()
	var results: Dictionary = stage.snapshot()
	results["frames_observed"] = deltas.size()
	results["frame_median_ms"] = snappedf(deltas[deltas.size() / 2], 0.01)
	results["frame_p95_ms"] = snappedf(deltas[mini(deltas.size() - 1, int(deltas.size() * 0.95))], 0.01)
	results["frame_max_ms"] = snappedf(deltas.back(), 0.01)
	results["renderer"] = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	print("FINAL_DRAGON_NATIVE: " + JSON.stringify(results))
	stage.stop()
	stage.queue_free()
	await process_frame
	print("FINAL_DRAGON_NATIVE_TEST: " + ("PASS" if valid else "FAIL"))
	quit(0 if valid else 1)
