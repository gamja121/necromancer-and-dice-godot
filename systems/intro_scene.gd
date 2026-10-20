extends Control
## Original v2-intro: impact, twelve dialogue lines, 520 ms fade to the map.
const DESIGN_SIZE = Vector2(1280,720)
const ButtonEffects = preload("res://systems/button_effects_module.gd")
const AudioSettings = preload("res://systems/audio_settings.gd")
@export_range(0.1,1.5,0.01) var ending_duration: float = 0.52
var canvas: Control
var impact: Control
var dialogue_stage: Control
var hero: TextureRect
var commander: TextureRect
var speaker_label: Label
var text_label: Label
var advance_button: Button
var skip_button: Button
var continue_button: Button
var hint_tween: Tween
var lines: Array = []
var line_index = -1
var leaving = false

func _ready() -> void:
	DisplayServer.window_set_title("Necromancer and Dice")
	AudioSettings.apply_saved()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro_dialogue.json"))
	if parsed is Array: lines = parsed
	var font = preload("res://assets/fonts/nanum_gothic_bold.ttf")
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 24
	var black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	canvas = Control.new()
	canvas.size = DESIGN_SIZE
	canvas.clip_contents = true
	add_child(canvas)
	advance_button = Button.new()
	advance_button.size = DESIGN_SIZE
	advance_button.flat = true
	advance_button.focus_mode = Control.FOCUS_NONE
	for state in ["normal","hover","pressed","focus"]: advance_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	advance_button.pressed.connect(advance)
	canvas.add_child(advance_button)
	_build_impact()
	_build_dialogue()
	continue_button = _utility_button("이어하기",Vector2(972,20),finish)
	continue_button.visible = FileAccess.file_exists("user://map_run_v1.json") and get_node("/root/RunSession").world==null
	skip_button = _utility_button("건너뛰기",Vector2(1120,20),finish)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if not is_instance_valid(canvas): return
	var ratio = minf(size.x/DESIGN_SIZE.x,size.y/DESIGN_SIZE.y)
	canvas.scale = Vector2.ONE*ratio
	canvas.position = (size-DESIGN_SIZE*ratio)/2.0

func _layer() -> Control:
	var node = Control.new()
	node.size = DESIGN_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(node)
	return node

func _label(parent: Control, value: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var node = Label.new()
	node.text = value
	node.position = pos
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node

func _build_impact() -> void:
	impact = _layer()
	var title = _label(impact,"쿵쾅쾅.",Vector2(240,285),Vector2(800,150),102,Color("eee8dc"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.pivot_offset = title.size/2.0
	title.scale = Vector2.ONE*0.64
	title.modulate.a = 0.0
	var strike = title.create_tween().set_parallel(true)
	strike.tween_property(title,"scale",Vector2.ONE*1.18,0.1312).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	strike.tween_property(title,"modulate:a",1.0,0.1312)
	strike.chain().tween_property(title,"scale",Vector2.ONE,0.6888).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var hint = _label(impact,"화면 클릭 / 터치 · Enter / Space",Vector2(280,642),Vector2(720,28),15,Color("918a80"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.35
	hint_tween = hint.create_tween().set_loops()
	hint_tween.tween_property(hint,"modulate:a",1.0,0.75).set_trans(Tween.TRANS_SINE)
	hint_tween.tween_property(hint,"modulate:a",0.35,0.75).set_trans(Tween.TRANS_SINE)

func _portrait(path: String, pos: Vector2, dimensions: Vector2, mirrored: bool = false) -> TextureRect:
	var texture: Texture2D = load(path)
	var node = TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	var factor = minf(dimensions.x/texture.get_width(),dimensions.y/texture.get_height())
	node.size = texture.get_size()*factor
	node.position = pos+Vector2((dimensions.x-node.size.x)/2.0,dimensions.y-node.size.y)
	node.flip_h = mirrored
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_stage.add_child(node)
	return node

func _build_dialogue() -> void:
	dialogue_stage = _layer()
	var backdrop = ColorRect.new()
	backdrop.size = DESIGN_SIZE
	backdrop.color = Color("050505")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_stage.add_child(backdrop)
	hero = _portrait("res://assets/intro/necromancer.webp",Vector2(51.2,14.4),Vector2(512,518.4))
	commander = _portrait("res://assets/intro/knight_commander.webp",Vector2(678.4,-28.8),Vector2(588.8,561.6),true)
	var box = Control.new()
	box.position = Vector2(102.4,489.6)
	box.size = Vector2(1075.2,216)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_stage.add_child(box)
	var frame = TextureRect.new()
	frame.texture = load("res://assets/intro/dialogue_frame.webp")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = box.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	speaker_label = _label(box,"",box.size*Vector2(0.1,0.17),Vector2(850,30),19,Color("3a2819"))
	text_label = _label(box,"",box.size*Vector2(0.1,0.42),Vector2(860,95),24,Color("21150d"))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var arrow = _label(box,"▼",Vector2(box.size.x*0.92-20,box.size.y*0.85-22),Vector2(22,24),18,Color("5e4329"))
	var baseline = arrow.position.y
	var bob = arrow.create_tween().set_loops().set_parallel(true)
	bob.tween_property(arrow,"position:y",baseline+4,0.45).set_trans(Tween.TRANS_SINE)
	bob.tween_property(arrow,"modulate:a",1.0,0.45).from(0.45)
	bob.chain().tween_property(arrow,"position:y",baseline,0.45).set_trans(Tween.TRANS_SINE)
	bob.parallel().tween_property(arrow,"modulate:a",0.45,0.45)
	dialogue_stage.hide()

func _utility_button(title: String, pos: Vector2, callback: Callable) -> Button:
	var node = Button.new()
	node.text = title
	node.position = pos
	node.size = Vector2(136,42)
	node.add_theme_font_size_override("font_size",15)
	node.add_theme_color_override("font_color",Color("b6aa95"))
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(callback)
	canvas.add_child(node)
	var feedback = ButtonEffects.new()
	feedback.hover_scale = Vector2.ONE*1.04
	feedback.hover_rotation_degrees = 0.0
	node.add_child(feedback)
	return node

func advance() -> void:
	if leaving: return
	if lines.is_empty(): finish(); return
	if line_index>=lines.size()-1: finish(); return
	line_index += 1
	if line_index==0:
		impact.hide()
		hint_tween.kill()
		dialogue_stage.show()
	var line: Dictionary = lines[line_index]
	speaker_label.text = line.speaker
	text_label.text = line.text
	hero.visible = line.speaker=="주인공"
	commander.visible = line.speaker=="기사단장"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
			advance()
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ESCAPE:
			finish()
			get_viewport().set_input_as_handled()

func finish() -> void:
	if leaving: return
	leaving = true
	advance_button.disabled = true
	skip_button.disabled = true
	continue_button.disabled = true
	var fade = create_tween()
	fade.tween_property(canvas,"modulate:a",0.0,ending_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade.finished
	var error = get_tree().change_scene_to_file("res://map.tscn")
	if error!=OK:
		leaving = false
		canvas.modulate.a = 1.0
		advance_button.disabled = false
		skip_button.disabled = false
		continue_button.disabled = false
		text_label.text = "맵을 열지 못했습니다. 다시 시도해 주세요."
