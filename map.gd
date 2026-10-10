extends Control
const MapPresentation = preload("res://systems/map_presentation.gd")
var presentation
var map_audio: Control
var map_music: AudioStreamPlayer

const BattleResources = preload("res://systems/battle_resources.gd")
const BookBattleLock = preload("res://systems/book_battle_lock.gd")
const ButtonEffects = preload("res://systems/button_effects_module.gd")
const PanelEffects = preload("res://systems/panel_effects_module.gd")
const InkSceneReveal = preload("res://systems/ink_scene_reveal.gd")
const WaxSealSelection = preload("res://systems/wax_seal_selection.gd")

const ExplorationActions = preload("res://systems/exploration_actions.gd")
const PlaceActions = preload("res://systems/place_actions.gd")
const HomeInheritance = preload("res://systems/home_inheritance.gd")
const MapState = preload("res://systems/map_state.gd")
const TreasureReward = preload("res://systems/treasure_reward.gd")
const DiceHand = preload("res://systems/dice_control_hand.gd")
const InventoryPanel = preload("res://systems/inventory_panel.gd")
const AudioSettings = preload("res://systems/audio_settings.gd")
const Battlefield = preload("res://battlefield.tscn")
const BattleDeck = preload("res://systems/battle_deck.gd")
const UnitInfo = preload("res://systems/unit_info.gd")
const DiceAnimation = preload("res://systems/dice_animation.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const TILE_SIZE = Vector2(120.0,90.0)
const SELECTED_TILE_SCALE = Vector2(1.025,1.025)
const EVENT_IMAGES = {"home":"home","village":"village","graveyard":"graveyard","altar":"altar","unknown":"world-tree","forest":"forest","rest":"camp","fortune-teller-camp":"fortune-teller"}
var session
var dice_animation = DiceAnimation.new()
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
var embedded_battle: Control
var book_button: TextureButton
var book_lock: Control
var battle_returning = false
var deck_button: TextureButton
var dice_count_label: Label

func _ready() -> void:
	DisplayServer.window_set_title("Necromancer and Dice")
	AudioSettings.apply_saved()
	session = get_node("/root/RunSession")
	session.ensure_world()
	world = session.world
	var font = preload("res://assets/fonts/nanum_gothic_regular.ttf")
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	presentation = MapPresentation.new()
	add_child(presentation)
	presentation.setup(self)
	map_music = AudioStreamPlayer.new()
	map_music.bus = "Music"
	map_music.stream = load("res://assets/map/music/map_board.mp3")
	map_music.volume_db = linear_to_db(0.3)
	add_child(map_music)
	map_music.finished.connect(map_music.play)
	if DisplayServer.get_name()!="headless": map_music.play()
	render()
	var battle_resources = BattleResources.new()
	battle_resources.name = "BattleResources"
	add_child(battle_resources)
	battle_resources.setup(world)
	if not session.notice.is_empty():
		status.text = session.notice
		session.notice = ""
	if world.roster.is_empty(): status.text = "출전 가능한 마물이 없습니다 · 새 원정을 시작하세요."
	session.save_world()
	if world.pending_reward.get("kind","")=="capture": open_embedded_battle(false)
	elif world.pending_reward.get("kind","") in ["treasure","mimic"]: show_treasure()
	elif not session.encounter.is_empty(): open_embedded_battle(false)
	elif not world.pending_move.is_empty(): call_deferred("resume_map_move")

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
	add_button_effect(node)
	return node

func add_button_effect(node: BaseButton) -> void:
	if node.has_node("ButtonEffectsModule"): return
	var effect = ButtonEffects.new()
	effect.name = "ButtonEffectsModule"
	effect.hover_scale = Vector2(1.04,1.04)
	effect.hover_rotation_degrees = 0.6
	node.add_child(effect)

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
	presentation.install(stage)
	for i in range(24):
		var node = TextureButton.new()
		node.ignore_texture_size = true
		node.texture_normal = texture(tile_path(i))
		node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		node.size = TILE_SIZE
		node.position = center(i)-node.size/2
		node.pivot_offset = node.size/2
		node.tooltip_text = "%d번 · %s%s" % [i+1,MapState.NAMES[world.tiles[i]]," · 처치 완료" if i in world.cleared else ""]
		node.pressed.connect(func(): select_tile(i))
		stage.add_child(node)
		if world.scout.scouted and not i in world.cleared and world.scout.intel.any(func(entry): return int(entry.index)==i):
			var badge = label_at(node,"정찰",Vector2(78,0),Vector2(40,20),10)
			badge.add_theme_color_override("font_color",Color("eed998"))
			node.tooltip_text += " · 정찰 정보 확인"
		node.z_index = 4
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
	hud = label_at(stage,"%s · %d바퀴" % [{"default":"기본 지역","winter":"겨울 지역","hell":"지옥 지역"}[world.region],world.laps],Vector2(420,16),Vector2(440,30),14)
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
	book_button = book
	stage.add_child(book)
	add_button_effect(book)
	book_lock = BookBattleLock.new()
	book.add_child(book_lock)
	label_at(stage,"보유 마물 %d" % world.roster.size(),Vector2(20,684),Vector2(130,26),12).z_index = 51
	deck_button = TextureButton.new()
	deck_button.ignore_texture_size = true
	deck_button.texture_normal = texture("res://assets/map/ui/map-card-deck.png")
	deck_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	deck_button.position = Vector2(1134,563)
	deck_button.size = Vector2(128,120)
	deck_button.z_index = 50
	deck_button.tooltip_text = "주사위·낙인 카드 보관함"
	deck_button.pressed.connect(func(): show_inventory("dice"))
	stage.add_child(deck_button)
	add_button_effect(deck_button)
	dice_count_label = label_at(stage,"주사위 카드 %d/5" % world.dice_cards.size(),Vector2(1120,684),Vector2(150,26),12)
	dice_count_label.z_index = 51
	map_audio = AudioSettings.new()
	map_audio.setup(stage)
	var options: Button = map_audio.get_child(0)
	options.text = ""
	options.position = Vector2(1053,133)
	options.size = Vector2(58,58)
	options.tooltip_text = "오디오 옵션"
	for state in ["normal","hover","pressed","disabled","focus"]: options.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	image(options,"res://assets/map/ui/map_audio_options.webp",Vector2.ZERO,options.size)
	add_button_effect(options)
	dice.disabled = moving
	highlight(world.position)

func hero_position(index: int) -> Vector2:
	return center(index)-Vector2(40.96,86.4)

func highlight(index: int) -> void:
	selected = index
	for i in range(buttons.size()):
		buttons[i].scale = SELECTED_TILE_SCALE if i==index else Vector2.ONE
		buttons[i].z_index = 5 if i==index else 4

func roll_move(instance_id: String = "") -> void:
	if moving or is_instance_valid(overlay): return
	if not world.pending_move.is_empty():
		await resume_map_move()
		return
	moving = true
	dice.disabled = true
	var result: Dictionary = session.prepare_map_roll(instance_id)
	if not result.get("ok",false):
		status.text = str(result.get("reason","이동 저장 실패"))
		moving = false
		dice.disabled = false
		return
	dice_count_label.text = "주사위 카드 %d/5" % world.dice_cards.size()
	status.text = "주사위를 굴리는 중…"+(" · "+str(result.label) if not str(result.label).is_empty() else "")
	await dice_animation.roll_map(dice,int(result.face),Rect2(148,143,984,412),texture,sound)
	var previous = int(result.origin)
	for raw_index in result.path:
		var index = int(raw_index)
		hero.flip_h = center(index).x<center(previous).x
		sound("move")
		var motion = create_tween()
		motion.tween_property(hero,"position",hero_position(index),0.23)
		await motion.finished
		highlight(index)
		previous = index
	await resume_map_move()

func resume_map_move() -> void:
	if world.pending_move.is_empty(): return
	moving = true
	dice.disabled = true
	var result: Dictionary = world.pending_move.duplicate(true)
	var landed = int(result.get("landed",world.position))
	hero.position = hero_position(landed)
	highlight(landed)
	dice.texture_normal = texture("res://assets/battle/dice/result-%02d.png" % int(result.face))
	status.text = "주사위 %d · %d칸 이동 · %s 도착%s" % [int(result.face),result.path.size(),MapState.NAMES[world.tiles[world.position]]," · "+str(result.label) if not str(result.label).is_empty() else ""]
	if world.tiles[landed]=="warp" and landed!=world.position:
		status.text = "%d번 워프 → %d번 워프" % [landed+1,world.position+1]
		await presentation.warp(hero,hero_position(world.position))
		highlight(world.position)
	elif world.tiles[landed]=="swamp":
		status.text = "오염된 늪지대 · 보유 마물 HP -1 · HP 1 보호"
		await presentation.swamp_hit()
	if not session.complete_map_move():
		status.text = "이동 완료 저장 실패 · 주사위를 눌러 다시 저장하세요"
		moving = false
		dice.disabled = false
		return
	moving = false
	dice.disabled = false
	var type: String = world.tiles[world.position]
	if type in ["monster","rare-monster","boss"] and not world.position in world.cleared: show_tile(world.position)
	elif type in EVENT_IMAGES or type in ["gem","event"]: show_tile(world.position)

func select_tile(index: int) -> void:
	if moving or is_instance_valid(overlay) or not world.pending_move.is_empty(): return
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
	backdrop.set_meta("ui_backdrop",true)
	node.add_child(backdrop)
	overlay = node
	PanelEffects.attach(node)
	return node

func close_overlay() -> void:
	if is_instance_valid(book_button) and (not is_instance_valid(book_lock) or not book_lock.locked): book_button.texture_normal = texture("res://assets/map/ui/map-book-closed.png")
	if is_instance_valid(deck_button): deck_button.texture_normal = texture("res://assets/map/ui/map-card-deck.png")
	if is_instance_valid(overlay):
		stage.remove_child(overlay)
		overlay.queue_free()
	overlay = null

func dismiss_overlay(after: Callable = Callable()) -> void:
	var panel = overlay
	if not is_instance_valid(panel): return
	if panel.has_method("close_cards"):
		if panel.closing: return
		await panel.close_cards()
		if overlay != panel: return
	var effect = panel.get_node_or_null("PanelEffectsModule")
	if effect == null:
		close_overlay()
		if after.is_valid(): after.call()
		return
	effect.play_close(func():
		if overlay != panel: return
		close_overlay()
		if after.is_valid(): after.call())

func show_tile(index: int) -> void:
	var type: String = world.tiles[index]
	if type=="basic": return
	if type=="home":
		show_home()
		return
	if type in ["monster","rare-monster","boss"] and not index in world.cleared:
		show_battle_deck(index)
		return
	if type=="gem":
		show_treasure(index)
		return
	if type=="warp":
		use_warp(index)
		return
	if type in EVENT_IMAGES:
		show_location(index)
		return
	var panel = modal()
	image(panel,tile_path(index),Vector2(465,160),Vector2(350,260))
	var title = label_at(panel,MapState.NAMES[type],Vector2(290,92),Vector2(700,36),24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(panel,"돌아가기",Vector2(550,574),Vector2(180,42),dismiss_overlay)

func show_roster() -> void:
	show_inventory("unit")

func show_inventory(kind: String) -> void:
	if moving or is_instance_valid(overlay) or not world.pending_move.is_empty(): return
	if kind=="dice":
		show_dice_hand()
		return
	sound("book-cards-open")
	book_button.texture_normal = texture("res://assets/map/ui/map-book-open.png")
	var panel = InventoryPanel.new()
	stage.add_child(panel)
	overlay = panel
	panel.setup(session,kind,book_button.get_global_transform_with_canvas()*(book_button.size*Vector2(0.9,0.5)))
	panel.closed.connect(dismiss_overlay)

func show_treasure(index: int = -1) -> void:
	if not session.open_treasure(index):
		status.text = session.notice if not session.notice.is_empty() else "보상 저장 실패 · 다시 시도하세요"
		return
	var panel = TreasureReward.new()
	stage.add_child(panel)
	overlay = panel
	panel.finished.connect(func():
		close_overlay()
		render()
		status.text = "보물상자 보상을 정리했습니다")
	panel.mimic_revealed.connect(func(index: int):
		close_overlay()
		status.text = "보물상자에서 미믹 출현 · 출전 마물을 선택하세요"
		show_battle_deck(index))
	panel.setup(self)

func animate_reward_to_inventory(kind: String, source: TextureButton) -> void:
	var target: TextureButton = deck_button if kind=="dice" else book_button
	var flyer = image(stage,source.texture_normal.resource_path,source.global_position,source.size)
	flyer.z_index = 220
	flyer.pivot_offset = flyer.size*0.5
	var start = flyer.position
	var end = target.position+target.size*0.5-flyer.size*0.5
	var control = start.lerp(end,0.4)+Vector2(0,-70)
	source.hide()
	var flight = create_tween()
	flight.tween_method(func(t: float):
		flyer.position = start*(1-t)*(1-t)+control*2*(1-t)*t+end*t*t
		flyer.scale = Vector2.ONE*lerpf(1.0,0.1,t)
		flyer.rotation_degrees = lerpf(source.rotation_degrees,0.0,t)
		flyer.modulate.a = minf(1.0,(1.0-t)*4.0),0.0,1.0,0.88).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await flight.finished
	flyer.queue_free()
	target.pivot_offset = target.size*0.5
	var receive = create_tween()
	receive.tween_property(target,"scale",Vector2.ONE*1.08,0.1)
	receive.tween_property(target,"scale",Vector2.ONE,0.16)
	await receive.finished

func confirm_new_run() -> void:
	if moving or is_instance_valid(overlay): return
	var panel = modal()
	var question = label_at(panel,"현재 원정을 끝내고 새로 시작하시겠습니까?",Vector2(300,280),Vector2(680,50),22)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(panel,"취소",Vector2(460,380),Vector2(150,42),close_overlay)
	button(panel,"새 원정 시작",Vector2(650,380),Vector2(180,42),func():
		var previous_world = world
		var previous_encounter: Dictionary = session.encounter.duplicate(true)
		var candidate = MapState.new(world.definitions,Time.get_ticks_usec(),world.patrol_plan)
		session.world = candidate
		session.encounter = {}
		if not session.save_world():
			session.world = previous_world
			session.encounter = previous_encounter
			status.text = session.notice
			return
		world = candidate
		close_overlay()
		if get_tree().change_scene_to_file("res://intro.tscn")!=OK: render())


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
			open_embedded_battle()
		else:
			close_overlay()
			status.text = session.notice if not session.notice.is_empty() else "출전 편성을 확인할 수 없습니다. 다시 선택하세요.")


func open_embedded_battle(animate_lock: bool = true) -> void:
	battle_returning = false
	map_music.stream_paused = true
	close_overlay()
	if is_instance_valid(book_lock): book_lock.set_locked(true,animate_lock)
	var host = Control.new()
	host.name = "CentralBattle"
	# The battle viewport stays at its original position and size; the frame surrounds it.
	host.position = Vector2(128,126)
	host.size = Vector2(1024,450)
	host.clip_contents = true
	host.z_index = 30
	stage.add_child(host)
	overlay = host
	for child in stage.get_children():
		if child is BaseButton: child.disabled = true
	dice.hide()
	map_audio.hide()
	status.hide()
	hero.hide()
	var viewport = Control.new()
	viewport.name = "BattleViewport"
	viewport.position = Vector2(22,22)
	viewport.size = Vector2(980,406)
	viewport.clip_contents = true
	host.add_child(viewport)
	var battle = Battlefield.instantiate()
	battle.embedded = true
	battle.detail_parent = stage
	battle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	battle.size = Vector2(1280,530)
	battle.scale = Vector2.ONE*(viewport.size.x/1280.0)
	embedded_battle = battle
	battle.finished.connect(finish_embedded_battle)
	viewport.add_child(battle)
	var frame = NinePatchRect.new()
	frame.name = "BattleFrame"
	frame.texture = texture("res://assets/map/ui/battle_frame.png")
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw_center = false
	# Keep corners at a fixed, restrained size; only the border strips stretch.
	frame.scale = Vector2.ONE*0.22
	frame.size = host.size/0.22
	frame.patch_margin_left = 170
	frame.patch_margin_right = 170
	frame.patch_margin_top = 150
	frame.patch_margin_bottom = 150
	frame.z_index = 10
	host.add_child(frame)
	host.modulate.a = 0.0
	var entry = create_tween()
	entry.tween_property(host,"modulate:a",1.0,0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func finish_embedded_battle() -> void:
	if battle_returning: return
	battle_returning = true
	if is_instance_valid(overlay): overlay.hide()
	if is_instance_valid(book_lock):
		book_lock.set_locked(false)
		await book_lock.transition_finished
	map_music.stream_paused = false
	embedded_battle = null
	overlay = null
	battle_returning = false
	world = session.world
	render()
	status.text = session.notice
	session.notice = ""
	if world.roster.is_empty(): status.text += " · 출전 가능한 마물이 없습니다."


func sound(kind: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	var extension = "mp3" if kind in ["treasure-chest-open","book-cards-open"] else "ogg"
	player.stream = load("res://assets/battle/sfx/%s.%s" % [kind,extension])
	player.volume_db = -12
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null


func show_dice_hand() -> void:
	if moving or is_instance_valid(overlay) or not world.pending_move.is_empty(): return
	deck_button.texture_normal = texture("res://assets/map/ui/map-card-deck-open.png")
	var hand = DiceHand.new()
	stage.add_child(hand)
	overlay = hand
	hand.setup(world.dice_cards,session.dice_context())
	hand.closed.connect(dismiss_overlay)
	hand.chosen.connect(func(id: String):
		close_overlay()
		roll_move(id))

func show_home(interior: bool = false) -> void:
	var panel = modal()
	var home_art = image(panel,"res://assets/map/events/home-interior.jpg" if interior else "res://assets/map/events/home.jpg",Vector2(256,120),Vector2(768,432))
	# The home exterior opens with ink; entering the house shows interior art instantly.
	if not interior:
		InkSceneReveal.play(home_art)
	var title = label_at(panel,"우리집 · 실내" if interior else "우리집",Vector2(290,92),Vector2(700,36),24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_button(panel,"나가기",Vector2(865,492),Vector2(150,50),exit_home,4)
	if not interior:
		location_button(panel,"들어가기",Vector2(865,397),Vector2(150,50),func():
			var injured = world.roster.any(func(u): return u.current_hp<u.max_hp)
			if not session.enter_home():
				status.text = session.notice
				return
			close_overlay()
			status.text = "귀환 · 모든 마물 체력 완전 회복"
			show_home(true)
			if injured: await presentation.full_heal())
	else:
		var allowed: Dictionary = session.home_action_allowed()
		var action = location_button(panel,"낙인 계승",Vector2(865,343),Vector2(150,50),show_home_inheritance,3)
		action.disabled = not allowed.ok
		var patrol = location_button(panel,"순찰경로",Vector2(865,397),Vector2(150,50),func():
			close_overlay()
			show_exploration_actions(MapState.HOME))
		patrol.disabled = session.place_visit_id("patrol",MapState.HOME) in world.reward_receipts
		if not allowed.ok:
			var hint = label_at(panel,str(allowed.reason),Vector2(340,463),Vector2(600,30),15)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func show_home_inheritance() -> void:
	var allowed: Dictionary = session.home_action_allowed()
	if not allowed.ok:
		status.text = allowed.reason
		return
	close_overlay()
	var panel = HomeInheritance.new()
	stage.add_child(panel)
	overlay = panel
	panel.setup(session)
	panel.closed.connect(func(): dismiss_overlay(func(): show_home(true)))

func show_place_actions(index: int) -> void:
	var panel = PlaceActions.new()
	stage.add_child(panel)
	overlay = panel
	panel.setup(self,index)
	panel.closed.connect(func(): dismiss_overlay(func():
		world = session.world
		presentation.refresh()
		show_location(index)))

func show_exploration_actions(index: int) -> void:
	var panel = ExplorationActions.new()
	stage.add_child(panel)
	overlay = panel
	panel.setup(self,index)
	panel.closed.connect(func(): dismiss_overlay(func():
		world = session.world
		if index==MapState.HOME: show_home(true)
		else: show_location(index)))

func location_button(parent: Control, title: String, pos: Vector2, dimensions: Vector2, callback: Callable, variant: int = 1) -> Button:
	var node = button(parent,title,pos,dimensions,callback)
	var style = StyleBoxTexture.new()
	style.texture = texture("res://assets/map/ui/parchment_button_variant_%02d.png" % variant)
	style.content_margin_left = 10
	style.content_margin_right = 10
	for state in ["normal","hover","pressed","disabled","focus"]: node.add_theme_stylebox_override(state,style)
	node.add_theme_color_override("font_color",Color("3f2818"))
	node.add_theme_color_override("font_hover_color",Color("3f2818"))
	node.add_theme_color_override("font_pressed_color",Color("3f2818"))
	node.add_theme_color_override("font_disabled_color",Color("6c594680"))
	node.add_theme_font_size_override("font_size",18)
	return node

func show_location(index: int) -> void:
	var type: String = world.tiles[index]
	var panel = modal()
	var scene_art = image(panel,"res://assets/map/events/%s.jpg" % EVENT_IMAGES[type],Vector2(243.2,136.8),Vector2(793.6,446.4))
	# Reveal artwork only for all seven location tile types; keep UI unaffected.
	InkSceneReveal.play(scene_art)
	var exit = location_button(panel,"나가기",Vector2(886,504),Vector2(143,48),func(): dismiss_overlay(render),4)
	if type=="rest":
		var allowed = session.rest_allowed(index)
		var heal = location_button(panel,"전체 회복",Vector2(886,406),Vector2(143,48),func():
			var result = session.heal_at_rest(index)
			status.text = result.reason
			if not result.ok: return
			exit.disabled = true
			await presentation.full_heal()
			close_overlay()
			show_location(index))
		heal.disabled = not allowed.ok
		heal.tooltip_text = "" if allowed.ok else allowed.reason
	elif type in ["village","altar","fortune-teller-camp"]:
		var names = {"village":"마물 상점","altar":"의식","fortune-teller-camp":"예언"}
		var variant = {"village":1,"altar":2,"fortune-teller-camp":4}[type]
		var action = location_button(panel,names[type],Vector2(886,406),Vector2(143,48),func(): close_overlay(); show_place_actions(index),variant)
		var key = "ritual" if type=="altar" else "prophecy"
		if type!="village": action.disabled = session.place_visit_id(key,index) in world.reward_receipts
	elif type in ["unknown","graveyard","forest"]:
		var names = {"unknown":"기도","graveyard":"시체 파헤치기","forest":"정찰 정보" if world.scout.scouted else "정찰"}
		var variant = {"unknown":3,"graveyard":4,"forest":2}[type]
		var open_exploration := func():
			close_overlay()
			show_exploration_actions(index)
		var action = location_button(panel,names[type],Vector2(876,406),Vector2(153,48),open_exploration,variant)
		# Pilot only: first click places the seal; second click performs the original action.
		if type=="graveyard":
			WaxSealSelection.attach(action,open_exploration,texture("res://assets/map/ui/wax_skull_seal.webp"))
		if type=="unknown": action.disabled = session.place_visit_id("purify",index) in world.reward_receipts
		if type=="graveyard": action.disabled = world.graveyard_corpses.is_empty() or session.place_visit_id("grave-extract",index) in world.reward_receipts

func use_warp(index: int) -> void:
	if moving: return
	var result = session.warp_from(index)
	if not result.ok: status.text = result.reason; return
	moving = true
	dice.disabled = true
	hero.position = hero_position(index)
	status.text = "%d번 워프 → %d번 워프" % [index+1,int(result.destination)+1]
	await presentation.warp(hero,hero_position(int(result.destination)))
	highlight(world.position)
	status.text = "%d번 워프로 이동 완료" % (world.position+1)
	dice.disabled = false
	moving = false

func exit_home() -> void:
	if moving: return
	moving = true
	close_overlay()
	var ok: bool = await presentation.cloud_refresh(func():
		if not session.leave_home(): return false
		world = session.world
		render()
		return true)
	moving = false
	dice.disabled = false
	if not ok:
		status.text = session.notice if not session.notice.is_empty() else "맵 교체 저장 실패 · 다시 시도하세요"
		show_home()
	else: status.text = "새 경로 · %d바퀴 · 오염도 %d/100" % [world.laps,world.contamination]
