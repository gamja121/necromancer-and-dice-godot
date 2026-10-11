extends "res://systems/reward_ui.gd"
signal finished
signal mimic_revealed(index: int)
const Overflow = preload("res://systems/reward_overflow.gd")
var session
var map
var options: Array = []
var status: Label
var busy = false
# Original HTML reward-card presentation only. These collections do not enter saves.
var reward_outlines: Array[Panel] = []
var reward_origins: Array[Vector2] = []
var reward_materials: Array[ShaderMaterial] = []
const REWARD_CARD_SIZE = Vector2(170,254)
const SELECT_RISE = 0.08
const REWARD_CARD_SHADE_SHADER = """
shader_type canvas_item;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.0, 1.0) = 1.0;
void fragment() {
    vec4 source = COLOR;
    float gray = dot(source.rgb,vec3(0.299,0.587,0.114));
    COLOR = vec4(mix(source.rgb,vec3(gray),desaturate)*brightness,source.a);
}
"""

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
	await animate_offer_entrance()
	busy = false

# Three successive source cards rise from 22% below, with 110ms staggering.
# Keep the chest/selection receipt and save pipeline completely separate.
func animate_offer_entrance() -> void:
	if options.is_empty(): return
	var rise=create_tween().set_parallel(true)
	for i in range(options.size()):
		var node: TextureButton=options[i]
		var target: Vector2=reward_origins[i]
		node.position=target+Vector2(0,REWARD_CARD_SIZE.y*0.22)
		node.scale=Vector2(0.78,0.78)
		node.modulate.a=0.0
		var lag: float=i*0.11
		rise.tween_property(node,"position:y",target.y,0.42).set_delay(lag).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_property(node,"scale",Vector2.ONE,0.42).set_delay(lag).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_property(node,"modulate:a",1.0,0.29).set_delay(lag)
	await rise.finished
	refresh()

func reward_outline(option: TextureButton) -> Panel:
	var border=Panel.new()
	border.name="TreasureSelectionOutline"
	border.position=Vector2(-8,-14)
	border.size=REWARD_CARD_SIZE+Vector2(16,28)
	border.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new()
	style.bg_color=Color(1,1,1,0)
	style.border_color=Color("ffe29a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color=Color("ffe29a99")
	style.shadow_size=9
	border.add_theme_stylebox_override("panel",style)
	border.visible=false
	option.add_child(border)
	return border

func reward_shade(option: TextureButton) -> ShaderMaterial:
	var material=ShaderMaterial.new()
	var shader=Shader.new()
	shader.code=REWARD_CARD_SHADE_SHADER
	material.shader=shader
	material.set_shader_parameter("desaturate",0.0)
	material.set_shader_parameter("brightness",1.0)
	option.material=material
	return material

func build_options() -> void:
	var pending: Dictionary = session.world.pending_reward
	for index in range(pending.offers.size()):
		var offer: Dictionary = pending.offers[index]
		var origin=Vector2(314+index*216,245)
		var option=card(self,offer.kind,offer.source,origin,REWARD_CARD_SIZE,func(): choose(index))
		option.rotation_degrees=[-7,0,7][index]
		option.set_meta("reward_index",index)
		reward_origins.append(origin)
		reward_materials.append(reward_shade(option))
		reward_outlines.append(reward_outline(option))
		options.append(option)
	refresh()

func refresh() -> void:
	var selected: int = int(session.world.pending_reward.get("selected",-1))
	for index in range(options.size()):
		var active: bool=selected==index
		var faded: bool=selected>=0 and not active
		var option: TextureButton=options[index]
		option.position=reward_origins[index]+Vector2(0,-REWARD_CARD_SIZE.y*SELECT_RISE if active else 0)
		option.scale=Vector2.ONE*(1.08 if active else 1.0)
		option.modulate=Color(1,1,1,0.48 if faded else 1.0)
		option.z_index=12 if active else 0
		reward_outlines[index].visible=active
		reward_materials[index].set_shader_parameter("desaturate",0.22 if faded else 0.0)
		reward_materials[index].set_shader_parameter("brightness",0.72 if faded else 1.0)

func show_confirmed_choice(index: int) -> void:
	# Presentation after a successfully stored reward, not before.
	for i in range(options.size()):
		var option: TextureButton=options[i]
		if i==index:
			option.position=reward_origins[i]+Vector2(0,-REWARD_CARD_SIZE.y*0.1)
			option.scale=Vector2(1.1,1.1)
			option.modulate.a=1.0
			option.z_index=15
			reward_outlines[i].visible=true
		else:
			option.modulate.a=0.0
			option.scale=Vector2(0.72,0.72)
			option.position=reward_origins[i]+Vector2(0,REWARD_CARD_SIZE.y*0.1)
			reward_outlines[i].visible=false

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
		show_confirmed_choice(index)
		status.text = options[index].tooltip_text+" 획득"
		await map.animate_reward_to_inventory(kind,options[index])
	else:
		status.text = "신규 보상을 버렸습니다"
		await get_tree().create_timer(0.22).timeout
	finished.emit()
