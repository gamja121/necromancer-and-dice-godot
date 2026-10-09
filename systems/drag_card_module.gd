extends Control
## Pointer capture in canvas coordinates; keyboard activation remains on BaseButton.
signal activated
@export var use_threshold: float = 34.0
var card: BaseButton
var home: Vector2
var start: Vector2
var pointer = -2
var displacement = Vector2.ZERO
var settling: Tween

func _ready() -> void:
	card = get_parent() as BaseButton
	if card == null:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	home = card.position
	set_process(false)

func point_in_parent(point: Vector2) -> Vector2:
	return card.get_parent().get_global_transform_with_canvas().affine_inverse()*point

func _gui_input(event: InputEvent) -> void:
	if card == null or card.disabled or pointer != -2: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		begin(-1,event.position + Vector2.ZERO, true)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		begin(event.index,event.position,true)
		accept_event()

func begin(id: int, point: Vector2, local_mouse: bool) -> void:
	if settling != null and settling.is_valid(): settling.kill()
	start = card.get_parent().get_global_transform_with_canvas().affine_inverse()*(get_global_transform_with_canvas()*point) if local_mouse else point_in_parent(point)
	pointer = id
	displacement = Vector2.ZERO
	card.z_index = 20
	card.grab_focus()
	set_process(true)

func _input(event: InputEvent) -> void:
	if pointer == -2: return
	if card.disabled:
		cancel()
		return
	if event is InputEventMouseMotion and pointer == -1:
		move_pointer(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == pointer:
		move_pointer(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and pointer == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		release(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == pointer and not event.pressed:
		if event.canceled: cancel()
		else: release(event.position)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()

func move_pointer(point: Vector2) -> void:
	displacement = point_in_parent(point)-start
	card.position = home+Vector2(0,clampf(displacement.y,-110,0))
	card.self_modulate = Color(1.15,1.1,0.85) if displacement.y <= -use_threshold else Color.WHITE

func release(point: Vector2) -> void:
	move_pointer(point)
	var upward = displacement.y <= -use_threshold
	var clicked = displacement.length() <= 6.0 and Rect2(Vector2.ZERO,card.size).has_point(card.get_global_transform_with_canvas().affine_inverse()*point)
	pointer = -2
	set_process(false)
	card.self_modulate = Color.WHITE
	if upward or clicked:
		activated.emit()
	else:
		restore()

func restore() -> void:
	if settling != null and settling.is_valid(): settling.kill()
	settling = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settling.tween_property(card,"position",home,0.14)
	card.z_index = 0

func cancel() -> void:
	pointer = -2
	set_process(false)
	if is_instance_valid(card):
		card.self_modulate = Color.WHITE
		restore()

func _process(_delta: float) -> void:
	if card.disabled or not card.is_visible_in_tree(): cancel()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and pointer != -2: cancel()

func _exit_tree() -> void:
	if settling != null and settling.is_valid(): settling.kill()
