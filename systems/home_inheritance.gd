extends "res://systems/reward_ui.gd"
signal closed
const BrandInheritance = preload("res://systems/brand_inheritance.gd")
const BrandCompletionSeal = preload("res://systems/brand_completion_seal.gd")
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
var tab = "unit"
var interface_data: Dictionary

func setup(run_session) -> void:
	session = run_session
	z_index = 85
	interface_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/interface.json"))
	backdrop()
	label_at(self,"낙인 계승",Vector2(450,20),Vector2(380,36),24)
	button(self,"닫기",Vector2(1105,26),Vector2(100,36),func(): if not busy: closed.emit())
	panel_slot(Vector2(212,66),true)
	panel_slot(Vector2(840,66),false)
	art(self,"res://assets/map/ui/inheritance_info.webp",Vector2(476,90),Vector2(328,286)).stretch_mode = TextureRect.STRETCH_SCALE
	var title = label_at(self,"낙인 · 최대 3칸",Vector2(503,107),Vector2(274,28),18)
	title.add_theme_color_override("font_color",Color("34251c"))
	title.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(502,143)
	scroll.size = Vector2(276,194)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",5)
	scroll.add_child(details)
	status = label_at(self,"",Vector2(206,384),Vector2(868,34),14)
	confirm_button = button(self,"계승",Vector2(529,423),Vector2(222,42),confirm)
	confirm_button.add_theme_font_size_override("font_size",16)
	button(self,"마물",Vector2(431,480),Vector2(180,32),func(): tab="unit"; render_hand())
	button(self,"낙인 카드",Vector2(629,480),Vector2(220,32),func(): tab="brand"; render_hand())
	render_hand()
	render_selection()

func panel_slot(pos: Vector2, material: bool) -> void:
	var node = Control.new()
	node.position = pos
	node.size = Vector2(228,310)
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
	label_at(node,"재료" if material else "받는 마물",Vector2(12,20),Vector2(204,28),19)
	var preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.position = Vector2(39,58)
	preview.size = Vector2(150,208)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(preview)
	var hint = label_at(node,"",Vector2(15,269),Vector2(198,28),13)
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
	BrandCompletionSeal.sync(node,item if kind=="unit" else {})

func detail(value: String, color: Color = Color("34251c")) -> void:
	var line = Label.new()
	line.text = value
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size",13)
	line.add_theme_color_override("font_color",color)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(line)

func append_brands(brands: Array, origin: String) -> void:
	for brand in brands:
		var name = str(interface_data.brands[brand.type].name).replace("의 낙인","")
		detail("%s · %s" % [origin,name])
		detail("축복 [%s] · 저주 [%s]" % [", ".join(brand.bless.map(func(n): return str(int(n)))),", ".join(brand.curse.map(func(n): return str(int(n))))],Color("5b3526"))

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
	if not receiver.is_empty():
		detail("받는 마물 · %d / 3칸" % receiver.brands.size())
		append_brands(BrandInheritance.normalize(receiver,session.world.definitions),"결과" if completed else "기존")
	if not material.is_empty(): append_brands(BrandInheritance.normalize(material,session.world.definitions),"재료")
	if not source_card.is_empty(): append_brands([source_card.brand],"카드")
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
		brand_options[id].modulate = Color(1.1,1.12,1.15) if id==brand_card_id else Color.WHITE
		brand_options[id].disabled = busy or completed

func render_hand() -> void:
	if is_instance_valid(hand):
		remove_child(hand)
		hand.queue_free()
	unit_options.clear()
	brand_options.clear()
	hand = Control.new()
	add_child(hand)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(124,526)
	scroll.size = Vector2(1032,190)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand.add_child(scroll)
	var row = HBoxContainer.new()
	row.custom_minimum_size.x = 1032
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",16)
	scroll.add_child(row)
	var items: Array = session.world.roster if tab=="unit" else session.world.brand_cards
	if items.is_empty(): label_at(hand,"보유한 마물이 없습니다" if tab=="unit" else "보유한 낙인 카드가 없습니다",Vector2(260,590),Vector2(760,40),18)
	for item in items:
		var box = Control.new()
		box.custom_minimum_size = Vector2(104,182)
		row.add_child(box)
		var id = str(item.id)
		var kind = tab
		var option = card(box,kind,item,Vector2(4,0),Vector2(96,139),func(): select_unit(id) if kind=="unit" else select_brand_card(id))
		option.get_child(0).add_theme_font_size_override("font_size",12)
		if tab=="unit": unit_options[id] = option
		else: brand_options[id] = option
	render_selection()

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
