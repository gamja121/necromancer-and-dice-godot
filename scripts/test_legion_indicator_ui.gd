extends SceneTree
const Indicator = preload("res://systems/legion_indicator.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
var passes := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		passes += 1
		print("PASS legion-ui: ",message)
	else:
		failures += 1
		push_error("FAIL legion-ui: "+message)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene := Control.new()
	scene.set_meta("test",true)
	root.add_child(scene)
	var info_calls := []
	var fake := RefCounted.new()
	# Instantiating the actual indicator verifies its rendering and button structure.
	var icon := Indicator.new()
	scene.add_child(icon)
	icon.configure(null,"ally","skeleton",true)
	check(not icon.active_effect,"undead is not permanently glowing")
	check(icon.notice != null and not icon.notice.visible,"undead starts with no activation caption")
	icon.trigger()
	check(icon.pulse_end>icon.elapsed and icon.notice_end>icon.elapsed,"actual temporary trigger lights icon and shows text")
	var plant := Indicator.new()
	scene.add_child(plant)
	plant.configure(null,"enemy","plant",true)
	check(plant.active_effect and plant.notice_end>0.0,"enemy continuous plant glows and announces")
	var corpse := Indicator.new()
	scene.add_child(corpse)
	corpse.configure(null,"ally","corpse",true)
	check(not corpse.active_effect and Indicator.EFFECTS.corpse.contains("정의"),"undefined corpse effect never falsely glows")
	check(Indicator.EFFECTS.element.contains("원소") and Indicator.EFFECTS.ice.contains("빙결"),"rule-based help text exists")
	print("LEGION_INDICATOR_UI: %d passed, %d failed" % [passes,failures])
	quit(1 if failures>0 else 0)
