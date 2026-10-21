extends SceneTree
## Empty layers sleep; active presentation and the last clear still draw.
const BATTLE = preload("res://battlefield.tscn")
var passed: int = 0
var failed: int = 0
var visual_draws: int = 0
var cue_draws: int = 0

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("_run")

func check(ok: bool, note: String) -> void:
	if ok:
		passed += 1
		print("PASS battle-visual-updates: ",note)
	else:
		failed += 1
		printerr("FAIL battle-visual-updates: ",note)

func settle(count: int = 3) -> void:
	for i in range(count): await process_frame

func _run() -> void:
	var scene = BATTLE.instantiate()
	root.add_child(scene)
	scene.paused = true
	scene.visuals.draw.connect(func(): visual_draws += 1)
	scene.cues.draw.connect(func(): cue_draws += 1)
	await settle()
	var original: String = JSON.stringify(scene.rules.snapshot())
	var before_visual: int = visual_draws
	var before_cue: int = cue_draws
	await settle(24)
	print("BATTLE_EMPTY_LAYER_DRAWS: visuals=",visual_draws-before_visual," cues=",cue_draws-before_cue," frames=24")
	check(visual_draws==before_visual,"empty status/particle layer receives no redraw")
	check(cue_draws==before_cue,"empty combat cue layer receives no redraw")

	var id: String = scene.rules.units[0].id
	scene.visuals.states[id].shields = 1
	scene.paused = false
	before_visual = visual_draws
	await settle(12)
	check(visual_draws-before_visual>=8,"shield animation keeps drawing")
	before_visual = visual_draws
	scene.visuals.states[id].shields = 0
	await settle()
	check(visual_draws>before_visual,"last shield frame is cleared")
	before_visual = visual_draws
	await settle(12)
	check(visual_draws==before_visual,"cleared shield returns to cached empty drawing")
	scene.visuals.states[id].poison.append({"damage":1})
	before_visual = visual_draws
	await settle(12)
	check(visual_draws-before_visual>=8,"poison particles keep drawing")
	scene.visuals.states[id].poison.clear()
	scene.visuals.states[id].frozen = true
	before_visual = visual_draws
	await settle(12)
	check(visual_draws-before_visual>=8,"frozen indicator remains visible")
	scene.visuals.states[id].frozen = false
	await settle()

	scene.cues.impact = {"id":id,"mode":"bless","started":scene.cues.clock,"duration":0.42}
	before_cue = cue_draws
	await settle(12)
	check(cue_draws-before_cue>=8,"blessing body impact keeps animating")
	before_cue = cue_draws
	scene.cues.impact.clear()
	await settle()
	check(cue_draws>before_cue,"last impact frame is cleared")
	scene.cues.chain_pulse = {"id":id,"started":scene.cues.clock,"duration":0.26,"count":2}
	before_cue = cue_draws
	await settle(12)
	check(cue_draws-before_cue>=8,"chain pulse keeps animating")
	scene.cues.chain_pulse.clear()
	scene.cues.marks = [{"id":id,"captions":[{"text":"Healing","color":Color.GREEN}]}]
	before_cue = cue_draws
	await settle(12)
	check(cue_draws-before_cue>=8,"active captions remain refreshed")
	before_cue = cue_draws
	scene.cues.marks.clear()
	await settle()
	check(cue_draws>before_cue,"last caption frame is cleared")
	before_cue = cue_draws
	await settle(12)
	check(cue_draws==before_cue,"empty cue drawing sleeps again")

	await scene.cues.play_dice_result(6)
	check(scene.dice.scale.is_equal_approx(scene.cues.dice_base_scale),"die animation restores original scale")
	check(scene.cues.rail_box.visible,"native cue rail remains visible without parent redraw")
	var expiry_deadline: int = Time.get_ticks_msec()+4000
	while scene.cues.rail_box.visible and Time.get_ticks_msec()<expiry_deadline:
		await process_frame
	check(not scene.cues.rail_box.visible,"native cue rail still expires on time")
	check(JSON.stringify(scene.rules.snapshot())==original,"presentation updates preserve complete battle state and RNG")
	scene.queue_free()
	await settle(6)
	print("BATTLE_VISUAL_UPDATES: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
