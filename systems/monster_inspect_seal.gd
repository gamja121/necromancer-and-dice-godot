extends Button
## One optional pointer action. The focused card owns the keyboard action.

static func attach(card: TextureButton, inspect: Callable) -> void:
	var seal := new()
	seal.name = "MonsterInspectSeal"
	seal.focus_mode = Control.FOCUS_NONE
	seal.flat = true
	seal.tooltip_text = "마물 정보"
	var side := 38.0 if DisplayServer.is_touchscreen_available() else 25.0
	seal.size = Vector2(side,side)
	seal.position = Vector2(card.size.x-side-5.0, 7.0)
	for state in ["normal", "hover", "pressed", "focus"]:
		seal.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	card.add_child(seal)
	seal.mouse_entered.connect(seal.queue_redraw)
	seal.mouse_exited.connect(seal.queue_redraw)
	seal.pressed.connect(_open_from_pointer.bind(card,inspect))
	seal.gui_input.connect(_right_click.bind(seal,card,inspect))
	card.gui_input.connect(_right_click.bind(card,card,inspect))
	card.set_meta("keyboard_secondary_action",inspect)
	card.set_meta("keyboard_action_hint","Enter · 선택 / Space · 정보")

static func _right_click(event: InputEvent, receiver: Control, card: TextureButton, inspect: Callable) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not card.disabled:
		receiver.accept_event()
		_open_from_pointer(card,inspect)

static func _open_from_pointer(card: TextureButton, inspect: Callable) -> void:
	if card.disabled or not inspect.is_valid(): return
	card.grab_focus()
	inspect.call()

func _draw() -> void:
	var center := size*0.5
	var edge := Color("d5b278") if is_hovered() else Color("a47b4c")
	var ink := Color("f8ddb0") if is_hovered() else Color("e6c58c")
	draw_circle(center,11.0,Color("281b12"),true,-1,true)
	draw_arc(center,10.0,0.0,TAU,24,edge,1.2,true)
	var lens := center-Vector2(1.4,1.4)
	draw_arc(lens,3.7,0.0,TAU,16,ink,1.35,true)
	draw_line(center+Vector2(1.4,1.4),center+Vector2(5.2,5.2),ink,1.65,true)
