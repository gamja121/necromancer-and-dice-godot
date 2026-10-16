extends Control
# Only displays confirmed battle data; never changes rules, saves or gameplay RNG.
const DICE_TIME = 0.20
const NAMES = {"critical":"치명타","vampire":"흡혈","combo":"연타","freeze":"빙결","poison":"독","guard":"보호","summon":"소환","counter":"반격","healing":"치유","lightspeed":"광속"}
var scene
var clock = 0.0
var dice_result: Dictionary = {}
var marks: Array = []
var impact: Dictionary = {}
var rail: HBoxContainer
var rail_box: PanelContainer
var expiry = 0.0
var dice_base_scale = Vector2.ONE

func setup(battle_scene) -> void:
	scene = battle_scene
	size = scene.surface_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 52
	dice_base_scale = scene.dice.scale
	scene.dice.pivot_offset = scene.dice.size*0.5
	rail_box = PanelContainer.new()
	rail_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_box.add_theme_stylebox_override("panel",pill(Color("17100ff5"),Color("c39a5ecc"),22,10))
	add_child(rail_box)
	rail = HBoxContainer.new()
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_theme_constant_override("separation",6)
	rail_box.add_child(rail)
	rail_box.visible = false

func pill(background: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

func step(value: String, color: Color) -> void:
	if rail.get_child_count()>=6:
		var old = rail.get_child(1)
		rail.remove_child(old)
		old.queue_free()
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",pill(Color("201711ee"),color.darkened(0.3),16,8))
	var label = Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",13)
	label.add_theme_color_override("font_color",color)
	panel.add_child(label)
	rail.add_child(panel)
	rail_box.visible = true
	expiry = clock+2.2

func _process(delta: float) -> void:
	if scene==null: return
	if not scene.paused and not scene.visuals.presentation_hold: clock += delta
	if not dice_result.is_empty():
		var t = clampf((clock-dice_result.started)/DICE_TIME,0,1)
		scene.dice.scale = dice_base_scale*(1.0+sin(t*PI)*(0.12 if dice_result.face in [1,6] else 0.08))
	if rail_box.visible:
		rail_box.size = rail_box.get_combined_minimum_size()
		rail_box.position = Vector2((size.x-rail_box.size.x)/2.0,size.y*0.145)
		rail_box.visible = clock<expiry
	queue_redraw()

func _exit_tree() -> void:
	if scene!=null and is_instance_valid(scene.dice): scene.dice.scale = dice_base_scale

func play_dice_result(face: int) -> void:
	for child in rail.get_children():
		rail.remove_child(child)
		child.queue_free()
	step("주사위 "+str(face),Color("ffe09a"))
	dice_result = {"face":face,"started":clock}
	await scene.wait_presentation(DICE_TIME)
	scene.dice.scale = dice_base_scale
	dice_result.clear()

func play_intent(actor_id: String, target_id: String) -> void:
	if not scene.sprites.has(actor_id) or not scene.sprites.has(target_id): return
	await scene.wait_presentation(0.32,0.18)

func show_attack(name_text: String) -> void:
	step("공격 "+name_text,Color("ffd39b"))

func show_damage(amount: int) -> void:
	step("피해 "+str(amount),Color("ff8f82"))
	expiry = clock+1.45

func play_brands(units: Array) -> void:
	# Presentation only: the round's blessing/curse values are already resolved.
	# Allies sweep left-to-right, then enemies sweep right-to-left.
	marks.clear()
	impact.clear()
	var ordered: Array = []
	for team in ["ally","enemy"]:
		var side: Array = []
		for unit in units:
			if unit.team==team and unit.alive and scene.sprites.has(unit.id):
				side.append(unit)
		side.sort_custom(func(a, b):
			return scene.unit_x(a)<scene.unit_x(b) if team=="ally" else scene.unit_x(a)>scene.unit_x(b))
		ordered.append_array(side)
	for unit in ordered:
		var captions: Array = []
		for mode in ["bless","curse"]:
			for key in unit[mode]:
				if int(unit[mode][key])<=0: continue
				var color = Color("ffe19a") if mode=="bless" else Color("b49acb")
				var caption = ("축복 " if mode=="bless" else "저주 ")+NAMES.get(key,key)
				captions.append({"text":caption,"color":color,"mode":mode})
		if captions.is_empty(): continue
		marks = [{"id":unit.id,"captions":captions.slice(0,3)}]
		var is_blessed: bool = false
		var is_cursed: bool = false
		for caption in captions:
			if caption.mode=="bless": is_blessed=true
			if caption.mode=="curse": is_cursed=true
		var sprite: TextureRect = scene.sprites[unit.id]
		var base_modulate: Color = sprite.modulate
		var effect_color = Color("ffe4a3") if is_blessed else Color("80628d")
		impact = {"id":unit.id,"mode":"bless" if is_blessed else "curse","started":clock,"duration":0.22 if is_blessed else 0.25}
		step(("축복 " if is_blessed else "저주 ")+str(unit.name),effect_color)
		# Quick gold burst for blessing; muted, sinking violet for curse.
		var tween = create_tween()
		tween.tween_property(sprite,"modulate",effect_color if is_blessed else Color("81738a"),0.075)
		tween.tween_property(sprite,"modulate",base_modulate,0.17)
		await scene.wait_presentation(0.22 if is_blessed else 0.25,0.15)
		if not is_inside_tree(): return
		if is_instance_valid(tween): tween.kill()
		if is_instance_valid(sprite): sprite.modulate = base_modulate
		marks.clear()
		impact.clear()
	marks.clear()
	impact.clear()

func _draw() -> void:
	if scene==null: return
	if not impact.is_empty() and scene.visuals.states.has(impact.id):
		var unit: Dictionary = scene.visuals.states[impact.id]
		var t: float = clampf((clock-float(impact.started))/float(impact.duration),0.0,1.0)
		var center: Vector2 = scene.presentation_layout.geometry(unit,scene.surface_size).effect
		if impact.mode=="bless":
			var alpha: float = 1.0-t
			draw_circle(center,24.0+75.0*t,Color(1.0,0.73,0.24,0.16*alpha))
			draw_arc(center,28.0+67.0*t,0.0,TAU,32,Color(1.0,0.87,0.43,0.95*alpha),4.5*(1.0-t)+1.0,true)
			for i in range(8):
				var angle: float = TAU*float(i)/8.0
				var ray: Vector2 = Vector2(cos(angle),sin(angle))
				draw_line(center+ray*(18.0+33.0*t),center+ray*(42.0+89.0*t),Color(1.0,0.94,0.65,0.85*alpha),3.0*(1.0-t)+1.0,true)
		else:
			var alpha: float = 1.0-t
			draw_circle(center+Vector2(0,16.0+28.0*t),43.0+19.0*t,Color(0.19,0.09,0.27,0.37*alpha))
			for i in range(5):
				var offset: float = (float(i)-2.0)*17.0
				var start: Vector2 = center+Vector2(offset,-23.0+18.0*t)
				draw_line(start,start+Vector2(offset*0.18,43.0+38.0*t),Color(0.53,0.34,0.64,0.75*alpha),5.0*(1.0-t)+1.0,true)
	var font: Font = scene.get_theme_default_font()
	for mark in marks:
		var unit: Dictionary = scene.visuals.states[mark.id]
		var y: float = scene.bars[mark.id].position.y-24.0*mark.captions.size()
		for caption in mark.captions:
			var width = font.get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+12.0
			var pos = Vector2(scene.unit_x(unit)-width/2.0,y)
			draw_style_box(pill(Color("17100fee"),caption.color.darkened(0.3),10,6),Rect2(pos,Vector2(width,21)))
			draw_string(font,pos+Vector2(6,15),caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,caption.color)
			y += 24.0
