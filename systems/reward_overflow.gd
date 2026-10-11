extends "res://systems/reward_ui.gd"
signal resolved(outcome: Dictionary)
var session
var selected: String = ""
var status: Label
var confirm: Button
var choices: Dictionary = {}
var choice_cards: Array = []
var is_capture_overflow: bool = false
var title_label: Label
var card_scroll: ScrollContainer

func setup(run_session) -> void:
	session = run_session
	is_capture_overflow = str(session.world.pending_reward.get("kind",""))=="capture"
	z_index = 250
	backdrop()
	# The frozen web source uses a centered 760px panel over a darkened map.
	var shade := get_child(0) as ColorRect
	if shade != null:
		shade.color = Color("050302c7")
	var background = Panel.new()
	background.name = "RewardOverflowPanel"
	background.position = Vector2(80,180) if is_capture_overflow else Vector2(260,112)
	background.size = Vector2(1120,360) if is_capture_overflow else Vector2(760,496)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	# Capture is a separate wide eleven-card parchment in the frozen battle UI.
	# Its original source JPEG is not a valid import here, so keep a native parchment fallback.
	style.bg_color = Color("c9aa94") if is_capture_overflow else Color("241a12f7")
	style.border_color = Color("7c5e43") if is_capture_overflow else Color("806447")
	style.set_border_width_all(4 if is_capture_overflow else 2)
	style.set_corner_radius_all(3 if is_capture_overflow else 8)
	style.shadow_color = Color(0,0,0,0.82)
	style.shadow_size = 20
	background.add_theme_stylebox_override("panel",style)
	add_child(background)

	var reward: Dictionary = session.world.pending_reward.reward
	var items: Array = session.world.roster if reward.kind=="unit" else session.world.dice_cards
	var capacity: int = Catalog.UNIT_CAPACITY if reward.kind=="unit" else Catalog.DICE_CAPACITY
	title_label = label_at(self,("마물 보관함 %d/%d" if reward.kind=="unit" else "주사위 카드더미 %d/%d") % [items.size(),capacity],Vector2(150,217) if is_capture_overflow else Vector2(300,142),Vector2(980,36) if is_capture_overflow else Vector2(680,36),24)
	title_label.name = "OverflowTitle"
	if is_capture_overflow: title_label.add_theme_color_override("font_color",Color("3a281c"))
	status = label_at(self,"새 마물을 받으려면 버릴 마물 카드 1장을 선택하세요." if is_capture_overflow else "새 보상을 받으려면 버릴 카드 1장을 선택하세요.",Vector2(150,261) if is_capture_overflow else Vector2(300,188),Vector2(980,30) if is_capture_overflow else Vector2(680,35),13)
	status.name = "OverflowStatus"
	status.add_theme_color_override("font_color",Color("5f4733") if is_capture_overflow else Color("cfb88e"))

	var row = scroll_row(Vector2(155,305) if is_capture_overflow else Vector2(295,244),Vector2(970,172) if is_capture_overflow else Vector2(690,260))
	row.add_theme_constant_override("separation",3 if is_capture_overflow else 8)
	card_scroll = row.get_parent() as ScrollContainer
	card_scroll.name = "OverflowCardScroll"
	card_scroll.follow_focus = true
	var candidates: Array = items.duplicate(true)
	candidates.append(reward.item)
	for index in range(candidates.size()):
		var item: Dictionary = candidates[index]
		var key: String = "__new__" if index==candidates.size()-1 else str(item.id)
		var box = Control.new()
		box.name = "OverflowCandidate_%d" % index
		box.custom_minimum_size = Vector2(85,162) if is_capture_overflow else Vector2(110,230)
		row.add_child(box)
		var option = card(box,reward.kind,item,Vector2(2,7) if is_capture_overflow else Vector2(5,16),Vector2(81,118) if is_capture_overflow else Vector2(100,146),func(): select_card(key))
		option.name = "OverflowCard_%d" % index
		option.focus_mode = Control.FOCUS_ALL
		# The original leaves unselected candidates fully colored and lifts only the chosen card.
		var outline = Panel.new()
		outline.name = "OverflowSelectedOutline"
		outline.size = option.size
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.z_index = 5
		var glow = StyleBoxFlat.new()
		glow.draw_center = false
		glow.border_color = Color("ffe291")
		glow.set_border_width_all(2)
		glow.set_corner_radius_all(3)
		glow.shadow_color = Color("ffe29188")
		glow.shadow_size = 9
		outline.add_theme_stylebox_override("panel",glow)
		outline.visible = false
		option.add_child(outline)
		var caption := option.get_child(0) as Label
		caption.position = Vector2(-4,123) if is_capture_overflow else Vector2(-10,154)
		caption.size = Vector2(89,32) if is_capture_overflow else Vector2(120,48)
		caption.add_theme_font_size_override("font_size",9 if is_capture_overflow else 10)
		if is_capture_overflow:
			caption.add_theme_color_override("font_color",Color("3a281c"))
			caption.autowrap_mode = TextServer.AUTOWRAP_OFF
			caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if key=="__new__":
			var badge = Panel.new()
			badge.name = "NewRewardBadge"
			badge.position = Vector2(46,0) if is_capture_overflow else Vector2(65,3)
			badge.size = Vector2(40,20) if is_capture_overflow else Vector2(42,23)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.z_index = 8
			var badge_style = StyleBoxFlat.new()
			badge_style.bg_color = Color("78311f")
			badge_style.set_corner_radius_all(8)
			badge.add_theme_stylebox_override("panel",badge_style)
			box.add_child(badge)
			var badge_text = label_at(badge,"신규",Vector2.ZERO,badge.size,10)
			badge_text.add_theme_color_override("font_color",Color("fff0cf"))
		choices[key] = option
		choice_cards.append(option)

	confirm = button(self,"선택한 카드 버리기",Vector2(490,486) if is_capture_overflow else Vector2(490,544),Vector2(300,40) if is_capture_overflow else Vector2(300,42),finish)
	confirm.name = "OverflowConfirm"
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color("704523") if is_capture_overflow else Color("3a2417")
	button_style.border_color = Color("aa8655")
	button_style.set_border_width_all(1)
	button_style.set_corner_radius_all(4)
	for state in ["normal","hover","focus","pressed","disabled"]:
		confirm.add_theme_stylebox_override(state,button_style)
	confirm.add_theme_color_override("font_color",Color("f7e5bf") if is_capture_overflow else Color("f4dfb7"))
	confirm.add_theme_color_override("font_disabled_color",Color("a28f72"))
	confirm.disabled = true
	confirm.modulate.a = 0.45

func select_card(key: String) -> void:
	if not choices.has(key): return
	selected = key
	for id in choices:
		var option: TextureButton = choices[id]
		var chosen: bool = id==key
		option.position.y = (0.0 if chosen else 7.0) if is_capture_overflow else (7.0 if chosen else 16.0)
		option.scale = Vector2(1.06,1.06) if chosen else Vector2.ONE
		option.z_index = 4 if chosen else 0
		option.modulate = Color.WHITE
		option.get_node("OverflowSelectedOutline").visible = chosen
	status.text = "%s 버리기 선택됨" % choices[key].tooltip_text
	confirm.disabled = false
	confirm.modulate.a = 1.0

func finish() -> void:
	if selected.is_empty() or confirm.disabled: return
	confirm.disabled = true
	confirm.modulate.a = 0.45
	var outcome: Dictionary = session.claim_reward(selected)
	if not outcome.get("ok",false):
		status.text = "저장 실패 · 다시 시도하세요"
		confirm.disabled = false
		confirm.modulate.a = 1.0
		return
	resolved.emit(outcome)
	queue_free()
