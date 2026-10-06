extends Control

const MapState = preload("res://systems/map_state.gd")
const BattleDeck = preload("res://systems/battle_deck.gd")
const UnitInfo = preload("res://systems/unit_info.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const EVENT_IMAGES = {"home":"home","village":"village","graveyard":"graveyard","altar":"altar","unknown":"world-tree","forest":"forest","rest":"camp","fortune-teller-camp":"fortune-teller"}
var session
var world
var stage: Control
var buttons: Array = []
var hero: TextureRect
var dice: TextureButton
var status: Label
var hud: Label
var overlay: Control
var selected = -1
var moving = false
var textures: Dictionary = {}

func _ready() -> void:
	DisplayServer.window_set_title("Necromancer and Dice")
	session = get_node("/root/RunSession")
	session.ensure_world()
	world = session.world
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic","맑은 고딕"])
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	render()
	if not session.notice.is_empty():
		status.text = session.notice
		session.notice = ""
	if world.roster.is_empty(): status.text = "출전 가능한 마물이 없습니다 · 새 원정을 시작하세요."
	session.save_world()

func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

func image(parent: Control, path: String, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var node = TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = texture(path)
	node.position = pos
	node.size = dimensions
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func label_at(parent: Control, value: String, pos: Vector2, dimensions: Vector2, font_size: int = 15) -> Label:
	var node = Label.new()
	node.text = value
	node.position = pos
	node.size = dimensions
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("f2dfb5"))
	node.add_theme_color_override("font_shadow_color",Color.BLACK)
	node.add_theme_constant_override("shadow_offset_y",2)
	parent.add_child(node)
	return node

func button(parent: Control, title: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var node = Button.new()
	node.text = title
	node.position = pos
	node.size = dimensions
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func center(index: int) -> Vector2:
	return MapState.centers()[index]*Vector2(12.8,7.2)

func tile_path(index: int) -> String:
	var id: String = world.tiles[index]
	if id=="rare-monster" and index in world.cleared: id = "monster"
	if index in world.cleared and id in ["monster","rare-monster","boss"]: id += "-cleared"
	return "res://assets/map/tiles/"+id+".png"

func render() -> void:
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	buttons = []
	stage = Control.new()
	stage.size = Vector2(1280,720)
	add_child(stage)
	var background = image(stage,"res://assets/map/maps/%s-map.jpg" % world.region,Vector2.ZERO,stage.size)
	background.stretch_mode = TextureRect.STRETCH_SCALE
	for i in range(24):
		var node = TextureButton.new()
		node.ignore_texture_size = true
		node.texture_normal = texture(tile_path(i))
		node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		node.size = Vector2(158.72,111.77)
		node.position = center(i)-node.size/2
		node.pivot_offset = node.size/2
		node.tooltip_text = "%d번 · %s%s" % [i+1,MapState.NAMES[world.tiles[i]]," · 처치 완료" if i in world.cleared else ""]
		node.pressed.connect(func(): select_tile(i))
		stage.add_child(node)
		buttons.append(node)
	hero = image(stage,"res://assets/map/hero/necromancer-hero.png",Vector2.ZERO,Vector2(81.92,120))
	hero.z_index = 16
	hero.position = hero_position(world.position)
	dice = TextureButton.new()
	dice.ignore_texture_size = true
	dice.texture_normal = texture("res://assets/battle/dice/result-%02d.png" % world.last_face)
	dice.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	dice.size = Vector2(76,76)
	dice.position = Vector2(602,307.6)
	dice.z_index = 19
	dice.tooltip_text = "주사위를 굴려 이동"
	dice.pressed.connect(roll_move)
	stage.add_child(dice)
	status = label_at(stage,"주사위를 굴려 길을 따라 이동하세요",Vector2(285,385),Vector2(710,38),16)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.z_index = 25
	hud = label_at(stage,"기본 지역 · 오염도 %d/100 · %d바퀴" % [world.contamination,world.laps],Vector2(420,16),Vector2(440,30),14)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.z_index = 25
	button(stage,"새 원정",Vector2(12,12),Vector2(94,30),confirm_new_run).z_index = 25
	var book = TextureButton.new()
	book.ignore_texture_size = true
	book.texture_normal = texture("res://assets/map/ui/map-book-closed.png")
	book.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	book.size = Vector2(133,133)
	book.position = Vector2(13,550)
	book.z_index = 50
	book.tooltip_text = "보유 마물"
	book.pressed.connect(show_roster)
	stage.add_child(book)
	label_at(stage,"보유 마물 %d" % world.roster.size(),Vector2(20,684),Vector2(130,26),12).z_index = 51
	highlight(world.position)

func hero_position(index: int) -> Vector2:
	return center(index)-Vector2(40.96,86.4)

func highlight(index: int) -> void:
	selected = index
	for i in range(buttons.size()):
		buttons[i].scale = Vector2(1.12,1.12) if i==index else Vector2.ONE
		buttons[i].z_index = 4 if i==index else 0

func roll_move() -> void:
	if moving or is_instance_valid(overlay): return
	moving = true
	dice.disabled = true
	status.text = "주사위를 굴리는 중…"
	for i in range(12):
		dice.texture_normal = texture("res://assets/battle/dice/roll-%02d.png" % (i+1))
		await get_tree().create_timer(0.07).timeout
	var face = world.rng.randi_range(1,6)
	dice.texture_normal = texture("res://assets/battle/dice/result-%02d.png" % face)
	var previous = world.position
	var path = world.move_path(face)
	for index in path:
		hero.flip_h = center(index).x < center(previous).x
		var tween = create_tween()
		tween.tween_property(hero,"position",hero_position(index),0.23)
		await tween.finished
		highlight(index)
		previous = index
	status.text = "주사위 %d · %d칸 이동 · %s 도착" % [face,path.size(),MapState.NAMES[world.tiles[world.position]]]
	if world.tiles[world.position]=="warp":
		world.position = world.warp_destination()
		hero.position = hero_position(world.position)
		highlight(world.position)
		status.text = "%d번 워프로 이동했습니다" % (world.position+1)
	elif world.tiles[world.position]=="swamp":
		for u in world.roster: u.current_hp = maxi(1,u.current_hp-1)
		status.text = "오염된 늪지대 · 보유 마물 체력 -1 (최소 1 유지)"
	session.save_world()
	moving = false
	dice.disabled = false
	var type: String = world.tiles[world.position]
	if type in ["monster","rare-monster","boss"] and not world.position in world.cleared: show_tile(world.position)
	elif type in EVENT_IMAGES or type in ["gem","event"]: show_tile(world.position)

func select_tile(index: int) -> void:
	if moving or is_instance_valid(overlay): return
	highlight(index)
	status.text = "%d번 · %s%s" % [index+1,MapState.NAMES[world.tiles[index]]," · 처치 완료" if index in world.cleared else ""]
	show_tile(index)

func modal() -> Control:
	var node = Control.new()
	node.size = Vector2(1280,720)
	node.z_index = 80
	stage.add_child(node)
	var backdrop = ColorRect.new()
	backdrop.color = Color("030201c4")
	backdrop.size = node.size
	node.add_child(backdrop)
	overlay = node
	return node

func close_overlay() -> void:
	if is_instance_valid(overlay):
		stage.remove_child(overlay)
		overlay.queue_free()
	overlay = null

func show_tile(index: int) -> void:
	var type: String = world.tiles[index]
	if type=="basic": return
	if type in ["monster","rare-monster","boss"] and not index in world.cleared:
		show_battle_deck(index)
		return
	var panel = modal()
	if type in EVENT_IMAGES:
		image(panel,"res://assets/map/events/%s.jpg" % EVENT_IMAGES[type],Vector2(256,120),Vector2(768,432))
	elif type=="gem":
		image(panel,"res://assets/map/events/treasure-chest-frame-1.png",Vector2(430,130),Vector2(420,390))
	else: image(panel,tile_path(index),Vector2(465,160),Vector2(350,260))
	var title = label_at(panel,MapState.NAMES[type],Vector2(290,92),Vector2(700,36),24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(panel,"돌아가기",Vector2(550,574),Vector2(180,42),func():
		close_overlay()
		if type=="home" and world.position==MapState.HOME:
			world.leave_home()
			session.save_world()
			render())
	if type=="rest":
		button(panel,"마물 체력 회복",Vector2(535,507),Vector2(210,42),func():
			for u in world.roster: u.current_hp = u.max_hp
			session.save_world()
			status.text = "숙영 · 모든 마물 체력 완전 회복"
			close_overlay())
	elif type=="warp":
		button(panel,"워프 이동",Vector2(550,507),Vector2(180,42),func():
			world.position = index
			world.position = world.warp_destination()
			session.save_world()
			close_overlay()
			render())

func show_roster() -> void:
	if moving or is_instance_valid(overlay): return
	var panel = modal()
	var heading = label_at(panel,"보유 마물",Vector2(240,120),Vector2(800,40),26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(world.roster.size()):
		var u: Dictionary = world.roster[i]
		var card = TextureButton.new()
		card.ignore_texture_size = true
		card.texture_normal = texture("res://assets/cards/unit-card-%s.png" % u.slug)
		card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		card.size = Vector2(135,200)
		card.position = Vector2(640-world.roster.size()*80+i*160,240)
		panel.add_child(card)
		label_at(panel,"%s\n체력 %d/%d" % [u.name,u.current_hp,u.max_hp],card.position+Vector2(0,206),Vector2(150,65),14)
		card.pressed.connect(func():
			var battle = Rules.new(world.definitions,1)
			battle.start([u],[])
			battle.units[0].hp = u.current_hp
			var info = UnitInfo.new()
			panel.add_child(info)
			info.setup(battle.units[0],battle))
	button(panel,"닫기",Vector2(550,570),Vector2(180,42),close_overlay)

func confirm_new_run() -> void:
	if moving or is_instance_valid(overlay): return
	var panel = modal()
	var question = label_at(panel,"현재 원정을 끝내고 새로 시작하시겠습니까?",Vector2(300,280),Vector2(680,50),22)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(panel,"취소",Vector2(460,380),Vector2(150,42),close_overlay)
	button(panel,"새 원정 시작",Vector2(650,380),Vector2(180,42),func():
		world = MapState.new(world.definitions,Time.get_ticks_usec())
		session.world = world
		session.encounter = {}
		session.save_world()
		close_overlay()
		render())


func show_battle_deck(index: int) -> void:
	if world.roster.is_empty():
		status.text = "출전 가능한 마물이 없습니다 · 새 원정을 시작하세요."
		return
	var deck = BattleDeck.new()
	deck.z_index = 80
	stage.add_child(deck)
	overlay = deck
	deck.setup(world.roster)
	deck.confirmed.connect(func(ids: Array):
		if session.start_encounter(index,ids):
			get_tree().change_scene_to_file("res://battlefield.tscn")
		else:
			close_overlay()
			status.text = "출전 편성을 확인할 수 없습니다. 다시 선택하세요.")
