extends SceneTree
## Battle toolbar source parity: right-side ✦☠ access without audio overlap.
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
	check(scene.round_label.position.x>300 and scene.round_label.position.x<450,"round counter remains in central HUD")
	check(scene.message.position.x>scene.round_label.position.x and scene.message.position.x+scene.message.size.x<=775,"message occupies source central header without overlapping buttons")
	check(scene.brand_reference_button.position.x>=775 and scene.brand_reference_button.position.x+scene.brand_reference_button.size.x<=896,"brand reference in right toolbar before audio options")
	check(scene.brand_reference_button.text.contains("✦") and scene.brand_reference_button.text.contains("☠"),"source blessing/curse meaning on reference button")
	check(Rect2(scene.brand_reference_button.position,scene.brand_reference_button.size).intersects(Rect2(scene.pause_button.position,scene.pause_button.size))==false,"brand and pause have no overlap")
	check(Rect2(scene.brand_reference_button.position,scene.brand_reference_button.size).intersects(Rect2(scene.speed_button.position,scene.speed_button.size))==false,"brand and speed controls have no overlap")
	var audio_controls: Array=scene.layer.get_children().filter(func(x): return x is AudioSettings)
	check(audio_controls.size()==1,"existing audio settings panel preserved")
	if audio_controls.size()==1:
		var audio_button: Button=audio_controls[0].get_child(0)
		check(not Rect2(scene.brand_reference_button.position,scene.brand_reference_button.size).intersects(Rect2(audio_button.position,audio_button.size)),"audio preferences remain accessible and do not overlap reference")
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
