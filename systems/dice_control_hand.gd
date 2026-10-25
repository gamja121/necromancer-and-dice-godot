extends "res://systems/reward_ui.gd"
const Sound = preload("res://systems/game_audio.gd")
signal chosen(instance_id: String)
signal closed
const DiceControl = preload("res://systems/dice_control.gd")
const DragCard = preload("res://systems/drag_card_module.gd")
const FanMotion = preload("res://systems/card_fan_motion.gd")
const Layout = preload("res://systems/dice_hand_layout.gd")
const CardDepthMotion = preload("res://systems/card_depth_motion.gd")
var status: Label
var options: Array = []
var choosing = false
var opening = true
var fan
var close_button: Button
var battle_mode = false
var fan_origin = Vector2(1198,623)
var battle_backdrop: Button
var hand_surface_height: float = 720.0

func setup(items: Array, context: Dictionary, battle: bool = false) -> void:
	z_index = 210
	battle_mode = battle
	hand_surface_height = float(context.get("ui_surface_height",720))
	setup_battle_shell(items,context)
	var history = "직전 눈금: %s" % (str(int(context.get("previous_roll",0))) if int(context.get("previous_roll",0))>0 else "없음")
	var previous = DiceControl.card(str(context.get("previous_card","")))
	history += " · 직전 카드: "+str(previous.get("label","없음"))
	var strip=Panel.new()
	strip.name="DiceCardInstruction"
	strip.position=Vector2(510,hand_surface_height-288)
	strip.size=Vector2(585,60)
	strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new()
	style.bg_color=Color("180f0bd6")
	style.border_color=Color("7c5d3d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	strip.add_theme_stylebox_override("panel",style)
	add_child(strip)
	status=label_at(self,history+" · 위로 끌어 사용",Vector2(523,hand_surface_height-283),Vector2(558,50),12)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	close_button=button(self,"닫기",Vector2(1112,hand_surface_height-274),Vector2(90,34),close_hand)
	close_button.set_meta("sfx_manual",true)
	fan = FanMotion.new()
	add_child(fan)
	if items.is_empty():
		label_at(self,"보유한 주사위 카드가 없습니다",Vector2(650,hand_surface_height-205),Vector2(450,38),16)
		opening = false
		return
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var id = str(item.id)
		var loc: Vector2=Layout.position_for(i,items.size(),hand_surface_height)
		var option=card(self,"dice",item,loc,Layout.CARD_SIZE,func(): choose(id))
		option.rotation_degrees=Layout.rotation_for(i,items.size())
		option.z_index=Layout.base_z(i)
		option.set_meta("hand_base_z",option.z_index)
		var available=DiceControl.can_use(str(item.card_id),context)
		option.disabled=not available.ok
		option.set_meta("sfx_manual",bool(available.ok))
		option.modulate=Color.WHITE if available.ok else Color(0.55,0.55,0.55)
		option.tooltip_text=DiceControl.description(str(item.card_id)) if available.ok else available.reason
		option.set_meta("instance_id",id)
		# The real artwork carries its own title/effect; hover lifts it fully into view.
		option.get_child(0).visible=false
		options.append(option)
		var drag=DragCard.new()
		drag.name="DiceCardDrag"
		option.add_child(drag)
		drag.activated.connect(func(): choose(id))
		CardDepthMotion.install(option,false,true)
		option.mouse_entered.connect(func(): focus_card(option,true))
		option.mouse_exited.connect(func(): focus_card(option,false))
		option.focus_entered.connect(func(): focus_card(option,true))
		option.focus_exited.connect(func(): focus_card(option,false))
		fan.register_card(option)
	await get_tree().process_frame
	await fan.animate(true,get_global_transform_with_canvas()*fan_origin)
	opening = false
	for option in options:
		var drag=option.get_node("DiceCardDrag")
		drag.home=option.position
		drag.home_z=option.z_index

func focus_card(option: TextureButton, focused: bool) -> void:
	if choosing or opening or not is_instance_valid(option) or option.disabled: return
	var drag=option.get_node("DiceCardDrag")
	if drag.pointer!=-2: return
	if drag.settling!=null and drag.settling.is_valid(): drag.settling.kill()
	if focused: option.move_to_front()
	else: restore_card_order()
	option.z_index=100 if focused else int(option.get_meta("hand_base_z"))
	option.position=drag.home+Vector2(0,-Layout.HOVER_LIFT if focused else 0)
	CardDepthMotion.set_shadow_lift(option,focused)

func restore_card_order() -> void:
	# Control input order follows siblings, independently of CanvasItem z_index.
	for option in options:
		if is_instance_valid(option): option.move_to_front()

func stop_drag_motion() -> void:
	for option in options:
		var drag=option.get_node("DiceCardDrag")
		if drag.settling!=null and drag.settling.is_valid(): drag.settling.kill()
		drag.pointer=-2
		drag.set_process(false)
		option.self_modulate=Color.WHITE

func setup_battle_shell(_items: Array, _context: Dictionary) -> void:
	# Same transparent lower hand on map and battlefield; board art stays visible.
	size=Vector2(1280,hand_surface_height)
	mouse_filter=Control.MOUSE_FILTER_PASS
	battle_backdrop=Button.new()
	battle_backdrop.name="BattleDiceBackdrop" if battle_mode else "MapDiceBackdrop"
	battle_backdrop.set_meta("sfx_manual",true)
	battle_backdrop.flat=true
	battle_backdrop.size=size
	battle_backdrop.tooltip_text="카드창 바깥을 눌러 닫기"
	battle_backdrop.pressed.connect(close_hand)
	add_child(battle_backdrop)
	fan_origin=Vector2(1170 if battle_mode else 1198,hand_surface_height-(82 if battle_mode else 97))

func choose(instance_id: String) -> void:
	if choosing or opening: return
	var selected: TextureButton
	for option in options:
		if option.disabled: continue
		if str(option.get_meta("instance_id",""))==instance_id: selected=option
	if selected==null: return
	Sound.cue(self,"card_use")
	stop_drag_motion()
	choosing=true
	close_button.disabled=true
	for option in options: option.disabled=true
	status.text="카드 사용 · 주사위를 굴립니다"
	var motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_property(selected,"position:y",selected.position.y-120,0.14)
	motion.tween_property(selected,"scale",Vector2(0.85,0.85),0.14)
	motion.tween_property(selected,"modulate:a",0.0,0.14)
	await motion.finished
	chosen.emit(instance_id)

func close_hand() -> void:
	if choosing: return
	Sound.cue(self,"ui_cancel")
	choosing=true
	fan.closing=true
	close_button.disabled=true
	# Finish opening before reversing, rather than leaving a killed Tween awaiter.
	while opening and is_inside_tree(): await get_tree().process_frame
	if not is_inside_tree(): return
	stop_drag_motion()
	await fan.animate(false,get_global_transform_with_canvas()*fan_origin)
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_hand()
