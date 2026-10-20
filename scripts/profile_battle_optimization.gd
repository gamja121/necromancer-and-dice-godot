extends SceneTree
## Production battlefield, renderer redraw signals, and stable visual snapshots.
const BATTLE = preload("res://battlefield.tscn")
var passed: int = 0
var failed: int = 0
var draws: int = 0
var capture_dir: String = ""

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("_run")

func check(ok: bool, note: String) -> void:
	if ok:
		passed += 1
		print("PASS battle-optimization: ",note)
	else:
		failed += 1
		printerr("FAIL battle-optimization: ",note)

func settle(count: int = 3) -> void:
	for i in range(count): await process_frame

func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image!=null and not image.is_empty(),"real rendered image exists: "+label)
	if image!=null and not image.is_empty():
		check(image.save_png(capture_dir.path_join(label+".png"))==OK,"saved graphical evidence: "+label)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture-dir" in args:
		capture_dir = args[args.find("--capture-dir")+1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(1280,720))
	var scene = BATTLE.instantiate()
	scene.selection = ["guardian-seed","goblin-commoner","plague-doctor","dracula"]
	root.add_child(scene)
	scene.paused = true
	scene.visuals.clock = 0.0
	scene.visuals.idle_clock = 0.0
	for id in scene.visuals.states:
		scene.sprites[id].position = scene.visuals.homes[id]
		scene.sprites[id].scale = Vector2.ONE
	scene.visuals.ground.draw.connect(func(): draws += 1)
	await settle()
	check(scene.rules.units.size()==8,"actual 4-versus-4 battlefield is instantiated")
	var original_snapshot: String = JSON.stringify(scene.rules.snapshot())
	await capture("01_idle")
	var before: int = draws
	await settle(24)
	var idle_draws: int = draws-before
	print("BATTLE_GROUND_IDLE_DRAWS: ",idle_draws," per 24 frames")
	check(idle_draws==0,"stationary ground reuses cached draw commands")

	var id: String = scene.rules.units[0].id
	scene.visuals.entry_circles[id] = 1.0
	before = draws
	scene.paused = false
	await settle(12)
	check(draws-before>=8,"active summon circle continues redrawing")
	scene.paused = true
	scene.visuals.clock = 0.5
	await capture("02_circle")
	scene.visuals.entry_circles.clear()
	await settle()
	before = draws
	await settle(12)
	check(draws==before,"circle cleanup leaves no continuing ground redraw")
	await capture("03_circle_cleared")

	before = draws
	scene.visuals.removed[id] = true
	await settle()
	check(draws>before,"removal outside sync invalidates cached shadow")
	await capture("04_removed")
	before = draws
	scene.visuals.removed.erase(id)
	await settle()
	check(draws>before,"restoring visibility invalidates cached shadow")

	var view: Array = scene.rules.units.duplicate(true)
	view[0].alive = false
	view[0].hp = 0
	before = draws
	scene.render_units(view)
	await settle()
	check(draws>before and not scene.visuals.states[id].alive,"death snapshot refreshes the shadow")
	await capture("05_dead")

	before = draws
	scene.surface_size = Vector2(1152,648)
	scene.render_units(view)
	await settle()
	check(draws>before and scene.visuals.homes[id]==scene.presentation_layout.geometry(view[0],scene.surface_size).position,"layout change refreshes ground geometry")
	scene.surface_size = Vector2(1280,720)
	scene.render_units(scene.rules.units)
	await settle()
	check(JSON.stringify(scene.rules.snapshot())==original_snapshot,"presentation tests preserve all combat state and RNG")

	# Measure candidate costs; this is CPU work, not a claimed FPS improvement.
	var start: int = Time.get_ticks_usec()
	for i in range(200): scene.render_units(scene.rules.units)
	print("BATTLE_RENDER_UNITS_CPU_US: ",float(Time.get_ticks_usec()-start)/200.0)
	start = Time.get_ticks_usec()
	for i in range(200): scene.visuals._process(0.0)
	print("BATTLE_VISUAL_PROCESS_CPU_US: ",float(Time.get_ticks_usec()-start)/200.0)
	var report: Dictionary = {"type":"heal","target":id,"amount":3,"hp":scene.rules.units[0].hp,"kind":"test","blocked":false,"critical":false}
	start = Time.get_ticks_usec()
	for i in range(8): scene.visuals.show_reports([report])
	print("BATTLE_EIGHT_HEAL_REPORTS_CPU_US: ",Time.get_ticks_usec()-start)
	print("BATTLE_EIGHT_HEAL_REPORTS_NODES: ",scene.visuals.art_items.size())
	if not capture_dir.is_empty():
		scene.paused = false
		await scene.wait_time(0.08)
		scene.paused = true
		await capture("06_healing_effects")
	scene.paused = false
	await scene.wait_time(1.3)
	check(scene.visuals.art_items.is_empty(),"stacked healing effects expire without lingering active items")
	for repeat in range(3):
		start = Time.get_ticks_usec()
		for i in range(8): scene.visuals.show_reports([report])
		print("BATTLE_WARM_HEAL_BURST_CPU_US: ",Time.get_ticks_usec()-start)
		await scene.wait_time(1.3)
		check(scene.visuals.art_items.is_empty(),"repeated healing burst expires "+str(repeat))
	scene.queue_free()
	await settle()
	print("BATTLE_OPTIMIZATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
