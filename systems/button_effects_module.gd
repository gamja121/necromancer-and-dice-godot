class_name ButtonEffectsModule
extends Control
## Attach directly below a Button or TextureButton. Owns only scale/rotation.
## Do not animate those two properties from a second component on the same button.

@export_group("Hover")
@export_range(0.01,0.5,0.01) var animation_duration: float = 0.07
@export var hover_scale: Vector2 = Vector2(1.05,1.05)
@export_range(0.0,3.0,0.1) var hover_rotation_degrees: float = 1.0
@export var use_hover_rotation: bool = true
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var transition_type: Tween.TransitionType = Tween.TRANS_QUAD

@export_group("Click")
@export var click_scale: Vector2 = Vector2(0.96,0.96)
@export_range(0.02,0.5,0.01) var click_duration: float = 0.10

var _button: BaseButton
var _tween: Tween
var _base_scale: Vector2
var _base_rotation: float
var _base_pivot: Vector2
var _base_pivot_ratio: Vector2
var _hovered: bool = false
var _hover_angle: float = 0.0
var _clicking: bool = false
var _touch_input: bool = false
var _was_disabled: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_button = get_parent() as BaseButton
	if _button == null:
		push_warning("ButtonEffectsModule requires a direct BaseButton parent.")
		set_process(false)
		set_process_input(false)
		return
	_base_scale = _button.scale
	_base_rotation = _button.rotation_degrees
	_base_pivot = _button.pivot_offset
	_base_pivot_ratio = _button.pivot_offset_ratio
	_button.pivot_offset = Vector2.ZERO
	_button.pivot_offset_ratio = Vector2(0.5,0.5)
	_was_disabled = _button.disabled
	_rng.randomize() # Independent from the battle RNG.
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	_button.pressed.connect(_on_pressed)
	_button.visibility_changed.connect(_on_visibility_changed)

func _process(_delta: float) -> void:
	if not is_instance_valid(_button): return
	if _was_disabled == _button.disabled: return
	_was_disabled = _button.disabled
	if _button.disabled:
		_hovered = false
		# A valid click may disable its button. Finish that click's return phase.
		if not _clicking: _restore_immediate()
	elif _button.is_hovered() and not _touch_input:
		_on_mouse_entered()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(_button): return
	if event is InputEventScreenTouch and event.pressed:
		_touch_input = true
		_hovered = false
		if not _clicking: _restore_immediate()
	elif (event is InputEventMouseMotion or event is InputEventMouseButton) and event.device != InputEvent.DEVICE_ID_EMULATION:
		var was_touch = _touch_input
		_touch_input = false
		if was_touch and _button.is_hovered(): _on_mouse_entered()
	# Observe input modality only; never consume or forward input.

func _on_mouse_entered() -> void:
	if not _available() or _touch_input: return
	_hovered = true
	_hover_angle = hover_rotation_degrees * (-1.0 if _rng.randi_range(0,1)==0 else 1.0)
	_animate_state(animation_duration)

func _on_mouse_exited() -> void:
	_hovered = false
	if not _available():
		_restore_immediate()
		return
	_animate_state(animation_duration)

func _on_pressed() -> void:
	if not _available(): return
	_hovered = _button.is_hovered() and not _touch_input
	_clicking = true
	reset_tween()
	var pulse = _button.scale*_positive_scale(click_scale)
	var minimum = _base_scale*_positive_scale(click_scale)
	pulse = Vector2(maxf(pulse.x,minimum.x),maxf(pulse.y,minimum.y))
	_tween.tween_property(_button,"scale",pulse,maxf(0.01,click_duration*0.4))
	_tween.tween_property(_button,"rotation_degrees",_target_rotation(),maxf(0.01,click_duration*0.4))
	_tween.chain().tween_callback(_recover_click)

func _recover_click() -> void:
	if not is_instance_valid(_button): return
	_animate_state(maxf(0.01,click_duration*0.6))

func _animate_state(duration: float) -> void:
	_clicking = false
	reset_tween()
	if _tween == null: return
	_tween.tween_property(_button,"scale",_target_scale(),maxf(0.01,duration))
	_tween.tween_property(_button,"rotation_degrees",_target_rotation(),maxf(0.01,duration))

func reset_tween() -> void:
	_kill_tween()
	if not is_instance_valid(_button) or not is_inside_tree(): return
	_tween = create_tween()
	_tween.set_ease(ease_type).set_trans(transition_type).set_parallel(true)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null

func _available() -> bool:
	return is_instance_valid(_button) and not _button.disabled and _button.is_visible_in_tree()

func _target_scale() -> Vector2:
	return _base_scale*_positive_scale(hover_scale) if _hovered and _available() else _base_scale

func _target_rotation() -> float:
	return _base_rotation+_hover_angle if _hovered and _available() and use_hover_rotation else _base_rotation

func _positive_scale(value: Vector2) -> Vector2:
	return Vector2(maxf(0.01,value.x),maxf(0.01,value.y))

func _on_visibility_changed() -> void:
	if not _button.is_visible_in_tree(): _restore_immediate()

func _restore_immediate() -> void:
	_kill_tween()
	_hovered = false
	_clicking = false
	if is_instance_valid(_button):
		_button.scale = _base_scale
		_button.rotation_degrees = _base_rotation

func _exit_tree() -> void:
	_restore_immediate()
	if not is_instance_valid(_button): return
	for connection in [
		[_button.mouse_entered,_on_mouse_entered],
		[_button.mouse_exited,_on_mouse_exited],
		[_button.pressed,_on_pressed],
		[_button.visibility_changed,_on_visibility_changed]]:
		if connection[0].is_connected(connection[1]): connection[0].disconnect(connection[1])
	_button.pivot_offset = _base_pivot
	_button.pivot_offset_ratio = _base_pivot_ratio
