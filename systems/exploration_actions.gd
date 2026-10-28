extends "res://systems/reward_ui.gd"
const Sound = preload("res://systems/game_audio.gd")
const HillRoutePicker=preload("res://systems/hill_route_picker.gd")
const GraveyardMotion=preload("res://systems/graveyard_reward_motion.gd")
const LocationNoticeStrip=preload("res://systems/location_notice_strip.gd")
signal closed
signal leave_to_map
signal hill_route_chosen(steps: int)
const PrayerEffect = preload("res://systems/world_tree_prayer_effect.gd")
const RoutePlan = preload("res://systems/route_plan.gd")
const PatrolRouteEditor = preload("res://systems/patrol_route_editor.gd")
const UnlockNoticeBadge = preload("res://systems/unlock_notice_badge.gd")
const ROUTE_RESERVE_ART = "res://assets/map/ui/patrol-route-frame.webp"
const ROUTE_CURRENT_ART = "res://assets/map/ui/patrol-route-current-frame.webp"
const PATROL_ENTER_PARCHMENT = "res://assets/map/events/enter-parchment.png"
const PATROL_EXIT_PARCHMENT = "res://assets/map/events/exit-parchment.png"
const GRAVEYARD_PARCHMENT_STRIP = "res://assets/map/ui/fortune_parchment_strip.webp"
const MapState = preload("res://systems/map_state.gd")
const Discovery = preload("res://systems/location_discoveries.gd")
const DiceAnimation = preload("res://systems/dice_animation.gd")
const RewardOverflow = preload("res://systems/reward_overflow.gd")
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
var graveyard_result: Dictionary = {}
var graveyard_message: String = ""
var graveyard_phase: String = "idle"
var graveyard_motion:Control
var graveyard_notice:Label
var graveyard_detail:Label
var graveyard_count_before:int=0
var graveyard_overflow: Control
var plan: Dictionary = {}
var selected_current = -1
var selected_reserve = -1
var current_options: Array = []
var reserve_options: Array = []
var route_plus_buttons: Dictionary = {}
var route_minus_buttons: Dictionary = {}
var route_count_labels: Dictionary = {}
var route_unlock_button: Button
var route_editor: Control
var route_feedback: String=""
var selected_route_slot: int = 0
# UI-only slot order; the existing save format still stores per-kind counts.
var route_slot_layout: Array[String] = []
var hill_picker:Control
var hill_notice:Label
var hill_detail:Label
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
	if type=="home":
		plan=session.world.patrol_plan.duplicate(true) if RoutePlan.is_new(session.world.patrol_plan) else RoutePlan.default_plan()
		if not plan.selection.has("forest"): plan.selection["forest"]=0
		initialize_route_slot_layout()
		route_editor=PatrolRouteEditor.new()
		add_child(route_editor)
		route_editor.setup(self)
		content=route_editor
		status=route_editor.status_label
		close_button=route_editor.back_button
		action_button=route_editor.confirm_button
		route_reset_button=route_editor.reset_button
		route_plus_buttons=route_editor.plus_buttons
		route_minus_buttons=route_editor.minus_buttons
		route_count_labels=route_editor.count_labels
		route_unlock_button=route_editor.unlock_button
		map.refresh_shared_die_input()
		return
	if type not in ["graveyard","forest"]:
		label_at(self,{"unknown":"세계수 · 정화 기도","forest":"언덕 · 이동 경로 선택","home":"우리집 · 순찰경로"}[type],Vector2(290,22),Vector2(700,40),24)
		close_button=button(self,"← 돌아가기",Vector2(1100,26),Vector2(110,38),func(): if not busy: closed.emit())
	status=label_at(self,"",Vector2(130,555),Vector2(1020,60),15)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content=Control.new()
	add_child(content)
	if type=="unknown":
		# World-tree prayers use the same full-stage die at its last rest pose.
		# No local decorative copy is created and nothing snaps to (610,245).
		dice=map.dice
		# The existing board die starts prayer; no second action control.
		status.text="정화 기도를 하려면 주사위를 누르세요.\n방문당 1회 · 1~3 실패(+1) · 4~5 축복(-3) · 6 대축복(-5) · 오염 %d/100" % session.world.contamination
		var saved=session.world.prayer_result
		if saved.get("visit","")==session.place_visit_id("purify",index):
			status.text="기도 결과 %d · 오염도 %+d · 현재 %d/100" % [int(saved.face),int(saved.delta),session.world.contamination]
	elif type=="graveyard":
		status.hide()
		graveyard_count_before=session.world.dice_cards.size()
		if str(session.world.pending_reward.get("kind",""))=="grave-dig":
			graveyard_result=session.world.pending_reward.reward.item.duplicate(true)
			graveyard_phase="ready"
		render_graveyard()
	elif type=="forest":
		status.hide()
		render_hill_choices()
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
	if type!="home" or session.patrol_edit_locked(): return
	route_feedback=""
	# Reset selection only. The user's earned unlock is irreversible.
	var unlocked: bool=bool(session.world.patrol_plan.get("rest_unlocked",false))
	plan=RoutePlan.default_plan()
	plan["rest_unlocked"]=unlocked
	plan["rest_discovered"]=bool(session.world.patrol_plan.get("rest_discovered",false))
	selected_current=-1
	selected_reserve=-1
	selected_route_slot=0
	initialize_route_slot_layout()
	render_route()

func clear_content() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()

## The ordinary cemetery is one screen: saved dig -> reveal -> collect.
func render_graveyard() -> void:
	clear_content()
	if is_instance_valid(graveyard_motion):
		graveyard_motion.cancel()
		graveyard_motion.queue_free()
	graveyard_motion=null
	var used:bool=session.place_visit_id("grave-extract",index) in session.world.reward_receipts
	var found:bool=not graveyard_result.is_empty()
	var shared:Dictionary=LocationNoticeStrip.build(content)
	var ribbon:TextureRect=shared.strip
	ribbon.name="GraveyardNoticeStrip"
	graveyard_notice=shared.text
	graveyard_notice.name="GraveyardNoticeText"
	graveyard_detail=shared.detail
	graveyard_detail.name="GraveyardNoticeDetail"
	graveyard_detail.text="방문당 1회 · 주사위 제어 카드 1장"
	graveyard_detail.visible=true
	var message:String="묘지를 파헤쳐 보세요"
	if found: message="카드를 발견했다"
	elif not graveyard_message.is_empty(): message=graveyard_message
	elif used: message="이번 방문의 발굴은 완료했습니다"
	_set_graveyard_notice(message)
	graveyard_exit_button=map.location_button(content,"맵으로 나가기",map.TILE_EVENT_EXIT_RECT.position,map.TILE_EVENT_EXIT_RECT.size,_leave_graveyard,4)
	graveyard_exit_button.name="GraveyardExitToMap"
	close_button=graveyard_exit_button
	action_button=map.location_button(content,"시체 파헤치기",map.TILE_EVENT_ACTION_RECT.position,map.TILE_EVENT_ACTION_RECT.size,_graveyard_action,4)
	action_button.name="GraveyardDigConfirm"
	if session.event_flag_is_set("ui:unlock:graveyard:action_pending"):
		UnlockNoticeBadge.attach(action_button,"NEW")
	action_button.disabled=used or busy
	action_button.tooltip_text="방문당 1회 · 무작위 주사위 제어 카드 1장 · 보유 한도 %d장"%Catalog.DICE_CAPACITY
	if found:
		graveyard_motion=_make_graveyard_motion()
		graveyard_motion.show_ready()
		graveyard_phase="ready"
		_show_graveyard_ready_controls()
	elif used:
		graveyard_phase="done"
		map.apply_pending_location_paper(self,action_button,index,"grave-extract")

func _set_graveyard_notice(message:String) -> void:
	if is_instance_valid(graveyard_notice): graveyard_notice.text=message
	if is_instance_valid(status): status.text=message

func _leave_graveyard() -> void:
	if busy: return
	leave_to_map.emit()

func _graveyard_action() -> void:
	if busy: return
	if graveyard_phase=="idle": dig_graveyard()
	elif graveyard_phase=="ready": collect_graveyard()

func _make_graveyard_motion() -> Control:
	var effect=GraveyardMotion.new()
	effect.name="GraveyardRewardMotion"
	content.add_child(effect)
	effect.setup(Catalog.image("dice",graveyard_result))
	effect.set_meta("reward_id",str(graveyard_result.get("id","")))
	return effect

func _show_graveyard_ready_controls() -> void:
	action_button.name="GraveyardCollectConfirm"
	action_button.text="챙기고 나가기"
	# Collection is also the exit: retain the same lower exit slot.
	action_button.position=map.TILE_EVENT_EXIT_RECT.position
	action_button.size=map.TILE_EVENT_EXIT_RECT.size
	action_button.disabled=false
	graveyard_detail.text="아래 버튼을 누르면 카드를 챙기고 맵으로 돌아갑니다"
	graveyard_exit_button.hide()
	_set_graveyard_notice("카드를 발견했다")

func dig_graveyard() -> void:
	if busy or graveyard_phase!="idle": return
	graveyard_count_before=session.world.dice_cards.size()
	map.acknowledge_discovery_action("graveyard")
	var new_badge:Control=action_button.get_node_or_null("UnlockNewBadge")
	if is_instance_valid(new_badge) and not session.event_flag_is_set("ui:unlock:graveyard:action_pending"):
		new_badge.hide()
	# Keep the original atomic draw/save before ANY successful presentation.
	var result:Dictionary=session.dig_graveyard(index)
	if not bool(result.get("ok",false)):
		graveyard_message=str(result.get("reason","발굴을 진행할 수 없습니다."))
		render_graveyard()
		return
	graveyard_result=result.item.duplicate(true)
	graveyard_message=""
	graveyard_phase="revealing"
	busy=true
	action_button.text="발굴 중…"
	action_button.disabled=true
	graveyard_exit_button.disabled=true
	_set_graveyard_notice("흙을 털어내는 중")
	Sound.cue(map,"grave_dig")
	graveyard_motion=_make_graveyard_motion()
	var presented:bool=await graveyard_motion.reveal()
	if not presented or not is_inside_tree() or is_queued_for_deletion(): return
	graveyard_phase="ready"
	busy=false
	_show_graveyard_ready_controls()

func collect_graveyard() -> void:
	if busy or graveyard_phase!="ready" or graveyard_result.is_empty(): return
	if str(session.world.pending_reward.get("kind",""))=="grave-dig":
		show_graveyard_overflow()
		return
	await _deliver_graveyard()

func _deliver_graveyard() -> void:
	if busy or not is_instance_valid(graveyard_motion): return
	busy=true
	graveyard_phase="delivering"
	action_button.disabled=true
	graveyard_exit_button.disabled=true
	var delivered:bool=await map.deliver_graveyard_reward(self,graveyard_motion,graveyard_count_before)
	if not delivered or not is_inside_tree() or is_queued_for_deletion(): return
	graveyard_phase="done"
	busy=false
	map.queue_used_location_paper(index,"grave-extract")
	leave_to_map.emit()

func show_graveyard_overflow() -> void:
	if str(session.world.pending_reward.get("kind",""))!="grave-dig" or busy: return
	if is_instance_valid(graveyard_overflow): return
	graveyard_result=session.world.pending_reward.reward.item.duplicate(true)
	graveyard_count_before=session.world.dice_cards.size()
	busy=true
	graveyard_phase="overflow"
	action_button.disabled=true
	var popup=RewardOverflow.new()
	popup.name="GraveyardRewardOverflow"
	graveyard_overflow=popup
	add_child(popup)
	popup.resolved.connect(func(outcome:Dictionary): _finish_graveyard_overflow(outcome,popup))
	popup.setup(session)

func _finish_graveyard_overflow(outcome:Dictionary,popup:Control) -> void:
	if not bool(outcome.get("ok",false)): return
	if is_instance_valid(popup): popup.hide()
	graveyard_overflow=null
	busy=false
	if bool(outcome.get("kept",false)):
		# claim_reward already saved the replacement; delivery never grants again.
		graveyard_phase="ready"
		await _deliver_graveyard()
	else:
		graveyard_result={}
		graveyard_phase="done"
		graveyard_message="새 카드를 포기했습니다"
		map.queue_used_location_paper(index,"grave-extract")
		render_graveyard()

func _exit_tree() -> void:
	if type not in ["graveyard","forest"]: return
	if type=="graveyard" and is_instance_valid(graveyard_motion):
		graveyard_motion.cancel()
		if not graveyard_motion.is_queued_for_deletion(): graveyard_motion.queue_free()
	if is_instance_valid(map) and not map.is_queued_for_deletion():
		# Never reorder stage children while an owner/map subtree is exiting.
		map.call_deferred("_clear_detached_location_overlay",weakref(self))

## Six forward routes are displayed; crossing the fixed HOME tile is
## forbidden by the same path-stop rule as normal die movement.
func hill_max_steps() -> int:
	for steps in range(1,7):
		if (index+steps)%24==MapState.HOME:
			return steps
	return 6

func _hill_allowed() -> Dictionary:
	var allowed:Dictionary=session.place_allowed(index,"forest")
	if not bool(allowed.get("ok",false)): return allowed
	if session.world.position!=index:
		return {"ok":false,"reason":"현재 언덕에 있을 때만 이동을 선택할 수 있습니다."}
	if session.place_visit_id("hill-route",index) in session.world.reward_receipts:
		return {"ok":false,"reason":"이번 언덕 방문의 이동은 이미 사용했습니다."}
	return {"ok":true}

func _set_hill_notice(message:String,detail:String="") -> void:
	if is_instance_valid(status): status.text=message
	if is_instance_valid(hill_notice): hill_notice.text=message
	if is_instance_valid(hill_detail):
		hill_detail.text=detail
		hill_detail.visible=not detail.is_empty()

func render_hill_choices() -> void:
	clear_content()
	hill_selected_steps=0
	var allowed:Dictionary=_hill_allowed()
	var shared:Dictionary=LocationNoticeStrip.build(content)
	shared.strip.name="HillNoticeStrip"
	hill_notice=shared.text
	hill_notice.name="HillNoticeText"
	hill_detail=shared.detail
	hill_detail.name="HillNoticeDetail"
	action_button=map.location_button(content,"여기로 이동",map.TILE_EVENT_ACTION_RECT.position,map.TILE_EVENT_ACTION_RECT.size,confirm_hill_route,4)
	action_button.name="LocationAction_hill-route"
	action_button.disabled=true
	if session.event_flag_is_set("ui:unlock:forest:action_pending"):
		UnlockNoticeBadge.attach(action_button,"NEW")
	close_button=map.location_button(content,"맵으로 나가기",map.TILE_EVENT_EXIT_RECT.position,map.TILE_EVENT_EXIT_RECT.size,_leave_hill,4)
	close_button.name="HillExitToMap"
	hill_picker=HillRoutePicker.new()
	content.add_child(hill_picker)
	hill_picker.setup(session.world.tiles,index,hill_max_steps(),bool(allowed.ok),"현재" if session.world.position==index else "언덕")
	hill_picker.step_selected.connect(select_hill_step)
	hill_choice_buttons=hill_picker.choice_buttons
	if bool(allowed.ok): _set_hill_notice("어디로 향하시겠습니까?","주사위 · 카드 소모 없음")
	else: _set_hill_notice(str(allowed.reason))
	if session.place_visit_id("hill-route",index) in session.world.reward_receipts:
		map.apply_pending_location_paper(self,action_button,index,"hill-route")

func _leave_hill() -> void:
	if busy: return
	map.highlight(session.world.position)
	leave_to_map.emit()

func select_hill_step(steps:int) -> void:
	if busy or steps<1 or steps>hill_max_steps(): return
	var allowed:Dictionary=_hill_allowed()
	if not bool(allowed.ok):
		show_hill_error(str(allowed.reason))
		return
	hill_selected_steps=steps
	hill_picker.set_selection(steps)
	var destination:int=(index+steps)%24
	map.highlight(destination)
	action_button.disabled=false
	_set_hill_notice("%d칸 앞 · %d번 %s"%[steps,destination+1,MapState.NAMES[session.world.tiles[destination]]],"이동 확정을 누르면 이동합니다")

func show_hill_error(reason:String) -> void:
	busy=false
	var allowed:Dictionary=_hill_allowed()
	hill_picker.set_available(bool(allowed.ok))
	hill_picker.set_locked(false)
	close_button.disabled=false
	if is_instance_valid(action_button): action_button.disabled=not bool(allowed.ok) or hill_selected_steps<1
	_set_hill_notice(reason,"다시 시도하거나 맵으로 나갈 수 있습니다." if bool(allowed.ok) else "")

func show_hill_departure(steps:int) -> void:
	busy=true
	hill_selected_steps=steps
	hill_picker.set_locked(true)
	hill_picker.set_available(true)
	hill_picker.set_selection(steps)
	close_button.disabled=true
	action_button.disabled=true
	var destination:int=(index+steps)%24
	_set_hill_notice("%d칸 앞 · %d번 %s"%[steps,destination+1,MapState.NAMES[session.world.tiles[destination]]],"선택한 길을 따라 출발합니다")

func confirm_hill_route() -> void:
	if busy or hill_selected_steps<1: return
	var allowed:Dictionary=_hill_allowed()
	if not bool(allowed.ok):
		show_hill_error(str(allowed.reason))
		return
	busy=true
	action_button.disabled=true
	close_button.disabled=true
	hill_picker.set_locked(true)
	map.acknowledge_discovery_action("forest")
	var marker:Control=action_button.get_node_or_null("UnlockNewBadge")
	if is_instance_valid(marker) and not session.event_flag_is_set("ui:unlock:forest:action_pending"): marker.hide()
	hill_route_chosen.emit(hill_selected_steps)


func initialize_route_slot_layout() -> void:
	route_slot_layout.clear()
	for kind in RoutePlan.CHOICES:
		for _i in range(int(plan.selection.get(kind,0))):
			route_slot_layout.append(kind)
	while route_slot_layout.size()<RoutePlan.OPTIONAL_CAPACITY:
		route_slot_layout.append("basic")

func route_slot_kind(slot: int) -> String:
	if route_slot_layout.size()!=RoutePlan.OPTIONAL_CAPACITY:
		initialize_route_slot_layout()
	return route_slot_layout[clampi(slot,0,RoutePlan.OPTIONAL_CAPACITY-1)]

func choose_route_slot(slot: int) -> void:
	selected_route_slot=clampi(slot,0,RoutePlan.OPTIONAL_CAPACITY-1)
	render_route()

func set_route_slot_kind(kind: String) -> void:
	if type!="home" or session.patrol_edit_locked(): return
	if kind!="basic" and not kind in RoutePlan.CHOICES: return
	if kind=="rest" and not bool(plan.get("rest_unlocked",false)): return
	if kind=="forest" and not Discovery.is_unlocked(session.world,"forest"): return
	var old_kind: String=route_slot_kind(selected_route_slot)
	if old_kind==kind: return
	var next: Dictionary=plan.duplicate(true)
	if old_kind!="basic": next.selection[old_kind]=int(next.selection.get(old_kind,0))-1
	if kind!="basic": next.selection[kind]=int(next.selection.get(kind,0))+1
	if not RoutePlan.valid(next) or not bool(session.world.patrol_preview(next).valid): return
	plan=next
	route_feedback=""
	route_slot_layout[selected_route_slot]=kind
	render_route()

func render_route() -> void:
	if is_instance_valid(route_editor): route_editor.refresh()

func unlock_rest() -> void:
	if type!="home" or bool(session.world.patrol_plan.get("rest_unlocked",false)): return
	var result: Dictionary=session.unlock_rest_tile()
	if not bool(result.get("ok",false)):
		route_feedback=str(result.get("reason","해금에 실패했습니다."))
		render_route()
		return
	# Keep any unconfirmed monster selections when the unlock is saved,
	# then let the player choose up to 3 rest tiles normally.
	if not RoutePlan.is_new(plan):
		plan=RoutePlan.default_plan()
	plan["rest_unlocked"]=true
	plan["rest_discovered"]=bool(session.world.patrol_plan.get("rest_discovered",false))
	# Preserve unconfirmed quantities after the permanent unlock.
	route_feedback=str(result.reason)
	render_route()

func adjust_route_tile(kind: String, difference: int) -> void:
	if type!="home" or session.patrol_edit_locked(): return
	if not kind in RoutePlan.CHOICES or difference not in [-1,1]: return
	if difference>0 and kind=="forest" and not Discovery.is_unlocked(session.world,"forest"): return
	if difference>0 and kind=="rest" and not bool(plan.get("rest_unlocked",false)): return
	var next: Dictionary=RoutePlan.adjust(plan,kind,difference)
	var preview: Dictionary=session.world.patrol_preview(next)
	if next==plan or (difference>0 and not bool(preview.valid)):
		route_feedback=str(preview.reason) if not bool(preview.valid) else "수량 제한을 확인하세요."
		render_route()
		return
	plan=next
	route_feedback=""
	initialize_route_slot_layout()
	render_route()

func confirm_route() -> void:
	var result: Dictionary=session.confirm_patrol(plan)
	route_feedback=str(result.reason)
	render_route()
	if bool(result.ok):
		map.queue_used_location_paper(session.MapState.HOME,"patrol")
		if is_inside_tree(): closed.emit()

func pray() -> void:
	if busy: return
	var result=session.pray_world_tree(index)
	if not result.ok: status.text=result.reason; return
	busy=true
	close_button.disabled=true
	status.text="세계수에 정화 기도 중…"
	await map.roll_shared_die(int(result.face))
	Sound.cue(map,"prayer_fail" if int(session.world.prayer_result.delta)>0 else "prayer_bless")
	status.text=result.reason
	map.presentation.refresh()
	# Prayer reward has been saved before the roll starts: peel its location
	# parchment as soon as the shared die has shown the result.
	map.queue_used_location_paper(index,"purify")
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
