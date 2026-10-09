extends "res://systems/reward_ui.gd"
signal resolved(outcome: Dictionary)
var session
var selected = ""
var status: Label
var confirm: Button
var choices: Dictionary = {}

func setup(run_session) -> void:
	session = run_session
	z_index = 250
	backdrop()
	# The original JPEG is corrupt; use a native panel until its source is replaced.
	var background = Panel.new()
	background.position = Vector2(100,85)
	background.size = Vector2(1080,550)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color("251d18")
	style.border_color = Color("a88a59")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0,0,0,0.6)
	style.shadow_size = 12
	background.add_theme_stylebox_override("panel",style)
	add_child(background)
	var reward: Dictionary = session.world.pending_reward.reward
	var items: Array = session.world.roster if reward.kind=="unit" else session.world.dice_cards
	label_at(self,"마물 보관함 10/10" if reward.kind=="unit" else "주사위 카드더미 5/5",Vector2(200,116),Vector2(880,38),24)
	status = label_at(self,"기존 카드와 신규 카드 중 버릴 카드 1장을 선택하세요",Vector2(180,165),Vector2(920,34),16)
	var row = scroll_row(Vector2(155,214),Vector2(970,325))
	var candidates = items.duplicate(true)
	candidates.append(reward.item)
	for index in range(candidates.size()):
		var item: Dictionary = candidates[index]
		var key: String = "__new__" if index==candidates.size()-1 else item.id
		var box = Control.new()
		box.custom_minimum_size = Vector2(138,296)
		row.add_child(box)
		var option = card(box,reward.kind,item,Vector2(6,8),Vector2(126,206),func(): select_card(key))
		choices[key] = option
		if key=="__new__": label_at(box,"신규",Vector2(25,-6),Vector2(88,28),16)
	confirm = button(self,"선택한 카드 버리기",Vector2(485,568),Vector2(310,42),finish)
	confirm.disabled = true

func select_card(key: String) -> void:
	selected = key
	for id in choices:
		choices[id].modulate = Color.WHITE if id==key else Color(0.65,0.65,0.65)
	status.text = choices[key].tooltip_text+" · 버리기 선택됨"
	confirm.disabled = false

func finish() -> void:
	if selected.is_empty(): return
	confirm.disabled = true
	var outcome: Dictionary = session.claim_reward(selected)
	if not outcome.get("ok",false):
		status.text = "저장 실패 · 다시 시도하세요"
		confirm.disabled = false
		return
	resolved.emit(outcome)
	queue_free()
