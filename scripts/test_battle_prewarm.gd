extends SceneTree
## The real battlefield owns a finite prewarm lifetime; no player saves.
const BATTLE = preload("res://battlefield.tscn")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("_run")

func check(ok: bool, note: String) -> void:
	if ok:
		passed += 1
		print("PASS battle-prewarm: ",note)
	else:
		failed += 1
		printerr("FAIL battle-prewarm: ",note)

func frame_reference(loader) -> WeakRef:
	for resource in loader.resources.values():
		if resource is Texture2D: return weakref(resource)
	return null

func _run() -> void:
	for iteration in range(2):
		var scene = BATTLE.instantiate()
		scene.selection = ["guardian-seed","goblin-commoner","plague-doctor","dracula"]
		root.add_child(scene)
		var loader = scene.layer.get_node_or_null("BattleFrameResources")
		check(loader!=null,"production battlefield creates battle-owned prewarm")
		if loader==null:
			scene.queue_free()
			quit(1)
			return
		var original: String = JSON.stringify(scene.rules.snapshot())
		var selected: Dictionary = {}
		for unit in scene.rules.units: selected[unit.slug] = true
		var paths_ok: bool = true
		for path in loader.queued:
			paths_ok = paths_ok and selected.has(String(path).get_base_dir().get_file())
			paths_ok = paths_ok and not String(path).ends_with("/attack-01.png")
		check(paths_ok and not loader.queued.is_empty(),"warmup only queues active combatant frames beyond visible idle art")
		check(loader.reserved_frame_bytes<=loader.FRAME_WARMUP_BUDGET,"estimated additional frames stay inside 32 MiB budget")
		var count: int = loader.queued.size()
		var reserved: int = loader.reserved_frame_bytes
		loader.warm_combatants(scene.rules.units,scene.presentation_layout.metrics)
		check(loader.queued.size()==count and loader.reserved_frame_bytes==reserved,"repeated snapshots do not duplicate requests or budget")
		var deadline: int = Time.get_ticks_msec()+15000
		var previous_count: int = loader.resources.size()
		var one_per_frame: bool = true
		while loader.is_processing() and Time.get_ticks_msec()<deadline:
			await process_frame
			one_per_frame = one_per_frame and loader.resources.size()-previous_count<=1
			previous_count = loader.resources.size()
		check(not loader.is_processing() and loader.requested.is_empty(),"bounded real threaded requests finish and stop")
		check(one_per_frame,"accepts at most one completed texture per frame")
		var decoded_bytes: int = 0
		var textures_ok: bool = true
		for resource in loader.resources.values():
			textures_ok = textures_ok and resource is Texture2D
			if resource is Texture2D: decoded_bytes += resource.get_width()*resource.get_height()*4
		check(textures_ok and decoded_bytes<=loader.FRAME_WARMUP_BUDGET,"actual imported frame dimensions remain inside budget")
		var first_path: String = str(loader.resources.keys()[0])
		check(scene.texture(first_path)==loader.resources[first_path],"production animation lookup reuses the prepared texture object")
		print("BATTLE_PREWARM_RESULT: iteration=",iteration," frames=",loader.resources.size()," estimated_bytes=",reserved," decoded_bytes=",decoded_bytes)
		check(JSON.stringify(scene.rules.snapshot())==original,"warmup preserves the exact battle snapshot and RNG")
		var owner_ref: WeakRef = weakref(loader)
		var texture_ref: WeakRef = frame_reference(loader)
		scene.queue_free()
		for i in range(6): await process_frame
		check(owner_ref.get_ref()==null,"leaving battle frees the prewarm owner")
		check(texture_ref!=null and texture_ref.get_ref()==null,"unused prewarmed texture references release with battle")
	# Exit during a real background request: the loader must not leave an
	# unclaimed ResourceLoader task retaining a texture after the scene dies.
	var early_scene = BATTLE.instantiate()
	early_scene.selection = ["guardian-seed","goblin-commoner","plague-doctor","dracula"]
	root.add_child(early_scene)
	var early_loader = early_scene.layer.get_node("BattleFrameResources")
	for i in range(5):
		early_loader._process(0.0)
		if not early_loader.requested.is_empty(): break
	var orphan_paths: Array = early_loader.requested.keys()
	check(not orphan_paths.is_empty(),"early-exit case contains actual in-flight engine requests")
	early_scene.free()
	await process_frame
	var deadline: int = Time.get_ticks_msec()+5000
	var drained: bool = false
	while Time.get_ticks_msec()<deadline:
		drained = orphan_paths.all(func(path): return ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
		if drained: break
		await process_frame
	check(drained,"early scene exit drains engine requests without blocking the UI")
	print("BATTLE_PREWARM: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
