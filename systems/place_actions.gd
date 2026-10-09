extends "res://systems/reward_ui.gd"
signal closed
const DiceAnimation = preload("res://systems/dice_animation.gd")
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
var unit_options: Dictionary = {}
var offer_options: Array = []

func setup(map_scene, tile_index: int) -> void:
	map=map_scene
	session=map.session
	index=tile_index
	type=session.world.tiles[index]
	z_index=85
	backdrop()
	art(self,"res://assets/map/events/%s.jpg" % {"village":"village","altar":"altar","fortune-teller-camp":"fortune-teller"}[type],Vector2(120,70),Vector2(1040,480)).modulate=Color(0.38,0.32,0.28,0.7)
	label_at(self,{"village":"마을 · 마물 상점","altar":"제단 · 피의 의식","fortune-teller-camp":"점술가 · 예언"}[type],Vector2(290,22),Vector2(700,40),24)
	close_button=button(self,"돌아가기",Vector2(1100,26),Vector2(110,38),func(): if not busy: closed.emit())
	status=label_at(self,"",Vector2(130,435),Vector2(1020,58),15)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if type=="fortune-teller-camp":
		dice=TextureButton.new()
		dice.ignore_texture_size=true
		dice.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		dice.position=Vector2(610,245)
		dice.size=Vector2(60,60)
		dice.mouse_filter=Control.MOUSE_FILTER_IGNORE
		dice.texture_normal=map.texture("res://assets/battle/dice/result-01.png")
		add_child(dice)
		confirm_button=button(self,"예언 듣기",Vector2(525,505),Vector2(230,42),roll_prophecy)
		var used=session.place_visit_id("prophecy",index) in session.world.reward_receipts
		confirm_button.disabled=used
		status.text="방문당 한 번 · 다음 전투에 적용할 예언을 주사위로 결정합니다\n누적: "+session.prophecy_label()
		if used and session.world.last_prophecy.get("visit","")==session.place_visit_id("prophecy",index):
			dice.texture_normal=map.texture("res://assets/battle/dice/result-%02d.png" % int(session.world.last_prophecy.face))
			status.text=session.world.last_prophecy.detail+"\n누적: "+session.prophecy_label()
		return
	donor_art=art(self,"res://assets/cards/unit-card-skeleton-spear.png",Vector2(178,95),Vector2(144,210))
	donor_art.texture=null
	donor_hint=label_at(self,"재물" if type=="altar" else "교환할 마물",Vector2(144,320),Vector2(210,35),16)
	if type=="altar":
		receiver_art=art(self,"res://assets/cards/unit-card-skeleton-spear.png",Vector2(952,95),Vector2(144,210))
		receiver_art.texture=null
		receiver_hint=label_at(self,"강화할 마물",Vector2(915,320),Vector2(230,35),16)
		label_at(self,"공격력 +1 · 최대 체력 +2\n개체당 최대 3회 · 방문당 1회\n재물은 영구 소멸합니다",Vector2(385,180),Vector2(510,120),20)
		confirm_button=button(self,"의식 실행",Vector2(525,380),Vector2(230,42),perform_ritual)
	else:
		offer_area=Control.new()
		add_child(offer_area)
		button(self,"선택 취소",Vector2(185,380),Vector2(150,36),func(): donor_id=""; chosen=-1; offers=[]; render_offers(); refresh())
	build_hand()
	refresh()

func build_hand() -> void:
	if is_instance_valid(hand): remove_child(hand); hand.queue_free()
	unit_options={}
	hand=Control.new()
	add_child(hand)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(130,515)
	scroll.size=Vector2(1020,190)
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	hand.add_child(scroll)
	var row=HBoxContainer.new()
	row.custom_minimum_size.x=1000
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",16)
	scroll.add_child(row)
	for unit in session.world.roster:
		var box=Control.new()
		box.custom_minimum_size=Vector2(105,182)
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
		render_offers()
	else:
		if id==donor_id: donor_id=""; receiver_id=""
		elif id==receiver_id: receiver_id=""
		elif donor_id.is_empty(): donor_id=id
		else: receiver_id=id
	refresh()

func refresh() -> void:
	var donor=session.owned_unit(donor_id)
	donor_art.texture=load(Catalog.image("unit",donor)) if not donor.is_empty() else null
	donor_hint.text=donor.name if not donor.is_empty() else ("재물 먼저 선택" if type=="altar" else "교환할 마물 선택")
	if type=="altar":
		var receiver=session.owned_unit(receiver_id)
		receiver_art.texture=load(Catalog.image("unit",receiver)) if not receiver.is_empty() else null
		var level=int(receiver.get("altar_enhancements",0))
		receiver_hint.text="%s · 강화 %d/3" % [receiver.name,level] if not receiver.is_empty() else "강화 대상 선택"
		var used=session.place_visit_id("ritual",index) in session.world.reward_receipts
		confirm_button.disabled=busy or completed or used or donor.is_empty() or receiver.is_empty() or level>=3
		if not completed: status.text="이번 방문의 의식은 완료했습니다" if used else ("강화 한도 3회에 도달했습니다" if level>=3 else "재물을 먼저 고른 뒤 강화할 마물을 선택하세요")
	else:
		status.text="상품을 선택하고 한 번 더 누르면 마물을 소모해 교환합니다" if not offers.is_empty() else "아래에서 교환할 마물을 선택하세요 · 마지막 마물은 교환할 수 없습니다"
	for id in unit_options:
		unit_options[id].modulate=Color.WHITE if id in [donor_id,receiver_id] else Color(0.76,0.70,0.61)

func render_offers() -> void:
	for node in offer_area.get_children(): offer_area.remove_child(node); node.queue_free()
	offer_options=[]
	for i in range(offers.size()):
		var offer=offers[i]
		var option=card(offer_area,offer.kind,offer.item,Vector2(390+i*145,140),Vector2(112,168),func(): choose_offer(i))
		option.disabled=busy or (offer.kind=="dice" and session.world.dice_cards.size()>=Catalog.DICE_CAPACITY)
		option.modulate=Color.WHITE if i==chosen or chosen<0 else Color(0.5,0.5,0.5)
		offer_options.append(option)

func choose_offer(i: int) -> void:
	if busy: return
	if chosen!=i: chosen=i; render_offers(); status.text="한 번 더 누르면 거래 확정 · 재물 마물은 영구 소멸합니다"; return
	busy=true
	var result=session.shop_trade(index,donor_id,i)
	busy=false
	if result.ok:
		donor_id=""; offers=[]; chosen=-1
		render_offers()
		build_hand()
		refresh()
	status.text=result.reason

func perform_ritual() -> void:
	if busy or completed: return
	busy=true
	var result=session.altar_ritual(index,donor_id,receiver_id)
	busy=false
	if result.ok:
		completed=true
		donor_id=""
		build_hand()
		refresh()
	status.text=result.reason

func roll_prophecy() -> void:
	if busy: return
	var result=session.fortune_prophecy(index)
	if not result.ok: status.text=result.reason; return
	busy=true
	close_button.disabled=true
	confirm_button.disabled=true
	status.text="예언의 주사위를 굴리는 중…"
	await DiceAnimation.new().roll_map(dice,int(result.face),Rect2(300,140,680,245),map.texture,map.sound)
	dice.position=Vector2(610,245)
	dice.rotation=0
	status.text=result.reason
	if int(result.face)==2: await map.presentation.full_heal()
	close_button.disabled=false
	busy=false

func card(parent: Control, kind: String, item: Dictionary, pos: Vector2, dimensions: Vector2, callback: Callable) -> TextureButton:
	var option = super.card(parent,kind,item,pos,dimensions,callback)
	add_button_effect(option)
	return option
