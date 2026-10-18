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
var chain_count: int = 0
var chain_pulse: Dictionary = {}
const MAX_BRAND_INDICATORS := 3
const MAX_BRAND_PRESENTATION_SECONDS := 2.8
const FAST_BRAND_UNIT_THRESHOLD := 5
# Longer, deliberate torso impacts; still under the original dense-round cue budget.
const NORMAL_FATE_BODY_TIME := 0.42
const DENSE_FATE_BODY_TIME := 0.27
const BLESS_TORSO_FRACTION := 0.40
var brand_cue_interval: float = 0.105
var brand_body_interval: float = 0.26

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
	chain_count = 0
	chain_pulse.clear()
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
	var triggered_units: int = 0
	for candidate in ordered:
		if not candidate.bless.is_empty() or not candidate.curse.is_empty():
			triggered_units += 1
	# Bound the total cue time when all eight combatants have active marks.
	var dense: bool = triggered_units >= FAST_BRAND_UNIT_THRESHOLD
	brand_cue_interval = 0.055 if dense else 0.105
	brand_body_interval = minf(DENSE_FATE_BODY_TIME, MAX_BRAND_PRESENTATION_SECONDS / float(maxi(1, triggered_units))) if dense else NORMAL_FATE_BODY_TIME
	for unit in ordered:
		var captions: Array = []
		for mode in ["bless","curse"]:
			for key in unit[mode]:
				if int(unit[mode][key])<=0: continue
				var color = Color("ffe19a") if mode=="bless" else Color("b49acb")
				var caption = ("축복 " if mode=="bless" else "저주 ")+NAMES.get(key,key)
				captions.append({"text":caption,"color":color,"mode":mode})
		if captions.is_empty(): continue
		# Count confirmed blessing triggers; no extra roll or gameplay event.
		var blessing_count: int = 0
		for caption in captions:
			if caption.mode=="bless": blessing_count += 1
		if blessing_count>0:
			chain_count += blessing_count
			step("축복 연쇄 ×%d" % chain_count,Color("ffe09a")) if chain_count>1 else step("축복 발동",Color("ffe09a"))
		marks = [{"id":unit.id,"captions":captions.slice(0,3)}]
		var is_blessed: bool = false
		var is_cursed: bool = false
		for caption in captions:
			if caption.mode=="bless": is_blessed=true
			if caption.mode=="curse": is_cursed=true
		var sprite: TextureRect = scene.sprites[unit.id]
		# Highlight each actually matched brand on the dock card before the body cue.
		await _pulse_matching_brands(unit)
		if not is_inside_tree(): return
		if blessing_count>0:
			chain_pulse = {"id":unit.id,"started":clock,"duration":0.26,"count":chain_count}
		_pulse_unit_card(unit.id, is_blessed)
		var base_modulate: Color = sprite.modulate
		# A dual trigger must show BOTH visual identities. Previously blessing
		# silently masked the curse body cue even though the HP icon said curse.
		var impact_mode: String = "mixed" if is_blessed and is_cursed else ("bless" if is_blessed else "curse")
		var effect_color: Color = Color("f1a0ff") if impact_mode=="mixed" else (Color("ffe5a3") if is_blessed else Color("dda0ff"))
		# Wait time is adjusted by the game's presentation speed. Draw the
		# chest mark over the *same real-time interval* so it completes cleanly
		# rather than being cut off while still at peak visibility.
		var minimum_body_time: float = 0.12 if dense else 0.23
		var actual_body_duration: float = maxf(minimum_body_time,brand_body_interval/minf(scene.speed_values[scene.speed_index],1.2))
		impact = {"id":unit.id,"mode":impact_mode,"started":clock,"duration":actual_body_duration}
		# Reveal the HP-bar icon in the exact same frame as the body impact.
		# Both animations now share their start; never reveal at round resolution.
		if scene.bars.has(unit.id):
			var fate_icon = scene.bars[unit.id].get_node_or_null("FateIcon")
			if fate_icon != null:
				fate_icon.set_mode("curse" if is_cursed else "bless")
		var caption: String = "축복·저주 " if impact_mode=="mixed" else ("축복 " if is_blessed else "저주 ")
		step(caption+str(unit.name),effect_color)
		# Brief, readable full-body feedback. The distinct chest effects below
		# carry the actual blessing/curse shape rather than a faint dark veil.
		var tween = create_tween()
		tween.tween_property(sprite,"modulate",effect_color,0.055)
		tween.tween_property(sprite,"modulate",base_modulate,0.14)
		await scene.wait_presentation(brand_body_interval,minimum_body_time)
		if not is_inside_tree(): return
		if is_instance_valid(tween): tween.kill()
		if is_instance_valid(sprite): sprite.modulate = base_modulate
		marks.clear()
		impact.clear()
		chain_pulse.clear()
	marks.clear()
	impact.clear()
	chain_pulse.clear()


func _pulse_matching_brands(unit: Dictionary) -> void:
	if scene == null or not scene.cards.has(unit.id): return
	var card: Control = scene.cards[unit.id]
	if not is_instance_valid(card): return
	var active: Array = []
	var face: int = int(scene.rules.face)
	for brand in unit.brands:
		var key: String = str(brand.get("type", ""))
		var cursed: bool = face in brand.get("curse", []) and int(unit.curse.get(key, 0)) > 0
		var blessed: bool = face in brand.get("bless", []) and int(unit.bless.get(key, 0)) > 0
		if blessed or cursed:
			active.append({"name": NAMES.get(key, key), "bless": blessed})
	if active.is_empty(): return
	var indicator := Control.new()
	indicator.name = "BrandTriggerIndicators"
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.size = card.size
	indicator.z_index = 4
	card.add_child(indicator)
	for i in range(mini(active.size(), MAX_BRAND_INDICATORS)):
		if not is_instance_valid(card) or not is_inside_tree(): break
		var entry: Dictionary = active[i]
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size = Vector2(12, 12)
		dot.position = Vector2(card.size.x * 0.5 + (float(i) - float(mini(active.size(), MAX_BRAND_INDICATORS)-1)*0.5)*17.0 - 6.0, card.size.y * 0.12)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("ffe4a0") if entry.bless else Color("b79acc")
		style.set_corner_radius_all(6)
		style.set_border_width_all(1)
		style.border_color = Color("fff2d2") if entry.bless else Color("dfc7f5")
		dot.add_theme_stylebox_override("panel", style)
		dot.modulate.a = 0.0
		dot.scale = Vector2(0.65, 0.65)
		dot.pivot_offset = dot.size * 0.5
		indicator.add_child(dot)
		var flash := create_tween().set_parallel(true)
		flash.tween_property(dot, "modulate:a", 1.0, 0.065)
		flash.tween_property(dot, "scale", Vector2(1.22, 1.22), 0.095).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if brand_cue_interval >= 0.1:
			step(("축복 " if entry.bless else "저주 ") + str(entry.name), Color("ffe19a") if entry.bless else Color("b49acb"))
		await scene.wait_presentation(brand_cue_interval,0.045 if brand_cue_interval < 0.1 else 0.075)
		if not is_inside_tree(): return
	if is_instance_valid(indicator):
		var fade := create_tween()
		fade.tween_property(indicator, "modulate:a", 0.0, 0.16)
		fade.tween_callback(indicator.queue_free)

func _pulse_unit_card(unit_id: String, blessed: bool) -> void:
	# Card and brand frame react in the same order as the resolved battlefield cue.
	# Presentation only: no changes to brand values, rules, or RNG.
	if scene == null or not scene.cards.has(unit_id): return
	var card: Control = scene.cards[unit_id]
	if not is_instance_valid(card): return
	var base_scale: Vector2 = card.scale
	var frame := card.get_node_or_null("BrandFrameOverlay") as CanvasItem
	var frame_color: Color = frame.modulate if frame != null else Color.WHITE
	var glow: Color = Color(1.0, 0.82, 0.38, 1.0) if blessed else Color(0.72, 0.56, 0.86, 1.0)
	var tween := create_tween()
	tween.tween_property(card, "scale", base_scale * (1.045 if blessed else 1.025), 0.075).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", base_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if frame != null:
		var frame_tween := create_tween()
		frame_tween.tween_property(frame, "modulate", glow, 0.07)
		frame_tween.tween_property(frame, "modulate", frame_color, 0.20)

# Use the opaque artwork's upper torso, not the ground-plane effect
# coordinate. This follows individual monsters' real sprite scale, breathing
# pose, depth, and hit displacement, even in embedded map battles.
func chest_anchor(unit: Dictionary) -> Vector2:
	if scene==null or not scene.sprites.has(unit.id):
		return Vector2.ZERO
	var sprite: TextureRect=scene.sprites[unit.id]
	var metric: Dictionary=scene.presentation_layout.metrics.get(str(unit.slug),{})
	var image_height: float=maxf(1.0,float(metric.get("height",320)))
	var visible_top: float=float(metric.get("top",0))
	var visible_bottom: float=float(metric.get("bottom",image_height-1.0))
	var upper_torso: float=clampf((visible_top+(visible_bottom-visible_top)*BLESS_TORSO_FRACTION)/image_height,0.12,0.80)
	var canvas_point: Vector2=sprite.get_global_transform_with_canvas()*Vector2(sprite.size.x*0.5,sprite.size.y*upper_torso)
	return get_global_transform_with_canvas().affine_inverse()*canvas_point

func _draw_chest_bless(center: Vector2, t: float, span: float) -> void:
	# A golden core IGNITES AT THE CHEST before emitting anything else.
	# Only upper-hemisphere rays: never a foot-to-head pillar or ground halo.
	var fade: float=pow(maxf(0.0,1.0-t),0.58)
	var core: float=(5.5+5.0*t)*span
	var ring_radius: float=(9.0+30.0*t)*span
	draw_circle(center,(16.0+19.0*t)*span,Color(1.0,0.56,0.09,0.40*fade))
	draw_circle(center,core*1.45,Color(1.0,0.80,0.22,0.70*fade))
	draw_circle(center,core*0.62,Color(1.0,1.0,0.89,0.98*fade))
	draw_arc(center,ring_radius,0.0,TAU,40,Color(1.0,0.87,0.39,0.90*fade),3.2*span,true)
	# Radial strokes cannot angle down into the feet: -PI..0 points up.
	for i in range(7):
		var direction: Vector2=Vector2.RIGHT.rotated(-PI+float(i)*PI/6.0)
		var from: Vector2=center+direction*(8.0+4.0*t)*span
		var to: Vector2=center+direction*(21.0+29.0*t)*span
		draw_line(from,to,Color(1.0,0.96,0.63,0.91*fade),2.9*span,true)
	for i in range(4):
		var dx: float=(float(i)-1.5)*(11.0+6.0*t)*span
		var dy: float=-(11.0+35.0*t+float(i%2)*7.0)*span
		draw_circle(center+Vector2(dx,dy),2.6*span,Color(1.0,0.96,0.72,0.85*fade))

func _draw_chest_curse(center: Vector2, t: float, span: float) -> void:
	# The curse is a visible MAGENTA FRACTURE over a dark chest scar, not
	# a darkened sprite. A two-stroke X remains legible on night maps/small
	# units, with a jagged ring that expands away from the chest only.
	var fade: float=pow(maxf(0.0,1.0-t),0.48)
	var strength: float=fade*(0.68+0.32*sin(minf(1.0,t*5.0)*PI*0.5))
	var radius: float=(12.0+29.0*t)*span
	draw_circle(center,(18.0+8.0*t)*span,Color(0.025,0.0,0.06,0.84*strength))
	draw_circle(center,(12.0+7.0*t)*span,Color(0.51,0.07,0.57,0.42*strength))
	# Bright outer split ring is intentionally much more opaque than the
	# former translucent violet mist.
	draw_arc(center,radius,-PI*0.92,PI*0.97,36,Color(1.0,0.30,0.93,1.0*strength),5.0*span,true)
	draw_arc(center,radius*1.16,PI*0.12,PI*1.82,32,Color(0.80,0.59,1.0,0.78*strength),2.7*span,true)
	var x: float=(10.0+3.0*t)*span
	var stroke_dark: Color=Color(0.06,0.005,0.09,0.97*strength)
	var stroke_bright: Color=Color(1.0,0.70,1.0,1.0*strength)
	draw_line(center+Vector2(-x,-x),center+Vector2(x,x),stroke_dark,8.0*span,true)
	draw_line(center+Vector2(x,-x),center+Vector2(-x,x),stroke_dark,8.0*span,true)
	draw_line(center+Vector2(-x,-x),center+Vector2(x,x),stroke_bright,3.9*span,true)
	draw_line(center+Vector2(x,-x),center+Vector2(-x,x),stroke_bright,3.9*span,true)
	for i in range(5):
		var x_offset: float=(float(i)-2.0)*10.0*span
		var upper: Vector2=center+Vector2(x_offset*0.38,-11.0*span)
		var kink: Vector2=center+Vector2(x_offset+(-7.0 if i%2==0 else 7.0)*span,(13.0+8.0*t)*span)
		var tip: Vector2=center+Vector2(x_offset*1.20,(27.0+19.0*t)*span)
		draw_line(upper,kink,Color(1.0,0.36,0.92,0.93*strength),3.5*span,true)
		draw_line(kink,tip,Color(0.88,0.68,1.0,0.90*strength),2.7*span,true)

func _draw() -> void:
	if scene==null: return
	if not impact.is_empty() and scene.visuals.states.has(impact.id):
		var unit: Dictionary=scene.visuals.states[impact.id]
		var t: float=clampf((clock-float(impact.started))/maxf(0.01,float(impact.duration)),0.0,1.0)
		var center: Vector2=chest_anchor(unit)
		var sprite: TextureRect=scene.sprites[unit.id]
		var span: float=clampf(sprite.size.y/150.0,0.72,1.30)
		if impact.mode in ["bless","mixed"]:
			_draw_chest_bless(center,t,span)
		if impact.mode in ["curse","mixed"]:
			_draw_chest_curse(center,t,span)
	if not chain_pulse.is_empty() and scene.visuals.states.has(chain_pulse.id):
		var pulse_unit: Dictionary = scene.visuals.states[chain_pulse.id]
		var progress: float = clampf((clock-float(chain_pulse.started))/float(chain_pulse.duration),0.0,1.0)
		var center: Vector2 = chest_anchor(pulse_unit)
		var opacity: float = sin(progress*PI)*0.42
		var radius: float = 22.0+progress*30.0
		draw_arc(center,radius,-PI*0.82,PI*0.82,28,Color(1.0,0.83,0.40,opacity),2.0,true)
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
