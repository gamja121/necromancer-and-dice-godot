extends Control
## Book presentation only. RunSession owns every durable transition.
signal battle_requested
signal title_requested
const Dragon = preload("res://systems/final_dragon_presentation.gd")
const InkReveal = preload("res://systems/ink_scene_reveal.gd")
const FONT = preload("res://assets/fonts/NanumBarunGothic.ttf")
const INK = Color("3e3024")
const RED_INK = Color("813b2e")
const PAPER_SHADER = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV * vec2(1160.0, 610.0);
	float grain = fract(sin(dot(floor(p), vec2(12.9898,78.233))) * 43758.5453);
	float fibers = sin(p.y * 1.6 + sin(p.x * 0.08)) * 0.006;
	float edge = pow(abs(UV.y-0.5)*2.0, 10.0)*0.045;
	vec3 paper = mix(vec3(0.81,0.69,0.49),vec3(0.91,0.82,0.64),0.66);
	COLOR = vec4(paper + (grain-0.5)*0.025 + fibers - edge,1.0);
}
"""
class InkAction:
	extends Button
	func _draw() -> void:
		if disabled or not (is_hovered() or has_focus() or button_pressed): return
		var ink := Color("813b2e")
		var middle := size.y*0.5
		draw_colored_polygon(PackedVector2Array([Vector2(8,middle-6),Vector2(19,middle),Vector2(8,middle+6)]),ink)
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_MOUSE_ENTER,NOTIFICATION_MOUSE_EXIT,NOTIFICATION_FOCUS_ENTER,NOTIFICATION_FOCUS_EXIT]:
			queue_redraw()

class BookDetails:
	extends Control
	var clock := 0.0
	func _draw() -> void:
		var rule := Color("a58a61")
		draw_rect(Rect2(94,188,496,289),Color("64523b"),false,2)
		draw_line(Vector2(100,175),Vector2(588,175),rule,1)
		draw_line(Vector2(699,368),Vector2(1166,368),rule,1)
		draw_line(Vector2(699,557),Vector2(1166,557),rule,1)
		draw_line(Vector2(88,608),Vector2(590,608),rule,1)
		draw_line(Vector2(88,618),Vector2(590,618),Color("b5a07a"),1)
		draw_arc(Vector2(339,563),44,0,TAU,64,Color("813b2eb0"),2,true)
		draw_arc(Vector2(339,563),40,0,TAU,64,Color("813b2e70"),1,true)
		for i in range(14):
			var x := 115.0+fmod(float(i)*91.7,451.0)
			var y := 207.0+fmod(float(i)*43.2-clock*(5.0+float(i%3))+2000.0,247.0)
			draw_circle(Vector2(x,y),0.9,Color(0.94,0.83,0.57,0.22+sin(clock+float(i))*0.07),true)

var details: BookDetails
var mode := ""
var presentation: Control
var action_button: Button
var skip_button: Button
var hint: Label
var record: Dictionary = {}
var page: Control
var age := 0.0
var leaving := false

func _ready() -> void:
	name = "FinalChapter"
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	set_process(false)

func _label(parent: Control, value: String, at: Vector2, bounds: Vector2, font_size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = bounds
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _action(value: String, at: Vector2, width: float, callback: Callable) -> Button:
	var button := InkAction.new()
	button.text = value
	button.position = at
	button.size = Vector2(width,48)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",FONT)
	button.add_theme_font_size_override("font_size",22)
	for key in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxEmpty.new()
		style.content_margin_left = 32
		style.content_margin_right = 8
		button.add_theme_stylebox_override(key,style)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(key,RED_INK if key!="font_color" else INK)
	button.add_theme_color_override("font_disabled_color",Color("8d7d61"))
	add_child(button)
	button.pressed.connect(callback)
	return button

func show_intro() -> void:
	mode = "intro"
	presentation = Dragon.new()
	presentation.size = size
	add_child(presentation)
	presentation.intro_finished.connect(_intro_ready)
	action_button = _action("전투 편성으로",Vector2(944,655),275,_request_battle)
	action_button.name = "EnterFinalBattle"
	action_button.disabled = true
	skip_button = _action("연출 건너뛰기",Vector2(986,23),250,_skip_intro)
	skip_button.name = "SkipFinalIntro"
	hint = _label(self,"",Vector2(76,665),Vector2(840,32),17,RED_INK)
	if not presentation.play_intro(): _intro_ready()
	skip_button.grab_focus()

func _skip_intro() -> void:
	if not is_instance_valid(presentation): return
	if presentation.intro_active: presentation.advance(Dragon.INTRO_SECONDS+0.1)
	_intro_ready()

func _intro_ready() -> void:
	action_button.disabled = false
	skip_button.hide()
	action_button.grab_focus()

func _request_battle() -> void:
	if leaving or action_button.disabled: return
	battle_requested.emit()

func show_storage_error(message: String) -> void:
	hint.text = message
	action_button.disabled = false
	action_button.grab_focus()

func show_ending(result: Dictionary, instant: bool = false) -> void:
	mode = "ending"
	record = result.duplicate(true)
	page = Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.size = size
	add_child(page)
	var paper := ColorRect.new()
	paper.position = Vector2(58,47)
	paper.size = Vector2(1164,615)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = PAPER_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	paper.material = material
	page.add_child(paper)
	# Spine shading leaves the illustration and prose on separate pages.
	for i in range(28):
		var fold := ColorRect.new()
		fold.position = Vector2(626+i,48)
		fold.size = Vector2(1,613)
		fold.color = Color(0.19,0.12,0.06,0.24*(1.0-absf(float(i)-13.5)/14.0))
		fold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(fold)
	_label(page,"NECROMANCER  AND  DICE",Vector2(100,83),Vector2(490,28),16,Color("766043"))
	_label(page,"최후의 드래곤",Vector2(100,119),Vector2(480,46),32)
	var art := Control.new()
	art.position = Vector2(96,190)
	art.size = Vector2(492,285)
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(art)
	var landscape := TextureRect.new()
	landscape.texture = load("res://assets/battle/backgrounds/haunted-forest-ruins-battlefield.jpg")
	landscape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	landscape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	landscape.size = art.size
	landscape.modulate = Color(0.61,0.56,0.43,0.8)
	landscape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(landscape)
	var dragon := TextureRect.new()
	dragon.name = "DragonEngraving"
	dragon.texture = load("res://assets/battle/final_dragon/final_dragon.png")
	dragon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dragon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dragon.position = Vector2(-8,-18)
	dragon.size = Vector2(508,318)
	dragon.modulate = Color(0.77,0.72,0.58,0.85)
	dragon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(dragon)
	if not instant: InkReveal.play(dragon,1.25)
	_label(page,"봉인된 유적에 남긴 마지막 기록",Vector2(101,490),Vector2(486,28),18,Color("756047"))
	var seal := _label(page,"격 파",Vector2(255,540),Vector2(168,47),26,RED_INK)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(page,"마지막 장",Vector2(696,88),Vector2(442,26),17,Color("876b46"))
	_label(page,"드래곤을 쓰러뜨렸다.",Vector2(695,133),Vector2(450,50),32)
	_label(page,"거대한 날갯짓이 멎고,\n폐허에는 다시 고요가 내려앉았다.\n\n이 원정의 마지막 전투가 끝났다.",Vector2(698,211),Vector2(454,139),21)
	var rows: Array = [
		["완주한 바퀴","%d" % int(record.get("laps",0))],
		["쓰러뜨린 적","%d" % int(record.get("enemies_defeated",0))],
		["전투 생존 마물","%d" % int(record.get("surviving_monsters",0))],
		["떠나보낸 마물","%d" % int(record.get("lost_monsters",0))]
	]
	for i in range(rows.size()):
		var x := 700.0+float(i%2)*216.0
		var y := 387.0+float(i/2)*82.0
		_label(page,rows[i][0],Vector2(x,y),Vector2(200,24),16,Color("816c4d"))
		_label(page,rows[i][1],Vector2(x,y+27),Vector2(200,37),28)
	details = BookDetails.new()
	details.size = size
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(details)
	_label(page,"원정 완료 · 기록이 저장되었습니다.",Vector2(700,571),Vector2(440,30),17,Color("786447"))
	action_button = _action("책을 덮고 타이틀로",Vector2(860,614),333,_request_title)
	action_button.name = "CloseFinalChapter"
	action_button.grab_focus()
	if not instant:
		page.modulate.a = 0.0
		create_tween().tween_property(page,"modulate:a",1.0,0.65)
	set_process(true)
	queue_redraw()

func _request_title() -> void:
	if leaving: return
	leaving = true
	action_button.disabled = true
	title_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and mode=="intro":
		_skip_intro()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	age += minf(delta,0.05)
	if is_instance_valid(details):
		details.clock = age
		details.queue_redraw()

func _draw() -> void:
	if mode!="ending": return
	draw_rect(Rect2(Vector2.ZERO,size),Color("0e100ff5"))
	for i in range(8):
		draw_rect(Rect2(43-i,38-i,1194+2*i,638+2*i),Color(0,0,0,0.055))
	draw_rect(Rect2(44,34,1192,644),Color("35291e"))
	for i in range(5):
		draw_rect(Rect2(52,42+i*3,1176,620),Color("9b825b"))

func _exit_tree() -> void:
	if is_instance_valid(presentation): presentation.stop()
