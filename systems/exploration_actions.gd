extends "res://systems/reward_ui.gd"
signal closed
signal leave_to_map
signal hill_route_chosen(steps: int)
const PrayerEffect = preload("res://systems/world_tree_prayer_effect.gd")
const RoutePlan = preload("res://systems/route_plan.gd")
const ROUTE_RESERVE_ART = "res://assets/map/ui/patrol-route-frame.webp"
const ROUTE_CURRENT_ART = "res://assets/map/ui/patrol-route-current-frame.webp"
const PATROL_ENTER_PARCHMENT = "res://assets/map/events/enter-parchment.png"
const PATROL_EXIT_PARCHMENT = "res://assets/map/events/exit-parchment.png"
const MapState = preload("res://systems/map_state.gd")
const DiceAnimation = preload("res://systems/dice_animation.gd")
const GRADES = {"normal":"일반","advanced":"고급","hero":"영웅"}
const LEGIONS = {"skeleton":"언데드","beast":"야수","corpse":"시체","plague":"역병","ice":"얼음","summon":"소환","demon":"악마","plant":"식물","insect":"벌레","element":"원소"}
var map
var session
var index: int
var type: String
var busy = false
var status: Label
var close_button: Button
var graveyard_exit_button: Button
var action_button: Button
var route_reset_button: Button
var content: Control
var dice: TextureButton
var corpse_id = ""
var corpse_options: Dictionary = {}
var graveyard_columns: Array = []
var graveyard_corpses_grid: GridContainer
var graveyard_brands_grid: GridContainer
var brand_options: Array = []
var plan: Dictionary = {}
var selected_current = -1
var selected_reserve = -1
var current_options: Array = []
var reserve_options: Array = []
var route_plus_buttons: Dictionary = {}
var route_minus_buttons: Dictionary = {}
var route_count_labels: Dictionary = {}
var hill_selected_steps: int = 0
var hill_choice_buttons: Array = []

func setup(map_scene, tile_index: int) -> void:
	map=map_scene
	session=map.session
	index=tile_index
	type=session.world.tiles[index]
	z_index=85
	backdrop()
	var background={"unknown":"world-tree","graveyard":"graveyard","forest":"forest","home":"home-interior"}[type]
	# The action layer uses the same 980x406 painting and 1024x450 nine-patch
	# as the location screen; action-specific controls are layered above it.
	map.location_scene_image(self,"res://assets/map/events/%s.jpg" % background)
	label_at(self,{"unknown":"세계수 · 정화 기도","graveyard":"공동묘지 · 낙인 추출","forest":"언덕 · 이동 경로 선택","home":"우리집 · 순찰경로"}[type],Vector2(290,22),Vector2(700,40),24)
	close_button=button(self,"돌아가기",Vector2(1100,26),Vector2(110,38),func(): if not busy: closed.emit())
	status=label_at(self,"",Vector2(130,555),Vector2(1020,60),15)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content=Control.new()
	add_child(content)
	if type=="unknown":
		# World-tree prayers use the same full-stage die at its last rest pose.
		# No local decorative copy is created and nothing snaps to (610,245).
		dice=map.dice
		action_button=button(self,"기도",Vector2(525,465),Vector2(230,42),pray)
		action_button.disabled=session.place_visit_id("purify",index) in session.world.reward_receipts
		status.text="1~3 실패: 오염도 +1 · 4~5 축복: -3 · 6 대축복: -5\n방문당 한 번 · 현재 오염도 %d/100" % session.world.contamination
		var saved=session.world.prayer_result
		if saved.get("visit","")==session.place_visit_id("purify",index):
			status.text="기도 결과 %d · 오염도 %+d · 현재 %d/100" % [int(saved.face),int(saved.delta),session.world.contamination]
	elif type=="graveyard":
		close_button.text="닫기"
		close_button.position=Vector2(911,148)
		close_button.size=Vector2(109,35)
		var close_style=StyleBoxTexture.new()
		close_style.texture=load("res://assets/map/ui/parchment_button_variant_04.png")
		for state in ["normal","hover","pressed","focus","disabled"]: close_button.add_theme_stylebox_override(state,close_style)
		close_button.add_theme_color_override("font_color",Color("3f2818"))
		status.position=Vector2(302,555)
		status.size=Vector2(674,39)
		status.add_theme_font_size_override("font_size",13)
		render_graveyard()
		# The extraction frame is added after the original close button.
		# Draw/input-order the close control over that frame, not behind it.
		close_button.name="GraveyardExtractClose"
		close_button.z_index=10
		close_button.move_to_front()
		# A separate, always-available one-click escape to the actual map:
		# no corpse, spent extraction or failed result may trap the player.
		graveyard_exit_button=button(self,"맵으로 나가기",Vector2(774,627),Vector2(248,55),func():
			if not busy: leave_to_map.emit())
		graveyard_exit_button.name="GraveyardExitToMap"
		graveyard_exit_button.z_index=10
		for state in ["normal","hover","pressed","focus","disabled"]:
			graveyard_exit_button.add_theme_stylebox_override(state,close_style)
		graveyard_exit_button.add_theme_color_override("font_color",Color("3f2818"))
		graveyard_exit_button.add_theme_font_size_override("font_size",18)
	elif type=="forest":
		action_button=button(self,"이동 확정",Vector2(525,478),Vector2(230,44),confirm_hill_route)
		action_button.disabled=true
		render_hill_choices()
	else:
		plan=session.world.patrol_plan.duplicate(true) if RoutePlan.is_new(session.world.patrol_plan) else RoutePlan.default_plan()
		close_button.text="닫기"
		close_button.position=Vector2(430,561)
		close_button.size=Vector2(128,36)
		status.position=Vector2(145,515)
		status.size=Vector2(722,42)
		status.add_theme_font_size_override("font_size",13)
		action_button=button(self,"경로 확정",Vector2(614,561),Vector2(160,36),confirm_route)
		action_button.name="PatrolRouteConfirm"
		style_patrol_button(action_button)
		route_reset_button=button(self,"기본값",Vector2(245,561),Vector2(148,36),reset_route)
		route_reset_button.name="PatrolRouteReset"
		style_patrol_button(route_reset_button)
		close_button.name="PatrolRouteClose"
		style_patrol_button(close_button,true)
		render_route()
	map.refresh_shared_die_input()

# These two *exact* source PNGs are already in the Godot repository but
# were never connected to the in-game patrol action buttons. The frozen
# v2-map-practice.css assigns enter parchment to reset/confirm and exit
# parchment to close; keep each original button's callback and position.
func style_patrol_button(control: Button, is_exit: bool = false) -> void:
	var path: String = PATROL_EXIT_PARCHMENT if is_exit else PATROL_ENTER_PARCHMENT
	var background = StyleBoxTexture.new()
	background.texture = load(path)
	for state in ["normal","hover","pressed","focus","disabled"]:
		control.add_theme_stylebox_override(state,background)
	control.add_theme_color_override("font_color",Color("49301d"))
	control.add_theme_color_override("font_hover_color",Color("49301d"))
	control.add_theme_color_override("font_pressed_color",Color("49301d"))
	control.add_theme_color_override("font_disabled_color",Color("857668"))
	control.add_theme_color_override("font_focus_color",Color("49301d"))
	control.add_theme_font_size_override("font_size",13)

func reset_route() -> void:
	plan=RoutePlan.default_plan()
	selected_current=-1
	selected_reserve=-1
	render_route()

func clear_content() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()

# Original map-practice extraction overlay: dark framed two-column panel,
# three-column corpse/brand card grids; game exchange rules remain unchanged.
func render_graveyard() -> void:
	clear_content()
	corpse_options={}
	brand_options=[]
	graveyard_columns=[]
	var frame=Panel.new()
	frame.name="GraveyardExtractFrame"
	frame.position=Vector2(256,135)
	frame.size=Vector2(768,470)
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var outer=StyleBoxFlat.new()
	outer.bg_color=Color("191818")
	outer.border_color=Color("66584c")
	outer.set_border_width_all(2)
	outer.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel",outer)
	content.add_child(frame)
	var heading=label_at(content,"공동묘지 · 낙인 추출",Vector2(287,160),Vector2(566,37),23)
	heading.add_theme_color_override("font_color",Color("ddd0be"))
	var guide=label_at(content,"전투에서 죽은 내 마물 시체를 선택한 뒤 낙인 1개를 추출하면 시체가 사라집니다.",Vector2(287,205),Vector2(710,37),13)
	guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	guide.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	guide.add_theme_color_override("font_color",Color("b8ada0"))
	for k in range(2):
		var column=Panel.new()
		column.name="CorpseColumn" if k==0 else "BrandColumn"
		column.position=Vector2(280,264) if k==0 else Vector2(670,264)
		column.size=Vector2(371,267) if k==0 else Vector2(329,267)
		var boxed=StyleBoxFlat.new()
		boxed.bg_color=Color("171615")
		boxed.border_color=Color("514a43")
		boxed.set_border_width_all(1)
		boxed.set_corner_radius_all(5)
		column.add_theme_stylebox_override("panel",boxed)
		content.add_child(column)
		graveyard_columns.append(column)
		var txt=label_at(content,"전투에서 죽은 마물" if k==0 else "추출할 낙인",Vector2(288,277) if k==0 else Vector2(675,277),Vector2(351,30) if k==0 else Vector2(316,30),17)
		txt.add_theme_color_override("font_color",Color("d1c2af"))
	var corpses_scroll=ScrollContainer.new()
	corpses_scroll.position=Vector2(293,319)
	corpses_scroll.size=Vector2(346,199)
	corpses_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(corpses_scroll)
	graveyard_corpses_grid=GridContainer.new()
	graveyard_corpses_grid.columns=3
	graveyard_corpses_grid.add_theme_constant_override("h_separation",8)
	graveyard_corpses_grid.add_theme_constant_override("v_separation",8)
	corpses_scroll.add_child(graveyard_corpses_grid)
	var used=session.place_visit_id("grave-extract",index) in session.world.reward_receipts
	for corpse in session.world.graveyard_corpses:
		var box=Control.new()
		box.custom_minimum_size=Vector2(104,165)
		graveyard_corpses_grid.add_child(box)
		var id: String=str(corpse.id)
		var option=card(box,"unit",corpse,Vector2(5,2),Vector2(94,134),func(): if not busy: corpse_id=id; render_graveyard())
		option.disabled=used or busy
		option.tooltip_text="%s · 시체" % str(corpse.name)
		option.modulate=Color(0.93,0.90,0.83) if id==corpse_id else Color(0.61,0.59,0.57)
		corpse_options[id]=option
	var brands_scroll=ScrollContainer.new()
	brands_scroll.position=Vector2(683,319)
	brands_scroll.size=Vector2(304,199)
	brands_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(brands_scroll)
	graveyard_brands_grid=GridContainer.new()
	graveyard_brands_grid.columns=3
	graveyard_brands_grid.add_theme_constant_override("h_separation",7)
	graveyard_brands_grid.add_theme_constant_override("v_separation",7)
	brands_scroll.add_child(graveyard_brands_grid)
	var choices: Array=session.graveyard_choices(corpse_id)
	for choice in choices:
		var slot=Control.new()
		slot.custom_minimum_size=Vector2(94,169)
		graveyard_brands_grid.add_child(slot)
		var option=card(slot,"brand",choice.item,Vector2(2,2),Vector2(90,134),func(): extract(int(choice.index)))
		option.disabled=used or busy
		brand_options.append(option)
	if choices.is_empty():
		var placeholder=label_at(content,"시체를 선택하세요" if corpse_id.is_empty() else "추출 가능한 낙인이 없습니다",Vector2(687,378),Vector2(293,59),14)
		placeholder.add_theme_color_override("font_color",Color("8f857b"))
	status.text="이번 방문의 추출은 완료했습니다" if used else ("전투에서 죽은 마물의 시체가 없습니다" if session.world.graveyard_corpses.is_empty() else ("시체를 선택하세요 · 낙인 하나를 추출하면 시체가 소모됩니다" if corpse_id.is_empty() else ("추출할 축복 낙인이 없습니다" if choices.is_empty() else "추출할 낙인을 누르세요 · 선택한 시체는 영구 소모됩니다")))

func extract(brand_index: int) -> void:
	if busy: return
	busy=true
	var result=session.extract_graveyard(index,corpse_id,brand_index)
	busy=false
	if result.ok: corpse_id=""
	render_graveyard()
	status.text=result.reason

## Six forward routes are displayed; crossing the fixed HOME tile is
## forbidden by the same path-stop rule as normal die movement.
func hill_max_steps() -> int:
	for steps in range(1,7):
		if (index+steps)%24==MapState.HOME:
			return steps
	return 6

func render_hill_choices() -> void:
	clear_content()
	hill_choice_buttons.clear()
	hill_selected_steps=0
	action_button.disabled=true
	status.text="현재 %d번 언덕 · 앞으로 이동할 1~6칸을 선택하세요. 집을 넘을 수 없습니다." % (index+1)
	var heading=label_at(content,"목적지 선택 · 주사위와 카드 소모 없음",Vector2(268,118),Vector2(740,40),22)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var max_steps: int=hill_max_steps()
	for steps in range(1,7):
		var destination: int=(index+steps)%24
		var allowed: bool=steps<=max_steps
		var caption: String="+%d칸 → %d번 · %s" % [steps,destination+1,MapState.NAMES[session.world.tiles[destination]]]
		if not allowed: caption+=" (집 통과 불가)"
		var chosen_step: int=steps
		var row: int=(steps-1)/2
		var column: int=(steps-1)%2
		var option: Button=button(content,caption,Vector2(232+column*420,190+row*85),Vector2(400,66),func(): select_hill_step(chosen_step))
		option.name="HillStep%d" % steps
		option.disabled=not allowed
		option.add_theme_font_size_override("font_size",19)
		hill_choice_buttons.append(option)

func select_hill_step(steps: int) -> void:
	if busy or steps<1 or steps>hill_max_steps(): return
	hill_selected_steps=steps
	for i in range(hill_choice_buttons.size()):
		var control: Button=hill_choice_buttons[i]
		control.add_theme_color_override("font_color",Color("e5c17f") if i+1==steps else Color("f2dfb5"))
	map.highlight((index+steps)%24)
	action_button.disabled=false
	status.text="%d칸 앞 · %d번 %s 선택 · 이동 확정을 누르면 실제로 이동합니다." % [steps,(index+steps)%24+1,MapState.NAMES[session.world.tiles[(index+steps)%24]]]

func confirm_hill_route() -> void:
	if busy or hill_selected_steps<1: return
	busy=true
	action_button.disabled=true
	close_button.disabled=true
	hill_route_chosen.emit(hill_selected_steps)


func render_route() -> void:
	clear_content()
	current_options=[]
	reserve_options=[]
	route_plus_buttons.clear()
	route_minus_buttons.clear()
	route_count_labels.clear()
	var used: bool=session.place_visit_id("patrol",session.MapState.HOME) in session.world.reward_receipts
	var total: int=RoutePlan.total_selected(plan)
	var remaining: int=RoutePlan.available(plan)
	var rest_unlocked: bool=bool(plan.get("rest_unlocked",false))
	# Preserve authentic parchment texture and the original enter/exit
	# buttons; remove the obscure 6-current vs 5-reserve swap puzzle.
	if ResourceLoader.exists(ROUTE_RESERVE_ART):
		var parchment=art(content,ROUTE_RESERVE_ART,Vector2(74,92),Vector2(829,541))
		parchment.stretch_mode=TextureRect.STRETCH_SCALE
	if ResourceLoader.exists(ROUTE_CURRENT_ART):
		var sidebar=art(content,ROUTE_CURRENT_ART,Vector2(925,65),Vector2(284,590))
		sidebar.stretch_mode=TextureRect.STRETCH_SCALE
	var heading=label_at(content,"다음 바퀴 · 타일 편성",Vector2(190,138),Vector2(630,40),24)
	heading.add_theme_color_override("font_color",Color("392519"))
	var note=label_at(content,"일반 마물 5칸은 자동 배치 · 아래에서 추가할 타일만 선택",Vector2(170,185),Vector2(680,27),14)
	note.add_theme_color_override("font_color",Color("67432b"))
	for metric in [
		{"title":"추가 가능","value":RoutePlan.OPTIONAL_CAPACITY,"x":181.0},
		{"title":"내가 선택","value":total,"x":397.0},
		{"title":"남은 칸","value":remaining,"x":613.0}
	]:
		var label=label_at(content,str(metric.title),Vector2(float(metric.x),219),Vector2(160,24),14)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color",Color("6f4932"))
		var number=label_at(content,"%d칸" % int(metric.value),Vector2(float(metric.x),246),Vector2(160,47),29)
		number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		number.add_theme_color_override("font_color",Color("342619"))
	var slot_positions: Array=[]
	for i in range(RoutePlan.OPTIONAL_CAPACITY):
		var id: String="basic"
		if i<int(plan.selection.monster):
			id="monster"
		elif i<total:
			id="rest"
		var x: float=150.0+float(i)*121.0
		slot_positions.append(x)
		var tile: TextureRect=art(content,"res://assets/map/tiles/%s.png" % id,Vector2(x,310),Vector2(81,78))
		tile.name="SelectedPatrolSlot%d" % i
		tile.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.modulate=Color.WHITE if i<total else Color(0.72,0.70,0.66,0.65)
		var caption=label_at(content,"선택 %d" % (i+1) if i<total else "빈 칸",Vector2(x-8,389),Vector2(97,23),12)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_color",Color("584132"))
	var guide=label_at(content,"타일을 누르면 수량이 바뀝니다 · 선택하지 않은 칸은 길로 남습니다",Vector2(158,422),Vector2(698,28),13)
	guide.add_theme_color_override("font_color",Color("684b36"))
	for j in range(RoutePlan.CHOICES.size()):
		var kind: String=str(RoutePlan.CHOICES[j])
		var unlocked: bool=kind=="monster" or rest_unlocked
		var count: int=int(plan.selection[kind])
		var x: float=182.0+j*369.0
		var art_tile=art(content,"res://assets/map/tiles/%s.png" % kind,Vector2(x,454),Vector2(75,71))
		art_tile.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not unlocked: art_tile.modulate=Color(0.50,0.49,0.47)
		var label=label_at(content,"일반 마물" if kind=="monster" else "숙영",Vector2(x+79,451),Vector2(240,27),18)
		label.add_theme_color_override("font_color",Color("352519"))
		var limit=label_at(content,"추가 수량 제한 없음" if kind=="monster" else ("최대 3칸" if unlocked else "첫 해금 타일 · 잠김"),Vector2(x+80,480),Vector2(250,22),13)
		limit.add_theme_color_override("font_color",Color("795536"))
		var minus=button(content,"−",Vector2(x+83,506),Vector2(53,45),func(): adjust_route_tile(kind,-1))
		minus.name="PatrolMinus_"+kind
		minus.disabled=used or count<=0
		var quantity=label_at(content,"%d" % count,Vector2(x+139,512),Vector2(65,35),22)
		quantity.name="PatrolCount_"+kind
		quantity.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		quantity.add_theme_color_override("font_color",Color("322317"))
		var plus=button(content,"+",Vector2(x+206,506),Vector2(53,45),func(): adjust_route_tile(kind,1))
		plus.name="PatrolPlus_"+kind
		plus.disabled=used or not unlocked or remaining<=0 or (kind=="rest" and count>=RoutePlan.REST_LIMIT)
		route_minus_buttons[kind]=minus
		route_plus_buttons[kind]=plus
		route_count_labels[kind]=quantity
	var sidebar_title=label_at(content,"자동 배치",Vector2(950,159),Vector2(240,37),21)
	sidebar_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	sidebar_title.add_theme_color_override("font_color",Color("382416"))
	for row in [
		{"label":"일반 마물","value":"5칸 확정"},
		{"label":"사건","value":"1칸 확정"},
		{"label":"보호 길","value":"2칸 고정"},
		{"label":"숙영","value":"%d / 3칸" % int(plan.selection.rest)},
		{"label":"늪지대","value":"시작 0칸"}
	]:
		var idx: int=int(["일반 마물","사건","보호 길","숙영","늪지대"].find(row.label))
		var first=label_at(content,str(row.label),Vector2(952,215+idx*58),Vector2(219,24),14)
		first.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		first.add_theme_color_override("font_color",Color("63442e"))
		var value=label_at(content,str(row.value),Vector2(952,238+idx*58),Vector2(219,28),17)
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_color_override("font_color",Color("382719"))
	action_button.disabled=used
	status.text="이번 방문은 확정 완료 · 다음 바퀴부터 반영" if used else ("추가 %d/%d칸 선택 · %d칸 남음 · 숙영은 해금 후 최대 3칸" % [total,RoutePlan.OPTIONAL_CAPACITY,remaining])

func adjust_route_tile(kind: String, difference: int) -> void:
	if type!="home" or session.place_visit_id("patrol",session.MapState.HOME) in session.world.reward_receipts: return
	if not kind in RoutePlan.CHOICES: return
	plan=RoutePlan.adjust(plan,kind,difference)
	render_route()

func confirm_route() -> void:
	var result=session.confirm_patrol(plan)
	status.text=result.reason
	if result.ok: closed.emit()

func pray() -> void:
	if busy: return
	var result=session.pray_world_tree(index)
	if not result.ok: status.text=result.reason; return
	busy=true
	close_button.disabled=true
	action_button.disabled=true
	status.text="세계수에 정화 기도 중…"
	await map.roll_shared_die(int(result.face))
	status.text=result.reason
	map.presentation.refresh()
	if bool(result.get("boss_appeared",false)) and map.buttons.size() > MapState.BOSS_TILE_INDEX:
		# A world-tree prayer can cross 19→20 mid-lap. Reveal the
		# already-persisted boss tile in place, with a quiet short fade.
		var boss_button: TextureButton = map.buttons[MapState.BOSS_TILE_INDEX]
		boss_button.texture_normal = map.texture(map.tile_path(MapState.BOSS_TILE_INDEX))
		boss_button.tooltip_text = "24번 · 보스"
		boss_button.modulate.a = 0.35
		map.create_tween().tween_property(boss_button,"modulate:a",1.0,0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		status.text += " · 보스 타일 출현"
	var popup = PrayerEffect.new()
	popup.position = Vector2(556,315)
	add_child(popup)
	popup.play(int(session.world.prayer_result.delta))
	close_button.disabled=false
	busy=false
	map.refresh_shared_die_input()

func card(parent: Control, kind: String, item: Dictionary, pos: Vector2, dimensions: Vector2, callback: Callable) -> TextureButton:
	var option = super.card(parent,kind,item,pos,dimensions,callback)
	add_button_effect(option)
	return option
