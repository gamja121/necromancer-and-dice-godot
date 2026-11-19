extends Control
## The main scene shows the studio emblem once per launch, then hands off to the menu.

const TITLE_SCENE := "res://title.tscn"
@onready var ident: Control = $StudioIdent
var leaving := false

func _ready() -> void:
	var reveal := create_tween()
	reveal.tween_property(ident, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_interval(0.84)
	reveal.tween_property(ident, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	reveal.tween_callback(finish)

func _unhandled_input(event: InputEvent) -> void:
	var skip := false
	if event is InputEventKey:
		var key: Key = event.keycode if event.keycode!=KEY_NONE else event.physical_keycode
		skip = event.pressed and not event.echo and key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	elif event is InputEventMouseButton:
		skip = event.pressed and event.button_index==MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		skip = event.pressed
	if skip:
		get_viewport().set_input_as_handled()
		finish()

func handle_cancel() -> bool:
	finish()
	return true

func finish() -> void:
	if leaving: return
	leaving = true
	if get_tree().change_scene_to_file(TITLE_SCENE)!=OK:
		leaving = false
