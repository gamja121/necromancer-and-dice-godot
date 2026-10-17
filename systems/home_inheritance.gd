extends "res://systems/reward_ui.gd"
const CardDepthMotion = preload("res://systems/card_depth_motion.gd")
signal closed
const BrandInheritance = preload("res://systems/brand_inheritance.gd")
var session
var material_id = ""
var receiver_id = ""
var brand_card_id = ""
var completed = false
var busy = false
var notice = ""
var material_art: TextureRect
var receiver_art: TextureRect
var material_marks: Label
var material_hint: Label
var receiver_hint: Label
var status: Label
var details: VBoxContainer
var confirm_button: Button
var hand: Control
var unit_options: Dictionary = {}
var brand_options: Dictionary = {}
var unit_hand_scroll: ScrollContainer
var brand_fan_scroll: ScrollContainer
var brand_fan: Control
var inheritance_frame: TextureRect
var interface_data: Dictionary

func setup(run_session, map_scene: Control = null) -> void:
	session = run_session
	z_index = 85
	interface_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/interface.json"))
	backdrop()
	# Optional map reference keeps direct tests/backwards callers compatible.
	if map_scene != null:
		map_scene.location_scene_image(self,"res://assets/map/events/home-interior.jpg")
	label_at(self,"낙인 계승",Vector2(450,7),Vector2(380,30),24)
	button(self,"닫기",Vector2(1129,29),Vector2(92,38),func(): if not busy: closed.emit())
	# Web prototype shows three adjacent columns and two simultaneous card sources.
	panel_slot(Vector2(198,38),true)
	panel_slot(Vector2(814,38),false)
	inheritance_frame=art(self,"res://assets/map/ui/inheritance_info.webp",Vector2(471,62),Vector2(338,352))
	inheritance_frame.stretch_mode=TextureRect.STRETCH_SCALE
	var title=label_at(self,"낙인 · 최대 3칸",Vector2(502,104),Vector2(276,27),18)
	title.add_theme_color_override("font_color",Color("34251c"))
	title.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(495,141)
	scroll.size=Vector2(292,213)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	details=VBoxContainer.new()
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",5)
	scroll.add_child(details)
	status=label_at(self,"",Vector2(361,384),Vector2(558,32),14)
	confirm_button=button(self,"계승",Vector2(552,419),Vector2(176,46),confirm)
	confirm_button.add_theme_font_size_override("font_size",17)
	var parchment=StyleBoxTexture.new()
	parchment.texture=load("res://assets/map/ui/parchment_button_variant_01.png")
	for state in ["normal","hover","pressed","focus","disabled"]:
		confirm_button.add_theme_stylebox_override(state,parchment)
	confirm_button.add_theme_color_override("font_color",Color("40291c"))
	render_hand()
	render_selection()

func panel_slot(pos: Vector2, material: bool) -> void:
	var node = Control.new()
	node.position = pos
	node.size = Vector2(266,390)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	var board = TextureRect.new()
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/map/events/inheritance-board.png")
	atlas.region = Rect2(342 if material else 997,30,570,780)
	board.texture = atlas
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.size = node.size
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(board)
	label_at(node,"재료" if material else "결과",Vector2(21,32),Vector2(225,31),20)
	var preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.position = Vector2(38,92)
	preview.size = Vector2(191,233)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(preview)
	var hint = label_at(node,"",Vector2(27,336),Vector2(214,34),13)
	if material:
		material_art = preview
		material_marks = label_at(preview,"",Vector2(18,164),Vector2(114,32),13)
		material_marks.add_theme_color_override("font_color",Color("101b2c"))
		material_marks.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		material_hint = hint
	else:
		receiver_art = preview
		receiver_hint = hint

func selected_card() -> Dictionary:
	for item in session.world.brand_cards:
		if str(item.id)==brand_card_id: return item
	return {}

func set_preview(node: TextureRect, kind: String, item: Dictionary) -> void:
	node.texture = load(Catalog.image(kind,item)) if not item.is_empty() else null
	BrandFrameOverlay.sync(node,item if kind=="unit" else {})
	AltarUpgradeBadge.sync(node,item if kind=="unit" else {})

func detail(value: String, color: Color = Color("34251c")) -> void:
	var line = Label.new()
	line.text = value
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size",13)
	line.add_theme_color_override("font_color",color)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(line)

func append_brands(brands: Array, origin: String, show_curse: bool = true) -> void:
	for brand in brands:
		var name = str(interface_data.brands[brand.type].name).replace("의 낙인","")
		detail("%s · %s" % [origin,name])
		var blessings: String = ", ".join(brand.bless.map(func(n): return str(int(n))))
		if show_curse and not brand.curse.is_empty():
			detail("축복 [%s] · 저주 [%s]" % [blessings,", ".join(brand.curse.map(func(n): return str(int(n))))],Color("5b3526"))
		else:
			# Inheritance consumes only blessings; don't show non-inherited material curses.
			detail("축복 [%s]" % blessings,Color("5b3526"))

func render_selection() -> void:
	var material: Dictionary = session.owned_unit(material_id)
	var receiver: Dictionary = session.owned_unit(receiver_id)
	var source_card = selected_card()
	set_preview(material_art,"brand" if not source_card.is_empty() else "unit",source_card if not source_card.is_empty() else material)
	set_preview(receiver_art,"unit",receiver)
	material_marks.text = "" if source_card.is_empty() else "축복 "+ " · ".join(source_card.brand.bless.map(func(n): return str(int(n))))
	material_hint.text = "소모 완료" if completed else (str(material.get("name","아래에서 재료 선택")) if source_card.is_empty() else "선택한 낙인 카드")
	receiver_hint.text = str(receiver.get("name","받는 마물 선택"))
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
	# Put material information above the receiving monster.
	# Materials pass blessings only; the receiver still shows its own curses.
	if not material.is_empty(): append_brands(BrandInheritance.normalize(material,session.world.definitions),"재료",false)
	if not source_card.is_empty(): append_brands([source_card.brand],"카드",false)
	if not receiver.is_empty():
		detail("받는 마물 · %d / 3칸" % receiver.brands.size())
		append_brands(BrandInheritance.normalize(receiver,session.world.definitions),"결과" if completed else "기존")
	if receiver.is_empty() and material.is_empty() and source_card.is_empty(): detail("재료 마물 또는 낙인 카드를 선택하세요.")
	status.text = notice if not notice.is_empty() else ("계승 완료 · 받는 마물의 능력치와 체력은 유지됩니다" if completed else ("낙인 카드 1장 소모 · 축복만 적용" if not source_card.is_empty() else "재료 마물 소모 · 무작위 낙인 1개의 축복만 계승"))
	var eligible = not receiver.is_empty() and receiver.brands.size()<3 and (not source_card.is_empty() or (not material.is_empty() and not material.brands.is_empty()))
	confirm_button.disabled = busy or completed or not eligible or not session.home_action_allowed().ok
	confirm_button.text = "계승 완료" if completed else ("카드 소모 · 적용" if not source_card.is_empty() else "재료 소모 · 계승")
	for id in unit_options:
		var option: TextureButton = unit_options[id]
		option.modulate = Color(1.14,1.08,0.87) if id in [material_id,receiver_id] else Color.WHITE
		option.get_child(0).text = str(session.owned_unit(id).get("name",""))+("\n재료" if id==material_id else ("\n받는 마물" if id==receiver_id else ""))
		option.disabled = busy or completed
	for id in brand_options:
		var brand_option: TextureButton=brand_options[id]
		brand_option.modulate = Color(1.1,1.12,1.15) if id==brand_card_id else Color.WHITE
		brand_option.position.y=float(brand_option.get_meta("fan_y",22))-16 if id==brand_card_id else float(brand_option.get_meta("fan_y",22))
		brand_option.rotation_degrees=0 if id==brand_card_id else float(brand_option.get_meta("fan_rotation",0))
		brand_option.z_index=20 if id==brand_card_id else 0
		brand_option.disabled = busy or completed

func render_hand() -> void:
	if is_instance_valid(hand):
		remove_child(hand)
		hand.queue_free()
	unit_options.clear()
	brand_options.clear()
	hand=Control.new()
	add_child(hand)
	# Display both resource sources at once, instead of a tab switch.
	var unit_label=label_at(hand,"보유 마물",Vector2(616,479),Vector2(200,25),14)
	unit_label.add_theme_color_override("font_color",Color("e9cc94"))
	unit_hand_scroll=ScrollContainer.new()
	unit_hand_scroll.position=Vector2(351,510)
	unit_hand_scroll.size=Vector2(828,200)
	unit_hand_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	hand.add_child(unit_hand_scroll)
	var unit_row=HBoxContainer.new()
	unit_row.alignment=BoxContainer.ALIGNMENT_CENTER
	unit_row.add_theme_constant_override("separation",16)
	unit_hand_scroll.add_child(unit_row)
	if session.world.roster.is_empty():
		label_at(hand,"보유한 마물이 없습니다",Vector2(540,605),Vector2(490,29),16)
	for item in session.world.roster:
		var box=Control.new()
		box.custom_minimum_size=Vector2(106,181)
		unit_row.add_child(box)
		var id=str(item.id)
		var option=card(box,"unit",item,Vector2(4,0),Vector2(97,140),func(): select_unit(id))
		CardDepthMotion.install(option)
		option.get_child(0).add_theme_font_size_override("font_size",12)
		unit_options[id]=option
	var fan_label=label_at(hand,"낙인 카드",Vector2(76,478),Vector2(240,26),14)
	fan_label.add_theme_color_override("font_color",Color("e3c58d"))
	brand_fan_scroll=ScrollContainer.new()
	brand_fan_scroll.position=Vector2(37,508)
	brand_fan_scroll.size=Vector2(310,193)
	brand_fan_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	hand.add_child(brand_fan_scroll)
	brand_fan=Control.new()
	brand_fan.custom_minimum_size=Vector2(maxi(310,125+session.world.brand_cards.size()*59),188)
	brand_fan_scroll.add_child(brand_fan)
	if session.world.brand_cards.is_empty():
		label_at(hand,"보유 낙인 없음",Vector2(70,604),Vector2(247,33),15)
	for i in range(session.world.brand_cards.size()):
		var item: Dictionary=session.world.brand_cards[i]
		var id: String=str(item.id)
		var option=card(brand_fan,"brand",item,Vector2(9+i*59,22),Vector2(107,151),func(): select_brand_card(id))
		option.rotation_degrees=clampf((i%5-2)*5.5,-14,14)
		option.set_meta("fan_y",option.position.y)
		option.set_meta("fan_rotation",option.rotation_degrees)
		CardDepthMotion.install(option)
		for child in option.get_children():
			if child is Label: child.visible=false
		brand_options[id]=option
	render_selection()
	# Rise-in motion matching the source card hand's entrance.
	hand.position.y=48
	hand.modulate.a=0.0
	var rise=create_tween().set_parallel(true)
	rise.tween_property(hand,"position:y",0.0,0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(hand,"modulate:a",1.0,0.24)

func select_unit(id: String) -> void:
	if completed or busy: return
	notice = ""
	var unit = session.owned_unit(id)
	if unit.is_empty(): return
	if not brand_card_id.is_empty():
		if id==receiver_id: receiver_id = ""
		elif unit.brands.size()>=3: notice = "낙인 3칸이 찬 마물에는 적용할 수 없습니다."
		else: receiver_id = id
	elif id==material_id:
		material_id = ""
		receiver_id = ""
	elif id==receiver_id: receiver_id = ""
	elif material_id.is_empty(): material_id = id
	elif unit.brands.size()>=3: notice = "낙인 3칸이 찬 마물은 받는 마물이 될 수 없습니다."
	else: receiver_id = id
	render_selection()

func select_brand_card(id: String) -> void:
	if completed or busy: return
	notice = ""
	brand_card_id = "" if brand_card_id==id else id
	material_id = ""
	receiver_id = ""
	render_selection()

func confirm() -> void:
	if busy or completed or confirm_button.disabled: return
	busy = true
	render_selection()
	var result = session.inherit_at_home(receiver_id,material_id,brand_card_id)
	busy = false
	if not result.ok:
		notice = result.reason
		render_selection()
		return
	completed = true
	notice = ""
	material_id = ""
	brand_card_id = ""
	render_hand()
	var flash = create_tween()
	receiver_art.modulate = Color(1.3,1.15,0.85)
	flash.tween_property(receiver_art,"modulate",Color.WHITE,0.28)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not busy:
		get_viewport().set_input_as_handled()
		closed.emit()
