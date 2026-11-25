extends Control
const CardDepthMotion = preload("res://systems/card_depth_motion.gd")

signal confirmed(selected_ids: Array)
signal closed
const PaintedAction = preload("res://systems/painted_action.gd")
const HAND_POSITION := Vector2(117,472)
const HAND_SIZE := Vector2(1046,150)
const HAND_CARD_SIZE := Vector2(104,143)
signal rename_submitted(instance_id: String, candidate: String)
const ButtonEffects = preload("res://systems/button_effects_module.gd")
const LayeredUnitCard = preload("res://systems/layered_unit_card.gd")
const AltarUpgradeBadge = preload("res://systems/altar_upgrade_badge.gd")
const UnitInfo = preload("res://systems/unit_info.gd")
const MonsterInspectSeal = preload("res://systems/monster_inspect_seal.gd")
const BattleRules = preload("res://systems/battlefield_rules.gd")
const Accent = preload("res://systems/presentation_accent.gd")
const TARGET_RATES = {1:[100],2:[35,65],3:[20,33,47],4:[15,20,27,38]}
var click_audio: AudioStreamPlayer
var entry_audio: AudioStreamPlayer
var card_shader: Shader
var departing = false
var owned: Array = []
var selected_ids: Array = []
var departure_origins: Dictionary = {}
var board: Control
var lineup: Control
var hand: Control
var status: Label
var confirm_button: Button
var close_button: Button
var info_window: Control
var active_legion_keys: Array = []
var hand_order_pending := false

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
	lineup.name = "SelectedLineup"
	lineup.position = board.size*Vector2(0.204,0.272)
	lineup.size = board.size*Vector2(0.611,0.472)
	board.add_child(lineup)
	hand = Control.new()
	hand.name = "OwnedCardHand"
	hand.position = HAND_POSITION
	hand.size = HAND_SIZE
	add_child(hand)
	status = text_label(board,"",Vector2(440,392),Vector2(285,34),16)
	status.name = "LineupStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color",Color("4d2d1a"))
	status.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	close_button = create_frame_close()
	confirm_button = deck_action("DeckStartButton","전투 시작",Vector2(873,637),2)
	confirm_button.pressed.connect(func():
		if selected_ids.is_empty(): return
		confirm_button.disabled = true
		close_button.disabled = true
		status.text = "전장으로 이동 중…"
		# The actual chosen card Controls are handed straight to the
		# map stage by the confirmed handler. No downward departure, full-screen
		# veil or recreated ghost: a card must never blink out between scenes.
		departing = true
		confirmed.emit(selected_ids.duplicate()))
	render_selection()
	board.position.y = -617
	board.modulate.a = 0
	hand.position.y += 306
	hand.modulate.a = 0
	confirm_button.modulate.a = 0
	# Original user-provided wooden-door opening clip; shared with the chest.
	# Play once for the descending board, never when selected cards redraw.
	entry_audio = AudioStreamPlayer.new()
	entry_audio.name = "DeckEntrySound"
	entry_audio.bus = "SFX"
	entry_audio.stream = preload("res://assets/battle/sfx/treasure-chest-open.mp3")
	entry_audio.volume_db = -14.0
	add_child(entry_audio)
	entry_audio.play()
	var drop = create_tween().set_parallel(true)
	drop.tween_property(board,"position:y",14.4,0.64).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_property(board,"modulate:a",1.0,0.3)
	drop.tween_property(hand,"position:y",HAND_POSITION.y,0.6).set_delay(0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_property(hand,"modulate:a",1.0,0.3).set_delay(0.18)
	drop.tween_property(confirm_button,"modulate:a",1.0,0.42).set_delay(0.38)

func create_frame_close() -> Button:
	var action := Button.new()
	action.name = "DeckCloseButton"
	action.text = "×"
	action.tooltip_text = "닫기"
	action.set_meta("keyboard_description","닫기")
	action.set_meta("keyboard_focus_key","DeckCloseButton")
	action.position = Vector2(951,67)
	action.custom_minimum_size = Vector2(44,38)
	action.size = action.custom_minimum_size
	action.z_index = 2
	action.add_theme_font_size_override("font_size",26)
	action.add_theme_color_override("font_color",Color("f0d1a0"))
	action.add_theme_color_override("font_hover_color",Color("ffe6ba"))
	action.add_theme_color_override("font_pressed_color",Color("ffe6ba"))
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color("34271dee")
	edge.border_color = Color("a87e56")
	edge.set_border_width_all(1)
	edge.set_corner_radius_all(4)
	action.add_theme_stylebox_override("normal",edge)
	action.add_theme_stylebox_override("pressed",edge)
	var hover := edge.duplicate() as StyleBoxFlat
	hover.bg_color = Color("503a29")
	hover.border_color = Color("e3b980")
	action.add_theme_stylebox_override("hover",hover)
	board.add_child(action)
	action.pressed.connect(request_close)
	return action


func deck_action(node_name: String, caption: String, at: Vector2, paper: int) -> Button:
	var action := Button.new()
	action.name = node_name
	action.text = caption
	action.position = at
	action.size = Vector2(204,48)
	action.set_meta("keyboard_focus_key",node_name)
	add_child(action)
	PaintedAction.style(action,paper)
	return action

func keyboard_focus_scope() -> Control:
	return info_window if is_instance_valid(info_window) else self

func request_close() -> void:
	if departing: return
	if is_instance_valid(info_window):
		info_window.request_close()
		return
	departing = true
	close_button.disabled = true
	confirm_button.disabled = true
	closed.emit()

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
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.position = pos
	button.size = dimensions
	button.pivot_offset = dimensions/2
	button.rotation_degrees = tilt
	button.tooltip_text = unit.name
	button.focus_mode = Control.FOCUS_ALL
	var material = ShaderMaterial.new()
	material.shader = card_shader
	material.set_shader_parameter("highlight",0.75 if selected_ids.has(unit.id) else 0.15)
	button.material = material
	button.mouse_entered.connect(func(): material.set_shader_parameter("highlight",1.0))
	button.mouse_exited.connect(func(): material.set_shader_parameter("highlight",0.75 if selected_ids.has(unit.id) else 0.15))
	parent.add_child(button)
	# Card art is built from independent runtime nodes, not a flattened PNG.
	LayeredUnitCard.install(button, str(unit.slug), str(unit.name), selected_ids.has(unit.id), unit.get("brands", []))
	CardDepthMotion.install(button, selected_ids.has(unit.id))
	AltarUpgradeBadge.sync(button,unit)
	button.set_meta("sfx_manual",true)
	button.pressed.connect(func(): toggle_unit(unit.id))
	return button

func toggle_unit(id: String) -> void:
	if departing or is_instance_valid(info_window): return
	var Sound = preload("res://systems/game_audio.gd")
	if selected_ids.has(id):
		Sound.cue(self,"ui_cancel")
		selected_ids.erase(id)
	elif selected_ids.size()<4:
		Sound.cue(self,"ui_select")
		selected_ids.append(id)
	else:
		Sound.cue(self,"ui_blocked")
	render_selection()

func render_selection() -> void:
	for parent in [lineup,hand]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	var rates: Array = TARGET_RATES.get(selected_ids.size(),[])
	var gap = lineup.size.x*0.028
	var width = (lineup.size.x-gap*3)/4
	# The web board keeps four fixed slot anchors even when fewer units are selected.
	for i in range(4):
		if i >= selected_ids.size():
			var empty = Control.new()
			empty.name = "EmptySlot_%d" % (i+1)
			empty.position = Vector2(i*(width+gap),0)
			empty.size = Vector2(width,lineup.size.y)
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lineup.add_child(empty)
			continue
		var unit: Dictionary = {}
		for entry in owned:
			if entry.id==selected_ids[i]: unit = entry
		var slot = card(lineup,unit,Vector2(i*(width+gap),0),Vector2(width,lineup.size.y),[-7.0,-1.0,1.0,7.0][i])
		slot.name = "SelectedUnit_%d" % (i+1)
		slot.set_meta("keyboard_focus_key","lineup:"+str(unit.id))
		var badge = Panel.new()
		badge.name = "TargetRate"
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
		rate.name = "TargetRateLabel"
		rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var stride := minf(122.0,(hand.size.x-HAND_CARD_SIZE.x)/maxi(1,owned.size()-1))
	var start_x := (hand.size.x-HAND_CARD_SIZE.x-stride*maxi(0,owned.size()-1))*0.5
	var previous_button: TextureButton
	var touch_seal := OS.has_feature("mobile") or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())
	for i in range(owned.size()):
		var unit: Dictionary = owned[i]
		var is_selected = selected_ids.has(unit.id)
		var y = -3.0 if is_selected else 10.0
		var button = card(hand,unit,Vector2(start_x+i*stride,y),HAND_CARD_SIZE,[-4.0,2.0,-1.0,3.0,-2.0][i%5])
		button.set_meta("keyboard_focus_key","unit:"+str(unit.id))
		button.set_meta("keyboard_focus_default",i==0)
		button.set_meta("hand_base_z",i)
		button.z_index = 3 if is_selected else 0
		button.scale = Vector2.ONE*1.05 if is_selected else Vector2.ONE
		var name_label = text_label(button,unit.name,Vector2(3,98),Vector2(98,22),12)
		name_label.name = "OwnedCardName"
		name_label.visible = not LayeredUnitCard.supports(str(unit.slug))
		if is_selected:
			# Numbered source-style marker makes the actual selection order visible.
			var order = Panel.new()
			order.name = "SelectionOrderBadge"
			order.position = Vector2(10,12)
			order.size = Vector2(24,24)
			order.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var order_style = StyleBoxFlat.new()
			order_style.bg_color = Color("e1a447")
			order_style.border_color = Color("ffe2a1")
			order_style.set_border_width_all(2)
			order_style.set_corner_radius_all(12)
			order.add_theme_stylebox_override("panel",order_style)
			button.add_child(order)
			var number = text_label(order,str(selected_ids.find(unit.id)+1),Vector2.ZERO,order.size,13)
			number.add_theme_color_override("font_color",Color("1b0d04"))
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		MonsterInspectSeal.attach(button,open_info.bind(str(unit.id)),touch_seal)
		button.focus_neighbor_top = button.get_path_to(close_button)
		if not selected_ids.is_empty():
			button.focus_neighbor_bottom = button.get_path_to(confirm_button)
		if previous_button != null:
			previous_button.focus_neighbor_right = previous_button.get_path_to(button)
			button.focus_neighbor_left = button.get_path_to(previous_button)
		if i == owned.size()-1:
			close_button.focus_neighbor_bottom = close_button.get_path_to(button)
			confirm_button.focus_neighbor_top = confirm_button.get_path_to(button)
		previous_button = button
		button.mouse_entered.connect(func():
			button.z_index = 3 if is_selected else 2
			button.position.y = y if is_selected else 3.82
			button.scale = Vector2.ONE*1.05
			queue_hand_order())
		button.mouse_exited.connect(func():
			button.z_index = 3 if is_selected else (2 if button.has_focus() else 0)
			button.position.y = y if is_selected or not button.has_focus() else 3.82
			button.scale = Vector2.ONE*1.05 if is_selected or button.has_focus() else Vector2.ONE
			queue_hand_order())
		button.focus_entered.connect(func():
			button.z_index = 3 if is_selected else 2
			button.position.y = y if is_selected else 3.82
			button.scale = Vector2.ONE*1.05
			queue_hand_order())
		button.focus_exited.connect(func():
			button.z_index = 3 if is_selected else (2 if button.is_hovered() else 0)
			button.position.y = y if is_selected or not button.is_hovered() else 3.82
			button.scale = Vector2.ONE*1.05 if is_selected or button.is_hovered() else Vector2.ONE
			queue_hand_order())
	CardDepthMotion.sync_input_order(hand.get_children())
	status.text = tr("출전 마물 %d/4") % selected_ids.size()
	confirm_button.disabled = selected_ids.is_empty()
	show_new_legion_links()

func queue_hand_order() -> void:
	# Focus may exit while the current cards are being removed from the hand.
	if hand_order_pending or not is_inside_tree(): return
	hand_order_pending = true
	sync_hand_order.call_deferred()

func sync_hand_order() -> void:
	hand_order_pending = false
	if not is_inside_tree(): return
	CardDepthMotion.sync_input_order(hand.get_children())

func show_new_legion_links() -> void:
	var previous := board.get_node_or_null("PresentationAccent_legion")
	if is_instance_valid(previous):
		board.remove_child(previous)
		previous.queue_free()
	var selected: Array = []
	for id in selected_ids:
		for unit in owned:
			if str(unit.id)==str(id): selected.append(unit)
	var groups := Accent.legion_groups(selected,BattleRules.NEED)
	var newly_active: Array = []
	var points: Array[Vector2] = []
	var names := {"skeleton":"언데드","beast":"야수","corpse":"시체","plague":"역병","ice":"얼음","summon":"소환","demon":"악마","plant":"식물","insect":"벌레","element":"원소"}
	var captions: Array[String] = []
	for key in groups:
		if key in active_legion_keys: continue
		newly_active.append(key)
		captions.append(str(names.get(key,key)))
	for i in range(selected.size()):
		var participates := false
		for key in newly_active:
			if str(selected[i].id) in groups[key]: participates = true
		if not participates: continue
		var node: Control = lineup.get_node_or_null("SelectedUnit_%d" % (i+1))
		if is_instance_valid(node):
			points.append(board.get_global_transform_with_canvas().affine_inverse()*(node.get_global_transform_with_canvas()*(node.size*Vector2(0.5,0.80))))
	active_legion_keys = groups.keys()
	if points.is_empty(): return
	var cue := Accent.create(board,"legion",points,Color("e6c68b"),0.80)
	cue.caption = " · ".join(captions)+" 군단 성립"
	cue.caption_rect = Rect2(230,89,710,32)


## One real owned-instance panel, with a disposable battle-rules preview.
## Opening this panel never selects/deselects a card or edits a save.
func open_info(instance_id: String) -> void:
	if departing or is_instance_valid(info_window): return
	var unit: Dictionary = {}
	for owned_unit in owned:
		if str(owned_unit.id)==instance_id: unit = owned_unit
	if unit.is_empty(): return
	var rules = BattleRules.new(JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units,1)
	rules.start([unit],[])
	var preview: Dictionary = rules.units[0]
	preview.hp = mini(int(preview.max_hp),int(unit.get("current_hp",preview.max_hp)))
	info_window = UnitInfo.new()
	info_window.name = "DeckUnitInformation"
	info_window.z_index = 140
	add_child(info_window)
	info_window.setup(preview,rules,{},true)
	info_window.rename_submitted.connect(func(chosen: String): rename_submitted.emit(instance_id,chosen))
	info_window.closed.connect(func(): info_window = null)

func apply_rename_result(instance_id: String, result: Dictionary) -> void:
	if bool(result.get("ok",false)):
		for unit in owned:
			if str(unit.id)==instance_id:
				unit["name"] = str(result.name)
				unit["nickname"] = str(result.name)
		render_selection()
	if is_instance_valid(info_window):
		info_window.apply_rename_result(result)

# Transfer the actual selected TextureButtons into the persistent map stage.
# Keeping the SAME nodes, textures, brand frames and badges across the UI
# replacement avoids any disappearing/recreated-card frame.
func release_selected_cards_to(parent: Control) -> Dictionary:
	var result: Dictionary = {}
	var inverse: Transform2D = parent.get_global_transform_with_canvas().affine_inverse()
	for i in range(selected_ids.size()):
		# Removing a child shifts numeric indices. Find each original named
		# slot instead, so 2/3/4 selected cards cannot be skipped or mismapped.
		var chosen: TextureButton = lineup.get_node_or_null("SelectedUnit_%d" % (i+1)) as TextureButton
		if chosen==null: continue
		var canvas: Transform2D = chosen.get_global_transform_with_canvas()
		var origin: Vector2 = inverse * (canvas * Vector2.ZERO)
		var right: Vector2 = inverse * (canvas * Vector2(chosen.size.x,0.0))
		var down: Vector2 = inverse * (canvas * Vector2(0.0,chosen.size.y))
		lineup.remove_child(chosen)
		parent.add_child(chosen)
		chosen.name = "DeckToBattleFlight_%d" % (i+1)
		chosen.set_meta("card_in_transfer",true)
		chosen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chosen.focus_mode = Control.FOCUS_NONE
		chosen.disabled = true
		# Preserve the 2D canvas footprint exactly, including original tilt.
		# Pivot zero makes the destination top-left transformation unambiguous.
		chosen.pivot_offset = Vector2.ZERO
		chosen.position = origin
		chosen.rotation = (right-origin).angle()
		chosen.scale = Vector2((right-origin).length()/chosen.size.x,(down-origin).length()/chosen.size.y)
		chosen.z_index = 120
		# Hit-rate captions belong to the deck selector, not the combat card.
		var rate := chosen.get_node_or_null("TargetRate")
		if rate!=null: rate.hide()
		result[str(selected_ids[i])] = chosen
	return result

func _exit_tree() -> void:
	for player in [entry_audio,click_audio]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
