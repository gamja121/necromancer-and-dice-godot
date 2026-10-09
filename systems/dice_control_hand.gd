extends "res://systems/reward_ui.gd"
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

func setup(items: Array, context: Dictionary, battle: bool = false) -> void:
	z_index = 210
	backdrop()
	label_at(self,"전투 주사위 제어" if battle else "이동 주사위 제어",Vector2(260,90),Vector2(760,42),25)
	var history = "직전 눈금: %s" % (str(int(context.get("previous_roll",0))) if int(context.get("previous_roll",0))>0 else "없음")
	var previous = DiceControl.card(str(context.get("previous_card","")))
	history += " · 직전 카드: "+str(previous.get("label","없음"))
	label_at(self,history,Vector2(240,147),Vector2(800,32),16)
	status = label_at(self,"위로 살짝 끌거나 클릭하면 1장을 사용하고 자동으로 굴립니다",Vector2(180,548),Vector2(920,40),16)
	close_button = button(self,"닫기",Vector2(550,605),Vector2(180,42),close_hand)
	fan = FanMotion.new()
	add_child(fan)
	if items.is_empty():
		label_at(self,"보유한 주사위 카드가 없습니다",Vector2(260,315),Vector2(760,40),19)
		opening = false
		return
	var half = (items.size()-1)*0.5
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var id = str(item.id)
		var offset = float(i)-half
		var option = card(self,"dice",item,Vector2(566+offset*152,232+absf(offset)*7),Vector2(148,224),func(): choose(id))
		option.rotation_degrees = -offset*5
		var available = DiceControl.can_use(str(item.card_id),context)
		option.disabled = not available.ok
		option.modulate = Color.WHITE if available.ok else Color(0.55,0.55,0.55)
		option.tooltip_text = DiceControl.description(str(item.card_id)) if available.ok else available.reason
		option.set_meta("instance_id",id)
		options.append(option)
		if not available.ok: option.get_child(0).text += " · 지금 사용 불가"
		var drag = DragCard.new()
		option.add_child(drag)
		drag.activated.connect(func(): choose(id))
		fan.register_card(option)
	await get_tree().process_frame
	await fan.animate(true,get_global_transform_with_canvas()*Vector2(1080,620))
	opening = false
	for option in options:
		var drag = option.get_child(1)
		drag.home = option.position

func choose(instance_id: String) -> void:
	if choosing or opening: return
	var selected: TextureButton
	for option in options:
		if option.disabled: continue
		# IDs are bound to each button, never to a mutable array index.
		if str(option.get_meta("instance_id",""))==instance_id: selected = option
	if selected == null: return
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
	choosing = true
	fan.closing = true
	close_button.disabled = true
	await fan.animate(false,get_global_transform_with_canvas()*Vector2(1080,620))
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_hand()
