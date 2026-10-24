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

## Approved minimal layout (2026-10-24):
## no header, one large new monster, existing roster in a 5 x 2 grid,
## an understated arrow, and two explicit decisions.
## Real layered portraits, portrait foot baselines, brands and reward saving
## are all handled by the existing shared card / claim_reward paths.
func exchange_button_style(action: Button, destructive: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("572b26") if destructive else Color("324a37")
	style.border_color = Color("b3946a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color("140c09a0")
	style.shadow_size = 3
	for state in ["normal","hover","pressed","focus","disabled"]:
		action.add_theme_stylebox_override(state,style)
	action.add_theme_color_override("font_color",Color("f5e1bf"))
	action.add_theme_color_override("font_disabled_color",Color("9a8a71"))
	action.add_theme_font_size_override("font_size",20)
	var effect := action.get_node_or_null("ButtonEffectsModule")
	if effect != null:
		effect.hover_scale = Vector2(1.015,1.015)
		effect.hover_rotation_degrees = 0.0

func exchange_outline(option: TextureButton) -> void:
	var outline := Panel.new()
	outline.name = "OverflowSelectedOutline"
	outline.size = option.size
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.z_index = 5
	var rim := StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = Color("e8b56b")
	rim.set_border_width_all(3)
	rim.set_corner_radius_all(3)
	rim.shadow_color = Color("d89d4e70")
	rim.shadow_size = 4
	outline.add_theme_stylebox_override("panel",rim)
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
		shade.color = Color("140e0aaf")
	var items: Array = session.world.roster
	# Reuse the actual dark-wood and parchment pieces from home/inheritance.
	# Nine-patch margins preserve the original painted corner ornamentation.
	var frame := NinePatchRect.new()
	frame.name = "RewardOverflowPanel"
	frame.texture = load("res://assets/map/ui/inheritance_roster_frame.webp")
	frame.patch_margin_left = 40
	frame.patch_margin_right = 40
	frame.patch_margin_top = 34
	frame.patch_margin_bottom = 34
	frame.position = Vector2(69,105)
	frame.size = Vector2(1142,528)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var fresh_paper := art(self,"res://assets/map/ui/inheritance_info.webp",Vector2(110,155),Vector2(304,391))
	fresh_paper.name = "OverflowNewMonsterPaper"
	fresh_paper.stretch_mode = TextureRect.STRETCH_SCALE
	# No duplicate section titles: the larger, isolated card is the incoming one.
	var fresh: Dictionary = reward.item
	var new_card := card(self,"unit",fresh,Vector2(155,183),Vector2(214,343),Callable())
	new_card.name = "OverflowNewMonster"
	new_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_card.focus_mode = Control.FOCUS_NONE
	if LayeredUnitCard.supports(str(fresh.get("slug",""))):
		new_card.get_child(0).hide()
	choices["__new__"] = new_card
	choice_cards.append(new_card)

	var arrow := label_at(self,"➜",Vector2(419,327),Vector2(62,70),44)
	arrow.name = "OverflowExchangeArrow"
	arrow.add_theme_color_override("font_color",Color("c9ab7b"))
	arrow.add_theme_color_override("font_shadow_color",Color("24170e"))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	monster_grid = GridContainer.new()
	monster_grid.name = "OverflowMonsterGrid"
	monster_grid.columns = 5
	monster_grid.position = Vector2(487,151)
	monster_grid.add_theme_constant_override("h_separation",6)
	monster_grid.add_theme_constant_override("v_separation",11)
	add_child(monster_grid)
	for index in range(items.size()):
		var old: Dictionary = items[index]
		var key: String = str(old.id)
		var slot := Control.new()
		slot.name = "OverflowCandidate_%d" % index
		slot.custom_minimum_size = Vector2(134,183)
		monster_grid.add_child(slot)
		var option := card(slot,"unit",old,Vector2(11,4),Vector2(112,175),func(): select_card(key))
		option.name = "OverflowCard_%d" % index
		option.focus_mode = Control.FOCUS_ALL
		option.tooltip_text = exchange_summary(old) + "\n선택 시 신규 마물과 교체"
		if LayeredUnitCard.supports(str(old.get("slug",""))):
			option.get_child(0).hide()
		exchange_outline(option)
		choices[key] = option
		choice_cards.append(option)

	# These informational labels stay hidden until an actual choice/error.
	# Thus the normal state matches the uncluttered approved mockup.
	status = label_at(self,"",Vector2(300,539),Vector2(680,27),15)
	status.name = "OverflowStatus"
	status.add_theme_color_override("font_color",Color("e9c79f"))
	status.visible = false
	selection_detail = label_at(self,"",Vector2(260,539),Vector2(760,27),14)
	selection_detail.name = "OverflowSelectionDetail"
	selection_detail.add_theme_color_override("font_color",Color("ddc19b"))
	selection_detail.visible = false

	decline_button = button(self,"획득하지 않기",Vector2(262,572),Vector2(321,51),on_decline_new)
	decline_button.name = "OverflowDeclineNew"
	exchange_button_style(decline_button,true)
	confirm = button(self,"선택한 마물과 교체",Vector2(693,572),Vector2(352,51),finish)
	confirm.name = "OverflowConfirm"
	exchange_button_style(confirm,false)
	confirm.disabled = true
	confirm.modulate.a = 0.45

func on_decline_new() -> void:
	# The second tap commits the irreversible refusal; first tap only arms it.
	if selected == "__new__":
		finish()
	else:
		select_card("__new__")

func select_monster_for_exchange(key: String) -> void:
	for id in choices:
		var option: TextureButton = choices[id]
		var chosen: bool = id == key and key != "__new__"
		option.scale = Vector2(1.025,1.025) if chosen else Vector2.ONE
		option.z_index = 4 if chosen else 0
		var outline := option.get_node_or_null("OverflowSelectedOutline")
		if outline != null:
			outline.visible = chosen
	status.visible = false
	status.text = ""
	selection_detail.visible = true
	if key == "__new__":
		selection_detail.text = "새 마물 획득 포기 · 왼쪽 버튼을 다시 누르면 확정"
		decline_button.text = "포기 확정"
		confirm.disabled = true
		confirm.modulate.a = 0.45
	else:
		var old: Dictionary = {}
		for unit in session.world.roster:
			if str(unit.id) == key:
				old = unit
				break
		selection_detail.text = exchange_summary(old) + " · 영구 제외"
		decline_button.text = "획득하지 않기"
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
	if selected.is_empty(): return
	if is_monster_swap:
		if selected != "__new__" and confirm.disabled: return
		if selected == "__new__" and decline_button.disabled: return
		decline_button.disabled = true
		confirm.disabled = true
	else:
		if confirm.disabled: return
		confirm.disabled = true
		confirm.modulate.a = 0.45
	var outcome: Dictionary = session.claim_reward(selected)
	if not outcome.get("ok",false):
		status.text = "저장 실패 · 다시 선택해 주세요"
		status.visible = true
		if is_monster_swap:
			decline_button.disabled = false
			if selected != "__new__":
				confirm.disabled = false
				confirm.modulate.a = 1.0
		else:
			confirm.disabled = false
			confirm.modulate.a = 1.0
		return
	resolved.emit(outcome)
	queue_free()
