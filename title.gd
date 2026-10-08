extends Control

const MAP_SCENE := "res://map.tscn"
const BACKGROUND_PATH := "res://assets/title/parallax/background.webp"
const BOARD_PATH := "res://assets/title/parallax/board_layer.webp"
const FOREGROUND_PATH := "res://assets/title/parallax/foreground_layer.webp"
const BASE_SIZE := Vector2(1280.0, 720.0)
const OVERSCAN := Vector2(48.0, 28.0)

var session
var art_root: Control
var background_layer: TextureRect
var board_layer: TextureRect
var foreground_layer: TextureRect
var continue_button: Button

var pointer_normalized := Vector2.ZERO
var touch_active := false
var mouse_seen := false
var idle_time := 0.0
var base_positions: Dictionary = {}

func _ready() -> void:
	session = get_node("/root/RunSession")
	_build_theme()
	_build_art()
	_build_menu()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	set_process(true)

func _build_theme() -> void:
	var game_theme = Theme.new()
	var display_font = SystemFont.new()
	display_font.font_names = PackedStringArray(["Times New Roman", "Georgia", "Malgun Gothic", "맑은 고딕", "sans-serif"])
	game_theme.default_font = display_font
	game_theme.default_font_size = 18
	game_theme.set_color("font_color", "Label", Color("ead9b7"))
	game_theme.set_color("font_color", "Button", Color("ead9b7"))
	game_theme.set_color("font_hover_color", "Button", Color("fff0c7"))
	game_theme.set_color("font_pressed_color", "Button", Color("d8bd82"))
	game_theme.set_color("font_disabled_color", "Button", Color("7f7668"))
	theme = game_theme

func _build_art() -> void:
	art_root = Control.new()
	art_root.name = "ParallaxArt"
	art_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_root)

	background_layer = _make_layer("Background", BACKGROUND_PATH, -4)
	board_layer = _make_layer("Board", BOARD_PATH, 0)
	foreground_layer = _make_layer("Foreground", FOREGROUND_PATH, 4)

	var veil = ColorRect.new()
	veil.name = "ReadabilityVeil"
	veil.color = Color(0.035, 0.025, 0.02, 0.12)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

func _make_layer(node_name: String, path: String, z: int) -> TextureRect:
	var layer = TextureRect.new()
	layer.name = node_name
	layer.texture = load(path)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = z
	art_root.add_child(layer)
	return layer

func _build_menu() -> void:
	var ui = Control.new()
	ui.name = "TitleUI"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)

	var title_shadow = Label.new()
	title_shadow.text = "NECROMANCER"
	title_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_shadow.add_theme_font_size_override("font_size", 54)
	title_shadow.add_theme_color_override("font_color", Color(0.02, 0.015, 0.012, 0.72))
	title_shadow.position = Vector2(363, 77)
	title_shadow.size = Vector2(560, 66)
	ui.add_child(title_shadow)

	var title = Label.new()
	title.text = "NECROMANCER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("d7c292"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.position = Vector2(360, 73)
	title.size = Vector2(560, 66)
	ui.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "&  D I C E"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color("a99166"))
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	subtitle.position = Vector2(465, 137)
	subtitle.size = Vector2(350, 38)
	ui.add_child(subtitle)

	var menu_panel = PanelContainer.new()
	menu_panel.position = Vector2(503, 425)
	menu_panel.size = Vector2(274, 224)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.02, 0.018, 0.54)
	panel_style.border_color = Color(0.36, 0.31, 0.22, 0.52)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(7)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	menu_panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(menu_panel)

	var menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	menu_panel.add_child(menu)

	var new_button = _menu_button("새 원정")
	new_button.pressed.connect(_start_new_run)
	menu.add_child(new_button)

	continue_button = _menu_button("이어하기")
	continue_button.disabled = not session.has_save()
	continue_button.pressed.connect(_continue_run)
	menu.add_child(continue_button)

	var exit_button = _menu_button("종료")
	exit_button.pressed.connect(func(): get_tree().quit())
	menu.add_child(exit_button)

	var hint = Label.new()
	hint.text = "마우스 또는 터치로 장면을 움직여 보세요"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.74, 0.67, 0.55, 0.72))
	hint.position = Vector2(430, 674)
	hint.size = Vector2(420, 24)
	ui.add_child(hint)

func _menu_button(text_value: String) -> Button:
	var button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(226, 48)
	button.focus_mode = Control.FOCUS_ALL
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.075, 0.06, 0.82)
	normal.border_color = Color(0.42, 0.35, 0.24, 0.78)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover = normal.duplicate()
	hover.bg_color = Color(0.16, 0.125, 0.085, 0.9)
	hover.border_color = Color(0.68, 0.55, 0.34, 0.95)
	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.055, 0.045, 0.036, 0.96)
	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.04, 0.038, 0.034, 0.65)
	disabled.border_color = Color(0.22, 0.21, 0.19, 0.5)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	return button

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_seen = true
		_set_pointer(event.position)
	elif event is InputEventScreenTouch:
		touch_active = event.pressed
		if event.pressed:
			_set_pointer(event.position)
	elif event is InputEventScreenDrag:
		touch_active = true
		_set_pointer(event.position)

func _set_pointer(position: Vector2) -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var center = viewport_size * 0.5
	pointer_normalized = Vector2(
		clampf((position.x - center.x) / center.x, -1.0, 1.0),
		clampf((position.y - center.y) / center.y, -1.0, 1.0)
	)

func _process(delta: float) -> void:
	idle_time += delta
	var idle = Vector2(sin(idle_time * 0.23), cos(idle_time * 0.19)) * 0.55
	var active_pointer = pointer_normalized if mouse_seen or touch_active else Vector2.ZERO
	var smoothing = 1.0 - exp(-delta * 5.2)
	_move_layer(background_layer, active_pointer, idle, Vector2(4.0, 2.6), 0.30, smoothing)
	_move_layer(board_layer, active_pointer, idle, Vector2(11.0, 6.5), 0.62, smoothing)
	_move_layer(foreground_layer, active_pointer, idle, Vector2(20.0, 11.0), 1.0, smoothing)

func _move_layer(layer: Control, pointer: Vector2, idle: Vector2, strength: Vector2, idle_weight: float, smoothing: float) -> void:
	var base: Vector2 = base_positions.get(layer, Vector2.ZERO)
	var target = base - pointer * strength + idle * idle_weight
	layer.position = layer.position.lerp(target, smoothing)

func _on_viewport_size_changed() -> void:
	var extra = OVERSCAN
	var layer_size = BASE_SIZE + extra * 2.0
	var base = -extra
	for layer in [background_layer, board_layer, foreground_layer]:
		if not is_instance_valid(layer):
			continue
		layer.position = base
		layer.size = layer_size
		base_positions[layer] = base

func _start_new_run() -> void:
	session.start_new_world()
	get_tree().change_scene_to_file(MAP_SCENE)

func _continue_run() -> void:
	if not session.has_save():
		continue_button.disabled = true
		return
	session.reload_world()
	get_tree().change_scene_to_file(MAP_SCENE)
