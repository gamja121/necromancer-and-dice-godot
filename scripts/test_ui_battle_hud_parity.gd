extends SceneTree
## The top row preserves access to combat controls without duplicating feedback.
const Battlefield=preload("res://battlefield.tscn")
const AudioSettings=preload("res://systems/audio_settings.gd")
var passed=0
var failed=0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool,label: String) -> void:
	if value:
		passed+=1
		print("PASS ui-battle-hud: ",label)
	else:
		failed+=1
		printerr("FAIL ui-battle-hud: ",label)
func _run() -> void:
	var scene=Battlefield.instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.layer!=null and scene.dice!=null,"live battlefield initializes")
	var plate: Rect2 = scene.round_label.get_rect()
	check(absf(plate.get_center().x-scene.surface_size.x/2.0)<1.0 and plate.size.x<180,"round plaque is compact and centered")
	var message: Rect2 = scene.message.get_rect()
	check(message.position.y>=plate.end.y and absf(message.get_center().x-plate.get_center().x)<1.0,"result and save-error notice sits below the round plaque")
	check(scene.brand_reference_button.position.x>plate.end.x and scene.brand_reference_button.text=="낙인표","right toolbar has a clearly labeled brand reference")
	check(Rect2(scene.brand_reference_button.position,scene.brand_reference_button.size).intersects(Rect2(scene.pause_button.position,scene.pause_button.size))==false,"brand and pause have no overlap")
	check(Rect2(scene.brand_reference_button.position,scene.brand_reference_button.size).intersects(Rect2(scene.speed_button.position,scene.speed_button.size))==false,"brand and speed controls have no overlap")
	var audio_controls: Array=scene.layer.get_children().filter(func(x): return x is AudioSettings)
	check(audio_controls.size()==1,"existing audio settings panel preserved")
	if audio_controls.size()==1:
		var audio_button: Button=audio_controls[0].get_child(0)
		check(not Rect2(scene.brand_reference_button.position,scene.brand_reference_button.size).intersects(Rect2(audio_button.position,audio_button.size)),"audio preferences remain accessible and do not overlap reference")
		var toolbar: Array[Button] = [scene.brand_reference_button,audio_button,scene.pause_button,scene.speed_button]
		var aligned := true
		for i in range(1,toolbar.size()):
			aligned = aligned and toolbar[i-1].get_rect().end.x<toolbar[i].position.x
			aligned = aligned and is_equal_approx(toolbar[i].position.y,toolbar[0].position.y)
		check(aligned and audio_button.text=="설정","brand, settings, pause and speed share one ordered row")
		check(scene.keyboard_focus_controls().has(audio_button),"keyboard navigation reaches battle settings")
		audio_button.pressed.emit()
		check(audio_controls[0].is_open(),"the settings button opens the existing panel")
		scene.handle_cancel()
		check(not audio_controls[0].is_open(),"cancel dismisses battle settings")
	var empty_legion_titles: Array = scene.layer.get_children().filter(func(node):
		return node is Label and node.text in ["아군 활성 군단","적군 활성 군단"])
	check(empty_legion_titles.is_empty(),"army sides do not show empty legion headings")
	check(scene.dice.texture_normal==load("res://assets/battle/dice/roll-01.png"),"first battle turn displays original unrolled die instead of result face 1")
	var snapshot: String=JSON.stringify(scene.rules.snapshot())
	check(scene.can_open_brand_reference(),"brand information available in ready phase")
	scene.show_brand_reference()
	await process_frame
	check(is_instance_valid(scene.brand_reference) and scene.brand_reference.dice_headers.size()==6,"battlefield opens corrected reference with six dice illustrations")
	check(snapshot==JSON.stringify(scene.rules.snapshot()),"opening a reference cannot advance dice or battle rules")
	scene.close_brand_reference()
	check(not is_instance_valid(scene.brand_reference),"reference closes without modifying battle")
	scene.queue_free()
	await process_frame
	print("UI_BATTLE_HUD_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
