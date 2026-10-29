extends Control
## Production story shell. RunSession and the existing map callbacks own progress.
signal opened
signal closed
const ManuscriptArt = preload("res://systems/main_story_manuscript_art.gd")
const Sound = preload("res://systems/game_audio.gd")
const Surface = preload("res://systems/story_book_surface.gd")
const InkChoice = preload("res://systems/story_book_ink_choice.gd")
const Typewriter = preload("res://systems/story_typewriter.gd")
const FONT = preload("res://assets/fonts/nanum_gothic_regular.ttf")
const DISPLAY_SCALE := Vector2(0.84,0.84)
const DISPLAY_POSITION := Vector2(102.4,57.6)
const ART_RECT := Rect2(178,218,360,202.5)
const SOURCE_ART := Rect2(243.2,136.8,793.6,446.4)
const INK := Color("3b2a1d")
const RED_INK := Color("813b2b")
class Seal extends Control:
	func _draw() -> void:
		draw_arc(Vector2(35,35),31,0,TAU,64,Color("813b2b"),1.4,true)
		draw_arc(Vector2(35,35),27,0,TAU,64,Color("813b2b80"),0.8,true)
var instant := false
var opening := true
var closing := false
var surface: Control
var page_frame: TextureRect
var art: Control
var typewriter: Node
var backdrop: ColorRect
var animation: Tween
var progress := 0.0
var _prepared := false
var _ready_emitted := false
var _button_states: Dictionary = {}
var _caption: Label
var _chapter: Label
var _record: Label
var _page_left: Label
var _page_right: Label

func _ready() -> void:
	name = "MainStoryBook"
	size = Vector2(1280,720)
	scale = DISPLAY_SCALE
	position = DISPLAY_POSITION
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop = ColorRect.new()
	backdrop.position = -DISPLAY_POSITION / DISPLAY_SCALE
	backdrop.size = size / DISPLAY_SCALE
	backdrop.color = Color("080705d9")
	backdrop.mouse_filter = Control.MOUSE_FILTER_PASS
	backdrop.set_meta("ui_backdrop",true)
	add_child(backdrop)
	surface = Surface.new()
	surface.size = size
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	page_frame = TextureRect.new()
	page_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	page_frame.texture = surface.open_texture
	page_frame.position = Vector2(40,60)
	page_frame.size = Vector2(1200,600)
	page_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_frame.visible = false
	add_child(page_frame)
	art = Control.new()
	art.name = "BookIllustration"
	art.position = ART_RECT.position
	art.size = ART_RECT.size
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	typewriter = Typewriter.new()
	typewriter.name = "StoryTypewriter"
	typewriter.characters_per_second = 38.0
	add_child(typewriter)
	gui_input.connect(_page_input)
	call_deferred("_start")

func _start() -> void:
	if _ready_emitted or closing or not is_inside_tree(): return
	_prepare()
	if instant:
		Sound.cue(self,"book_page")
		_finish_opening()
		return
	Sound.cue(self,"book_open")
	_set_page_alpha(0.0)
	_set_progress(0.0)
	animation = create_tween()
	animation.tween_method(_set_progress,0.0,1.0,1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	animation.tween_method(_set_page_alpha,0.0,1.0,0.28)
	animation.tween_callback(_finish_opening)

func _prepare() -> void:
	if _prepared: return
	_prepared = true
	arrange_actions()
	for child in get_children():
		if child is Button:
			_button_states[child] = child.disabled
			child.disabled = true
		if child is Label and child.has_meta("book_copy_role"):
			child.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			child.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			child.add_theme_color_override("font_color",RED_INK if child.get_meta("book_copy_role")=="speaker" else INK)
			child.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
			child.add_theme_constant_override("shadow_offset_y",0)
	typewriter.set_process(false)

func _set_progress(value: float) -> void:
	progress = value
	surface.progress = value
	surface.queue_redraw()
	surface.visible = value < 0.9999
	page_frame.visible = not surface.visible

func _set_page_alpha(value: float) -> void:
	for child in get_children():
		if child is CanvasItem and child not in [surface,page_frame,backdrop]: child.modulate.a = value

func _finish_opening() -> void:
	if _ready_emitted or not is_inside_tree(): return
	_ready_emitted = true
	opening = false
	_set_progress(1.0)
	_set_page_alpha(1.0)
	for action in _button_states:
		if is_instance_valid(action): action.disabled = bool(_button_states[action])
	typewriter.set_process(typewriter.is_revealing())
	for child in get_children():
		if child is Button and not child.disabled and bool(child.get_meta("story_button_primary",true)):
			child.grab_focus()
			break
	opened.emit()

func skip_opening() -> void:
	if not opening: return
	Sound.stop(self)
	if animation != null and animation.is_valid(): animation.kill()
	_prepare()
	_finish_opening()

func reveal_for_input() -> bool:
	if closing: return true
	if opening:
		skip_opening()
		typewriter.reveal_all()
		return true
	return typewriter.reveal_all()

func _page_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap and opening:
		skip_opening()
		accept_event()

func close_book() -> void:
	if closing: return
	closing = true
	Sound.stop(self)
	Sound.cue(get_parent(),"book_close")
	if animation != null and animation.is_valid(): animation.kill()
	typewriter.clear()
	for child in get_children():
		if child is Button: child.disabled = true
	animation = create_tween()
	animation.tween_method(_set_page_alpha,1.0,0.0,0.2)
	animation.tween_method(_set_progress,1.0,0.0,1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	animation.tween_callback(func(): closed.emit())

static func is_source_art_rect(at: Vector2, dimensions: Vector2) -> bool:
	return SOURCE_ART.grow(0.5).encloses(Rect2(at,dimensions))

static func layer_bounds(path: String, original: Rect2) -> Rect2:
	if path.get_file().begins_with("manuscript_"):
		var mirrored_player: bool = path.ends_with("manuscript_village_necromancer.png") and not original.is_equal_approx(SOURCE_ART)
		return ManuscriptArt.layer_bounds(path,ART_RECT.size,mirrored_player)
	match path.get_file():
		"prophet_story_actor.png": return Rect2(145,4,210,246)
		"rumor-villagers-whisper.webp", "rumor-villagers-turn.webp": return Rect2(53,12.5,152.05,190)
		"rumor-necromancer.webp": return Rect2(206,12.5,152.05,190)
		"knight-commander-upperbody-hd.webp": return Rect2(124,34.5,224,168)
		"necromancer-upperbody-hd.webp": return Rect2(18,42.5,213.333333,160)
		"monster-hunter-corrupted-beast-scene.webp": return Rect2(90,0,180,202.5)
		"monster-hunter-pen-clean.webp": return Rect2(214,18.5,122.666667,184)
		"cultist-rumor-procession.webp", "cultist-altar-ritual-layer.webp", "cultist-altar-summon-layer.webp": return Rect2(37.8533475,42.5,284.293305,160)
		"ritual-portal-energy-layer.webp", "ritual-portal-cultists-layer.webp", "ritual-portal-omen-layer.webp": return Rect2(7.2,6.075,270,151.875)
	return Rect2((original.position-SOURCE_ART.position)/SOURCE_ART.size*ART_RECT.size,original.size/SOURCE_ART.size*ART_RECT.size)

func add_source_image(path: String, original: Rect2, source_texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = source_texture
	if path.get_file().begins_with("manuscript_"):
		# Detailed manuscript paintings are reduced to the small book picture.
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var bounds := layer_bounds(path,original)
	image.position = bounds.position
	image.size = bounds.size
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if original.is_equal_approx(SOURCE_ART) and bounds.size.is_equal_approx(ART_RECT.size) else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(image)
	return image

func copy(value: String, bounds: Rect2, points: int, color: Color=INK) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",color)
	label.position = bounds.position
	label.size = bounds.size
	label.text = value
	add_child(label)
	return label

func show_seal(value: String) -> void:
	var seal := Seal.new()
	seal.position = Vector2(315,481)
	seal.size = Vector2(70,70)
	seal.pivot_offset = Vector2(35,35)
	seal.rotation_degrees = -6.0
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seal)
	var caption := copy(value,Rect2(0,18,70,30),21,RED_INK)
	caption.reparent(seal,false)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opened.connect(func():
		Sound.cue(self,"book_stamp")
		seal.modulate.a = 0.0
		create_tween().tween_property(seal,"modulate:a",1.0,0.36)
	,CONNECT_ONE_SHOT)

func set_heading(value: String) -> void:
	var heading := value.trim_prefix("사건 · ")
	var information: Array = ["기록",heading,"원정 이야기",0]
	match heading:
		"습격받는 아이": information = ["첫 번째 기록","습격받는 아이","공동묘지",1]
		"마을": information = ["두 번째 기록","마을 소문","마을",3]
		"기사단장": information = ["세 번째 기록","기사단장","마을 길목",5]
		"세계수": information = ["네 번째 기록","마물 사냥꾼","세계수",7]
		"예언가": information = ["네 번째 기록","예언가의 단서","예언자의 막사",7]
		"같은 문양": information = ["다섯 번째 기록","광신도 소문","마을",9]
		"광신도의 의식", "광신도": information = ["여섯 번째 기록","광신도의 의식","밤의 제단",11]
		"마물의 왕 부활 의식": information = ["일곱 번째 기록",heading,"의식의 폐허",13]
		"왕의 흔적": information = ["여덟 번째 기록","마물의 왕 추적","세계수",15]
	if _record == null:
		_record = copy(str(information[0]),Rect2(118,126,450,30),18,Color("775b3d"))
		_chapter = copy("제1장 · "+str(information[2]),Rect2(702,124,444,25),14,Color("81684b"))
		_caption = copy(str(information[2]),Rect2(178,440,360,30),16,Color("81684b"))
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_page_left = copy(str(information[3]),Rect2(118,564,30,24),13,Color("9a805d"))
		_page_right = copy(str(int(information[3])+1),Rect2(1149,564,30,24),13,Color("9a805d"))
	return

func add_source_label(value: String, original: Rect2, points: int) -> Label:
	var role := "note"
	var bounds := Rect2(702,482,432,46)
	var font_size := 17
	var shown := value
	if original.position.y>=75.0 and original.position.y<140.0 and original.size.x>300.0:
		set_heading(value)
		role = "title"
		bounds = Rect2(702,158,444,62)
		font_size = 29
		shown = value.trim_prefix("사건 · ")
		if shown=="마을": shown="마을 소문"
		elif shown=="세계수": shown="마물 사냥꾼"
		elif shown=="같은 문양": shown="광신도 소문"
		elif shown=="왕의 흔적": shown="마물의 왕 추적"
	elif original.position.y>=525.0 and original.position.y<590.0:
		role = "narration"
		bounds = Rect2(702,233,432,78)
		font_size = 20
	elif original.position.y>=590.0 and original.position.y<647.0:
		if original.size.x<180.0 and value!="▼":
			role = "speaker"
			bounds = Rect2(702,321,432,25)
			font_size = 16
		else:
			role = "speech"
			bounds = Rect2(702,358,432,112)
			font_size = 24
			var colon := value.find(": ")
			if colon>0 and colon<20:
				var speaker := copy(value.left(colon),Rect2(702,321,432,25),16,RED_INK)
				speaker.set_meta("book_copy_role","speaker")
				shown = value.substr(colon+2)
	var label := copy(shown,bounds,font_size)
	label.set_meta("book_copy_role",role)
	if value=="▼":
		label.hide()
		label.set_meta("book_skip",true)
	elif role in ["narration","speech"] and not shown.is_empty():
		label.set_meta("ui_story_copy_role",role)
		typewriter.track(label)
	return label

func style_action(action: Button, bounds: Rect2, points: int=22) -> void:
	action.set_meta("sfx_manual",true) # First input may only reveal dialogue.
	if action.get_script()!=InkChoice: action.set_script(InkChoice)
	action.position = bounds.position
	action.size = bounds.size
	action.alignment = HORIZONTAL_ALIGNMENT_LEFT
	action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 33
	for state in ["normal","hover","focus","pressed","disabled"]: action.add_theme_stylebox_override(state,empty)
	action.add_theme_font_override("font",FONT)
	action.add_theme_font_size_override("font_size",points)
	action.add_theme_color_override("font_color",INK)
	action.add_theme_color_override("font_disabled_color",Color("9a805d"))
	for state in ["font_hover_color","font_focus_color","font_pressed_color"]: action.add_theme_color_override(state,RED_INK)

func arrange_actions() -> void:
	var primary: Array[Button] = []
	var secondary: Array[Button] = []
	for child in get_children():
		if child is Button and child.has_meta("story_button_primary"):
			if bool(child.get_meta("story_button_primary")): primary.append(child)
			else: secondary.append(child)
	for i in range(primary.size()):
		style_action(primary[i],Rect2(700,482 if primary.size()==1 else 428+i*54,440,44))
	for i in range(secondary.size()):
		var width := 440.0 if secondary.size()==1 else 210.0
		style_action(secondary[i],Rect2(700+i*240,554,width,44),17)
	for child in get_children():
		if not child is Label or not child.has_meta("book_copy_role") or child.has_meta("book_skip"): continue
		var role: String = str(child.get_meta("book_copy_role"))
		var points := 20 if role=="narration" else (24 if role=="speech" else (29 if role=="title" else 16))
		if role=="speech" and primary.size()>1:
			child.size.y = 64
			points = 20
		if role=="narration" and not _has_speech(): child.size.y = 177
		child.add_theme_font_size_override("font_size",points)
		while points>16 and child.get_line_count()*child.get_line_height()>child.size.y:
			points -= 1
			child.add_theme_font_size_override("font_size",points)

func _has_speech() -> bool:
	for child in get_children():
		if child is Label and child.get_meta("book_copy_role","")=="speech" and not child.has_meta("book_skip") and not child.text.is_empty(): return true
	return false

func _exit_tree() -> void:
	Sound.stop(self)
	if animation != null and animation.is_valid(): animation.kill()

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree() and is_instance_valid(typewriter):
		call_deferred("arrange_actions")
