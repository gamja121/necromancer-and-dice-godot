extends Control

signal confirmed(selected_ids: Array)
const ButtonEffects = preload("res://systems/button_effects_module.gd")
const TARGET_RATES = {1:[100],2:[35,65],3:[20,33,47],4:[15,20,27,38]}
var click_audio: AudioStreamPlayer
var card_shader: Shader
var departing = false
var owned: Array = []
var selected_ids: Array = []
var board: Control
var lineup: Control
var hand: Control
var status: Label
var confirm_button: Button

func setup(roster: Array) -> void:
	owned = roster.duplicate(true)
	click_audio = AudioStreamPlayer.new()
	click_audio.bus = "SFX"
	click_audio.stream = load("res://assets/battle/sfx/ui.ogg")
	click_audio.volume_db = -16
	add_child(click_audio)
	card_shader = Shader.new()
	card_shader.code = """
shader_type canvas_item;
uniform float highlight = 0.15;
void fragment() {
	vec4 source = COLOR;
	float sweep = pow(max(0.0, 1.0 - abs(UV.x + UV.y * 0.25 - fract(TIME * 0.35) * 1.5) * 7.0), 3.0);
	source.rgb += vec3(0.2, 0.15, 0.05) * sweep * highlight;
	COLOR = source;
}
"""
	selected_ids.clear()
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	board = Control.new()
	board.position = Vector2(57.6,14.4)
	board.size = Vector2(1164.8,522.95)
	add_child(board)
	var art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture = load("res://assets/battle/ui/battle-deck-selection-board.png")
	art.size = board.size
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(art)
	lineup = Control.new()
	lineup.position = board.size*Vector2(0.204,0.272)
	lineup.size = board.size*Vector2(0.611,0.472)
	board.add_child(lineup)
	hand = Control.new()
	hand.position = Vector2(12.8,496.8)
	hand.size = Vector2(870.4,244.8)
	add_child(hand)
	status = text_label(self,"",Vector2(610,560),Vector2(606,34),14)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	confirm_button = Button.new()
	confirm_button.text = "전투 시작"
	confirm_button.position = Vector2(1049.6,609.2)
	confirm_button.size = Vector2(166.4,46)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("51301c")
	style.border_color = Color("a17b4c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	confirm_button.add_theme_stylebox_override("normal",style)
	confirm_button.add_theme_color_override("font_color",Color("ffe3ad"))
	add_child(confirm_button)
	var confirm_effects = ButtonEffects.new()
	confirm_effects.name = "ButtonEffectsModule"
	confirm_effects.hover_scale = Vector2(1.075,1.075)
	confirm_effects.hover_rotation_degrees = 1.75
	confirm_button.add_child(confirm_effects)
	confirm_button.pressed.connect(func():
		if selected_ids.is_empty(): return
		confirm_button.disabled = true
		status.text = "전장으로 이동 중…"
		departing = true
		await depart()
		confirmed.emit(selected_ids.duplicate()))
	render_selection()
	board.position.y = -617
	board.modulate.a = 0
	hand.position.y += 306
	hand.modulate.a = 0
	status.modulate.a = 0
	confirm_button.modulate.a = 0
	var drop = create_tween().set_parallel(true)
	drop.tween_property(board,"position:y",14.4,0.64).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_property(board,"modulate:a",1.0,0.3)
	drop.tween_property(hand,"position:y",496.8,0.6).set_delay(0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_property(hand,"modulate:a",1.0,0.3).set_delay(0.18)
	drop.tween_property(status,"modulate:a",1.0,0.42).set_delay(0.38)
	drop.tween_property(confirm_button,"modulate:a",1.0,0.42).set_delay(0.38)

func text_label(parent: Control, value: String, pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label = Label.new()
	label.text = value
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("ffe3a6"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func card(parent: Control, unit: Dictionary, pos: Vector2, dimensions: Vector2, tilt: float) -> TextureButton:
	var button = TextureButton.new()
	button.ignore_texture_size = true
	button.texture_normal = load("res://assets/cards/unit-card-%s.png" % unit.slug)
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.position = pos
	button.size = dimensions
	button.pivot_offset = dimensions/2
	button.rotation_degrees = tilt
	button.tooltip_text = unit.name
	var material = ShaderMaterial.new()
	material.shader = card_shader
	material.set_shader_parameter("highlight",0.75 if selected_ids.has(unit.id) else 0.15)
	button.material = material
	button.mouse_entered.connect(func(): material.set_shader_parameter("highlight",1.0))
	button.mouse_exited.connect(func(): material.set_shader_parameter("highlight",0.75 if selected_ids.has(unit.id) else 0.15))
	parent.add_child(button)
	button.pressed.connect(func(): toggle_unit(unit.id))
	return button

func toggle_unit(id: String) -> void:
	if departing: return
	click_audio.play()
	if selected_ids.has(id): selected_ids.erase(id)
	elif selected_ids.size()<4: selected_ids.append(id)
	render_selection()

func render_selection() -> void:
	for parent in [lineup,hand]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	var rates: Array = TARGET_RATES.get(selected_ids.size(),[])
	var gap = lineup.size.x*0.028
	var width = (lineup.size.x-gap*3)/4
	for i in range(selected_ids.size()):
		var unit: Dictionary = {}
		for entry in owned:
			if entry.id==selected_ids[i]: unit = entry
		var slot = card(lineup,unit,Vector2(i*(width+gap),0),Vector2(width,lineup.size.y),[-7.0,-1.0,1.0,7.0][i])
		var badge = Panel.new()
		badge.position = Vector2(width*0.03,lineup.size.y*0.98-25)
		badge.size = Vector2(width*0.94,25)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style = StyleBoxFlat.new()
		style.bg_color = Color("190d08e8")
		style.border_color = Color("d7ae6a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		badge.add_theme_stylebox_override("panel",style)
		slot.add_child(badge)
		var rate = text_label(badge,"피격 %d%%" % rates[i],Vector2.ZERO,badge.size,13)
		rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for i in range(owned.size()):
		var unit: Dictionary = owned[i]
		var is_selected = selected_ids.has(unit.id)
		var y = 19.584 + (-49.55 if is_selected else 22.52)
		var button = card(hand,unit,Vector2(i*87.04,y),Vector2(121.856,225.216),[-4.0,2.0,-1.0,3.0,-2.0][i%5])
		button.z_index = 3 if is_selected else 0
		button.scale = Vector2.ONE*1.05 if is_selected else Vector2.ONE
		var name_label = text_label(button,unit.name,Vector2(6,185),Vector2(110,24),11)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.mouse_entered.connect(func():
			button.z_index = 3 if is_selected else 2
			button.position.y = y if is_selected else 3.82
			button.scale = Vector2.ONE*1.05)
		button.mouse_exited.connect(func():
			button.z_index = 3 if is_selected else 0
			button.position.y = y
			button.scale = Vector2.ONE*1.05 if is_selected else Vector2.ONE)
	status.text = "마물 카드 %d / 4" % selected_ids.size()
	if not rates.is_empty():
		var parts = PackedStringArray()
		for rate in rates: parts.append(str(rate))
		status.text += " · 왼쪽부터 피격 %s%%" % " · ".join(parts)
	confirm_button.disabled = selected_ids.is_empty()


func depart() -> void:
	var veil = ColorRect.new()
	veil.size = size
	veil.color = Color("180e26")
	veil.modulate.a = 0
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.z_index = 20
	add_child(veil)
	var exit = create_tween().set_parallel(true)
	exit.tween_property(hand,"position:y",850.0,0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(board.get_child(0),"modulate:a",0.0,0.4)
	exit.tween_property(status,"modulate:a",0.0,0.2)
	exit.tween_property(confirm_button,"modulate:a",0.0,0.2)
	for i in range(lineup.get_child_count()):
		var selected: Control = lineup.get_child(i)
		exit.tween_property(selected,"position",Vector2(400-board.position.x-lineup.position.x+i*105,530-board.position.y-lineup.position.y),0.42).set_delay(i*0.045).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		exit.tween_property(selected,"scale",Vector2(0.58,0.58),0.42).set_delay(i*0.045)
		exit.tween_property(selected,"rotation_degrees",0.0,0.3)
	exit.tween_property(veil,"modulate:a",1.0,0.2).set_delay(0.35)
	await exit.finished
