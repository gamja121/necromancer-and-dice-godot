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
var is_monster_swap: bool = false
var monster_grid: GridContainer
var selection_detail: Label
var decline_button: Button

func setup(run_session) -> void:
	session = run_session
	is_capture_overflow = str(session.world.pending_reward.get("kind",""))=="capture"
	z_index = 250
	backdrop()
	# Monsters use a dedicated legible two-row exchange layout; dice keep
	# their original shared overflow UI and persistence contract.
	var pending_reward: Dictionary = session.world.pending_reward.reward
	if str(pending_reward.get("kind", "")) == "unit":
		is_monster_swap = true
		setup_monster_swap(pending_reward)
		return
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
	# Keep the original immutable web parchment as a real Godot runtime texture.
	# Native panel colors remain as an asset-loading fallback.
	if is_capture_overflow:
		var source_art = load("res://assets/map/ui/capture-overflow-panel-bg.jpg")
		if source_art is Texture2D:
			var parchment = TextureRect.new()
			parchment.name = "CaptureOverflowBackgroundArt"
			parchment.texture = source_art
			parchment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			parchment.stretch_mode = TextureRect.STRETCH_SCALE
			parchment.size = background.size
			parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
			background.add_child(parchment)

	var reward: Dictionary = pending_reward
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

## A dedicated 10-owned / 1-new monster exchange. Only the layout changes:
## the existing claim_reward(discard_id) transaction still commits on confirmation.
func exchange_panel(name: String, pos: Vector2, dimensions: Vector2, fill: Color, edge: Color) -> Panel:
	var panel := Panel.new()
	panel.name = name
	panel.position = pos
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	return panel

func exchange_button_style(action: Button, destructive: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("5c2c25") if destructive else Color("72502e")
	style.border_color = Color("d1aa75")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	for state in ["normal","hover","pressed","focus","disabled"]:
		action.add_theme_stylebox_override(state,style)
	action.add_theme_color_override("font_color",Color("ffe9c1"))
	action.add_theme_color_override("font_disabled_color",Color("a99880"))
	action.add_theme_font_size_override("font_size",17)

func exchange_outline(option: TextureButton) -> void:
	var outline := Panel.new()
	outline.name = "OverflowSelectedOutline"
	outline.size = option.size
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.z_index = 5
	var glow := StyleBoxFlat.new()
	glow.draw_center = false
	glow.border_color = Color("e9a26c")
	glow.set_border_width_all(3)
	glow.set_corner_radius_all(5)
	glow.shadow_color = Color("e88c5288")
	glow.shadow_size = 8
	outline.add_theme_stylebox_override("panel",glow)
	outline.visible = false
	option.add_child(outline)

func exchange_summary(unit: Dictionary) -> String:
	var brands: Array = unit.get("brands",[])
	return "%s · 체력 %d/%d · 낙인 %d개" % [
		str(unit.get("name","마물")),
		int(unit.get("current_hp",0)),
		int(unit.get("max_hp",0)),
		brands.size()
	]

func setup_monster_swap(reward: Dictionary) -> void:
	var shade := get_child(0) as ColorRect
	if shade != null:
		shade.color = Color("070403e6")
	var items: Array = session.world.roster
	var capacity: int = Catalog.UNIT_CAPACITY
	# All measurements use the existing 1280x720 Godot canvas.
	exchange_panel("RewardOverflowPanel",Vector2(48,25),Vector2(1184,675),Color("241910f5"),Color("b89a71"))
	exchange_panel("NewMonsterSection",Vector2(80,169),Vector2(316,438),Color("32251c"),Color("a78558"))
	exchange_panel("OwnedMonsterSection",Vector2(415,169),Vector2(785,438),Color("2a2119"),Color("806447"))
	title_label = label_at(self,"마물 보관함 %d/%d · 동료 교체" % [items.size(),capacity],Vector2(95,54),Vector2(1090,45),28)
	title_label.name = "OverflowTitle"
	title_label.add_theme_color_override("font_color",Color("f4d7a0"))
	status = label_at(self,"새로운 마물을 얻었습니다. 보유 마물 한 명을 내보내거나, 새 마물을 포기하세요.",Vector2(105,111),Vector2(1070,31),17)
	status.name = "OverflowStatus"
	status.add_theme_color_override("font_color",Color("d2b99a"))

	var fresh_title := label_at(self,"새로 얻은 마물",Vector2(104,187),Vector2(270,32),19)
	fresh_title.add_theme_color_override("font_color",Color("ffdf9b"))
	var old_title := label_at(self,"보유 마물 10장 · 교체할 마물 선택",Vector2(432,187),Vector2(745,31),19)
	old_title.add_theme_color_override("font_color",Color("e8d2b4"))
	var fresh: Dictionary = reward.item
	var new_card := card(self,"unit",fresh,Vector2(147,231),Vector2(180,283),Callable())
	new_card.name = "OverflowNewMonster"
	new_card.focus_mode = Control.FOCUS_NONE
	if LayeredUnitCard.supports(str(fresh.get("slug",""))):
		new_card.get_child(0).hide()
	exchange_outline(new_card)
	choices["__new__"] = new_card
	choice_cards.append(new_card)

	var fresh_badge := Panel.new()
	fresh_badge.name = "NewRewardBadge"
	fresh_badge.position = Vector2(293,222)
	fresh_badge.size = Vector2(70,28)
	fresh_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("783b23")
	badge_style.border_color = Color("e8b47b")
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(6)
	fresh_badge.add_theme_stylebox_override("panel",badge_style)
	add_child(fresh_badge)
	label_at(fresh_badge,"신규",Vector2.ZERO,fresh_badge.size,14)
	var new_info := label_at(self,exchange_summary(fresh),Vector2(94,527),Vector2(294,57),13)
	new_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_info.add_theme_color_override("font_color",Color("edcea4"))

	monster_grid = GridContainer.new()
	monster_grid.name = "OverflowMonsterGrid"
	monster_grid.columns = 5
	monster_grid.position = Vector2(437,228)
	monster_grid.add_theme_constant_override("h_separation",8)
	monster_grid.add_theme_constant_override("v_separation",6)
	add_child(monster_grid)
	for index in range(items.size()):
		var old: Dictionary = items[index]
		var key: String = str(old.id)
		var slot := Control.new()
		slot.name = "OverflowCandidate_%d" % index
		slot.custom_minimum_size = Vector2(138,174)
		monster_grid.add_child(slot)
		var option := card(slot,"unit",old,Vector2(11,3),Vector2(116,166),func(): select_card(key))
		option.name = "OverflowCard_%d" % index
		option.focus_mode = Control.FOCUS_ALL
		if LayeredUnitCard.supports(str(old.get("slug",""))):
			option.get_child(0).hide()
		exchange_outline(option)
		choices[key] = option
		choice_cards.append(option)

	decline_button = button(self,"새 마물 포기",Vector2(93,631),Vector2(245,47),func(): select_card("__new__"))
	decline_button.name = "OverflowDeclineNew"
	exchange_button_style(decline_button,true)
	selection_detail = label_at(self,"보유 마물 중 교체 대상을 선택하세요.",Vector2(354,628),Vector2(548,53),14)
	selection_detail.name = "OverflowSelectionDetail"
	selection_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_detail.add_theme_color_override("font_color",Color("e7cfaf"))
	confirm = button(self,"교체 대상 선택 필요",Vector2(917,631),Vector2(278,47),finish)
	confirm.name = "OverflowConfirm"
	exchange_button_style(confirm,false)
	confirm.disabled = true
	confirm.modulate.a = 0.45

func select_monster_for_exchange(key: String) -> void:
	for id in choices:
		var option: TextureButton = choices[id]
		var chosen: bool = id == key and key != "__new__"
		option.scale = Vector2(1.025,1.025) if chosen else Vector2.ONE
		option.z_index = 4 if chosen else 0
		option.get_node("OverflowSelectedOutline").visible = chosen
	if key == "__new__":
		status.text = "새로운 마물을 포기하고 현재 보유 마물 10명을 유지합니다."
		selection_detail.text = "신규 보상 포기 선택됨 · 아래에서 확정해야 적용됩니다."
		confirm.text = "새 마물 포기 확정"
	else:
		var old: Dictionary = {}
		for unit in session.world.roster:
			if str(unit.id) == key:
				old = unit
				break
		status.text = "내보낼 마물을 선택했습니다. 보상 확정 시 이 마물은 영구적으로 제외됩니다."
		selection_detail.text = exchange_summary(old) + "\n선택한 마물을 내보내고 신규 마물을 받습니다."
		confirm.text = "교체하고 획득"
	confirm.disabled = false
	confirm.modulate.a = 1.0

func select_card(key: String) -> void:
	if not choices.has(key): return
	selected = key
	if is_monster_swap:
		select_monster_for_exchange(key)
		return
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
