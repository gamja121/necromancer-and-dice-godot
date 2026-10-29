extends "res://systems/reward_ui.gd"
const Sound = preload("res://systems/game_audio.gd")
signal closed
const DiceAnimation = preload("res://systems/dice_animation.gd")
const ShopWindowVisual = preload("res://systems/shop_window_visual.gd")
const ProphecyInkEffect=preload("res://systems/prophecy_ink_effect.gd")
const FORTUNE_STRIP_PATH = "res://assets/map/ui/fortune_parchment_strip.webp"
const ALTAR_SLOTS_PATH = "res://assets/map/events/altar-ritual-slots.png"
const ALTAR_INFO_PATH = "res://assets/map/events/altar-ritual-info.png"
const ALTAR_SLOTS_RECT = Rect2(192.0,36.0,896.0,403.2)
const ALTAR_INFO_RECT = Rect2(384.0,309.6,512.0,176.0)
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
var fortune_effect:Control
var unit_options: Dictionary = {}
var offer_options: Array = []
var shop_window: TextureRect
var shop_remaining: Label
var shop_summary: Label
var shop_empty_hint: Label
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
	elif type=="fortune-teller-camp":
		status=label_at(self,"",Vector2.ZERO,Vector2.ONE,20)
		close_button=map.location_button(self,"맵으로 나가기",map.TILE_EVENT_EXIT_RECT.position,map.TILE_EVENT_EXIT_RECT.size,request_fortune_exit,4)
		close_button.name="FortuneExitToMap"
		setup_fortune_result()
		dice=map.dice
		fortune_effect=ProphecyInkEffect.new()
		add_child(fortune_effect)
		fortune_effect.setup(dice)
		show_fortune_state()
		map.refresh_shared_die_input()
		return
	else:
		label_at(self,"제단 · 피의 의식",Vector2(290,22),Vector2(700,40),24)
		close_button=button(self,"← 돌아가기",Vector2(1100,26),Vector2(110,38),func(): if not busy: closed.emit())
		status=label_at(self,"",Vector2(130,435),Vector2(1020,58),15)
		status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
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
	altar_slots.set_meta("ui_custom_open_motion",true)
	altar_info.set_meta("ui_custom_open_motion",true)
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
		hand.set_meta("ui_custom_open_motion",true)
		hand.position=Vector2(0,170)
		hand.modulate.a=0.0
		enter.tween_property(hand,"position",Vector2.ZERO,0.68).set_delay(0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		enter.tween_property(hand,"modulate:a",1.0,0.68).set_delay(0.16)

# Only the village uses this window; altar and prophecy keep their own art.
func setup_shop_visual() -> void:
	shop_window=art(self,ShopWindowVisual.FRAME_PATH,ShopWindowVisual.FRAME_RECT.position,ShopWindowVisual.FRAME_RECT.size)
	shop_window.name="ShopWindowFrame"
	var frame_texture=AtlasTexture.new()
	frame_texture.atlas=load(ShopWindowVisual.FRAME_PATH)
	frame_texture.region=ShopWindowVisual.FRAME_SOURCE_RECT
	shop_window.texture=frame_texture
	shop_window.stretch_mode=TextureRect.STRETCH_SCALE
	label_at(self,"마물 상점",Vector2(430,62),Vector2(420,40),28)
	shop_remaining=label_at(self,"",Vector2(932,74),Vector2(202,26),16)
	shop_remaining.name="ShopTradesRemaining"
	ShopWindowVisual.line(self,Rect2(132,116,1016,1))
	ShopWindowVisual.line(self,Rect2(415,135,1,308))
	ShopWindowVisual.line(self,Rect2(132,453,1016,1))
	ShopWindowVisual.line(self,Rect2(132,626,1016,1))
	label_at(self,"내놓을 마물",Vector2(145,127),Vector2(208,28),18)
	label_at(self,"상인의 제안",Vector2(468,127),Vector2(666,28),18)
	label_at(self,"보유 마물",Vector2(146,457),Vector2(150,24),16).horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	donor_art=LayeredUnitCard.make_preview(self,{},Vector2(164,164),Vector2(166,211))
	donor_art.name="ShopDonorCard"
	donor_art.texture=null
	donor_hint=label_at(self,"아래에서 마물 선택",Vector2(145,380),Vector2(208,24),14)
	shop_cancel_button=button(self,"다시 선택",Vector2(170,409),Vector2(154,32),reset_shop_selection)
	shop_cancel_button.name="ShopResetSelection"
	ShopWindowVisual.style_button(shop_cancel_button)
	shop_confirm_button=button(self,"교환 확정",Vector2(960,632),Vector2(176,38),confirm_shop_trade)
	shop_confirm_button.name="ShopTradeConfirm"
	shop_confirm_button.disabled=true
	ShopWindowVisual.style_button(shop_confirm_button,true)
	shop_offer_scroll=ScrollContainer.new()
	shop_offer_scroll.position=Vector2(468,166)
	shop_offer_scroll.size=Vector2(666,242)
	shop_offer_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	shop_offer_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(shop_offer_scroll)
	var row=HBoxContainer.new()
	row.custom_minimum_size.x=666
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",26)
	shop_offer_scroll.add_child(row)
	offer_area=row
	shop_empty_hint=label_at(self,"내놓을 마물을 고르면\n교환할 카드 3장이 나타납니다.",Vector2(488,232),Vector2(626,90),19)
	shop_empty_hint.name="ShopEmptyOffers"
	shop_summary=label_at(self,"",Vector2(468,410),Vector2(666,30),16)
	shop_summary.name="ShopTradeSummary"
	shop_summary.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	status=label_at(self,"",Vector2(142,634),Vector2(610,32),13)
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	close_button=button(self,"나가기",Vector2(802,632),Vector2(144,38),func(): if not busy: closed.emit())
	close_button.name="ShopExit"
	ShopWindowVisual.style_button(close_button)

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
	scroll.position=Vector2(140,480) if type=="village" else Vector2(192,532)
	scroll.size=Vector2(1000,144) if type=="village" else Vector2(896,220)
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	if type=="altar": altar_scroll=scroll
	hand.add_child(scroll)
	var row=HBoxContainer.new()
	row.custom_minimum_size.x=1000 if type=="village" else 880
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",16)
	scroll.add_child(row)
	for unit in session.world.roster:
		var box=Control.new()
		box.custom_minimum_size=Vector2(120,136) if type=="village" else Vector2(110,184)
		row.add_child(box)
		var id=str(unit.id)
		var option=card(box,"unit",unit,Vector2(12,6) if type=="village" else Vector2(4,0),Vector2(96,122) if type=="village" else Vector2(96,139),func(): select_unit(id))
		if type=="village":
			ShopWindowVisual.hide_duplicate_caption(option)
			ShopWindowVisual.select_card(option,id==donor_id)
		unit_options[id]=option
	if session.world.roster.size()<2 and type=="altar": label_at(hand,"마물이 2마리 이상 있어야 사용할 수 있습니다",Vector2(280,595),Vector2(720,40),18)

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
		var remaining:int=session.shop_trades_remaining(index)
		shop_remaining.text="남은 거래 %d / 3" % remaining
		shop_empty_hint.visible=offers.is_empty()
		shop_empty_hint.text="이번 방문의 거래를 모두 마쳤습니다." if remaining<=0 else "내놓을 마물을 고르면\n교환할 카드 3장이 나타납니다."
		shop_summary.text=""
		if chosen>=0 and chosen<offers.size() and not donor.is_empty():
			shop_summary.text="%s → %s" % [str(donor.name),Catalog.label(offers[chosen].kind,offers[chosen].item)]
		shop_summary.tooltip_text=shop_summary.text
		status.text="이번 방문의 거래 3회를 모두 마쳤습니다." if remaining<=0 else ("상품을 고른 뒤 교환 확정 · 내놓은 마물은 사라집니다." if not donor.is_empty() else "아래에서 내놓을 마물을 고르세요. 마지막 마물은 교환할 수 없습니다.")
		if is_instance_valid(shop_confirm_button): shop_confirm_button.disabled=busy or remaining<=0 or donor.is_empty() or chosen<0 or chosen>=offers.size()
		if is_instance_valid(shop_cancel_button):
			shop_cancel_button.visible=not donor.is_empty()
			shop_cancel_button.disabled=busy
	for id in unit_options:
		if type=="village":
			ShopWindowVisual.select_card(unit_options[id],id==donor_id)
			unit_options[id].disabled=busy or session.shop_trades_remaining(index)<=0 or session.world.roster.size()<2
		else:
			unit_options[id].modulate=Color.WHITE if id in [donor_id,receiver_id] else Color(0.76,0.70,0.61)

func render_offers() -> void:
	for node in offer_area.get_children(): offer_area.remove_child(node); node.queue_free()
	offer_options=[]
	for i in range(mini(offers.size(),3)):
		var offer=offers[i]
		var parent: Control=offer_area
		var pos=Vector2(390+i*145,140)
		var dims=Vector2(112,168)
		if type=="village":
			var slot=Control.new()
			slot.custom_minimum_size=Vector2(198,238)
			offer_area.add_child(slot)
			parent=slot
			pos=Vector2(16,6)
			dims=Vector2(166,211)
		var option=card(parent,offer.kind,offer.item,pos,dims,func(): choose_offer(i))
		if type=="village":
			ShopWindowVisual.hide_duplicate_caption(option)
		option.disabled=busy or (offer.kind=="dice" and session.world.dice_cards.size()>=Catalog.DICE_CAPACITY)
		if type=="village":
			ShopWindowVisual.select_card(option,i==chosen)
			if option.disabled:
				option.modulate=Color(0.5,0.5,0.5)
				option.tooltip_text+=" · 주사위 카드 보관함이 가득 찼습니다."
		else:
			option.modulate=Color.WHITE if i==chosen or chosen<0 else Color(0.5,0.5,0.5)
		offer_options.append(option)
	if is_instance_valid(shop_confirm_button): shop_confirm_button.disabled=busy or session.shop_trades_remaining(index)<=0 or donor_id.is_empty() or chosen<0 or chosen>=offer_options.size()

func choose_offer(i: int) -> void:
	if busy or donor_id.is_empty() or i<0 or i>=offer_options.size(): return
	if offer_options[i].disabled: return
	chosen=i
	render_offers()
	refresh()

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

func fortune_availability() -> Dictionary:
	if type!="fortune-teller-camp" or session==null or session.world==null:
		return {"ok":false,"reason":"예언을 확인할 수 없습니다."}
	if not is_instance_valid(map) or map.world!=session.world or map.overlay!=self:
		return {"ok":false,"reason":"현재 예언 화면에서만 주사위를 누를 수 있습니다."}
	var transition:Node=get_node_or_null("PanelEffectsModule")
	if transition!=null and transition.closing:
		return {"ok":false,"reason":"맵으로 돌아가는 중입니다."}
	var allowed:Dictionary=session.place_allowed(index,"fortune-teller-camp")
	if not bool(allowed.get("ok",false)): return allowed
	if session.world.position!=index:
		return {"ok":false,"reason":"현재 막사에 도착했을 때만 예언할 수 있습니다."}
	if session.place_visit_id("prophecy",index) in session.world.reward_receipts:
		return {"ok":false,"reason":"이번 방문의 예언은 완료했습니다."}
	if busy or not is_instance_valid(map) or map.overlay!=self or map.moving or map.shared_die_busy:
		return {"ok":false,"reason":"예언을 확인하는 중입니다."}
	return {"ok":true}

func fortune_can_roll() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and bool(fortune_availability().get("ok",false))

func refresh_fortune_input() -> void:
	if not is_instance_valid(dice): return
	var allowed:Dictionary=fortune_availability()
	dice.disabled=not fortune_can_roll()
	# A used die must not cover the common exit if it stopped above it.
	dice.mouse_filter=Control.MOUSE_FILTER_IGNORE if dice.disabled else Control.MOUSE_FILTER_STOP
	dice.tooltip_text="예언 주사위 · 이동 없음 · 방문당 1회" if not dice.disabled else str(allowed.get("reason","이번 방문의 예언은 완료했습니다."))
	if is_instance_valid(fortune_effect): fortune_effect.set_available(not dice.disabled)

func request_fortune_exit() -> void:
	if busy: return
	busy=true
	close_button.disabled=true
	refresh_fortune_input()
	closed.emit()

func show_fortune_state() -> void:
	var visit:String=session.place_visit_id("prophecy",index)
	var used:bool=visit in session.world.reward_receipts
	fortune_result.visible=true
	if used:
		var saved:Dictionary=session.world.last_prophecy
		if str(saved.get("visit",""))==visit:
			var face:int=int(saved.get("face",0))
			status.text="예언 완료 · "+str(saved.get("detail","이번 방문의 예언은 완료했습니다")).replace("다음 전투 ","")
			if face==2: status.text=status.text.replace("아군 전체 ","아군 전체 즉시 ")
			if face>=1 and face<=6 and session.world.position==index:
				dice.texture_normal=map.texture("res://assets/battle/dice/result-%02d.png"%face)
		else:
			status.text="이번 방문의 예언은 완료했습니다"
		show_fortune_result()
	else:
		status.text="주사위를 눌러 예언을 확인하세요"
		fortune_result.text="이동 없음 · 방문당 1회 · 1 저주 / 2 즉시 회복 / 3~6 축복"
		fortune_result.tooltip_text="회복은 즉시 적용되며, 그 외 효과는 다음 전투 시작 때 한 번 적용됩니다.\n이동하거나 주사위 제어 카드를 소모하지 않습니다."
		var allowed:Dictionary=fortune_availability()
		if not bool(allowed.get("ok",false)):
			status.text="지금은 예언을 확인할 수 없습니다"
			fortune_result.text=str(allowed.get("reason","진행 중인 일을 먼저 마쳐주세요."))
	status.visible_ratio=1.0
	fortune_result.visible_ratio=1.0
	fit_fortune_total()
	call_deferred("fit_fortune_total")
	refresh_fortune_input()

func show_fortune_result() -> void:
	if not is_instance_valid(fortune_result): return
	var parts:Array[String]=[]
	for pair in [["ally_attack","공격"],["ally_hp","체력"],["ally_speed","속도"],["enemy_attack","적 공격"]]:
		var value:int=int(session.world.prophecy.get(pair[0],0))
		if value>0: parts.append("%s +%d"%[pair[1],value])
	fortune_result.text="다음 전투 합계: "+(" · ".join(parts) if not parts.is_empty() else "없음")
	fortune_result.tooltip_text="다음 전투 시작 때 한 번 적용: "+session.prophecy_label()
	fit_fortune_total()
	# The shared typography pass runs after controls enter the tree.
	call_deferred("fit_fortune_total")
	fortune_result.visible=true

func fit_fortune_total() -> void:
	if not is_instance_valid(fortune_result): return
	var font:Font=fortune_result.get_theme_font("font")
	var width:float=font.get_string_size(fortune_result.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	fortune_result.add_theme_font_size_override("font_size",14 if width<=fortune_result.size.x else 12)

static func fortune_context_alive(owner_ref:WeakRef,map_ref:WeakRef,world_ref:WeakRef,visit:String) -> bool:
	var owner:Node=owner_ref.get_ref()
	var scene:Node=map_ref.get_ref()
	if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion(): return false
	if not is_instance_valid(scene) or not scene.is_inside_tree() or scene.is_queued_for_deletion() or scene.overlay!=owner: return false
	return scene.session.world!=null and scene.session.world==world_ref.get_ref() and scene.session.place_visit_id("prophecy",owner.index)==visit

func roll_prophecy() -> void:
	if not fortune_can_roll(): return
	var owner_ref:WeakRef=weakref(self)
	var map_ref:WeakRef=weakref(map)
	var world_ref:WeakRef=weakref(session.world)
	var visit:String=session.place_visit_id("prophecy",index)
	var result:Dictionary=session.fortune_prophecy(index)
	if not bool(result.get("ok",false)):
		status.text="예언을 저장하지 못했습니다"
		fortune_result.text="다시 주사위를 누르거나 맵으로 나갈 수 있습니다"
		refresh_fortune_input()
		return
	busy=true
	close_button.disabled=true
	fortune_effect.set_available(false)
	status.text="예언의 주사위를 굴리는 중…"
	fortune_result.text="이동하지 않습니다 · 이번 방문의 예언을 확인 중"
	await map.roll_shared_die(int(result.face))
	if not fortune_context_alive(owner_ref,map_ref,world_ref,visit): return
	Sound.cue(map,"prophecy_curse" if int(result.face)==1 else ("recovery" if int(result.face)==2 else "prophecy_bless"))
	show_fortune_state()
	fortune_effect.play(status,fortune_result,int(result.face))
	if int(result.face)==2:
		await map.presentation.full_heal()
		if not fortune_context_alive(owner_ref,map_ref,world_ref,visit): return
	var tree:SceneTree=get_tree()
	while fortune_effect.active:
		await tree.process_frame
		if not fortune_context_alive(owner_ref,map_ref,world_ref,visit): return
	close_button.disabled=false
	busy=false
	map.refresh_shared_die_input()

func _exit_tree() -> void:
	if type!="fortune-teller-camp": return
	if is_instance_valid(map) and not map.is_queued_for_deletion():
		if is_instance_valid(dice) and (map.overlay==self or not is_instance_valid(map.overlay)):
			dice.tooltip_text="주사위 · 멈춘 자리에서 다시 누르기"
		map.call_deferred("_clear_detached_location_overlay",weakref(self))


func card(parent: Control, kind: String, item: Dictionary, pos: Vector2, dimensions: Vector2, callback: Callable) -> TextureButton:
	var option = super.card(parent,kind,item,pos,dimensions,callback)
	# Shop selection owns whole-card scale; the generic click/hover module
	# restores its own base scale and would otherwise erase that selection.
	if type!="village": add_button_effect(option)
	return option
