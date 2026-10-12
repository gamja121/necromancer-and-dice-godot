extends "res://systems/reward_ui.gd"
signal closed
## Purely visual inventory hand; owned units and persistence stay in RunSession.
const HAND_TOP = 512.0
const HAND_CARD_SIZE = Vector2(136,218)
const HAND_SPACING = 90.0
const HAND_BOOK_OFFSET = Vector2(24.0,-105.0)
const HAND_SCROLL_WIDTH = 944.0
const HAND_SCROLL_THRESHOLD = 10
const UnitInfo = preload("res://systems/unit_info.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const FanMotion = preload("res://systems/card_fan_motion.gd")
var session
var content: Control
var fan
var origin_global: Vector2
var changing = false
var closing = false
var tab_buttons: Array = []
var info: Control
var backdrop_shade: ColorRect
var title_label: Label
var close_button: Button

func setup(run_session, initial: String = "unit", book_origin: Vector2 = Vector2(130,616)) -> void:
	session = run_session
	origin_global = book_origin
	z_index = 80
	backdrop()
	backdrop_shade = get_child(0) as ColorRect
	backdrop_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the map readable behind the book hand, while catching board inputs.
	var outside = Button.new()
	outside.name = "InventoryOutsideClose"
	outside.flat = true
	outside.size = size
	outside.tooltip_text = "카드창 바깥을 눌러 닫기"
	outside.set_meta("ui_backdrop",true)
	outside.pressed.connect(func():
		if not changing and not closing: closed.emit())
	add_child(outside)
	title_label = label_at(self,"보유 카드",Vector2(300,95),Vector2(680,42),25)
	for entry in [["unit","마물"],["dice","주사위 카드"],["brand","낙인 카드"]]:
		var key: String = entry[0]
		var index: int = ["unit","dice","brand"].find(key)
		tab_buttons.append(button(self,entry[1],Vector2(355+index*195,155),Vector2(180,38),func(): show_kind(key)))
	close_button = button(self,"닫기",Vector2(550,590),Vector2(180,42),func(): closed.emit())
	show_kind(initial)

func layout_shell(kind: String) -> void:
	var hand = kind=="unit"
	backdrop_shade.color = Color.TRANSPARENT if hand else Color("030201d9")
	title_label.visible = not hand
	for index in range(tab_buttons.size()):
		var tab: Button = tab_buttons[index]
		tab.position = Vector2(780+index*108,480) if hand else Vector2(355+index*195,155)
		tab.size = Vector2(102,34) if hand else Vector2(180,38)
		tab.text = ["마물","주사위","낙인"][index] if hand else ["마물","주사위 카드","낙인 카드"][index]
	close_button.position = Vector2(1112,480) if hand else Vector2(550,590)
	close_button.size = Vector2(86,34) if hand else Vector2(180,42)

func roster_hand_start() -> Vector2:
	# Map passes the clicked book's actual canvas position. Convert it to this
	# overlay, then lay out from its right page instead of the board's center.
	# The cards deliberately tuck a few pixels below the board edge.
	var book_local: Vector2 = get_global_transform_with_canvas().affine_inverse()*origin_global
	return Vector2(
		clampf(book_local.x+HAND_BOOK_OFFSET.x,0.0,size.x-HAND_CARD_SIZE.x),
		clampf(book_local.y+HAND_BOOK_OFFSET.y,0.0,size.y-HAND_CARD_SIZE.y+12.0)
	)

func focus_hand_card(option: TextureButton, home: Vector2, focused: bool) -> void:
	if closing or not is_instance_valid(option): return
	option.z_index = 20 if focused else 0
	option.position = home+Vector2(0,-26 if focused else 0)

func show_kind(kind: String) -> void:
	if changing or closing: return
	changing = true
	for tab in tab_buttons: tab.disabled = true
	layout_shell(kind)
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Control.new()
	add_child(content)
	fan = FanMotion.new()
	content.add_child(fan)
	var items: Array = session.world.roster if kind=="unit" else (session.world.dice_cards if kind=="dice" else session.world.brand_cards)
	if items.is_empty():
		label_at(content,"보유한 마물이 없습니다" if kind=="unit" else "보유한 카드가 없습니다",
			Vector2(385,568) if kind=="unit" else Vector2(300,335),
			Vector2(510,40) if kind=="unit" else Vector2(680,40),18)
	var holder: Control = content
	var hand_start: Vector2 = roster_hand_start() if kind=="unit" else Vector2.ZERO
	if kind=="unit" and items.size()>HAND_SCROLL_THRESHOLD:
		# Never shrink a large roster into illegible cards. Scroll an overlapping hand.
		var scroll = ScrollContainer.new()
		scroll.name = "RosterHandScroll"
		scroll.position = hand_start
		scroll.size = Vector2(minf(HAND_SCROLL_WIDTH,size.x-hand_start.x),maxf(1.0,size.y-hand_start.y))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(scroll)
		holder = Control.new()
		holder.custom_minimum_size = Vector2((items.size()-1)*HAND_SPACING+HAND_CARD_SIZE.x,235)
		scroll.add_child(holder)
	elif kind!="unit" and items.size()>10:
		var row = scroll_row(Vector2(135,225),Vector2(1010,330))
		row.get_parent().reparent(content)
		holder = row
	var half = (items.size()-1)*0.5
	var step = minf(156,880.0/maxi(1,items.size()-1))
	# The owned-monster hand always grows RIGHT from the left book, even
	# when it holds just one or two cards. Never recenter based on count.
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var parent: Control = content
		var pos = Vector2(572+(i-half)*step,240+absf(i-half)*3.5)
		if kind=="unit":
			parent = holder
			pos = Vector2(i*HAND_SPACING,0.0) if holder!=content else hand_start+Vector2(i*HAND_SPACING,-minf(float(i),5.0)*2.0)
		elif holder is HBoxContainer:
			parent = Control.new()
			parent.custom_minimum_size = Vector2(152,300)
			holder.add_child(parent)
			pos = Vector2(8,12)
		var option = card(parent,kind,item,pos,HAND_CARD_SIZE,func(): show_item(kind,item))
		option.rotation_degrees = (3.0-7.0*float(i)/float(maxi(items.size()-1,1))) if kind=="unit" else clampf((i-half)*1.6,-5,5)
		if kind=="unit":
			option.get_child(0).text += "\n체력 %d/%d" % [item.current_hp,item.max_hp]
			option.get_child(0).visible = false
			option.tooltip_text += "\n체력 %d/%d" % [item.current_hp,item.max_hp]
			var home: Vector2 = pos
			option.mouse_entered.connect(func(): focus_hand_card(option,home,true))
			option.mouse_exited.connect(func(): focus_hand_card(option,home,false))
			option.focus_entered.connect(func(): focus_hand_card(option,home,true))
			option.focus_exited.connect(func(): focus_hand_card(option,home,false))
		elif items.size()>6:
			option.get_child(0).visible = false
			option.mouse_entered.connect(func(): option.get_child(0).visible = true; option.z_index = 20)
			option.mouse_exited.connect(func(): option.get_child(0).visible = false; option.z_index = 0)
			option.focus_entered.connect(func(): option.get_child(0).visible = true; option.z_index = 20)
			option.focus_exited.connect(func(): option.get_child(0).visible = false; option.z_index = 0)
		fan.register_card(option)
	await get_tree().process_frame
	if closing: return
	await fan.animate(true,origin_global)
	if closing: return
	changing = false
	for tab in tab_buttons: tab.disabled = false

func show_item(kind: String, item: Dictionary) -> void:
	if closing or changing or kind!="unit": return
	if is_instance_valid(info): return
	var rules = Rules.new(session.world.definitions,1)
	rules.start([item.duplicate(true)],[])
	rules.units[0].hp = item.current_hp
	info = UnitInfo.new()
	add_child(info)
	info.setup(rules.units[0],rules,session.world.prophecy)
	info.closed.connect(func(): info = null)

func close_cards() -> void:
	if closing: return
	closing = true
	if is_instance_valid(info):
		info.queue_free()
		info = null
	for tab in tab_buttons: tab.disabled = true
	if fan != null:
		fan.closing = true
		await fan.animate(false,origin_global)

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(info): return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not closing: closed.emit()
