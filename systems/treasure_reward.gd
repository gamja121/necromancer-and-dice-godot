extends "res://systems/reward_ui.gd"
signal finished
signal mimic_revealed(index: int)
const Overflow = preload("res://systems/reward_overflow.gd")
var session
var map
var options: Array = []
var status: Label
var busy = false

func setup(map_scene) -> void:
	map = map_scene
	session = map.session
	z_index = 80
	backdrop()
	label_at(self,"보물상자",Vector2(280,90),Vector2(720,42),25)
	status = label_at(self,"보물상자를 여는 중…",Vector2(250,565),Vector2(780,54),17)
	if session.world.pending_reward.has("reward"):
		build_options()
		call_deferred("resume_reward")
		return
	map.sound("treasure-chest-open")
	var chest = art(self,"res://assets/map/events/treasure-chest-frame-1.png",Vector2(380,130),Vector2(520,400))
	busy = true
	for index in range(4):
		chest.texture = load("res://assets/map/events/treasure-chest-frame-%d.png" % (index+1))
		await get_tree().create_timer([0.18,0.22,0.25,0.34][index]).timeout
	if session.world.pending_reward.get("kind","")=="mimic":
		status.text = "보물상자가 꿈틀거린다… 미믹 %d마리!" % int(session.world.pending_reward.count)
		var shake = create_tween()
		for offset in [-8,8,-5,5,0]:
			shake.tween_property(chest,"position:x",380.0+offset,0.06)
		await shake.finished
		await get_tree().create_timer(0.36).timeout
		mimic_revealed.emit(int(session.world.pending_reward.index))
		return
	chest.modulate.a = 0.28
	status.text = "선택한 카드를 한 번 더 누르면 획득합니다"
	build_options()
	busy = false

func build_options() -> void:
	var pending: Dictionary = session.world.pending_reward
	for index in range(pending.offers.size()):
		var offer: Dictionary = pending.offers[index]
		var option = card(self,offer.kind,offer.source,Vector2(314+index*216,245),Vector2(170,254),func(): choose(index))
		option.rotation_degrees = [-7,0,7][index]
		options.append(option)
	refresh()

func refresh() -> void:
	var selected: int = int(session.world.pending_reward.get("selected",-1))
	for index in range(options.size()):
		options[index].modulate = Color.WHITE if selected<0 or selected==index else Color(0.55,0.55,0.55)
		options[index].scale = Vector2.ONE*(1.04 if index==selected else 1.0)

func choose(index: int) -> void:
	if busy: return
	if int(session.world.pending_reward.selected)!=index:
		if not session.select_treasure(index):
			status.text = "선택 저장 실패 · 다시 시도하세요"
			return
		refresh()
		status.text = options[index].tooltip_text+" 선택 · 한 번 더 누르면 획득"
		return
	busy = true
	if not session.prepare_treasure_reward(index):
		busy = false
		status.text = "보상 준비 저장 실패 · 다시 시도하세요"
		return
	await receive(index)

func resume_reward() -> void:
	busy = true
	await receive(int(session.world.pending_reward.selected))

func receive(index: int) -> void:
	for option in options: option.disabled = true
	var kind: String = session.world.pending_reward.reward.kind
	var outcome: Dictionary = session.claim_reward()
	if outcome.get("overflow",false):
		var overflow = Overflow.new()
		map.stage.add_child(overflow)
		overflow.setup(session)
		outcome = await overflow.resolved
	if not outcome.get("ok",false):
		status.text = "획득 저장 실패 · 다시 시도하세요"
		for option in options: option.disabled = false
		busy = false
		return
	if outcome.kept:
		status.text = options[index].tooltip_text+" 획득"
		await map.animate_reward_to_inventory(kind,options[index])
	else:
		status.text = "신규 보상을 버렸습니다"
		await get_tree().create_timer(0.22).timeout
	finished.emit()
