extends Control
const Sound = preload("res://systems/game_audio.gd")
## The same approved book skin serves the actual final intro and saved ending.
## Durable acknowledgements, combat, rewards and title routing remain in map/RunSession.
signal battle_requested
signal title_requested
signal return_requested
const Book = preload("res://systems/main_story_book.gd")
const Dragon = preload("res://systems/final_dragon_presentation.gd")
const InkReveal = preload("res://systems/ink_scene_reveal.gd")
const STAGE_SIZE := Vector2(1168,657)
const STAGE_FACTOR := 360.0/1168.0
const FOREGROUND_OFFSET := Vector2(0,153)
var mode := ""
var presentation: Control
var action_button: Button
var skip_button: Button
var hint: Label
var record: Dictionary = {}
var page: Control
var book: Control
var foreground: Control
var title: Label
var narrative: Label
var leaving := false
var ending_reveal: Tween
var _last_caption := ""
var _skipping_intro := false

func _ready() -> void:
	name = "FinalChapter"
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200

func _new_book(instant: bool=false) -> void:
	book = Book.new()
	book.instant = instant
	add_child(book)
	page = book

func _action(value: String, bounds: Rect2, callback: Callable, points: int=22) -> Button:
	var action := Button.new()
	action.text = value
	book.style_action(action,bounds,points)
	action.pressed.connect(callback)
	book.add_child(action)
	return action

func show_intro() -> void:
	mode = "intro"
	_new_book()
	book.copy("아홉 번째 기록",Rect2(118,126,450,30),18,Color("775b3d"))
	book.copy("최후의 장",Rect2(702,124,444,25),14,Color("81684b"))
	title = book.copy("드래곤",Rect2(702,158,444,43),29)
	title.modulate.a = 0.0
	narrative = book.copy("",Rect2(702,233,432,130),20)
	var caption: Label = book.copy("봉인된 유적",Rect2(178,440,360,30),16,Color("81684b"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	book.copy("17",Rect2(118,564,30,24),13,Color("9a805d"))
	book.copy("18",Rect2(1149,564,30,24),13,Color("9a805d"))
	presentation = Dragon.new()
	presentation.size = Dragon.BASE_SIZE
	presentation.visible = false
	add_child(presentation)
	presentation.boss_title.modulate.a = 0.0
	var source_children: Array = presentation.stage.get_children()
	var background: TextureRect = source_children[0]
	var shade: ColorRect = source_children[1]
	presentation.stage.reparent(book.art,false)
	presentation.stage.size = STAGE_SIZE
	presentation.stage.position = Vector2.ZERO
	presentation.stage.scale = Vector2.ONE*STAGE_FACTOR
	background.size = STAGE_SIZE
	shade.size = STAGE_SIZE
	foreground = Control.new()
	foreground.position = FOREGROUND_OFFSET
	foreground.size = Dragon.ART_RECT.size
	foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.stage.add_child(foreground)
	for i in range(2,source_children.size()): source_children[i].reparent(foreground,false)
	presentation.intro_finished.connect(_intro_ready)
	action_button = _action("전투 편성으로",Rect2(700,482,440,44),_request_battle)
	action_button.name = "EnterFinalBattle"
	action_button.disabled = true
	skip_button = _action("연출 건너뛰기",Rect2(700,428,440,44),_skip_intro,18)
	skip_button.name = "SkipFinalIntro"
	_action("연출 다시보기",Rect2(700,554,210,44),_request_replay,17)
	_action("돌아가기",Rect2(940,554,200,44),_request_return,17)
	hint = book.copy("",Rect2(702,382,432,40),16,Book.RED_INK)
	book.opened.connect(_replay_intro)
	RenderingServer.frame_pre_draw.connect(_sync_from_presentation)

func _sync_from_presentation() -> void:
	if not is_instance_valid(presentation) or not is_instance_valid(presentation.stage): return
	var shake: Vector2 = presentation.stage.position-Dragon.ART_RECT.position
	# Source camera shake belongs to the figures; the page/background stay fixed.
	if presentation.stage.position.length()<10.0: shake = Vector2.ZERO
	presentation.stage.position = Vector2.ZERO
	foreground.position = FOREGROUND_OFFSET+shake
	title.modulate.a = presentation.boss_title.modulate.a if not book.opening else 0.0
	var value: String = str(presentation.caption.text)
	if value!=_last_caption:
		_last_caption = value
		narrative.text = value

func _replay_intro() -> void:
	if leaving or book.opening: return
	action_button.disabled = true
	skip_button.show()
	skip_button.disabled = false
	hint.text = ""
	if not presentation.play_intro(false,_skipping_intro): _intro_ready()
	skip_button.grab_focus()

func _request_replay() -> void:
	if leaving or book.opening: return
	Sound.cue(self,"book_confirm")
	_replay_intro()

func _skip_intro() -> void:
	if leaving: return
	_skipping_intro = true
	book.skip_opening()
	Sound.stop(presentation)
	if presentation.intro_active: presentation.advance(Dragon.INTRO_SECONDS+0.1,true)
	_skipping_intro = false
	Sound.cue(self,"book_confirm")
	_sync_from_presentation()
	_intro_ready()

func _intro_ready() -> void:
	action_button.disabled = false
	skip_button.hide()
	action_button.grab_focus()

func _request_battle() -> void:
	if leaving or action_button.disabled or book.opening: return
	Sound.stop(presentation)
	Sound.cue(self,"book_confirm")
	battle_requested.emit()

func _request_return() -> void:
	if leaving: return
	Sound.stop(presentation)
	Sound.cue(self,"book_confirm")
	leaving = true
	return_requested.emit()

func show_storage_error(message: String) -> void:
	hint.text = message
	action_button.disabled = false
	action_button.grab_focus()

func show_ending(result: Dictionary, instant: bool=false) -> void:
	mode = "ending"
	record = result.duplicate(true)
	_new_book(instant)
	book.copy("마지막 기록",Rect2(118,126,450,30),18,Color("775b3d"))
	book.copy("마지막 장",Rect2(702,124,444,25),14,Color("81684b"))
	title = book.copy("드래곤을 쓰러뜨렸다.",Rect2(702,158,444,43),29)
	narrative = book.copy("거대한 날갯짓이 멎고,\n폐허에는 다시 고요가 내려앉았다.\n\n이 원정의 마지막 전투가 끝났다.",Rect2(702,233,432,110),20)
	var background := TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.texture = load("res://assets/battle/backgrounds/haunted-forest-ruins-battlefield.jpg")
	background.size = Book.ART_RECT.size
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = Book.ART_RECT.size
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.61,0.56,0.43,0.8)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.art.add_child(background)
	var dragon := TextureRect.new()
	dragon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dragon.name = "DragonEngraving"
	dragon.texture = load("res://assets/battle/final_dragon/final_dragon.png")
	dragon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dragon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dragon.position = Vector2(8,12)
	dragon.size = Vector2(344,180)
	dragon.modulate = Color(0.77,0.72,0.58,0.85)
	dragon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.art.add_child(dragon)
	var caption: Label = book.copy("봉인된 유적에 남긴 마지막 기록",Rect2(178,440,360,30),16,Color("81684b"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var seal = Book.Seal.new()
	seal.position = Vector2(315,481)
	seal.size = Vector2(70,70)
	seal.rotation_degrees = -6.0
	seal.pivot_offset = Vector2(35,35)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(seal)
	var seal_label: Label = book.copy("격 파",Rect2(0,18,70,30),21,Book.RED_INK)
	seal_label.reparent(seal,false)
	seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rows: Array = [["완주한 바퀴","laps"],["쓰러뜨린 적","enemies_defeated"],["전투 생존 마물","surviving_monsters"],["떠나보낸 마물","lost_monsters"]]
	for i in range(rows.size()):
		var x := 702.0+228.0*float(i%2)
		var y := 366.0+72.0*float(i/2)
		book.copy(rows[i][0],Rect2(x,y,200,22),16,Color("81684b"))
		book.copy("%d" % int(record.get(rows[i][1],0)),Rect2(x,y+25,200,32),26)
	book.copy("원정 완료 · 기록이 저장되었습니다.",Rect2(702,514,432,24),15,Color("81684b"))
	book.copy("19",Rect2(118,564,30,24),13,Color("9a805d"))
	book.copy("20",Rect2(1149,564,30,24),13,Color("9a805d"))
	action_button = _action("책을 덮고 타이틀로",Rect2(700,548,440,44),_request_title)
	action_button.name = "CloseFinalChapter"
	action_button.disabled = not instant
	book.opened.connect(func():
		if instant:
			action_button.disabled = false
			action_button.grab_focus()
		else:
			Sound.cue(self,"final_clear")
			InkReveal.play(dragon,1.25)
			seal.modulate.a = 0.0
			ending_reveal = create_tween()
			ending_reveal.tween_interval(0.85)
			ending_reveal.tween_callback(func(): Sound.cue(self,"book_stamp"))
			ending_reveal.tween_property(seal,"modulate:a",1.0,0.45)
			ending_reveal.tween_callback(func():
				action_button.disabled = false
				action_button.grab_focus())
	)

func _request_title() -> void:
	if leaving or action_button.disabled or book.opening: return
	Sound.cue(self,"book_confirm")
	leaving = true
	action_button.disabled = true
	book.closed.connect(func(): title_requested.emit(),CONNECT_ONE_SHOT)
	book.close_book()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and mode=="intro":
		_skip_intro()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	Sound.stop(self)
	if ending_reveal != null and ending_reveal.is_valid(): ending_reveal.kill()
	if is_instance_valid(presentation): presentation.stop()
