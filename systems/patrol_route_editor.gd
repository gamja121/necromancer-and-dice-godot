extends Control
## Localized presentation only. The host owns the draft and atomic session actions.
const BOARD_ART="res://assets/map/ui/patrol_planning_board_v1.png"
const Discovery=preload("res://systems/location_discoveries.gd")
const RoutePlan=preload("res://systems/route_plan.gd")
const State=preload("res://systems/map_state.gd")
const INK=Color("382719")
const MUTED=Color("715942")
var actions: Control
var title_label: Label
var subtitle_label: Label
var budget_label: Label
var status_label: Label
var back_button: Button
var reset_button: Button
var confirm_button: Button
var unlock_button: Button
var plus_buttons: Dictionary={}
var minus_buttons: Dictionary={}
var count_labels: Dictionary={}
var station_hints: Dictionary={}
var station_badges: Dictionary={}
var station_art: Dictionary={}
var summary_labels: Dictionary={}
var discovery_cells: Dictionary={}
var discovery_badges: Dictionary={}
var copy_controls: Array[Control]=[]
var body_scroll: ScrollContainer
var discovery_grid: GridContainer
var empty_discovery: Label
var _built: bool=false
var _body_font: Font
var _heading_font: Font

func setup(host: Control) -> void:
	actions=host
	name="PatrolRouteEditor"
	layout_direction=Control.LAYOUT_DIRECTION_APPLICATION_LOCALE
	position=Vector2(92,38)
	size=Vector2(1096,644)
	mouse_filter=Control.MOUSE_FILTER_STOP
	set_meta("ui_font_preserve",true)
	_prepare_fonts()
	_build()
	_built=true
	refresh()

func _prepare_fonts() -> void:
	var fallback:=SystemFont.new()
	fallback.font_names=PackedStringArray(["Noto Sans","Segoe UI","Arial"])
	var typography: Node=get_node_or_null("/root/UiTypography")
	if typography!=null and typography.body_font!=null:
		_body_font=typography.body_font.duplicate() as Font
		_body_font.fallbacks=[fallback]
	else: _body_font=fallback
	if typography!=null and typography.heading_font!=null:
		_heading_font=typography.heading_font.duplicate() as Font
		_heading_font.fallbacks=[fallback]
	else: _heading_font=fallback

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSLATION_CHANGED and _built: refresh.call_deferred()

func _copy(label: Label, source: String, values: Dictionary={}) -> void:
	label.set_meta("patrol_source",source)
	label.set_meta("patrol_values",values)
	label.text="" if source.is_empty() else tr(source).format(values)

func _label(parent: Node, node_name: String, source: String, points: int=18, role: String="body", centered: bool=false) -> Label:
	var label:=Label.new()
	label.name=node_name
	label.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.set_meta("ui_font_role",role)
	label.add_theme_font_override("font",_heading_font if role=="heading" else _body_font)
	label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",INK)
	label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	parent.add_child(label)
	copy_controls.append(label)
	_copy(label,source)
	return label

func _button(parent: Node, node_name: String, source: String, primary: bool=false, compact: bool=false) -> Button:
	var button:=Button.new()
	button.name=node_name
	button.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.text=tr(source)
	button.accessibility_name=button.text
	button.custom_minimum_size=Vector2(42,42) if compact else Vector2(138,48)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL if primary else Control.SIZE_FILL
	button.focus_mode=Control.FOCUS_ALL
	button.mouse_filter=Control.MOUSE_FILTER_STOP
	button.set_meta("patrol_source",source)
	button.set_meta("ui_font_role","body")
	button.add_theme_font_override("font",_body_font)
	button.add_theme_font_size_override("font_size",24 if compact else 18)
	var palette: Dictionary={"normal":Color("684a30") if compact else (Color("d5b477") if primary else Color("e6d4af")),"hover":Color("87633f") if compact else Color("f0deb9"),"pressed":Color("4b3526") if compact else Color("c4a574"),"disabled":Color("9b917c") if compact else Color("c6bca6")}
	for state in palette:
		var style:=StyleBoxFlat.new()
		style.bg_color=palette[state]
		style.border_color=Color("815f35") if state!="disabled" else Color("a2967c")
		style.set_border_width_all(2 if primary or compact else 1)
		style.set_corner_radius_all(3)
		style.shadow_color=Color(0.14,0.08,0.03,0.18)
		style.shadow_size=2 if state!="pressed" else 0
		for side in [SIDE_LEFT,SIDE_RIGHT]: style.set_content_margin(side,7)
		style.set_content_margin(SIDE_TOP,7)
		style.set_content_margin(SIDE_BOTTOM,7)
		button.add_theme_stylebox_override(state,style)
	var focus:=StyleBoxFlat.new()
	focus.draw_center=false
	focus.border_color=Color("e0b752")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(3)
	button.add_theme_stylebox_override("focus",focus)
	button.set_meta("patrol_compact",compact)
	parent.add_child(button)
	copy_controls.append(button)
	button.tooltip_text=tr(source)
	return button

func _button_state(button: Button, disabled: bool, tooltip: String="") -> void:
	button.disabled=disabled
	button.text=tr(str(button.get_meta("patrol_source","")))
	button.accessibility_name=button.text
	button.tooltip_text=tooltip if not tooltip.is_empty() else button.text
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,Color("f6e6c6") if bool(button.get_meta("patrol_compact",false)) else INK)
	button.add_theme_color_override("font_disabled_color",Color("887c66"))

func _image(parent: Node, node_name: String, path: String, dimensions: Vector2) -> TextureRect:
	var image:=TextureRect.new()
	image.name=node_name
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size=dimensions
	image.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	image.texture=load(path)
	parent.add_child(image)
	return image

func _rule(parent: Node, vertical: bool=false) -> Control:
	var rule: Control=VSeparator.new() if vertical else HSeparator.new()
	var style:=StyleBoxLine.new()
	style.color=Color("9d8055")
	style.thickness=1
	style.vertical=vertical
	rule.add_theme_stylebox_override("separator",style)
	parent.add_child(rule)
	return rule

func _build() -> void:
	var art:=TextureRect.new()
	art.name="PatrolPlanningBoardArt"
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_SCALE
	art.size=size
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BOARD_ART): art.texture=load(BOARD_ART)
	add_child(art)
	var margins:=MarginContainer.new()
	margins.name="SafeContent"
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["margin_left","margin_right"]: margins.add_theme_constant_override(key,48)
	margins.add_theme_constant_override("margin_top",50)
	margins.add_theme_constant_override("margin_bottom",28)
	add_child(margins)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",9)
	margins.add_child(column)
	title_label=_label(column,"PatrolTitle","순찰 편성",30,"heading",true)
	title_label.custom_minimum_size.y=38
	subtitle_label=_label(column,"PatrolSubtitle","다음 바퀴에 추가할 타일을 정하세요",18,"body",true)
	subtitle_label.custom_minimum_size.y=28
	_rule(column)
	body_scroll=ScrollContainer.new()
	body_scroll.name="PatrolBodyScroll"
	body_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.follow_focus=true
	column.add_child(body_scroll)
	var body:=HBoxContainer.new()
	body.name="PlanningColumns"
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",22)
	body_scroll.add_child(body)
	var left:=VBoxContainer.new()
	left.name="OptionalTiles"
	left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio=2.0
	left.custom_minimum_size.x=600
	left.add_theme_constant_override("separation",12)
	body.add_child(left)
	_label(left,"OptionalTitle","추가할 타일",23,"heading")
	var stations:=HBoxContainer.new()
	stations.add_theme_constant_override("separation",18)
	left.add_child(stations)
	for kind in RoutePlan.CHOICES: _station(stations,str(kind))
	_rule(left)
	var budget:=HBoxContainer.new()
	budget.add_theme_constant_override("separation",12)
	left.add_child(budget)
	_image(budget,"BudgetRoad","res://assets/map/tiles/basic.png",Vector2(50,36))
	budget_label=_label(budget,"PatrolBudget","",20,"body",true)
	_rule(body,true)
	var right:=VBoxContainer.new()
	right.name="NextMap"
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x=276
	right.add_theme_constant_override("separation",5)
	body.add_child(right)
	_label(right,"NextMapTitle","다음 지도",23,"heading")
	for pair in [["event","사건"],["swamp","늪지대"],["rest","숙영"]]:
		var row:=HBoxContainer.new()
		right.add_child(row)
		_label(row,"SummaryName_"+str(pair[0]),str(pair[1]),18)
		var amount:=_label(row,"SummaryCount_"+str(pair[0]),"",20,"body")
		amount.custom_minimum_size.x=54
		amount.size_flags_horizontal=Control.SIZE_FILL
		amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		summary_labels[str(pair[0])]=amount
	_rule(right)
	_label(right,"DiscoveryTitle","발견한 장소",20,"heading")
	empty_discovery=_label(right,"NoDiscoveries","아직 발견한 장소가 없습니다.",17)
	discovery_grid=GridContainer.new()
	discovery_grid.name="DiscoveredPlaces"
	discovery_grid.columns=3
	discovery_grid.add_theme_constant_override("h_separation",8)
	discovery_grid.add_theme_constant_override("v_separation",6)
	right.add_child(discovery_grid)
	for kind in Discovery.ORDER: _discovery(str(kind))
	# Keep remaining capacity visible even when long localized body copy scrolls.
	budget.reparent(column)
	status_label=_label(column,"PatrolStatus","",17)
	status_label.custom_minimum_size.y=34
	_rule(column)
	var footer:=HBoxContainer.new()
	footer.name="PatrolFooter"
	footer.add_theme_constant_override("separation",16)
	column.add_child(footer)
	back_button=_button(footer,"PatrolRouteClose","돌아가기")
	back_button.pressed.connect(func(): if not actions.busy: actions.closed.emit())
	reset_button=_button(footer,"PatrolRouteReset","기본값")
	reset_button.custom_minimum_size.x=112
	reset_button.pressed.connect(actions.reset_route)
	var footer_note:=_label(footer,"PatrolApplyHint","다음 바퀴부터 적용",16,"body",true)
	footer_note.custom_minimum_size.x=160
	confirm_button=_button(footer,"PatrolRouteConfirm","편성 확정",true)
	confirm_button.custom_minimum_size.x=202
	confirm_button.size_flags_stretch_ratio=1.2
	confirm_button.pressed.connect(actions.confirm_route)

func _station(parent: Node, kind: String) -> void:
	var column:=VBoxContainer.new()
	column.name="PatrolStation_"+kind
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x=176
	column.add_theme_constant_override("separation",6)
	parent.add_child(column)
	station_art[kind]=_image(column,"PatrolTile_"+kind,"res://assets/map/tiles/%s.png" % kind,Vector2(142,106))
	var heading:=HBoxContainer.new()
	column.add_child(heading)
	var names: Dictionary={"monster":"일반 마물","rest":"숙영","forest":"언덕"}
	var label:=_label(heading,"PatrolKind_"+kind,str(names[kind]),20,"heading",true)
	label.custom_minimum_size.y=42
	var badge:=_label(heading,"UnlockNewBadge","◆",12)
	badge.custom_minimum_size.x=10
	badge.size_flags_horizontal=Control.SIZE_SHRINK_END
	badge.add_theme_color_override("font_color",Color("7f4b28"))
	station_badges[kind]=badge
	var counter:=HBoxContainer.new()
	counter.name="Counter_"+kind
	counter.layout_direction=Control.LAYOUT_DIRECTION_LTR
	counter.alignment=BoxContainer.ALIGNMENT_CENTER
	counter.add_theme_constant_override("separation",6)
	column.add_child(counter)
	var minus:=_button(counter,"PatrolMinus_"+kind,"−",false,true)
	minus.pressed.connect(func(): actions.adjust_route_tile(kind,-1))
	minus_buttons[kind]=minus
	var count:=_label(counter,"PatrolCount_"+kind,"",25,"body",true)
	count.custom_minimum_size=Vector2(42,42)
	count.size_flags_horizontal=Control.SIZE_FILL
	count_labels[kind]=count
	var plus:=_button(counter,"PatrolPlus_"+kind,"+",false,true)
	plus.pressed.connect(func(): actions.adjust_route_tile(kind,1))
	plus_buttons[kind]=plus
	var hint:=_label(column,"PatrolHint_"+kind,"",16,"body",true)
	hint.custom_minimum_size.y=50
	hint.add_theme_color_override("font_color",MUTED)
	station_hints[kind]=hint
	if kind=="rest":
		unlock_button=_button(column,"PatrolUnlockRest","숙영 해금")
		unlock_button.pressed.connect(actions.unlock_rest)

func _discovery(kind: String) -> void:
	var cell:=VBoxContainer.new()
	cell.name="Discovered_"+kind
	cell.custom_minimum_size.x=82
	cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation",3)
	discovery_grid.add_child(cell)
	var icon_name: String="HomeUnlockedForestTile" if kind=="forest" else "HomeUnlockedTile_"+kind
	_image(cell,icon_name,"res://assets/map/tiles/%s.png" % kind,Vector2(60,44))
	var name_row:=HBoxContainer.new()
	name_row.add_theme_constant_override("separation",2)
	cell.add_child(name_row)
	var label_name: String="HomeForestUnlockedLabel" if kind=="forest" else "HomeUnlockLabel_"+kind
	var label:=_label(name_row,label_name,str(State.NAMES[kind]),16,"body",true)
	label.custom_minimum_size.y=22
	var badge:=_label(name_row,"UnlockNewBadge","◆",11)
	badge.custom_minimum_size.x=8
	badge.size_flags_horizontal=Control.SIZE_SHRINK_END
	badge.add_theme_color_override("font_color",Color("7f4b28"))
	discovery_cells[kind]=cell
	discovery_badges[kind]=badge

func _plus_reason(kind: String, preview: Dictionary, locked: bool) -> String:
	if locked: return tr("이번 방문의 편성을 확정했습니다.")
	if kind=="rest" and not bool(actions.plan.get("rest_unlocked",false)): return tr("숙영을 해금한 뒤 편성할 수 있습니다.")
	if kind=="forest" and not Discovery.is_unlocked(actions.session.world,"forest"): return tr("사건에서 언덕을 발견한 뒤 편성할 수 있습니다.")
	if kind=="rest" and int(actions.plan.selection.get("rest",0))+(1 if bool(actions.plan.get("rest_discovered",false)) else 0)>=RoutePlan.REST_LIMIT:
		return tr("숙영은 전체 {limit}칸까지 배치할 수 있습니다.").format({"limit":RoutePlan.REST_LIMIT})
	if int(preview.remaining)<=0: return tr("추가로 배치할 수 있는 칸이 없습니다.")
	return ""

func refresh() -> void:
	if not _built or not is_instance_valid(actions): return
	var previous_focus: Control=get_viewport().gui_get_focus_owner()
	for control in copy_controls:
		if control is Label:
			var source: String=str(control.get_meta("patrol_source",""))
			control.text="" if source.is_empty() else tr(source).format(control.get_meta("patrol_values",{}))
			if control.name=="UnlockNewBadge":
				control.tooltip_text=tr("신규")
				control.accessibility_name=tr("신규")
	var preview: Dictionary=actions.session.world.patrol_preview(actions.plan)
	var locked: bool=actions.session.patrol_edit_locked()
	for kind in RoutePlan.CHOICES:
		var count: int=int(actions.plan.selection.get(kind,0))
		count_labels[kind].text=str(count)
		var reason: String=_plus_reason(str(kind),preview,locked)
		_button_state(plus_buttons[kind],not reason.is_empty(),reason)
		_button_state(minus_buttons[kind],locked or count<=0,tr("이번 방문의 편성을 확정했습니다.") if locked else tr("추가 수량 줄이기"))
		var is_unlocked: bool=(kind=="monster") or (bool(actions.plan.get("rest_unlocked",false)) if kind=="rest" else Discovery.is_unlocked(actions.session.world,"forest"))
		station_art[kind].modulate=Color.WHITE if is_unlocked else Color(0.65,0.63,0.59,0.65)
		station_badges[kind].visible=(kind=="rest" and actions.session.event_flag_is_set("ui:unlock:rest:action_pending")) or (kind=="forest" and actions.session.event_flag_is_set(Discovery.home_flag("forest")))
		if kind=="rest" and is_unlocked:
			_copy(station_hints[kind],"전체 {count} / {limit}",{"count":int(preview.counts.get("rest",0)),"limit":RoutePlan.REST_LIMIT})
		elif kind=="forest" and not is_unlocked: _copy(station_hints[kind],"사건에서 발견 후 편성 가능")
		elif kind=="rest": _copy(station_hints[kind],"숙영 해금 후 편성 가능")
		else: _copy(station_hints[kind],"추가 수량")
	var unlock_allowed: Dictionary=actions.session.rest_unlock_allowed()
	unlock_button.visible=not bool(actions.plan.get("rest_unlocked",false))
	_button_state(unlock_button,locked or not bool(unlock_allowed.get("ok",false)),tr(str(unlock_allowed.get("reason","숙영 해금"))))
	if bool(preview.valid):
		_copy(budget_label,"추가 가능 {count}칸",{"count":int(preview.remaining)})
		budget_label.add_theme_color_override("font_color",INK)
	else:
		_copy(budget_label,"선택 {selected}칸 · 편성 가능 {capacity}칸",{"selected":int(preview.selected),"capacity":int(preview.capacity)})
		budget_label.add_theme_color_override("font_color",Color("843f2a"))
	for kind in summary_labels: summary_labels[kind].text=str(int(preview.counts.get(kind,0)))
	var visible_places: int=0
	for kind in Discovery.ORDER:
		var found: bool=actions.session.event_flag_is_set(Discovery.unlock_flag(str(kind)))
		discovery_cells[kind].visible=found
		discovery_badges[kind].visible=found and actions.session.event_flag_is_set(Discovery.home_flag(str(kind)))
		if found: visible_places+=1
	discovery_grid.visible=visible_places>0
	empty_discovery.visible=visible_places==0
	_button_state(confirm_button,locked or not bool(preview.valid))
	_button_state(reset_button,locked)
	_button_state(back_button,false)
	var feedback: String=str(actions.route_feedback)
	if not feedback.is_empty(): _copy(status_label,feedback)
	elif locked: _copy(status_label,"이번 방문의 편성을 확정했습니다.")
	elif not bool(preview.valid): _copy(status_label,str(preview.reason))
	else: _copy(status_label,"")
	status_label.visible=not status_label.text.is_empty()
	if is_instance_valid(previous_focus) and previous_focus is BaseButton and previous_focus.disabled:
		for kind in plus_buttons:
			if previous_focus==plus_buttons[kind] and not minus_buttons[kind].disabled:
				minus_buttons[kind].grab_focus()
				return
			if previous_focus==minus_buttons[kind] and not plus_buttons[kind].disabled:
				plus_buttons[kind].grab_focus()
				return
		back_button.grab_focus()
