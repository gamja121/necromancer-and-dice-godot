extends "res://systems/place_actions.gd"
## Approved sacrifice-first preview connected to real saved transactions.
const Fire = preload("res://systems/altar_sacrifice_fire.gd")
var content: Control
var boon_title: Label
var boon_value: Label
var instruction: Label
var result_boon: Dictionary = {}
var result_receiver: Dictionary = {}
var result_before: Dictionary = {}
var effect: Control

func setup(map_scene, tile_index: int) -> void:
	map=map_scene
	session=map.session
	index=tile_index
	type="altar"
	z_index=85
	backdrop()
	map.location_scene_image(self,"res://assets/map/events/altar.jpg")
	redraw_flow()

func text(parent:Control, value:String, pos:Vector2, dimensions:Vector2, points:int=18, ink:Color=Color("efd9ac")) -> Label:
	var node=label_at(parent,value,pos,dimensions,points)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.add_theme_color_override("font_color",ink)
	node.add_theme_color_override("font_shadow_color",Color("24180f") if ink.get_luminance()>0.5 else Color.TRANSPARENT)
	return node

func action(value:String, pos:Vector2, dimensions:Vector2, callback:Callable) -> Button:
	var node=button(content,value,pos,dimensions,callback)
	var atlas=AtlasTexture.new()
	atlas.atlas=load("res://assets/map/ui/routine_choice_button_v1.png")
	atlas.region=Rect2(29,221,2131,273)
	atlas.filter_clip=true
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style=StyleBoxTexture.new()
		style.texture=atlas
		style.modulate_color=Color(0.65,0.61,0.55) if state=="disabled" else Color.WHITE
		node.add_theme_stylebox_override(state,style)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		node.add_theme_color_override(state,Color("38291b"))
	node.add_theme_color_override("font_disabled_color",Color("72634e"))
	node.add_theme_font_size_override("font_size",18)
	return node

func single_slot(pos:Vector2, dimensions:Vector2) -> TextureRect:
	var node=art(content,ALTAR_SLOTS_PATH,pos,dimensions)
	var atlas=AtlasTexture.new()
	atlas.atlas=node.texture
	var original:Vector2=atlas.atlas.get_size()
	atlas.region=Rect2(original.x*0.125,0,original.x*0.355,original.y)
	atlas.filter_clip=true
	node.texture=atlas
	node.name="AltarRitualSlots"
	return node

func redraw_flow() -> void:
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content=Control.new()
	content.size=Vector2(1280,720)
	content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var pending:Dictionary=session.altar_boon(index)
	var used:bool=session.place_visit_id("ritual",index) in session.world.reward_receipts
	completed=used
	var revealed:bool=not pending.is_empty() or not result_boon.is_empty()
	var boon:Dictionary=pending.get("boon",result_boon)
	var active_stage:int=2 if completed or not receiver_id.is_empty() else (1 if revealed else 0)
	for i in range(3):
		text(content,["1  제물 선택","2  축복 공개","3  대상 선택"][i],Vector2(310+i*220,70),Vector2(210,32),19,Color("f0cf80") if i==active_stage else Color("a3977e"))
	close_button=action("← 돌아가기" if pending.is_empty() else "의식 보류",Vector2(1100,24),Vector2(145,42),request_exit)
	close_button.name="AltarExit"
	if revealed:
		altar_info=art(content,ALTAR_INFO_PATH,Vector2(220,137),Vector2(560,253))
		altar_info.name="AltarRitualInfo"
		altar_info.stretch_mode=TextureRect.STRETCH_SCALE
		boon_title=text(content,"초대박 · 세 가지 축복" if bool(boon.get("jackpot",false)) else "제단의 응답",Vector2(270,163),Vector2(460,40),24,Color("684316"))
		boon_title.name="AltarBoonTitle"
		boon_value=text(content,boon_text(boon),Vector2(270,210),Vector2(460,106),32 if bool(boon.get("jackpot",false)) else 44,Color("352316"))
		boon_value.name="AltarBoonValue"
		text(content,"한 카드에 세 효과가 모두 적용됩니다" if bool(boon.get("jackpot",false)) else "이 효과를 받을 카드를 선택하세요",Vector2(270,324),Vector2(460,34),16,Color("58412b"))
		altar_slots=single_slot(Vector2(810,110),Vector2(250,292))
		receiver_art=LayeredUnitCard.make_preview(content,{},Vector2(860,142),Vector2(151,211))
		receiver_art.name="AltarTargetCard"
		var receiver:Dictionary=result_receiver if completed else session.owned_unit(receiver_id)
		LayeredUnitCard.sync_preview(receiver_art,receiver)
		AltarUpgradeBadge.sync(receiver_art,receiver)
		receiver_hint=text(content,"강화 대상 선택" if receiver.is_empty() else "강화 대상 · %s"%str(receiver.name),Vector2(785,371),Vector2(300,30),17)
		receiver_hint.name="AltarTargetHint"
		if receiver.is_empty():
			text(content,"강화할 마물\n선택",Vector2(855,181),Vector2(160,110),23)
		var preview=art(content,ALTAR_INFO_PATH,Vector2(220,398),Vector2(670,96))
		preview.stretch_mode=TextureRect.STRETCH_SCALE
		var summary:String="아래에서 강화할 마물을 선택하세요"
		var prior:Dictionary=result_before if completed and not result_before.is_empty() else receiver
		if not receiver.is_empty():
			summary="공격 %d → %d · 체력 %d → %d · 속도 %d → %d"%[
				int(prior.attack),int(receiver.attack)+(0 if completed else int(boon.get("attack",0))),
				int(prior.max_hp),int(receiver.max_hp)+(0 if completed else int(boon.get("hp",0))),
				int(prior.speed),int(receiver.speed)+(0 if completed else int(boon.get("speed",0)))]
		text(content,summary,Vector2(252,410),Vector2(606,40),17,Color("4c3520"))
		var level:int=int(receiver.get("altar_enhancements",0))
		altar_level=text(content,"강화 완료 · %d/3"%level if completed else ("강화 %d/3 → %d/3"%[level,level+1] if not receiver.is_empty() else "강화 한도 3회 · 결과는 저장됩니다"),Vector2(280,454),Vector2(550,24),14,Color("755231"))
		altar_level.name="AltarRitualLevel"
		confirm_button=action("강화 완료" if completed else "이 카드에 축복 적용",Vector2(922,425),Vector2(280,49),perform_ritual)
		confirm_button.name="AltarRitualConfirm"
		status=text(content,"강화 완료" if completed else "제물은 바쳐졌습니다. 축복을 받을 마물을 고르세요.",Vector2(250,498),Vector2(780,36),18)
		donor_art=null
	else:
		altar_slots=single_slot(Vector2(462,100),Vector2(356,316))
		donor_art=LayeredUnitCard.make_preview(content,{},Vector2(553,136),Vector2(174,231))
		donor_art.name="AltarMaterialCard"
		var donor:Dictionary=session.owned_unit(donor_id)
		LayeredUnitCard.sync_preview(donor_art,donor)
		AltarUpgradeBadge.sync(donor_art,donor)
		donor_hint=text(content,"제물을 선택하세요" if donor.is_empty() else "제물 · %s"%str(donor.name),Vector2(455,390),Vector2(370,31),19)
		donor_hint.name="AltarMaterialHint"
		altar_info=art(content,ALTAR_INFO_PATH,Vector2(220,424),Vector2(840,102))
		altar_info.name="AltarRitualInfo"
		altar_info.stretch_mode=TextureRect.STRETCH_SCALE
		status=text(content,"이번 방문의 의식은 완료했습니다" if used else "제물을 바치면 영구 소멸하고 무작위 축복이 공개됩니다.",Vector2(265,433),Vector2(750,31),17,Color("4c3520"))
		confirm_button=action("의식 완료" if used else "제물로 바치고 축복 받기",Vector2(470,474),Vector2(340,44),perform_ritual)
		confirm_button.name="AltarRitualConfirm"
		altar_level=text(content,"강화 대상은 축복을 확인한 뒤 선택합니다",Vector2(300,526),Vector2(680,25),16)
		altar_level.name="AltarRitualLevel"
		receiver_art=null
	build_hand()
	refresh()

func build_hand() -> void:
	if is_instance_valid(hand):
		hand.get_parent().remove_child(hand)
		hand.queue_free()
	hand=Control.new()
	hand.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content.add_child(hand)
	unit_options={}
	altar_scroll=ScrollContainer.new()
	altar_scroll.position=Vector2(192,555)
	altar_scroll.size=Vector2(896,156)
	altar_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	hand.add_child(altar_scroll)
	var row=HBoxContainer.new()
	row.custom_minimum_size.x=880
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",20)
	altar_scroll.add_child(row)
	for unit in session.world.roster:
		var box=Control.new()
		box.custom_minimum_size=Vector2(120,150)
		row.add_child(box)
		var id:String=str(unit.id)
		var option=card(box,"unit",unit,Vector2(12,0),Vector2(96,139),func():select_unit(id))
		# The composed live card already includes its name.
		ShopWindowVisual.hide_duplicate_caption(option)
		unit_options[id]=option

func can_offer(id:String) -> bool:
	if session.world.roster.size()<2: return false
	for unit in session.world.roster:
		if str(unit.id)!=id and int(unit.get("altar_enhancements",0))<3: return true
	return false

func select_unit(id:String) -> void:
	if busy or completed or not unit_options.has(id) or unit_options[id].disabled: return
	if session.altar_boon(index).is_empty():
		donor_id="" if donor_id==id else id
	else:
		receiver_id="" if receiver_id==id else id
	redraw_flow()

func refresh() -> void:
	var pending:Dictionary=session.altar_boon(index)
	var used:bool=session.place_visit_id("ritual",index) in session.world.reward_receipts
	var here:bool=session.world.position==index and session.world.tiles[index]=="altar"
	close_button.disabled=busy
	for id in unit_options:
		var unit:Dictionary=session.owned_unit(id)
		var eligible:bool=can_offer(id) if pending.is_empty() else int(unit.get("altar_enhancements",0))<3
		unit_options[id].disabled=busy or used or not here or not eligible
		var selected:bool=id==donor_id if pending.is_empty() else id==receiver_id
		unit_options[id].modulate=Color.WHITE if selected else Color(0.72,0.67,0.59)
		if not eligible: unit_options[id].tooltip_text+=" · 강화 한도 또는 남은 대상 확인"
	var valid:bool=not donor_id.is_empty() and can_offer(donor_id) if pending.is_empty() else not receiver_id.is_empty() and not session.owned_unit(receiver_id).is_empty() and int(session.owned_unit(receiver_id).get("altar_enhancements",0))<3
	confirm_button.disabled=busy or used or not here or not valid
	if not here: status.text="현재 제단에 도착했을 때만 의식할 수 있습니다."
	elif not used and pending.is_empty() and session.world.roster.size()<2: status.text="마물이 2마리 이상 있어야 사용할 수 있습니다"
	elif not used and pending.is_empty():
		var any_target:bool=false
		for unit in session.world.roster:
			if int(unit.get("altar_enhancements",0))<3: any_target=true
		if not any_target: status.text="모든 마물이 강화 한도 3회에 도달했습니다"

func request_exit() -> void:
	if busy: return
	busy=true
	closed.emit()

func perform_ritual() -> void:
	if busy or completed or confirm_button.disabled: return
	if not session.altar_boon(index).is_empty():
		var prior:Dictionary=session.owned_unit(receiver_id).duplicate(true)
		var applied:Dictionary=session.altar_apply_boon(index,receiver_id)
		if not applied.get("ok",false):
			status.text=str(applied.get("reason","강화 저장 실패"))
			return
		result_before=prior
		result_boon=applied.boon
		result_receiver=applied.receiver
		completed=true
		Sound.cue(map,"ritual_complete")
		map.queue_used_location_paper(index,"ritual")
		redraw_flow()
		status.text="강화 완료 · %s"%str(applied.receiver.name)
		return
	var sacrificed:Dictionary=session.altar_sacrifice(index,donor_id)
	if not sacrificed.get("ok",false):
		status.text=str(sacrificed.get("reason","제물 저장 실패"))
		return
	busy=true
	refresh()
	status.text="제물을 바치는 중…"
	var hand_card:Control=unit_options.get(donor_id)
	if is_instance_valid(hand_card): hand_card.hide()
	effect=Fire.new()
	effect.name="AltarSacrificeFire"
	add_child(effect)
	var original_world:WeakRef=weakref(session.world)
	var visit:String=session.place_visit_id("ritual",index)
	effect.finished.connect(func():
		if not is_instance_valid(effect) or not effect.completed: return
		if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(map) or map.overlay!=self or original_world.get_ref()!=session.world or session.place_visit_id("ritual",index)!=visit: return
		busy=false
		donor_id=""
		redraw_flow()
		if is_instance_valid(effect): effect.queue_free()
	,CONNECT_ONE_SHOT)
	effect.play(donor_art,sacrificed.donor)

static func boon_text(boon:Dictionary) -> String:
	var parts:Array[String]=[]
	if int(boon.get("attack",0))>0: parts.append("공격력 +%d"%int(boon.attack))
	if int(boon.get("hp",0))>0: parts.append("체력 +%d"%int(boon.hp))
	if int(boon.get("speed",0))>0: parts.append("속도 +%d"%int(boon.speed))
	return "\n".join(parts)