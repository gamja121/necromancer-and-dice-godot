extends "res://systems/reward_ui.gd"
signal closed
const PrayerEffect = preload("res://systems/world_tree_prayer_effect.gd")
const RoutePlan = preload("res://systems/route_plan.gd")
const ROUTE_RESERVE_ART = "res://assets/map/ui/patrol-route-frame.webp"
const ROUTE_CURRENT_ART = "res://assets/map/ui/patrol-route-current-frame.webp"
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
var action_button: Button
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

func setup(map_scene, tile_index: int) -> void:
	map=map_scene
	session=map.session
	index=tile_index
	type=session.world.tiles[index]
	z_index=85
	backdrop()
	var background={"unknown":"world-tree","graveyard":"graveyard","forest":"forest","home":"home-interior"}[type]
	art(self,"res://assets/map/events/%s.jpg" % background,Vector2(120,70),Vector2(1040,480)).modulate=Color(0.42,0.35,0.28,0.65)
	label_at(self,{"unknown":"세계수 · 정화 기도","graveyard":"공동묘지 · 낙인 추출","forest":"언덕 · 전역 정찰","home":"우리집 · 순찰경로"}[type],Vector2(290,22),Vector2(700,40),24)
	close_button=button(self,"돌아가기",Vector2(1100,26),Vector2(110,38),func(): if not busy: closed.emit())
	status=label_at(self,"",Vector2(130,555),Vector2(1020,60),15)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content=Control.new()
	add_child(content)
	if type=="unknown":
		dice=TextureButton.new()
		dice.ignore_texture_size=true
		dice.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		dice.position=Vector2(610,245)
		dice.size=Vector2(60,60)
		dice.mouse_filter=Control.MOUSE_FILTER_IGNORE
		dice.texture_normal=map.texture("res://assets/battle/dice/result-01.png")
		add_child(dice)
		action_button=button(self,"기도",Vector2(525,465),Vector2(230,42),pray)
		action_button.disabled=session.place_visit_id("purify",index) in session.world.reward_receipts
		status.text="1~3 실패: 오염도 +1 · 4~5 축복: -3 · 6 대축복: -5\n방문당 한 번 · 현재 오염도 %d/100" % session.world.contamination
		var saved=session.world.prayer_result
		if saved.get("visit","")==session.place_visit_id("purify",index):
			dice.texture_normal=map.texture("res://assets/battle/dice/result-%02d.png" % int(saved.face))
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
	elif type=="forest":
		action_button=button(self,"전역 정찰",Vector2(525,465),Vector2(230,42),scout)
		if session.world.scout.scouted: render_intel()
		else: status.text="남은 마물 타일의 적 수·등급·군단을 확인합니다 · 정확한 종류는 전투 진입 시 결정"
	else:
		plan=session.world.patrol_plan.duplicate(true)
		close_button.text="닫기"
		close_button.position=Vector2(430,561)
		close_button.size=Vector2(128,36)
		status.position=Vector2(145,515)
		status.size=Vector2(722,42)
		status.add_theme_font_size_override("font_size",13)
		action_button=button(self,"경로 확정",Vector2(614,561),Vector2(160,36),confirm_route)
		button(self,"기본값",Vector2(245,561),Vector2(148,36),func(): plan=RoutePlan.default_plan(); selected_current=-1; selected_reserve=-1; render_route())
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

func scout() -> void:
	if busy: return
	var result=session.scout_hill(index)
	if not result.ok: status.text=result.reason; return
	render_intel()

func render_intel() -> void:
	clear_content()
	action_button.disabled=true
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(180,105)
	scroll.size=Vector2(920,335)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var grid=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	var intel=session.active_scout_intel()
	for entry in intel:
		var tile=PanelContainer.new()
		tile.custom_minimum_size=Vector2(438,104)
		var style=StyleBoxFlat.new()
		style.bg_color=Color("241b18ed")
		style.border_color=Color("89734c")
		style.set_border_width_all(1)
		style.content_margin_left=14
		style.content_margin_top=10
		tile.add_theme_stylebox_override("panel",style)
		grid.add_child(tile)
		var text=Label.new()
		text.text="%d번 · %s\n적 %d마리 · %s 포함 · %s 군단 확인" % [int(entry.index)+1,session.world.NAMES[entry.type],int(entry.count),GRADES[entry.grade],LEGIONS.get(entry.legion,entry.legion)]
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size",17)
		tile.add_child(text)
	status.text="남은 마물 타일 %d곳 정찰 완료 · 적 수와 확인된 등급/군단은 실제 전투에 적용" % intel.size()

func render_route() -> void:
	clear_content()
	current_options=[]
	reserve_options=[]
	var used=session.place_visit_id("patrol",session.MapState.HOME) in session.world.reward_receipts
	# Original reference: two real parchment panels, not two flattened rows.
	if ResourceLoader.exists(ROUTE_RESERVE_ART):
		var large=art(content,ROUTE_RESERVE_ART,Vector2(74,92),Vector2(829,541))
		large.stretch_mode=TextureRect.STRETCH_SCALE
	else:
		var backup=ColorRect.new()
		backup.position=Vector2(74,92)
		backup.size=Vector2(829,541)
		backup.color=Color("c6a77c")
		content.add_child(backup)
	if ResourceLoader.exists(ROUTE_CURRENT_ART):
		var small=art(content,ROUTE_CURRENT_ART,Vector2(925,65),Vector2(284,590))
		small.stretch_mode=TextureRect.STRETCH_SCALE
	else:
		var backup=ColorRect.new()
		backup.position=Vector2(925,65)
		backup.size=Vector2(284,590)
		backup.color=Color("c6a77c")
		content.add_child(backup)
	var title=label_at(content,"교체 타일",Vector2(250,164),Vector2(450,36),23)
	title.add_theme_color_override("font_color",Color("382416"))
	title.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	var guide=label_at(content,"현재 경로를 고른 뒤 이쪽 타일을 눌러 교체하세요",Vector2(168,207),Vector2(640,27),13)
	guide.add_theme_color_override("font_color",Color("6a4a31"))
	guide.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	var current_title=label_at(content,"현재 경로",Vector2(951,151),Vector2(235,33),19)
	current_title.add_theme_color_override("font_color",Color("382416"))
	current_title.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	for area in ["current","reserve"]:
		for i in range(plan[area].size()):
			var id: String=str(plan[area][i])
			var option=TextureButton.new()
			option.texture_normal=map.texture("res://assets/map/tiles/%s.png" % id)
			option.ignore_texture_size=true
			option.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			if area=="reserve":
				option.position=Vector2(163+i*134,289)
				option.size=Vector2(88,88)
			else:
				option.position=Vector2(1034,201+i*62)
				option.size=Vector2(56,52)
			option.disabled=used
			option.tooltip_text="%s · %s" % [session.world.NAMES[id],"교체 타일" if area=="reserve" else "현재 경로"]
			add_button_effect(option)
			option.pressed.connect(func(): choose_route(area,i))
			content.add_child(option)
			if area=="reserve":
				var label=label_at(content,session.world.NAMES[id],option.position+Vector2(-10,87),Vector2(108,24),11)
				label.add_theme_color_override("font_color",Color("f2ddb7"))
			var selected: bool=(selected_current if area=="current" else selected_reserve)==i
			option.modulate=Color("fff0c8") if selected else Color.WHITE
			if selected:
				option.scale=Vector2(1.08,1.08)
				option.pivot_offset=option.size*0.5
			if area=="current": current_options.append(option)
			else: reserve_options.append(option)
	action_button.disabled=used
	status.text="이번 방문의 경로는 확정했습니다 · 다음 맵 배치에 적용" if used else ("교체판에서 바꿀 타일을 선택하세요" if selected_current>=0 else ("현재 경로에서 바꿀 타일을 선택하세요" if selected_reserve>=0 else "현재 경로와 교체판에서 하나씩 눌러 교환하세요 · 현재 맵은 유지"))

func choose_route(area: String, i: int) -> void:
	if session.place_visit_id("patrol",session.MapState.HOME) in session.world.reward_receipts: return
	if area=="current":
		if selected_reserve>=0:
			var old=plan.current[i]
			plan.current[i]=plan.reserve[selected_reserve]
			plan.reserve[selected_reserve]=old
			selected_current=-1; selected_reserve=-1
		else: selected_current=-1 if selected_current==i else i
	else:
		if selected_current>=0:
			var old=plan.reserve[i]
			plan.reserve[i]=plan.current[selected_current]
			plan.current[selected_current]=old
			selected_current=-1; selected_reserve=-1
		else: selected_reserve=-1 if selected_reserve==i else i
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
	await DiceAnimation.new().roll_map(dice,int(result.face),Rect2(300,140,680,245),map.texture,map.sound)
	dice.position=Vector2(610,245)
	dice.rotation=0
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

func card(parent: Control, kind: String, item: Dictionary, pos: Vector2, dimensions: Vector2, callback: Callable) -> TextureButton:
	var option = super.card(parent,kind,item,pos,dimensions,callback)
	add_button_effect(option)
	return option
