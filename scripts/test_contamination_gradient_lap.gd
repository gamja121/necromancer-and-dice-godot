extends SceneTree
## Continuous ten-slot colour gradient, new +7 lap rule and v1 save round-trip.
## Never touches the player's live save path.
const HUD = preload("res://systems/contamination_hud.gd")
const STATE = preload("res://systems/map_state.gd")
const SESSION = preload("res://systems/run_session.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("PASS contamination-gradient-lap: ",what)
	else:
		failed += 1
		printerr("FAIL contamination-gradient-lap: ",what)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var hud: Control = HUD.new()
	root.add_child(hud)
	await process_frame
	check(hud.uses_approved_art and hud.size==Vector2(480,160),"approved crow and stone art, compact layout preserved")
	check(hud.COLORS.size()==10,"ten gradient anchors correspond to ten art windows")
	check(hud.gradient_color(0.0).is_equal_approx(hud.COLORS[0]),"green starts at left edge")
	check(hud.gradient_color(1.0).is_equal_approx(hud.COLORS[9]),"purple ends at right edge")
	check(hud.gradient_color(-1.0).is_equal_approx(hud.COLORS[0]) and hud.gradient_color(2.0).is_equal_approx(hud.COLORS[9]),"out-of-range gradient values clamp")
	for i in range(1,10):
		var border: float = float(i)/10.0
		var before: Color = hud.gradient_color(border-0.0001)
		var after: Color = hud.gradient_color(border+0.0001)
		var delta: float = absf(before.r-after.r)+absf(before.g-after.g)+absf(before.b-after.b)
		check(delta<0.005,"gradient is continuous at slot edge %d" % i)
	hud.set_value(7,true)
	var steps: PackedFloat32Array = hud.segment_fractions(hud.display_value)
	check(steps.size()==10 and is_equal_approx(steps[0],0.7) and steps[1]==0.0,"first lap fills only 70 percent of first segment")
	hud.set_value(14,true)
	steps = hud.segment_fractions(hud.display_value)
	check(steps[0]==1.0 and is_equal_approx(steps[1],0.4) and steps[2]==0.0,"second lap fills the next segment by 40 percent")
	hud.set_value(21,true)
	check(hud.segment_fractions(hud.display_value)[2]>0.0,"third lap crosses into the third segment")
	hud.queue_free()
	await process_frame

	var session: Node = root.get_node_or_null("RunSession")
	var created: bool = session==null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var original_path: String = session.save_file_path
	var temp_path: String = "user://contamination_gradient_lap_%d.json" % OS.get_process_id()
	session.save_file_path = temp_path
	session.start_new_world()
	var world = session.world
	check(world.contamination==0 and world.laps==0,"new expedition starts without accumulated contamination")
	check(STATE.LAP_CONTAMINATION_GAIN==7,"authoritative gameplay lap increment is seven")
	for i in range(3):
		world.position = STATE.HOME
		world.lap_ready = true
		world.leave_home()
		check(world.contamination==7*(i+1),"lap %d adds exactly seven" % (i+1))
		check(world.laps==i+1 and not world.lap_ready,"lap %d advances once and resets home-ready state" % (i+1))
		check(world.tiles.size()==24,"lap %d preserves all map tiles" % (i+1))
	check(not world.tiles.has("boss"),"three completed laps do not bypass the final story and contamination gate")
	world.contamination = 98
	world.position = STATE.HOME
	world.lap_ready = true
	world.leave_home()
	check(world.contamination==100,"lap gain clamps at 100 rather than overflowing")
	var saved: Dictionary = world.snapshot().duplicate(true)
	check(session.save_world(),"changed lap values persist in the original v1 save format")
	session.reload_world()
	check(session.world.snapshot()==saved,"saved lap, contamination, board and dice data restore unchanged")
	session.save_file_path = original_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(temp_path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path+suffix))
	if created: session.queue_free()
	print("CONTAMINATION_GRADIENT_LAP: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
