extends "res://systems/reward_ui.gd"
const CardDepthMotion = preload("res://systems/card_depth_motion.gd")
const PanelDepthMotion = preload("res://systems/panel_depth_motion.gd")
signal closed
const BrandInheritance = preload("res://systems/brand_inheritance.gd")
var session
var closing_depth := false
var depth_panels: Array[Control] = []
var material_id = ""
var receiver_id = ""
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
var unit_hand_scroll: ScrollContainer
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
	button(self,"닫기",Vector2(1129,29),Vector2(92,38),func(): if not busy: close_depth())
	# Web prototype shows three adjacent columns and two simultaneous card sources.
	panel_slot(Vector2(198,38),true)
	panel_slot(Vector2(814,38),false)
	inheritance_frame=art(self,"res://assets/map/ui/inheritance_info.webp",Vector2(471,62),Vector2(338,352))
	inheritance_frame.stretch_mode=TextureRect.STRETCH_SCALE
	PanelDepthMotion.shadow(inheritance_frame)
	PanelDepthMotion.enter(inheritance_frame)
	depth_panels.append(inheritance_frame)
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
	PanelDepthMotion.shadow(node)
	PanelDepthMotion.enter(node)
	depth_panels.append(node)
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
	set_preview(material_art,"unit",material)
	set_preview(receiver_art,"unit",receiver)
	material_marks.text = ""
	material_hint.text = "소모 완료" if completed else str(material.get("name","아래에서 재료 선택"))
	receiver_hint.text = str(receiver.get("name","받는 마물 선택"))
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
	if not material.is_empty(): append_brands(BrandInheritance.normalize(material,session.world.definitions),"재료",false)
	if not receiver.is_empty():
		detail("받는 마물 · %d / 3칸" % receiver.brands.size())
		append_brands(BrandInheritance.normalize(receiver,session.world.definitions),"결과" if completed else "기존")
	if receiver.is_empty() and material.is_empty(): detail("계승할 재료 마물과 받는 마물을 선택하세요.")
	if not notice.is_empty():
		status.text=notice
	elif completed:
		status.text="계승 완료 · 받는 마물의 능력치와 체력은 유지됩니다"
	elif material.is_empty():
		status.text="① 희생할 재료 마물 선택 → ② 받을 마물 선택"
	elif receiver.is_empty():
		status.text="② 축복을 받을 마물을 선택하세요 · 재료는 확정 시 영구 소모됩니다"
	else:
		status.text="③ 재료 마물 영구 소모 · 무작위 낙인 1개의 축복 계승"
	var eligible: bool = not receiver.is_empty() and receiver.brands.size()<3 and not material.is_empty() and not material.brands.is_empty() and material_id!=receiver_id
	confirm_button.disabled = busy or completed or not eligible or not session.home_action_allowed().ok
	confirm_button.text = "계승 완료" if completed else "마물 소모 · 계승 확정"
	for id in unit_options:
		var option: TextureButton = unit_options[id]
		option.modulate = Color(1.14,1.08,0.87) if id in [material_id,receiver_id] else Color.WHITE
		option.get_child(0).text = str(session.owned_unit(id).get("name",""))+("\n재료" if id==material_id else ("\n받는 마물" if id==receiver_id else ""))
		option.disabled = busy or completed

func render_hand() -> void:
	if is_instance_valid(hand):
		remove_child(hand)
		hand.queue_free()
	unit_options.clear()
	hand=Control.new()
	add_child(hand)
	# Monster cards are the only material source.
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
	if id==material_id:
		material_id = ""
		receiver_id = ""
	elif id==receiver_id: receiver_id = ""
	elif material_id.is_empty(): material_id = id
	elif unit.brands.size()>=3: notice = "낙인 3칸이 찬 마물은 받는 마물이 될 수 없습니다."
	else: receiver_id = id
	render_selection()

func confirm() -> void:
	if busy or completed or confirm_button.disabled: return
	busy = true
	render_selection()
	var result = session.inherit_at_home(receiver_id,material_id)
	busy = false
	if not result.ok:
		notice = result.reason
		render_selection()
		return
	completed = true
	notice = ""
	material_id = ""
	render_hand()
	var flash = create_tween()
	receiver_art.modulate = Color(1.3,1.15,0.85)
	flash.tween_property(receiver_art,"modulate",Color.WHITE,0.28)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not busy:
		get_viewport().set_input_as_handled()
		close_depth()

func close_depth() -> void:
	if busy or closing_depth: return
	closing_depth = true
	for panel in depth_panels:
		if is_instance_valid(panel): PanelDepthMotion.exit(panel, Callable())
	get_tree().create_timer(0.14).timeout.connect(func():
		if is_instance_valid(self): closed.emit())
