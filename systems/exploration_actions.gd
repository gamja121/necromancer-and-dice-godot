extends "res://systems/reward_ui.gd"
signal closed
const PrayerEffect = preload("res://systems/world_tree_prayer_effect.gd")
const RoutePlan = preload("res://systems/route_plan.gd")
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
		status.position.y=605
		render_graveyard()
	elif type=="forest":
		action_button=button(self,"전역 정찰",Vector2(525,465),Vector2(230,42),scout)
		if session.world.scout.scouted: render_intel()
		else: status.text="남은 마물 타일의 적 수·등급·군단을 확인합니다 · 정확한 종류는 전투 진입 시 결정"
	else:
		plan=session.world.patrol_plan.duplicate(true)
		action_button=button(self,"경로 확정",Vector2(655,465),Vector2(210,42),confirm_route)
		button(self,"기본 경로",Vector2(414,465),Vector2(210,42),func(): plan=RoutePlan.default_plan(); selected_current=-1; selected_reserve=-1; render_route())
		render_route()

func clear_content() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()

func render_graveyard() -> void:
	clear_content()
	corpse_options={}
	brand_options=[]
	label_at(content,"전투에서 죽은 마물의 시체",Vector2(200,105),Vector2(880,32),18)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(150,150)
	scroll.size=Vector2(980,207)
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var row=HBoxContainer.new()
	row.custom_minimum_size.x=950
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",16)
	scroll.add_child(row)
	var used=session.place_visit_id("grave-extract",index) in session.world.reward_receipts
	for corpse in session.world.graveyard_corpses:
		var box=Control.new()
		box.custom_minimum_size=Vector2(108,188)
		row.add_child(box)
		var id=str(corpse.id)
		var option=card(box,"unit",corpse,Vector2(4,0),Vector2(100,146),func(): if not busy: corpse_id=id; render_graveyard())
		option.disabled=used or busy
		option.modulate=Color.WHITE if id==corpse_id else Color(0.73,0.67,0.60)
		corpse_options[id]=option
	var choices=session.graveyard_choices(corpse_id)
	for i in range(choices.size()):
		var choice=choices[i]
		var option=card(content,"brand",choice.item,Vector2((1280.0-(choices.size()*155-43))/2+i*155,367),Vector2(112,163),func(): extract(int(choice.index)))
		option.disabled=used or busy
		brand_options.append(option)
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
	label_at(content,"현재 경로 6칸",Vector2(300,98),Vector2(680,32),19)
	label_at(content,"교체판 5칸",Vector2(300,270),Vector2(680,32),19)
	for area in ["current","reserve"]:
		for i in range(plan[area].size()):
			var id=plan[area][i]
			var option=TextureButton.new()
			option.texture_normal=map.texture("res://assets/map/tiles/%s.png" % id)
			option.ignore_texture_size=true
			option.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			option.position=Vector2((173 if area=="current" else 250)+i*155,140 if area=="current" else 315)
			option.size=Vector2(132,98)
			option.disabled=used
			add_button_effect(option)
			option.pressed.connect(func(): choose_route(area,i))
			content.add_child(option)
			label_at(option,session.world.NAMES[id],Vector2(0,98),Vector2(132,26),13)
			var selected=(selected_current if area=="current" else selected_reserve)==i
			option.modulate=Color.WHITE if selected else Color(0.78,0.71,0.61)
			if area=="current": current_options.append(option)
			else: reserve_options.append(option)
	action_button.disabled=used
	status.text="이번 방문의 경로는 확정했습니다 · 다음 맵 배치에 적용" if used else ("교체판에서 바꿀 타일을 선택하세요" if selected_current>=0 else ("현재 경로에서 바꿀 타일을 선택하세요" if selected_reserve>=0 else "현재 경로와 교체판 타일을 하나씩 눌러 교환하세요 · 현재 맵은 유지"))

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
