extends "res://systems/reward_ui.gd"
const Sound = preload("res://systems/game_audio.gd")
signal closed
const DiceAnimation = preload("res://systems/dice_animation.gd")
const SHOP_COUNTER_PATH = "res://assets/map/ui/monster-shop-counter.png"
const FORTUNE_STRIP_PATH = "res://assets/map/ui/fortune_parchment_strip.webp"
const ALTAR_SLOTS_PATH = "res://assets/map/events/altar-ritual-slots.png"
const ALTAR_INFO_PATH = "res://assets/map/events/altar-ritual-info.png"
const ALTAR_SLOTS_RECT = Rect2(192.0,36.0,896.0,403.2)
const ALTAR_INFO_RECT = Rect2(384.0,309.6,512.0,176.0)
const SHOP_STAGE = Rect2(115.2,10.13,1049.6,699.73)
var session
var map
var index: int
var type: String
var donor_id = ""
var receiver_id = ""
var chosen = -1
var offers: Array = []
var busy = false
var completed = false
var status: Label
var confirm_button: Button
var close_button: Button
var hand: Control
var offer_area: Control
var donor_art: TextureRect
var receiver_art: TextureRect
var donor_hint: Label
var receiver_hint: Label
var dice: TextureButton
var fortune_result: Label
var fortune_notice_strip: TextureRect
var unit_options: Dictionary = {}
var offer_options: Array = []
var shop_counter: TextureRect
var shop_cancel_button: Button
var shop_confirm_button: Button
var shop_offer_scroll: ScrollContainer
var altar_slots: TextureRect
var altar_info: TextureRect
var altar_scroll: ScrollContainer
var altar_level: Label

func setup(map_scene, tile_index: int) -> void:
	map=map_scene
	session=map.session
	index=tile_index
	type=session.world.tiles[index]
	z_index=85
	backdrop()
	# Keep the location artwork and the exact embedded-battle border in place
	# while shop, ritual or prophecy controls are used.
	var location_art: String = {"village":"village","altar":"altar","fortune-teller-camp":"fortune-teller"}[type]
	map.location_scene_image(self,"res://assets/map/events/%s.jpg" % location_art)
	if type=="village":
		setup_shop_visual()
	else:
		label_at(self,{"altar":"제단 · 피의 의식","fortune-teller-camp":"점술가 · 예언"}[type],Vector2(290,22),Vector2(700,40),24)
		close_button=button(self,"← 돌아가기",Vector2(1100,26),Vector2(110,38),func(): if not busy: closed.emit())
		status=label_at(self,"",Vector2(130,435),Vector2(1020,58),15)
		status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if type=="fortune-teller-camp":
		setup_fortune_result()
		# Fortune uses the persistent map die; never spawn/center a duplicate.
		dice=map.dice
		# The persistent map die is the only prophecy action: no duplicate button.
		var used=session.place_visit_id("prophecy",index) in session.world.reward_receipts
		status.text="예언 듣기"
		fortune_result.text="주사위를 눌러 예언을 확인하세요 · 방문당 1회"
		fortune_result.visible=true
		if used and session.world.last_prophecy.get("visit","")==session.place_visit_id("prophecy",index):
			status.text=str(session.world.last_prophecy.get("detail",""))
			show_fortune_result()
		map.refresh_shared_die_input()
		return
	if type=="altar":
		setup_altar_visual()
		donor_art=LayeredUnitCard.make_preview(self,{},Vector2(340,108),Vector2(190,254))
		donor_art.name="AltarMaterialCard"
		donor_art.z_index=3
		donor_art.texture=null
		donor_hint=label_at(self,"재물 먼저 선택",Vector2(320,379),Vector2(230,35),13)
		donor_hint.name="AltarMaterialHint"
		donor_hint.z_index=4
		receiver_art=LayeredUnitCard.make_preview(self,{},Vector2(752,108),Vector2(190,254))
		receiver_art.name="AltarTargetCard"
		receiver_art.z_index=3
		receiver_art.texture=null
		receiver_hint=label_at(self,"강화 대상 선택",Vector2(730,379),Vector2(235,35),13)
		receiver_hint.name="AltarTargetHint"
		receiver_hint.z_index=4
		for label in [{"text":"재물","pos":Vector2(366,67)},{"text":"강화","pos":Vector2(776,67)}]:
			var heading=label_at(self,label.text,label.pos,Vector2(148,29),17)
			heading.z_index=4
		confirm_button=button(self,"의식 실행",Vector2(746,435),Vector2(125,43),perform_ritual)
		confirm_button.name="AltarRitualConfirm"
		confirm_button.z_index=10
		style_shop_button(confirm_button,2)
	build_hand()
	if type=="altar": animate_altar_open()
	refresh()

# The frozen web altar's two original images are already shipped with the
# project but were not rendered. Their coordinates derive from source CSS
# 15%/70% slots and 30%/40% info at the 1280x720 map design canvas.
func setup_altar_visual() -> void:
	altar_slots=art(self,ALTAR_SLOTS_PATH,ALTAR_SLOTS_RECT.position,ALTAR_SLOTS_RECT.size)
	altar_slots.name="AltarRitualSlots"
	altar_slots.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	altar_slots.z_index=2
	altar_info=art(self,ALTAR_INFO_PATH,ALTAR_INFO_RECT.position,ALTAR_INFO_RECT.size)
	altar_info.name="AltarRitualInfo"
	altar_info.stretch_mode=TextureRect.STRETCH_SCALE
	altar_info.z_index=8
	var plaque_title=label_at(self,"피의 의식",Vector2(523,343),Vector2(238,25),18)
	plaque_title.name="AltarRitualPlaqueTitle"
	plaque_title.add_theme_color_override("font_color",Color("3a271b"))
	plaque_title.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	plaque_title.z_index=9
	status.position=Vector2(445,373)
	status.size=Vector2(390,55)
	status.add_theme_font_size_override("font_size",12)
	status.add_theme_color_override("font_color",Color("3a271b"))
	status.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	status.z_index=9
	altar_level=label_at(self,"강화 대상 선택 전",Vector2(474,423),Vector2(280,21),11)
	altar_level.name="AltarRitualLevel"
	altar_level.add_theme_color_override("font_color",Color("3a271b"))
	altar_level.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	altar_level.z_index=9
	close_button.position=Vector2(1114,29)
	close_button.size=Vector2(112,39)
	close_button.text="← 돌아가기"
	close_button.z_index=10
	style_shop_button(close_button,4)

func animate_altar_open() -> void:
	altar_slots.modulate.a=0.0
	altar_info.modulate.a=0.0
	altar_slots.position=ALTAR_SLOTS_RECT.position+Vector2(0,10)
	altar_info.position=ALTAR_INFO_RECT.position+Vector2(0,10)
	var enter=create_tween().set_parallel(true)
	enter.tween_property(altar_slots,"modulate:a",1.0,0.26)
	enter.tween_property(altar_slots,"position",ALTAR_SLOTS_RECT.position,0.26)
	enter.tween_property(altar_info,"modulate:a",1.0,0.26)
	enter.tween_property(altar_info,"position",ALTAR_INFO_RECT.position,0.26)
	if is_instance_valid(hand):
		hand.position=Vector2(0,170)
		hand.modulate.a=0.0
		enter.tween_property(hand,"position",Vector2.ZERO,0.68).set_delay(0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		enter.tween_property(hand,"modulate:a",1.0,0.68).set_delay(0.16)

# The 1280x720 source uses a centered 82%-wide 3:2 trading counter.
# This method ONLY runs on village tiles: altar/fortune presentation is unchanged.
func setup_shop_visual() -> void:
	if ResourceLoader.exists(SHOP_COUNTER_PATH):
		shop_counter=art(self,SHOP_COUNTER_PATH,SHOP_STAGE.position,SHOP_STAGE.size)
		shop_counter.stretch_mode=TextureRect.STRETCH_SCALE
	else:
		shop_counter=TextureRect.new()
		shop_counter.position=SHOP_STAGE.position
		shop_counter.size=SHOP_STAGE.size
		add_child(shop_counter)
		var fallback=ColorRect.new()
		fallback.color=Color("392719")
		fallback.size=SHOP_STAGE.size
		fallback.mouse_filter=Control.MOUSE_FILTER_IGNORE
		shop_counter.add_child(fallback)
	var trade_origin: Vector2=SHOP_STAGE.position+Vector2(SHOP_STAGE.size.x*0.145,SHOP_STAGE.size.y*0.122)
	var offer_origin: Vector2=SHOP_STAGE.position+Vector2(SHOP_STAGE.size.x*0.445,SHOP_STAGE.size.y*0.122)
	label_at(self,"내가 올린 카드",trade_origin+Vector2(12,0),Vector2(235,28),17)
	label_at(self,"상인의 제안",offer_origin+Vector2(50,0),Vector2(300,28),17)
	donor_art=LayeredUnitCard.make_preview(self,{},trade_origin+Vector2(45,35),Vector2(166,211))
	donor_art.texture=null
	donor_hint=label_at(self,"교환할 마물 선택",trade_origin+Vector2(15,247),Vector2(225,32),14)
	shop_cancel_button=button(self,"거래대에서 내리기",trade_origin+Vector2(38,281),Vector2(189,37),reset_shop_selection)
	style_shop_button(shop_cancel_button,3)
	shop_confirm_button=button(self,"교환 확정",Vector2(875,476),Vector2(206,38),confirm_shop_trade)
	shop_confirm_button.name="ShopTradeConfirm"
	shop_confirm_button.disabled=true
	style_shop_button(shop_confirm_button,2)
	shop_offer_scroll=ScrollContainer.new()
	shop_offer_scroll.position=offer_origin+Vector2(2,35)
	shop_offer_scroll.size=Vector2(425,218)
	shop_offer_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	shop_offer_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	add_child(shop_offer_scroll)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	shop_offer_scroll.add_child(row)
	offer_area=row
	var backing=ColorRect.new()
	backing.position=Vector2(293,434)
	backing.size=Vector2(703,45)
	backing.color=Color("c9a878e6")
	backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	status=label_at(self,"",Vector2(309,443),Vector2(672,30),14)
	status.add_theme_color_override("font_color",Color("49301d"))
	status.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	close_button=button(self,"← 돌아가기",Vector2(992,55),Vector2(146,42),func(): if not busy: closed.emit())
	style_shop_button(close_button,4)

func style_shop_button(control: Button, variant: int) -> void:
	var path="res://assets/map/ui/parchment_button_variant_%02d.png" % variant
	var background=StyleBoxTexture.new()
	background.texture=load(path)
	for state in ["normal","hover","pressed","focus","disabled"]:
		control.add_theme_stylebox_override(state,background)
	control.add_theme_color_override("font_color",Color("412819"))
	control.add_theme_color_override("font_hover_color",Color("5f351c"))
	control.add_theme_font_size_override("font_size",16)

func reset_shop_selection() -> void:
	if busy: return
	donor_id=""
	chosen=-1
	offers=[]
	render_offers()
	refresh()

func build_hand() -> void:
	if is_instance_valid(hand): remove_child(hand); hand.queue_free()
	unit_options={}
	hand=Control.new()
	hand.z_index=5 if type=="altar" else 0
	add_child(hand)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(192,532) if type=="altar" else Vector2(130,515)
	scroll.size=Vector2(896,220) if type=="altar" else Vector2(1020,190)
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	if type=="altar": altar_scroll=scroll
	hand.add_child(scroll)
	var row=HBoxContainer.new()
	row.custom_minimum_size.x=880 if type=="altar" else 1000
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",16)
	scroll.add_child(row)
	for unit in session.world.roster:
		var box=Control.new()
		box.custom_minimum_size=Vector2(110,184) if type=="altar" else Vector2(105,182)
		row.add_child(box)
		var id=str(unit.id)
		var option=card(box,"unit",unit,Vector2(4,0),Vector2(96,139),func(): select_unit(id))
		unit_options[id]=option
	if session.world.roster.size()<2: label_at(hand,"마물이 2마리 이상 있어야 사용할 수 있습니다",Vector2(280,595),Vector2(720,40),18)

func select_unit(id: String) -> void:
	if busy or completed: return
	if type=="village":
		var result=session.shop_offers(index,id)
		if not result.ok: status.text=result.reason; return
		donor_id=id
		chosen=-1
		offers=result.offers
		shop_offer_scroll.scroll_horizontal=0
		render_offers()
	else:
		if id==donor_id: donor_id=""; receiver_id=""
		elif id==receiver_id: receiver_id=""
		elif donor_id.is_empty(): donor_id=id
		else: receiver_id=id
	refresh()

func refresh() -> void:
	var donor=session.owned_unit(donor_id)
	LayeredUnitCard.sync_preview(donor_art,donor)
	AltarUpgradeBadge.sync(donor_art,donor)
	donor_hint.text=donor.name if not donor.is_empty() else ("재물 먼저 선택" if type=="altar" else "교환할 마물 선택")
	if type=="altar":
		var receiver=session.owned_unit(receiver_id)
		LayeredUnitCard.sync_preview(receiver_art,receiver)
		AltarUpgradeBadge.sync(receiver_art,receiver)
		var level=int(receiver.get("altar_enhancements",0))
		receiver_hint.text="%s · 강화 %d/3" % [receiver.name,level] if not receiver.is_empty() else "강화 대상 선택"
		if is_instance_valid(altar_level):
			altar_level.text="강화 단계 %d/3" % level if not receiver.is_empty() else "강화 대상 선택 전"
		var used=session.place_visit_id("ritual",index) in session.world.reward_receipts
		confirm_button.disabled=busy or completed or used or donor.is_empty() or receiver.is_empty() or level>=3
		if not completed: status.text="이번 방문의 의식은 완료했습니다" if used else ("강화 한도 3회에 도달했습니다" if level>=3 else "재물을 먼저 고른 뒤 강화할 마물을 선택하세요")
	else:
		status.text="상품 선택 후 교환 확정 · 선택한 마물은 영구 소멸" if not offers.is_empty() else "아래에서 교환할 마물을 선택하세요 · 마지막 마물은 교환할 수 없습니다"
		if is_instance_valid(shop_confirm_button): shop_confirm_button.disabled=busy or donor.is_empty() or chosen<0 or chosen>=offers.size()
		if is_instance_valid(shop_cancel_button):
			shop_cancel_button.visible=not donor.is_empty()
			shop_cancel_button.disabled=busy
	for id in unit_options:
		unit_options[id].modulate=Color.WHITE if id in [donor_id,receiver_id] else Color(0.76,0.70,0.61)

func render_offers() -> void:
	for node in offer_area.get_children(): offer_area.remove_child(node); node.queue_free()
	offer_options=[]
	for i in range(offers.size()):
		var offer=offers[i]
		var parent: Control=offer_area
		var pos=Vector2(390+i*145,140)
		var dims=Vector2(112,168)
		if type=="village":
			var slot=Control.new()
			slot.custom_minimum_size=Vector2(129,212)
			offer_area.add_child(slot)
			parent=slot
			pos=Vector2(3,4)
			dims=Vector2(122,182)
		var option=card(parent,offer.kind,offer.item,pos,dims,func(): choose_offer(i))
		if type=="village":
			for child in option.get_children():
				if child is Label: child.visible=false
		option.disabled=busy or (offer.kind=="dice" and session.world.dice_cards.size()>=Catalog.DICE_CAPACITY)
		option.modulate=Color.WHITE if i==chosen or chosen<0 else Color(0.5,0.5,0.5)
		offer_options.append(option)
	if is_instance_valid(shop_confirm_button): shop_confirm_button.disabled=busy or donor_id.is_empty() or chosen<0 or chosen>=offer_options.size()

func choose_offer(i: int) -> void:
	if busy or donor_id.is_empty() or i<0 or i>=offer_options.size(): return
	if offer_options[i].disabled: return
	chosen=i
	render_offers()
	status.text="%s 소모 → %s 획득 · 아래 교환 확정" % [str(session.owned_unit(donor_id).get("name","선택 마물")),offer_options[i].tooltip_text]

func confirm_shop_trade() -> void:
	if busy or not is_instance_valid(shop_confirm_button) or shop_confirm_button.disabled: return
	if donor_id.is_empty() or chosen<0 or chosen>=offers.size(): return
	busy=true
	shop_confirm_button.disabled=true
	var result=session.shop_trade(index,donor_id,chosen)
	busy=false
	if result.ok:
		Sound.cue(map,"shop_trade")
		donor_id=""; offers=[]; chosen=-1
		render_offers()
		build_hand()
		refresh()
	else:
		render_offers()
	status.text=result.reason

func perform_ritual() -> void:
	if busy or completed: return
	busy=true
	var result=session.altar_ritual(index,donor_id,receiver_id)
	busy=false
	if result.ok:
		Sound.cue(map,"ritual_complete")
		completed=true
		donor_id=""
		# After the once-only receipt is persisted, remove its original paper.
		map.queue_used_location_paper(index,"ritual")
		build_hand()
		refresh()
	status.text=result.reason

# One restrained two-line reading panel; the painted tent, table and crystal
# remain part of the ORIGINAL full-screen artwork, never spawned as new props.
# All coordinates target the actual 1280x720 embedded location artwork.
func setup_fortune_result() -> void:
	var shared:Dictionary=preload("res://systems/location_notice_strip.gd").build(self,status)
	fortune_notice_strip=shared.strip
	fortune_notice_strip.name="FortuneNoticeStrip"
	fortune_result=shared.detail
	fortune_result.name="FortuneProphecyOutcome"

func show_fortune_result() -> void:
	if not is_instance_valid(fortune_result): return
	var value: Dictionary=session.world.last_prophecy
	if value.is_empty(): return
	# The primary result is status above; show the stack only once below.
	fortune_result.text="누적 효과: "+session.prophecy_label()
	fortune_result.visible=true

func roll_prophecy() -> void:
	if busy: return
	var result=session.fortune_prophecy(index)
	if not result.ok: status.text=result.reason; return
	busy=true
	close_button.disabled=true
	status.text="예언의 주사위를 굴리는 중…"
	fortune_result.text="이번 방문의 예언을 확인하고 있습니다"
	await map.roll_shared_die(int(result.face))
	Sound.cue(map,"prophecy_curse" if int(result.face)==1 else ("recovery" if int(result.face)==2 else "prophecy_bless"))
	status.text=str(session.world.last_prophecy.get("detail",result.reason))
	show_fortune_result()
	# Shared die is still the input: only the saved entry parchment peels.
	map.queue_used_location_paper(index,"prophecy")
	if int(result.face)==2: await map.presentation.full_heal()
	close_button.disabled=false
	busy=false
	map.refresh_shared_die_input()

func card(parent: Control, kind: String, item: Dictionary, pos: Vector2, dimensions: Vector2, callback: Callable) -> TextureButton:
	var option = super.card(parent,kind,item,pos,dimensions,callback)
	add_button_effect(option)
	return option
