extends "res://systems/reward_ui.gd"
const Sound = preload("res://systems/game_audio.gd")
signal chosen(instance_id: String)
signal closed
const DiceControl = preload("res://systems/dice_control.gd")
const DragCard = preload("res://systems/drag_card_module.gd")
const FanMotion = preload("res://systems/card_fan_motion.gd")
var status: Label
var options: Array = []
var choosing = false
var opening = true
var fan
var close_button: Button
var battle_mode = false
var fan_origin = Vector2(1080,620)
var battle_backdrop: Button
var hand_surface_height: float = 720.0
const BATTLE_CARD_ROTATIONS = [10.0,5.0,0.0,-5.0,-10.0]
const BATTLE_CARD_OFFSETS = [0.04,-0.78,-1.60,-2.42,-3.24]

func setup(items: Array, context: Dictionary, battle: bool = false) -> void:
	z_index = 210
	battle_mode = battle
	hand_surface_height = float(context.get("ui_surface_height",720))
	if battle:
		setup_battle_shell(items,context)
	else:
		backdrop()
	if not battle: label_at(self,"이동 주사위 제어",Vector2(260,90),Vector2(760,42),25)
	var history = "직전 눈금: %s" % (str(int(context.get("previous_roll",0))) if int(context.get("previous_roll",0))>0 else "없음")
	var previous = DiceControl.card(str(context.get("previous_card","")))
	history += " · 직전 카드: "+str(previous.get("label","없음"))
	if battle:
		var strip=Panel.new()
		strip.name="DiceCardInstruction"
		strip.position=Vector2(667,hand_surface_height-370)
		strip.size=Vector2(460,65)
		strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var strip_style=StyleBoxFlat.new()
		strip_style.bg_color=Color("180f0bd6")
		strip_style.border_color=Color("7c5d3d")
		strip_style.set_border_width_all(1)
		strip_style.set_corner_radius_all(5)
		strip.add_theme_stylebox_override("panel",strip_style)
		add_child(strip)
		status=label_at(self,history+" · 위로 끌어 사용",Vector2(680,hand_surface_height-365),Vector2(440,55),12)
		status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		close_button=button(self,"닫기",Vector2(1115,hand_surface_height-370),Vector2(85,39),close_hand)
	else:
		label_at(self,history,Vector2(240,147),Vector2(800,32),16)
		status = label_at(self,"위로 살짝 끌거나 클릭하면 1장을 사용하고 자동으로 굴립니다",Vector2(180,548),Vector2(920,40),16)
		close_button = button(self,"닫기",Vector2(550,605),Vector2(180,42),close_hand)
	close_button.set_meta("sfx_manual",true)
	fan = FanMotion.new()
	add_child(fan)
	if items.is_empty():
		if not battle: label_at(self,"보유한 주사위 카드가 없습니다",Vector2(260,315),Vector2(760,40),19)
		opening = false
		return
	var half = (items.size()-1)*0.5
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var id = str(item.id)
		var offset = float(i)-half
		var loc: Vector2=Vector2(566+offset*152,232+absf(offset)*7)
		var card_size: Vector2=Vector2(148,224)
		if battle:
			# HTML source: 68% hand right 8.7%, bottom 4.8%,
			# five overlapping cards with angles +10,+5,0,-5,-10.
			var slot_index: int=mini(i,4)
			card_size=Vector2(124,190)
			var right_edge: float=1280.0-111.36
			loc=Vector2(right_edge-card_size.x+BATTLE_CARD_OFFSETS[slot_index]*card_size.x,
				hand_surface_height-34.56-card_size.y+[-0.01,-0.06,-0.09,-0.07,-0.03][slot_index]*card_size.y)
		var option = card(self,"dice",item,loc,card_size,func(): choose(id))
		option.rotation_degrees=BATTLE_CARD_ROTATIONS[mini(i,4)] if battle else -offset*5
		option.z_index = 5-i if battle else 0
		var available = DiceControl.can_use(str(item.card_id),context)
		option.disabled = not available.ok
		option.set_meta("sfx_manual",bool(available.ok))
		option.modulate = Color.WHITE if available.ok else Color(0.55,0.55,0.55)
		option.tooltip_text = DiceControl.description(str(item.card_id)) if available.ok else available.reason
		option.set_meta("instance_id",id)
		options.append(option)
		if battle:
			# Raw source HTML uses only card art; card labels stay in tooltip.
			option.get_child(0).visible=false
		else:
			if not available.ok: option.get_child(0).text += " · 지금 사용 불가"
		var drag = DragCard.new()
		option.add_child(drag)
		drag.activated.connect(func(): choose(id))
		fan.register_card(option)
	await get_tree().process_frame
	await fan.animate(true,get_global_transform_with_canvas()*fan_origin)
	opening = false
	for option in options:
		var drag = option.get_child(1)
		drag.home = option.position

func setup_battle_shell(items: Array, context: Dictionary) -> void:
	# Unlike map inventory, battle card overlay is translucent and
	# fan cards rise directly from the bottom-right book illustration.
	size=Vector2(1280,hand_surface_height)
	mouse_filter=Control.MOUSE_FILTER_PASS
	battle_backdrop=Button.new()
	battle_backdrop.name="BattleDiceBackdrop"
	battle_backdrop.set_meta("sfx_manual",true)
	battle_backdrop.flat=true
	battle_backdrop.size=size
	battle_backdrop.tooltip_text="카드창 바깥을 눌러 닫기"
	battle_backdrop.pressed.connect(close_hand)
	add_child(battle_backdrop)
	fan_origin=Vector2(1170,hand_surface_height-82)
	if items.is_empty():
		label_at(self,"보유한 주사위 카드가 없습니다",Vector2(720,hand_surface_height-220),Vector2(420,38),15)


func choose(instance_id: String) -> void:
	if choosing or opening: return
	var selected: TextureButton
	for option in options:
		if option.disabled: continue
		# IDs are bound to each button, never to a mutable array index.
		if str(option.get_meta("instance_id",""))==instance_id: selected = option
	if selected == null: return
	Sound.cue(self,"card_use")
	choosing = true
	close_button.disabled = true
	for option in options: option.disabled = true
	status.text = "카드 사용 · 주사위를 굴립니다"
	var motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_property(selected,"position:y",selected.position.y-120,0.14)
	motion.tween_property(selected,"scale",Vector2(0.85,0.85),0.14)
	motion.tween_property(selected,"modulate:a",0.0,0.14)
	await motion.finished
	chosen.emit(instance_id)

func close_hand() -> void:
	if choosing: return
	Sound.cue(self,"ui_cancel")
	choosing = true
	fan.closing = true
	close_button.disabled = true
	await fan.animate(false,get_global_transform_with_canvas()*fan_origin)
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_hand()
