extends Control

const Rules = preload("res://systems/battlefield_rules.gd")
const BattleVisuals = preload("res://systems/battle_visuals.gd")
const UnitInfo = preload("res://systems/unit_info.gd")
const ButtonEffects = preload("res://systems/button_effects_module.gd")
const AudioSettings = preload("res://systems/audio_settings.gd")
const ROSTER = ["death-knight","skeleton-spear","skeleton-archer","ghoul","ancient-treant","goblin-rider","minotaur","plague-doctor","spider-knight","siren"]
const ENEMIES = ["goblin-rider","orc-warrior","boulder-ogre","minotaur"]
const RATIOS = {"ancient-treant":1.0,"minotaur":1.5,"orc-warrior":1.5,"boulder-ogre":1.5,"spider-knight":2.0,"spiderling":0.5}
const LEGIONS = {"skeleton":"언데드","beast":"야수","corpse":"시체","plague":"역병","ice":"얼음","summon":"소환","demon":"악마","plant":"식물","insect":"벌레","element":"원소"}
var definitions: Dictionary
var rules
var selection: Array = ["skeleton-spear","spider-knight","plague-doctor","siren"]
var layer: Control
var sprites: Dictionary = {}
var bars: Dictionary = {}
var cards: Dictionary = {}
var cache: Dictionary = {}
var scales: Dictionary = {}
var message: Label
var round_label: Label
var dice: TextureButton
var pause_button: Button
var speed_button: Button
var editing: Control
var detail: Control
var selected_card = ""
var card_tweens: Dictionary = {}
var busy = false
var paused = false
var speed_index = 0
var speed_values = [1.5,2.25,3.0]
var audio: AudioStreamPlayer
var map_mode = false
var map_return: Button
var world_layer: Control
var visuals
var session

func _exit_tree() -> void:
	stop_audio()

func stop_audio() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null

func _ready() -> void:
	DisplayServer.window_set_title("Necromancer and Dice")
	session = get_node_or_null("/root/RunSession")
	map_mode = session != null and not session.encounter.is_empty()
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic","맑은 고딕"])
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	AudioSettings.apply_saved()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	audio.stream = load("res://assets/battle/music/battle.mp3")
	audio.volume_db = -15
	audio.finished.connect(audio.play)
	if DisplayServer.get_name() != "headless": audio.play()
	reset_battle()
	if map_mode:
		var veil = ColorRect.new()
		veil.color = Color("180e26")
		veil.size = Vector2(1280,720)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.z_index = 100
		layer.add_child(veil)
		var entry = create_tween()
		entry.tween_property(veil,"modulate:a",0.0,0.4)
		entry.tween_callback(veil.queue_free)
	var args = OS.get_cmdline_user_args()
	if "--capture" in args:
		if "--action-preview" in args: await roll_round()
		if "--info-preview" in args: show_detail(rules.units[0])
		if "--enemy-info-preview" in args: show_detail(rules.units[4])
		if "--selection-preview" in args: show_selection()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[args.find("--capture")+1])
		stop_audio()
		await get_tree().process_frame
		get_tree().quit()

func texture(path: String) -> Texture2D:
	if not cache.has(path): cache[path] = load(path) if ResourceLoader.exists(path) else null
	return cache[path]

func image(parent: Control, path: String, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var node = TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = texture(path)
	node.position = pos
	node.size = dimensions
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func text(parent: Control, value: String, pos: Vector2, dimensions: Vector2, font_size: int = 15) -> Label:
	var node = Label.new()
	node.text = value
	node.position = pos
	node.size = dimensions
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("f7ead0"))
	node.add_theme_color_override("font_shadow_color",Color.BLACK)
	node.add_theme_constant_override("shadow_offset_x",1)
	node.add_theme_constant_override("shadow_offset_y",2)
	parent.add_child(node)
	return node

func button(parent: Control, value: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var node = Button.new()
	node.text = value
	node.position = pos
	node.size = dimensions
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func reset_battle() -> void:
	busy = false
	paused = false
	rules = Rules.new(definitions,Time.get_ticks_usec())
	var allies: Array = []
	var enemies: Array = []
	if map_mode:
		allies = session.encounter.allies.duplicate(true)
		enemies = session.encounter.enemies.duplicate(true)
	else:
		for i in range(4):
			allies.append(rules.individual(selection[i],"ally-"+str(i)))
			enemies.append(rules.individual(ENEMIES[i],"enemy-"+str(i)))
	rules.start(allies,enemies)
	if map_mode:
		for u in rules.units:
			if u.team=="ally": u.hp = mini(u.max_hp,u.get("current_hp",u.max_hp)+(u.max_hp-u.base_hp))
	if is_instance_valid(layer):
		remove_child(layer)
		layer.queue_free()
	sprites = {}
	bars = {}
	cards = {}
	card_tweens = {}
	selected_card = ""
	layer = Control.new()
	layer.size = Vector2(1280,720)
	add_child(layer)
	var background = image(layer,"res://assets/battle/backgrounds/snow-forest.jpg",Vector2.ZERO,Vector2(1280,720))
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shade = ColorRect.new()
	shade.color = Color(0.02,0.02,0.02,0.25)
	shade.size = Vector2(1280,720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	world_layer = Control.new()
	world_layer.size = Vector2(1280,720)
	world_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(world_layer)
	visuals = BattleVisuals.new()
	world_layer.add_child(visuals)
	visuals.setup(self,world_layer)
	map_return = button(layer,"맵으로",Vector2(24,18),Vector2(110,32),return_to_map)
	map_return.disabled = map_mode
	round_label = text(layer,"%d VS %d" % [allies.size(),enemies.size()],Vector2(470,16),Vector2(340,32),20)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message = text(layer,"주사위를 굴리면 1턴이 시작됩니다",Vector2(360,54),Vector2(560,36),15)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_button = button(layer,"일시정지",Vector2(986,18),Vector2(90,32),toggle_pause)
	var pause_effects = ButtonEffects.new()
	pause_effects.name = "ButtonEffectsModule"
	pause_button.add_child(pause_effects)
	speed_button = button(layer,"×1",Vector2(1080,18),Vector2(54,32),cycle_speed)
	var formation_button = button(layer,"편성 변경",Vector2(1138,18),Vector2(116,32),show_selection)
	formation_button.visible = not map_mode
	for team in ["ally","enemy"]:
		var title = text(layer,"아군 활성 군단" if team == "ally" else "적군 활성 군단",Vector2(25.6 if team == "ally" else 1174.4,72),Vector2(80,54),10)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var enabled: Array = rules.legions[team].active.filter(func(key): return rules.active(team,key))
		if enabled.is_empty():
			text(layer,"없음",Vector2(112 if team == "ally" else 1126,88),Vector2(45,25),9)
		for i in range(enabled.size()):
			var key = enabled[i]
			var x = 112+i*56 if team == "ally" else 1114.4-i*56
			image(layer,"res://assets/battle/ui/legion-slot-frame.png",Vector2(x,72),Vector2(54,54))
			var name_text = text(layer,LEGIONS[key],Vector2(x,82),Vector2(54,17),10)
			name_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var count = text(layer,"%d/%d" % [rules.legions[team].counts[key],rules.NEED[key]],Vector2(x,101),Vector2(54,12),8)
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice = TextureButton.new()
	dice.position = Vector2(580,308)
	dice.size = Vector2(120,120)
	dice.ignore_texture_size = true
	dice.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	dice.texture_normal = texture("res://assets/battle/dice/result-01.png")
	dice.pressed.connect(roll_round)
	dice.tooltip_text = "클릭하여 다음 라운드 진행"
	layer.add_child(dice)
	render_units(rules.units)
	AudioSettings.new().setup(layer)
	pause_button.disabled = true
	if not map_mode:
		button(layer,"새 전투",Vector2(582,664),Vector2(116,32),func():
			if not busy: reset_battle())

func unit_x(u: Dictionary) -> float:
	var columns = [4,3,2,1,5] if u.team == "ally" else [2,3,4,5,1]
	return (0.0 if u.team == "ally" else 665.6)+(columns[mini(u.slot,4)]-0.5)*122.88

func frame_path(u: Dictionary, motion: String, index: int) -> String:
	return "res://assets/battle/frames/%s/%s-%02d.png" % [u.slug,motion,index]

func body_scale(u: Dictionary) -> float:
	if scales.has(u.slug): return scales[u.slug]
	var tex = texture(frame_path(u,"attack",1))
	if tex == null: return 1.0
	var bounds = tex.get_image().get_used_rect()
	var factor = 138.0*RATIOS.get(u.slug,1.0)/maxi(bounds.size.y,1)
	scales[u.slug] = factor
	return factor

func render_units(values: Array) -> void:
	for u in values:
		if not sprites.has(u.id):
			var node = image(world_layer,frame_path(u,"attack",1),Vector2.ZERO,Vector2(320,320))
			node.z_index = 2
			sprites[u.id] = node
			var bar = ProgressBar.new()
			bar.size = Vector2(92,15)
			bar.show_percentage = false
			var backdrop = StyleBoxFlat.new()
			backdrop.bg_color = Color("271918")
			backdrop.border_color = Color("ac9869")
			backdrop.set_border_width_all(1)
			var fill = StyleBoxFlat.new()
			fill.bg_color = Color("68a75b") if u.team == "ally" else Color("b85548")
			bar.add_theme_stylebox_override("background",backdrop)
			bar.add_theme_stylebox_override("fill",fill)
			layer.add_child(bar)
			bars[u.id] = bar
			var card = TextureButton.new()
			card.texture_normal = texture("res://assets/cards/unit-card-%s.png" % u.slug)
			card.ignore_texture_size = true
			card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			card.size = Vector2(78.93,115.2)
			card.pivot_offset = card.size*Vector2(0.5,0.85)
			var angles = [-3,2,-1,3,-2]
			card.rotation_degrees = angles[(u.slot+(2 if u.team == "enemy" else 0))%5]
			card.position = Vector2(unit_x(u)-39.465,700 if busy else 612.8)
			card.disabled = busy
			card.tooltip_text = "%s · %d/%d" % [u.name,u.hp,u.max_hp]
			var id: String = u.id
			card.pressed.connect(func(): show_detail(rules.find_id(id)))
			card.mouse_entered.connect(func(): card.z_index = 6 if selected_card==id else 5)
			card.mouse_exited.connect(func(): card.z_index = 6 if selected_card==id else 0)
			layer.add_child(card)
			cards[u.id] = card
		var sprite: TextureRect = sprites[u.id]
		var factor = body_scale(u)
		var tex = texture(frame_path(u,"attack",1))
		if tex != null:
			sprite.size = tex.get_size()*factor
			if u.alive: sprite.texture = tex
			sprite.position = Vector2(clampf(unit_x(u)-sprite.size.x/2,0,1280-sprite.size.x),570-sprite.size.y+u.slot*6)
			sprite.flip_h = u.team == "enemy"
			sprite.modulate = Color.WHITE if u.alive else Color(0.4,0.4,0.4,0.35)
		bars[u.id].position = Vector2(unit_x(u)-46,maxf(170,sprite.position.y-24))
		bars[u.id].max_value = u.max_hp
		bars[u.id].value = u.hp
		bars[u.id].tooltip_text = "%s · 체력 %d/%d" % [u.name,u.hp,u.max_hp]
		cards[u.id].modulate = Color.WHITE if u.alive else Color(0.6,0.6,0.6,0.6)
		cards[u.id].tooltip_text = "%s · %d/%d" % [u.name,u.hp,u.max_hp]
		if u.alive and u.frozen: sprite.modulate = Color(0.5,0.85,1.0)
		elif u.alive and not u.poison.is_empty(): sprite.modulate = Color(0.6,1.0,0.5)

		for node in [sprite,bars[u.id],cards[u.id]]:
			node.visible = not visuals.removed.has(u.id)
	visuals.sync(values)

func wait_time(seconds: float) -> void:
	var remaining = seconds
	while remaining > 0:
		await get_tree().process_frame
		if not paused: remaining -= get_process_delta_time()*speed_values[speed_index]

func animate_unit(id: String, motion: String) -> void:
	var u = rules.find_id(id)
	if u.is_empty(): return
	for index in range(1,11):
		var tex = texture(frame_path(u,motion,index))
		if tex == null: break
		sprites[id].texture = tex
		await wait_time(0.16)

func sound(kind: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var player = AudioStreamPlayer.new()
	player.stream = load("res://assets/battle/sfx/permanent_death.wav" if kind=="permanent-death" else "res://assets/battle/sfx/%s.ogg" % kind)
	player.volume_db = -12
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func roll_round() -> void:
	if busy or not rules.winner().is_empty(): return
	close_detail()
	busy = true
	set_card_phase(true)
	dice.disabled = true
	pause_button.disabled = false
	message.text = "주사위를 굴리는 중…"
	for i in range(12):
		sound("dice-tick")
		dice.texture_normal = texture("res://assets/battle/dice/roll-%02d.png" % (i+1))
		await wait_time(0.075)
	var round_before = rules.units.duplicate(true)
	rules.begin_round()
	sound("dice-land")
	dice.texture_normal = texture("res://assets/battle/dice/result-%02d.png" % rules.face)
	round_label.text = "%d턴 · 주사위 %d" % [rules.round_number,rules.face]
	render_units(rules.units)
	await visuals.play_round(round_before,rules.units,rules.presentation_events)
	await wait_time(0.5)
	while true:
		var action: Dictionary = rules.next_action()
		if action.is_empty(): break
		render_units(action.before)
		message.text = "%s 행동" % rules.find_id(action.actor).name
		await visuals.play_action(action)
		message.text = " / ".join(action.events)
		await wait_time(0.22)
	var winner = rules.winner()
	if winner=="ally": sound("victory")
	message.text = ("승리! · 새 전투 또는 편성 변경" if winner == "ally" else "패배 · 새 전투 또는 편성 변경") if not winner.is_empty() else "주사위를 굴리면 %d턴이 시작됩니다" % (rules.round_number+1)
	busy = false
	set_card_phase(false)
	paused = false
	pause_button.text = "일시정지"
	pause_button.disabled = true
	dice.disabled = not winner.is_empty()
	if map_mode and not winner.is_empty():
		map_return.disabled = false
		message.text = ("승리!" if winner=="ally" else "패배")+" · 맵으로 돌아가 계속하세요"

func return_to_map() -> void:
	if busy: return
	if map_mode:
		if rules.winner().is_empty(): return
		session.finish_encounter(rules)
	get_tree().change_scene_to_file("res://map.tscn")

func toggle_pause() -> void:
	paused = not paused
	pause_button.text = "계속" if paused else "일시정지"

func cycle_speed() -> void:
	speed_index = (speed_index+1)%3
	speed_button.text = "×%d" % (speed_index+1)

func show_detail(u: Dictionary) -> void:
	if busy or u.is_empty(): return
	close_detail()
	selected_card = u.id
	set_card_phase(false)
	detail = UnitInfo.new()
	layer.add_child(detail)
	detail.setup(u,rules)
	detail.closed.connect(func():
		detail = null
		selected_card = ""
		set_card_phase(busy))

func close_detail() -> void:
	if is_instance_valid(detail):
		detail.get_parent().remove_child(detail)
		detail.queue_free()
	detail = null
	selected_card = ""
	set_card_phase(busy)

func set_card_phase(acting: bool) -> void:
	for id in cards:
		var card: TextureButton = cards[id]
		card.disabled = acting or visuals.removed.has(id)
		card.z_index = 6 if selected_card==id else 0
		if card_tweens.has(id) and card_tweens[id].is_valid(): card_tweens[id].kill()
		var tween = create_tween()
		card_tweens[id] = tween
		tween.tween_property(card,"position:y",700.0 if acting else (588.8 if selected_card==id else 612.8),0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func show_selection() -> void:
	if busy: return
	close_detail()
	if is_instance_valid(editing): return
	editing = Control.new()
	editing.size = Vector2(1280,720)
	editing.z_index = 80
	layer.add_child(editing)
	var backdrop = ColorRect.new()
	backdrop.color = Color("050302d4")
	backdrop.size = editing.size
	editing.add_child(backdrop)
	var board_texture = texture("res://assets/battle/ui/battle-deck-selection-board.png")
	var board = image(editing,"res://assets/battle/ui/battle-deck-selection-board.png",Vector2(57.6,14.4),Vector2(1164.8,1164.8*board_texture.get_height()/board_texture.get_width()))
	board.stretch_mode = TextureRect.STRETCH_SCALE
	var selected_group = Control.new()
	selected_group.name = "SelectedSlots"
	editing.add_child(selected_group)
	var selected_label = text(editing,"",Vector2(965,557),Vector2(251,32),14)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var confirm = button(editing,"확인",Vector2(1046,609),Vector2(170,46),func():
		if selection.size()==4: reset_battle())
	confirm.name = "ConfirmFormation"
	button(editing,"닫기",Vector2(1160,29),Vector2(82,30),func():
		editing.queue_free()
		editing = null)
	var roster_cards: Dictionary = {}
	var refresh_selection = func():
		for child in selected_group.get_children():
			selected_group.remove_child(child)
			child.queue_free()
		for i in range(selection.size()):
			var slug: String = selection[selection.size()-1-i]
			var slot = TextureButton.new()
			slot.texture_normal = texture("res://assets/cards/unit-card-%s.png" % slug)
			slot.ignore_texture_size = true
			slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			slot.size = Vector2(170,302.4)
			slot.position = Vector2(275.2+i*190.4,194.4)
			slot.pivot_offset = slot.size/2
			slot.rotation_degrees = [-7,-1,1,7][i]
			slot.tooltip_text = definitions[slug].name+" 선택 해제"
			slot.pressed.connect(func(): toggle_selection(slug))
			selected_group.add_child(slot)
		for slug in roster_cards:
			var card: TextureButton = roster_cards[slug]
			var selected = slug in selection
			card.position.y = 513.97 if selected else 552.26
			card.scale = Vector2(1.05,1.05) if selected else Vector2.ONE
			card.z_index = 2 if selected else 0
			card.get_node("Order").text = str(selection.find(slug)+1) if selected else ""
		selected_label.text = "마물 카드 %d / 4" % selection.size()
		confirm.disabled = selection.size()!=4
	editing.set_meta("refresh",refresh_selection)
	for i in range(ROSTER.size()):
		var slug: String = ROSTER[i]
		var card = TextureButton.new()
		card.texture_normal = texture("res://assets/cards/unit-card-%s.png" % slug)
		card.ignore_texture_size = true
		card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		card.position = Vector2(25.6+i*98.09,552.26)
		card.size = Vector2(121.34,225.22)
		card.pivot_offset = card.size*Vector2(0.5,0.85)
		card.rotation_degrees = [-4,2,-1,3,-2][i%5]
		card.tooltip_text = definitions[slug].name
		card.pressed.connect(func(): toggle_selection(slug))
		var order = text(card,"",Vector2(10,16),Vector2(24,24),15)
		order.name = "Order"
		order.mouse_filter = Control.MOUSE_FILTER_IGNORE
		order.add_theme_color_override("font_color",Color("e1a447"))
		var name_label = text(card,definitions[slug].name,Vector2(6,187),Vector2(109,20),11)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		roster_cards[slug] = card
		card.mouse_entered.connect(func(): card.z_index = 4)
		card.mouse_exited.connect(func(): card.z_index = 2 if slug in selection else 0)
		editing.add_child(card)
	refresh_selection.call()

func toggle_selection(slug: String) -> void:
	if slug in selection: selection.erase(slug)
	elif selection.size()<4: selection.append(slug)
	if is_instance_valid(editing): editing.get_meta("refresh").call()
