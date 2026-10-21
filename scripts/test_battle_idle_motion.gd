extends SceneTree
## Live 47-species battle idle regression: original art, visual-only changes.
const BATTLE = preload("res://battlefield.tscn")
const LAYOUT = preload("res://systems/battle_presentation_layout.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS battle-idle: ",label)
	else:
		failed += 1
		printerr("FAIL battle-idle: ",label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var layout = LAYOUT.new()
	var rigid_count := 0
	for slug in layout.metrics:
		if bool(layout.metrics[slug].get("rigid_idle",false)): rigid_count += 1
	check(layout.metrics.size()==47 and rigid_count==43,"47 species registered, original 43 rigid illustrations preserved")

	# Instantiate actual production battlefield; do not generate synthetic sprites.
	var scene = BATTLE.instantiate()
	scene.selection = ["skeleton-spear","skeleton-archer","soul-reaper","dracula"]
	root.add_child(scene)
	await process_frame
	var rigid_id: String = ""
	var flexible_id: String = ""
	var enemy_id: String = ""
	for unit in scene.rules.units:
		if unit.team=="ally" and unit.slug=="skeleton-spear": rigid_id=str(unit.id)
		if unit.team=="ally" and unit.slug=="soul-reaper": flexible_id=str(unit.id)
		if unit.team=="enemy" and enemy_id.is_empty(): enemy_id=str(unit.id)
	check(not rigid_id.is_empty() and not flexible_id.is_empty() and not enemy_id.is_empty(),"live rigid ally, flexible ally and enemy visible")
	if rigid_id.is_empty() or flexible_id.is_empty() or enemy_id.is_empty():
		scene.queue_free()
		quit(1)
		return
	var snapshot: String = JSON.stringify(scene.rules.snapshot())
	var rng_state: int = scene.rules.rng.state
	var initial_texture: Texture2D = scene.sprites[rigid_id].texture
	var initial_size: Vector2 = scene.sprites[rigid_id].size
	var initial_pivot: Vector2 = scene.sprites[rigid_id].pivot_offset
	var initial_home: Vector2 = scene.visuals.homes[rigid_id]
	await create_timer(0.28).timeout
	var first_angle: float = scene.sprites[rigid_id].rotation
	var first_enemy: float = scene.sprites[enemy_id].rotation
	var first_flexible: float = scene.sprites[flexible_id].rotation
	await create_timer(0.31).timeout
	var second_angle: float = scene.sprites[rigid_id].rotation
	check(absf(first_angle-second_angle)>0.003 and absf(first_angle)>0.003,"rigid original artwork visibly sways during idle")
	check(absf(first_enemy-scene.sprites[enemy_id].rotation)>0.003,"enemy also idles independently")
	check(absf(first_flexible-scene.sprites[flexible_id].rotation)>0.003,"non-rigid ally keeps idle motion")
	check(scene.sprites[rigid_id].scale.is_equal_approx(Vector2.ONE),"rigid originals do not squash/stretch")
	check(scene.sprites[rigid_id].texture==initial_texture,"idle retains the real frame artwork")
	check(scene.sprites[rigid_id].size.is_equal_approx(initial_size) and scene.sprites[rigid_id].pivot_offset.is_equal_approx(initial_pivot),"idle never alters sprite dimensions or foot pivot")
	check(scene.sprites[rigid_id].position.is_equal_approx(initial_home),"sway leaves feet positioned at their original battlefield slot")
	check(JSON.stringify(scene.rules.snapshot())==snapshot and scene.rules.rng.state==rng_state,"idle never advances turns, HP or RNG")

	scene.paused=true
	var paused_angle: float = scene.sprites[rigid_id].rotation
	await create_timer(0.24).timeout
	check(absf(scene.sprites[rigid_id].rotation-paused_angle)<0.0001,"pause freezes idle at its current pose")
	scene.paused=false
	await create_timer(0.20).timeout
	check(absf(scene.sprites[rigid_id].rotation-paused_angle)>0.001,"unpause resumes idle")

	scene.visuals.active[rigid_id] = true
	await process_frame
	check(absf(scene.sprites[rigid_id].rotation)<0.0001,"active attack suppresses idle")
	scene.visuals.active.erase(rigid_id)
	var unit: Dictionary=scene.visuals.states[rigid_id]
	unit.frozen=true
	scene.visuals.states[rigid_id]=unit
	await process_frame
	check(absf(scene.sprites[rigid_id].rotation)<0.0001,"frozen unit does not idle")
	unit.frozen=false
	unit.alive=false
	scene.visuals.states[rigid_id]=unit
	await process_frame
	check(absf(scene.sprites[rigid_id].rotation)<0.0001,"dead unit does not idle")
	unit.alive=true
	scene.visuals.states[rigid_id]=unit
	await create_timer(0.16).timeout
	check(absf(scene.sprites[rigid_id].rotation)>0.001,"alive restored unit resumes idling")

	scene.visuals.presentation_hold=true
	var hold_angle: float=scene.sprites[rigid_id].rotation
	await create_timer(0.15).timeout
	check(absf(scene.sprites[rigid_id].rotation-hold_angle)<0.0001,"presentation hold does not advance idle")
	scene.visuals.presentation_hold=false
	scene.queue_free()
	await process_frame
	print("BATTLE_IDLE_MOTION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
