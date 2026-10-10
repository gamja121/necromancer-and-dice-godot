extends Control

signal finished

var embedded = false
var detail_parent: Control
var surface_size = Vector2(1280,720)

const PresentationLayout = preload("res://systems/battle_presentation_layout.gd")
var presentation_layout = PresentationLayout.new()

const BrandReference = preload("res://systems/brand_reference.gd")
const DiceHand = preload("res://systems/dice_control_hand.gd")
const DiceAnimation = preload("res://systems/dice_animation.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const CorpseCapture = preload("res://systems/corpse_capture.gd")
const CombatCues = preload("res://systems/combat_cues.gd")
const BattleVisuals = preload("res://systems/battle_visuals.gd")
const UnitInfo = preload("res://systems/unit_info.gd")
const BrandFrameOverlay = preload("res://systems/brand_frame_overlay.gd")
const ButtonEffects = preload("res://systems/button_effects_module.gd")
const AudioSettings = preload("res://systems/audio_settings.gd")
const ROSTER = ["death-knight","skeleton-spear","skeleton-archer","ghoul","ancient-treant","goblin-rider","minotaur","plague-doctor","spider-knight","siren","dracula","soul-reaper"]
const ENEMIES = ["goblin-rider","orc-warrior","boulder-ogre","minotaur"]
const RATIOS = {"ancient-treant":1.0,"minotaur":1.5,"orc-warrior":1.5,"boulder-ogre":1.5,"spider-knight":2.0,"spiderling":0.5,"hydra":2.0}
const LEGIONS = {"skeleton":"언데드","beast":"야수","corpse":"시체","plague":"역병","ice":"얼음","summon":"소환","demon":"악마","plant":"식물","insect":"벌레","element":"원소"}
@export_range(100.0,220.0,1.0) var unit_body_height: float = 160.0
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
var cues
var capture_panel: Control
var session
var dice_animation = DiceAnimation.new()
var dice_hand: Control
var dice_cards_button: Button
var brand_reference: Control
var brand_reference_button: Button

func _exit_tree() -> void:
	close_brand_reference()
	close_dice_hand()
	stop_audio()

func stop_audio() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null

func _ready() -> void:
	DisplayServer.window_set_title("Necromancer and Dice")
	session = get_node_or_null("/root/RunSession")
	map_mode = session != null and (not session.encounter.is_empty() or (session.world!=null and session.world.pending_reward.get("kind","")=="capture"))
	if embedded:
		surface_size = Vector2(1280,530)
		unit_body_height = 100.0
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	# Embedded battles inherit the map font/theme instead of loading it again.
	if not embedded:
		var font = preload("res://assets/fonts/nanum_gothic_regular.ttf")
		theme = Theme.new()
		theme.default_font = font
		theme.default_font_size = 15
	AudioSettings.apply_saved()
	audio = AudioStreamPlayer.new()
	audio.bus = "Music"
	add_child(audio)
	audio.stream = load("res://assets/battle/music/battle.mp3")
	audio.volume_db = -15
	audio.finished.connect(audio.play)
	if DisplayServer.get_name() != "headless": audio.play()
	reset_battle()
	if map_mode and session.world.pending_reward.get("kind","")=="capture": begin_capture()
	elif map_mode and not session.encounter.is_empty() and session.encounter.get("phase","ready")!="ready":
		resume_battle()
	if map_mode:
		var veil = ColorRect.new()
		veil.color = Color("180e26")
		veil.size = surface_size
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
	var style = StyleBoxFlat.new()
	style.bg_color = Color("17100fee")
	style.border_color = Color("846337")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	node.add_theme_stylebox_override("normal",style)
	node.add_theme_stylebox_override("hover",style)
	node.add_theme_font_size_override("font_size",13)
	parent.add_child(node)
	return node

func reset_battle() -> void:
	close_brand_reference()
	busy = false
	paused = false
	rules = Rules.new(definitions,Time.get_ticks_usec())
	var allies: Array = []
	var enemies: Array = []
	var checkpoint: Dictionary = session.world.pending_reward.get("battle",{}) if map_mode else {}
	if checkpoint.is_empty() and map_mode: checkpoint = session.encounter.get("checkpoint",{})
	if not checkpoint.is_empty():
		allies = checkpoint.units.filter(func(u): return u.team=="ally").duplicate(true)
		enemies = checkpoint.units.filter(func(u): return u.team=="enemy").duplicate(true)
	elif map_mode:
		allies = session.encounter.allies.duplicate(true)
		enemies = session.encounter.enemies.duplicate(true)
	else:
		for i in range(4):
			allies.append(rules.individual(selection[i],"ally-"+str(i)))
			enemies.append(rules.individual(ENEMIES[i],"enemy-"+str(i)))
	rules.start(allies,enemies)
	if not checkpoint.is_empty(): rules.restore(checkpoint)
	if map_mode and checkpoint.is_empty():
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
	layer.size = surface_size
	layer.clip_contents = true
	add_child(layer)
	var background = image(layer,battle_background_path(),Vector2.ZERO,surface_size)
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shade = ColorRect.new()
	shade.color = Color.WHITE
	var shade_shader = Shader.new()
	shade_shader.code = """
shader_type canvas_item;
uniform float cinematic = 0.0;
uniform vec2 surface = vec2(1280.0,530.0);
varying vec2 shade_uv;
void vertex() { shade_uv = VERTEX / surface; }
void fragment() {
 float bottom = smoothstep(0.45,1.0,shade_uv.y)*0.79;
 float top = (1.0-smoothstep(0.0,0.24,shade_uv.y))*0.4;
 float side = max(1.0-smoothstep(0.0,0.36,shade_uv.x),smoothstep(0.64,1.0,shade_uv.x))*0.32;
 COLOR = vec4(mix(vec3(0.01,0.03,0.04),vec3(0.08,0.025,0.02),shade_uv.x),max(max(top,bottom),side)+(1.0-max(max(top,bottom),side))*cinematic*0.333);
}
"""
	var shade_material = ShaderMaterial.new()
	shade_material.shader = shade_shader
	shade_material.set_shader_parameter("surface",surface_size)
	shade.material = shade_material
	shade.name = "BattleShade"
	shade.size = surface_size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	world_layer = Control.new()
	world_layer.size = surface_size
	world_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(world_layer)
	visuals = BattleVisuals.new()
	world_layer.add_child(visuals)
	visuals.setup(self,world_layer)
	var header = Panel.new()
	header.position = Vector2(420,14)
	header.size = Vector2(452,36)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color("17100ff0")
	header_style.border_color = Color("846337")
	header_style.set_border_width_all(1)
	header.add_theme_stylebox_override("panel",header_style)
	layer.add_child(header)
	map_return = button(layer,"전투 닫기" if embedded else "맵으로",Vector2(24,18),Vector2(110,32),return_to_map)
	map_return.disabled = map_mode
	round_label = text(layer,"%d VS %d" % [allies.size(),enemies.size()],Vector2(422,14),Vector2(110,36),18)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if rules.round_number>0: round_label.text = "%d턴 · 주사위 %d" % [rules.round_number,rules.face]
	message = text(layer,"주사위를 굴리면 %d턴이 시작됩니다" % (rules.round_number+1),Vector2(536,14),Vector2(334,36),12)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.clip_text = true
	pause_button = button(layer,"일시정지",Vector2(986,18),Vector2(90,32),toggle_pause)
	var pause_effects = ButtonEffects.new()
	pause_effects.name = "ButtonEffectsModule"
	pause_button.add_child(pause_effects)
	speed_button = button(layer,"×1",Vector2(1080,18),Vector2(54,32),cycle_speed)
	var formation_button = button(layer,"편성 변경",Vector2(1138,18),Vector2(116,32),show_selection)
	formation_button.visible = not map_mode
	dice_cards_button = button(layer,"주사위 카드",Vector2(1138,18),Vector2(116,32),show_dice_hand)
	dice_cards_button.visible = map_mode
	brand_reference_button = button(layer,"낙인 확인표",Vector2(148,18),Vector2(118,32),show_brand_reference)
	for team in ["ally","enemy"]:
		var title = text(layer,"아군 활성 군단" if team == "ally" else "적군 활성 군단",Vector2(25.6 if team == "ally" else 1054.4,53),Vector2(200,26),16)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if team=="ally" else HORIZONTAL_ALIGNMENT_RIGHT
		var enabled: Array = rules.legions[team].active.filter(func(key): return rules.active(team,key))
		for i in range(enabled.size()):
			var key = enabled[i]
			var x = 25.6+i*56 if team == "ally" else 1200.4-i*56
			image(layer,"res://assets/battle/ui/legion-slot-frame.png",Vector2(x,82),Vector2(54,54))
			var name_text = text(layer,LEGIONS[key],Vector2(x,92),Vector2(54,17),10)
			name_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var count = text(layer,"%d/%d" % [rules.legions[team].counts[key],rules.NEED[key]],Vector2(x,111),Vector2(54,12),8)
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice = TextureButton.new()
	dice.size = Vector2(124,106)
	dice.position = (surface_size-dice.size)/2.0
	dice.ignore_texture_size = true
	dice.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	dice.texture_normal = texture("res://assets/battle/dice/result-%02d.png" % rules.face)
	dice.pressed.connect(on_dice_pressed)
	dice.tooltip_text = "클릭하여 다음 라운드 진행"
	layer.add_child(dice)
	render_units(rules.units)
	AudioSettings.new().setup(layer)
	cues = CombatCues.new()
	layer.add_child(cues)
	cues.setup(self)
	pause_button.disabled = true
	if not map_mode:
		button(layer,"새 전투",Vector2(582,664),Vector2(116,32),func():
			if not busy: reset_battle())

func battle_background_path() -> String:
	var region = session.world.region if map_mode else "winter"
	var names = {"default":"dark-forest","winter":"snow-forest","hell":"lava-forest"}
	return "res://assets/battle/backgrounds/%s.jpg" % names.get(region,"dark-forest")

func unit_floor_y() -> float:
	return 390.0 if embedded else 570.0

func card_rest_y() -> float:
	return surface_size.y-107.2

func card_action_y() -> float:
	return surface_size.y-20.0

func unit_x(u: Dictionary) -> float:
	var columns = [4,3,2,1,5] if u.team == "ally" else [2,3,4,5,1]
	return (0.0 if u.team == "ally" else 665.6)+(columns[mini(u.slot,4)]-0.5)*122.88

func frame_path(u: Dictionary, motion: String, index: int) -> String:
	return "res://assets/battle/frames/%s/%s-%02d.png" % [u.slug,motion,index]

func body_scale(u: Dictionary) -> float:
	return presentation_layout.geometry(u,surface_size).scale

func motion_frames(u: Dictionary, motion: String) -> Array:
	return presentation_layout.frames(u.slug,motion)

func wait_presentation(seconds: float, minimum: float = 0.0) -> void:
	var remaining = maxf(minimum,seconds/minf(speed_values[speed_index],1.2))
	while remaining>0:
		await get_tree().process_frame
		if not paused: remaining -= get_process_delta_time()

func render_units(values: Array) -> void:
	for u in values:
		if not sprites.has(u.id):
			var node = image(world_layer,frame_path(u,"attack",1),Vector2.ZERO,Vector2(320,320))
			node.z_index = 2
			sprites[u.id] = node
			var bar = PresentationLayout.HealthBar.new()
			bar.size = Vector2(surface_size.x*0.48/5.0*0.86,5)
			bar.z_index = 48
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
			card.position = Vector2(unit_x(u)-39.465,card_action_y() if busy else card_rest_y())
			card.disabled = busy
			card.tooltip_text = "%s · %d/%d" % [u.name,u.hp,u.max_hp]
			var id: String = u.id
			card.pressed.connect(func(): show_detail(rules.find_id(id)))
			card.mouse_entered.connect(func(): card.z_index = 46 if selected_card==id else 45)
			card.mouse_exited.connect(func(): card.z_index = 46 if selected_card==id else 44)
			layer.add_child(card)
			card.z_index = 44
			cards[u.id] = card
			BrandFrameOverlay.sync(card,u)
		var sprite: TextureRect = sprites[u.id]
		var tex = texture(frame_path(u,"attack",1))
		if tex != null:
			var geometry = presentation_layout.geometry(u,surface_size)
			sprite.size = geometry.size
			sprite.pivot_offset = geometry.pivot
			sprite.z_index = geometry.z
			if u.alive: sprite.texture = tex
			sprite.position = geometry.position
			sprite.flip_h = u.team == "enemy"
			sprite.modulate = Color.WHITE if u.alive else Color(0.4,0.4,0.4,0.35)
		bars[u.id].position = Vector2(unit_x(u)-bars[u.id].size.x/2.0,surface_size.y*0.3028)
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
	var profile: Dictionary = presentation_layout.metrics.get(u.slug,{})
	var custom_delays: Array = profile.get(motion+"_delays",[])
	var step = 0
	for index in motion_frames(u,motion):
		var tex = texture(frame_path(u,motion,index))
		if tex == null: break
		sprites[id].texture = tex
		await wait_time(float(custom_delays[step]) if step<custom_delays.size() else 0.16)
		step += 1

func sound(kind: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = load("res://assets/battle/sfx/permanent_death.wav" if kind=="permanent-death" else "res://assets/battle/sfx/%s.ogg" % kind)
	player.volume_db = -12
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func roll_round(instance_id: String = "") -> void:
	if busy or is_instance_valid(capture_panel) or is_instance_valid(brand_reference): return
	if not map_mode and not rules.winner().is_empty(): return
	var phase = str(session.encounter.get("phase","ready")) if map_mode else "ready"
	if phase=="ready" and not rules.winner().is_empty(): return
	close_brand_reference()
	close_detail()
	close_dice_hand()
	busy = true
	set_card_phase(true)
	dice.disabled = true
	dice_cards_button.disabled = true
	pause_button.disabled = false
	var result: Dictionary = {}
	if phase=="ready":
		if map_mode:
			result = session.prepare_battle_roll(rules,instance_id)
			if not result.get("ok",false):
				storage_failed(str(result.get("reason","굴림 저장 실패")))
				return
		else: result = {"face":0,"label":""}
		message.text = "주사위를 굴리는 중…"+(" · "+str(result.label) if not str(result.label).is_empty() else "")
		await dice_animation.roll_battle(dice,texture,sound,wait_time)
		phase = "rolled"
	elif phase=="rolled": result = session.encounter.roll
	if phase=="rolled":
		if result.is_empty(): result = session.encounter.roll
		var round_before = rules.units.duplicate(true)
		rules.begin_round(int(result.face))
		if map_mode and not session.checkpoint_battle(rules,"actions"):
			storage_failed("턴 시작 저장 실패 · 주사위를 눌러 재개하세요")
			return
		sound("dice-land")
		dice.texture_normal = texture("res://assets/battle/dice/result-%02d.png" % rules.face)
		round_label.text = "%d턴 · 주사위 %d" % [rules.round_number,rules.face]
		render_units(rules.units)
		await cues.play_dice_result(rules.face)
		await cues.play_brands(rules.units)
		await visuals.play_round(round_before,rules.units,rules.presentation_events)
		await wait_time(0.5)
	else:
		dice.texture_normal = texture("res://assets/battle/dice/result-%02d.png" % rules.face)
		round_label.text = "%d턴 · 주사위 %d · 재개" % [rules.round_number,rules.face]
	while true:
		var action: Dictionary = rules.next_action()
		if map_mode and not session.checkpoint_battle(rules,"actions"):
			storage_failed("행동 저장 실패 · 주사위를 눌러 재개하세요")
			return
		if action.is_empty(): break
		render_units(action.before)
		message.text = "%s 행동" % rules.find_id(action.actor).name
		await visuals.play_action(action)
		message.text = " / ".join(action.events)
		await wait_time(0.22)
	var winner = rules.winner()
	if winner.is_empty() and map_mode and not session.checkpoint_battle(rules,"ready"):
		storage_failed("턴 완료 저장 실패 · 주사위를 눌러 재개하세요")
		return
	if winner=="ally": sound("victory")
	message.text = ("승리! · 새 전투 또는 편성 변경" if winner=="ally" else "패배 · 새 전투 또는 편성 변경") if not winner.is_empty() else "주사위를 굴리면 %d턴이 시작됩니다" % (rules.round_number+1)
	busy = false
	set_card_phase(false)
	paused = false
	pause_button.text = "일시정지"
	pause_button.disabled = true
	dice.disabled = not winner.is_empty()
	dice_cards_button.disabled = not winner.is_empty()
	if map_mode and not winner.is_empty():
		if not session.finish_encounter(rules):
			map_return.disabled = false
			message.text = "전투 결과 저장 실패 · 전투 닫기로 다시 시도하세요"
			return
		if session.world.pending_reward.get("kind","")=="capture":
			begin_capture()
			return
		map_return.disabled = false
		message.text = ("승리!" if winner=="ally" else "패배")+" · 전투를 닫고 원정을 계속하세요"

func storage_failed(reason: String) -> void:
	busy = false
	paused = false
	pause_button.text = "일시정지"
	pause_button.disabled = true
	dice.disabled = false
	dice_cards_button.disabled = session.encounter.get("phase","ready")!="ready"
	set_card_phase(false)
	render_units(rules.units)
	message.text = reason

func resume_battle() -> void:
	await roll_round()

func show_dice_hand() -> void:
	close_brand_reference()
	if not map_mode or busy or is_instance_valid(capture_panel) or not rules.winner().is_empty() or session.encounter.get("phase","ready")!="ready": return
	if is_instance_valid(dice_hand): return
	close_detail()
	dice_hand = DiceHand.new()
	(detail_parent if embedded else layer).add_child(dice_hand)
	dice_hand.setup(session.world.dice_cards,session.dice_context(true),true)
	dice_hand.closed.connect(close_dice_hand)
	dice_hand.chosen.connect(func(id: String):
		close_dice_hand()
		roll_round(id))

func close_dice_hand() -> void:
	if is_instance_valid(dice_hand):
		dice_hand.get_parent().remove_child(dice_hand)
		dice_hand.queue_free()
	dice_hand = null

func return_to_map() -> void:
	if busy: return
	if map_mode:
		if rules.winner().is_empty(): return
		if not session.finish_encounter(rules):
			message.text = "전투 결과 저장 실패 · 다시 시도하세요"
			return
		if not session.world.pending_reward.is_empty():
			if not is_instance_valid(capture_panel): begin_capture()
			return
	if embedded:
		finished.emit()
	else:
		get_tree().change_scene_to_file("res://map.tscn")

func toggle_pause() -> void:
	paused = not paused
	pause_button.text = "계속" if paused else "일시정지"

func cycle_speed() -> void:
	speed_index = (speed_index+1)%3
	speed_button.text = "×%d" % (speed_index+1)

func show_detail(u: Dictionary) -> void:
	if busy or u.is_empty(): return
	close_brand_reference()
	close_detail()
	selected_card = u.id
	set_card_phase(false)
	detail = UnitInfo.new()
	(detail_parent if embedded and is_instance_valid(detail_parent) else layer).add_child(detail)
	detail.setup(u,rules)
	if embedded: detail.z_index = 200
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
		card.z_index = 46 if selected_card==id else 44
		if card_tweens.has(id) and card_tweens[id].is_valid(): card_tweens[id].kill()
		var tween = create_tween()
		card_tweens[id] = tween
		tween.tween_property(card,"position:y",card_action_y() if acting else (card_rest_y()-24.0 if selected_card==id else card_rest_y()),0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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


func on_dice_pressed() -> void:
	if is_instance_valid(capture_panel): await capture_panel.roll()
	else: await roll_round()

func begin_capture() -> void:
	close_brand_reference()
	close_dice_hand()
	dice_cards_button.disabled = true
	close_detail()
	capture_panel = CorpseCapture.new()
	layer.add_child(capture_panel)
	capture_panel.setup(self)

func can_open_brand_reference() -> bool:
	if busy or is_instance_valid(capture_panel) or rules == null: return false
	if not rules.winner().is_empty(): return false
	return not map_mode or session.encounter.get("phase","ready")=="ready"

func _process(_delta: float) -> void:
	if is_instance_valid(brand_reference_button):
		brand_reference_button.disabled = not can_open_brand_reference()

func show_brand_reference() -> void:
	if not can_open_brand_reference() or is_instance_valid(brand_reference): return
	close_detail()
	close_dice_hand()
	brand_reference = BrandReference.new()
	(detail_parent if embedded and is_instance_valid(detail_parent) else layer).add_child(brand_reference)
	brand_reference.setup(rules)
	brand_reference.closed.connect(close_brand_reference)

func close_brand_reference() -> void:
	if is_instance_valid(brand_reference):
		brand_reference.get_parent().remove_child(brand_reference)
		brand_reference.queue_free()
	brand_reference = null
