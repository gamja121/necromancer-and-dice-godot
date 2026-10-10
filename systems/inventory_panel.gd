extends "res://systems/reward_ui.gd"
signal closed
const UnitInfo = preload("res://systems/unit_info.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const FanMotion = preload("res://systems/card_fan_motion.gd")
const BrandFrameOverlay = preload("res://systems/brand_frame_overlay.gd")
var session
var content: Control
var fan
var origin_global: Vector2
var changing = false
var closing = false
var tab_buttons: Array = []
var info: Control

func setup(run_session, initial: String = "unit", book_origin: Vector2 = Vector2(130,616)) -> void:
	session = run_session
	origin_global = book_origin
	z_index = 80
	backdrop()
	label_at(self,"보유 카드",Vector2(300,95),Vector2(680,42),25)
	for entry in [["unit","마물"],["dice","주사위 카드"],["brand","낙인 카드"]]:
		var key: String = entry[0]
		var index: int = ["unit","dice","brand"].find(key)
		tab_buttons.append(button(self,entry[1],Vector2(355+index*195,155),Vector2(180,38),func(): show_kind(key)))
	button(self,"닫기",Vector2(550,590),Vector2(180,42),func(): closed.emit())
	show_kind(initial)

func show_kind(kind: String) -> void:
	if changing or closing: return
	changing = true
	for tab in tab_buttons: tab.disabled = true
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Control.new()
	add_child(content)
	fan = FanMotion.new()
	content.add_child(fan)
	var items: Array = session.world.roster if kind=="unit" else (session.world.dice_cards if kind=="dice" else session.world.brand_cards)
	if items.is_empty(): label_at(content,"보유한 카드가 없습니다",Vector2(300,335),Vector2(680,40),18)
	var row: HBoxContainer
	if items.size()>10:
		row = scroll_row(Vector2(135,225),Vector2(1010,330))
		row.get_parent().reparent(content)
	var half = (items.size()-1)*0.5
	var step = minf(156,880.0/maxi(1,items.size()-1))
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var parent: Control = content
		var pos = Vector2(572+(i-half)*step,240+absf(i-half)*3.5)
		if row != null:
			parent = Control.new()
			parent.custom_minimum_size = Vector2(152,300)
			row.add_child(parent)
			pos = Vector2(8,12)
		var option = card(parent,kind,item,pos,Vector2(136,218),func(): show_item(kind,item))
		option.rotation_degrees = clampf((i-half)*1.6,-5,5)
		if kind=="unit":
			option.get_child(0).text += "\n체력 %d/%d" % [item.current_hp,item.max_hp]
			BrandFrameOverlay.sync(option,item)
		if items.size()>6:
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
