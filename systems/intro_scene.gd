extends Control
## Original v2-intro: impact, twelve dialogue lines, 520 ms fade to the map.
const DESIGN_SIZE = Vector2(1280,720)
const ButtonEffects = preload("res://systems/button_effects_module.gd")
const AudioSettings = preload("res://systems/audio_settings.gd")
const StoryTypewriter = preload("res://systems/story_typewriter.gd")
@export_range(0.1,1.5,0.01) var ending_duration: float = 0.52
var canvas: Control
var impact: Control
var dialogue_stage: Control
var hero: TextureRect
var commander: TextureRect
var speaker_label: Label
var text_label: Label
var dialogue_typewriter: Node
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

## High-fidelity intro dialogue trim, assembled from live Godot nodes.
## This intentionally does not alter the shared story parchment or any art.
func _dialogue_panel(parent: Control, title: String, bounds: Rect2, fill: Color, outline: Color, width: int = 2, rounding: int = 6) -> Panel:
	var node := Panel.new()
	node.name = title
	node.position = bounds.position
	node.size = bounds.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = fill
	skin.border_color = outline
	skin.set_border_width_all(width)
	skin.set_corner_radius_all(rounding)
	node.add_theme_stylebox_override("panel",skin)
	parent.add_child(node)
	return node

func _dialogue_rule(parent: Control, title: String, bounds: Rect2, tint: Color) -> ColorRect:
	var line := ColorRect.new()
	line.name = title
	line.position = bounds.position
	line.size = bounds.size
	line.color = tint
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line

func _dialogue_diamond(parent: Control, title: String, center: Vector2, radius: float, tint: Color) -> Polygon2D:
	var gem := Polygon2D.new()
	gem.name = title
	gem.position = center
	gem.polygon = PackedVector2Array([
		Vector2(0,-radius),Vector2(radius,0),
		Vector2(0,radius),Vector2(-radius,0)])
	gem.color = tint
	parent.add_child(gem)
	return gem

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
	box.name = "IntroDialogueBox"
	box.position = Vector2(102.4,489.6)
	box.size = Vector2(1075.2,216)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_stage.add_child(box)
	# Antique bronze depth behind the original hand-drawn parchment.
	_dialogue_panel(box,"DialogueShadow",Rect2(9,12,1057,195),
		Color("110c0bd9"),Color("21140edd"),5,9)
	var frame = TextureRect.new()
	frame.name = "IntroParchment"
	frame.texture = load("res://assets/map/ui/shared_dialogue_panel.svg")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = box.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	# Double-rule metalwork adds depth without masking the original paper.
	_dialogue_panel(box,"BronzeInset",Rect2(34,34,1007,151),
		Color.TRANSPARENT,Color("67442d99"),2,3)
	_dialogue_panel(box,"GoldHairline",Rect2(40,40,995,139),
		Color.TRANSPARENT,Color("fff0c451"),1,2)
	_dialogue_rule(box,"UpperGiltRule",Rect2(334,24,685,2),Color("deb87bba"))
	_dialogue_rule(box,"UpperDarkRule",Rect2(334,28,685,1),Color("48301bb8"))
	_dialogue_rule(box,"LowerGiltRule",Rect2(115,186,845,2),Color("9f7645c9"))
	# The speaker sits in its own raised oxblood nameplate instead of floating
	# inside the parchment alongside the spoken line.
	var plate := _dialogue_panel(box,"SpeakerNameplate",
		Rect2(78,-14,331,67),Color("261511"),Color("a37b4d"),3,7)
	_dialogue_panel(plate,"NameplateInset",Rect2(5,5,321,57),
		Color("43251f"),Color("c49960"),1,5)
	_dialogue_rule(plate,"NameplateSheen",Rect2(72,11,235,1),Color("efd0a66f"))
	_dialogue_rule(plate,"NameplateUnderline",Rect2(72,54,235,1),Color("130d0b"))
	# A small layered heraldic seal is drawn with native polygons.
	var seal := _dialogue_panel(plate,"HeraldicSeal",
		Rect2(10,9,48,49),Color("271d17"),Color("d5ad70"),2,8)
	_dialogue_diamond(seal,"OuterCrest",Vector2(24,24),15,Color("d6ae6f"))
	_dialogue_diamond(seal,"InnerCrest",Vector2(24,24),10,Color("493022"))
	_dialogue_diamond(seal,"CrestStar",Vector2(24,24),5,Color("f6dfab"))
	speaker_label = _label(plate,"",Vector2(75,12),Vector2(242,42),24,Color("f7e3b5"))
	speaker_label.name = "IntroSpeakerName"
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.add_theme_color_override("font_shadow_color",Color("090504ad"))
	speaker_label.add_theme_constant_override("shadow_offset_y",1)
	# Readable manuscript text, with a consistent left inset and room for
	# wrapping all twelve existing lines without clipping.
	text_label = _label(box,"",Vector2(94,84),Vector2(860,99),27,Color("24170f"))
	text_label.name = "IntroDialogueText"
	text_label.add_theme_font_override("font",preload("res://assets/fonts/nanum_gothic_regular.ttf"))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_typewriter = StoryTypewriter.new()
	dialogue_typewriter.name = "IntroTypewriter"
	dialogue_stage.add_child(dialogue_typewriter)
	# A gold-trimmed live continue marker; the full-screen input button stays
	# above the visual stage and remains the sole scene-advance input.
	var next_badge := _dialogue_panel(box,"DialogueNextBadge",
		Rect2(975,146,49,46),Color("2c1c15e6"),Color("b9915e"),2,8)
	_dialogue_diamond(next_badge,"NextCrest",Vector2(24,23),13,Color("dcb778"))
	_dialogue_diamond(next_badge,"NextCore",Vector2(24,23),9,Color("4b3021"))
	var arrow = _label(next_badge,"▼",Vector2(10,8),Vector2(28,28),19,Color("f5d69d"))
	arrow.name = "IntroContinueArrow"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var baseline = arrow.position.y
	var bob = arrow.create_tween().set_loops().set_parallel(true)
	bob.tween_property(arrow,"position:y",baseline+3,0.45).set_trans(Tween.TRANS_SINE)
	bob.tween_property(arrow,"modulate:a",1.0,0.45).from(0.6)
	bob.chain().tween_property(arrow,"position:y",baseline,0.45).set_trans(Tween.TRANS_SINE)
	bob.parallel().tween_property(arrow,"modulate:a",0.6,0.45)
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
	if is_instance_valid(dialogue_typewriter) and dialogue_typewriter.reveal_all(): return
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
	dialogue_typewriter.clear()
	dialogue_typewriter.track(text_label)
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
