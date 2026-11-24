extends Control
const Accent = preload("res://systems/presentation_accent.gd")
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
var _had_drawn_content: bool = false
const MAX_BRAND_INDICATORS := 3
const MAX_BRAND_PRESENTATION_SECONDS := 2.8
const FAST_BRAND_UNIT_THRESHOLD := 5
# Keep body effects readable within the dense-round cue budget.
const NORMAL_FATE_BODY_TIME := 0.42
const DENSE_FATE_BODY_TIME := 0.27
const CHAIN_TORSO_FRACTION := 0.40
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
	delta *= scene.battle_tempo
	if not scene.paused and not scene.visuals.presentation_hold: clock += delta
	if not dice_result.is_empty():
		var t = clampf((clock-dice_result.started)/DICE_TIME,0,1)
		scene.dice.scale = dice_base_scale*(1.0+sin(t*PI)*(0.12 if dice_result.face in [1,6] else 0.08))
	if rail_box.visible:
		rail_box.size = rail_box.get_combined_minimum_size()
		rail_box.position = Vector2((size.x-rail_box.size.x)/2.0,58.0)
		rail_box.visible = clock<expiry
	var drawn_content: bool = not marks.is_empty() or not impact.is_empty() or not chain_pulse.is_empty()
	if drawn_content or _had_drawn_content: queue_redraw()
	_had_drawn_content = drawn_content

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

func play_legion_entry() -> void:
	var active: Array[String] = []
	var points: Array[Vector2] = []
	for key in scene.rules.legions.get("ally",{}).get("active",[]):
		if scene.rules.active("ally",key): active.append(str(key))
	if active.is_empty(): return
	for unit in scene.rules.units:
		if unit.team!="ally" or unit.is_summon or not unit.alive: continue
		var participates := false
		for key in unit.legions:
			if key in active: participates = true
		if participates: points.append(Vector2(scene.unit_x(unit),scene.unit_floor_y()-6.0))
	if points.is_empty(): return
	var visual = weakref(scene.visuals)
	var cue := Accent.create(self,"legion",points,Color("e0c28a"),0.90,func():
		var live = visual.get_ref()
		return float(live.clock) if is_instance_valid(live) else 999999.0)
	var captions: Array[String] = []
	for key in active: captions.append(str(scene.LEGIONS.get(key,key)))
	cue.caption = " · ".join(captions)+" 군단"
	cue.caption_rect = Rect2(size.x*0.15,size.y*0.10,size.x*0.7,32)
	await scene.wait_presentation(0.90)

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
		# Highlight each actually matched brand on the dock card before the body cue.
		await _pulse_matching_brands(unit)
		if not is_inside_tree(): return
		if blessing_count>0 and chain_count>1:
			chain_pulse = {"id":unit.id,"started":clock,"duration":0.26,"count":chain_count}
		_pulse_unit_card(unit.id, is_blessed)
		# A dual trigger must show BOTH visual identities. Previously blessing
		# silently masked the curse body cue even though the HP icon said curse.
		var impact_mode: String = "mixed" if is_blessed and is_cursed else ("bless" if is_blessed else "curse")
		var effect_color: Color = Color("f1a0ff") if impact_mode=="mixed" else (Color("ffe5a3") if is_blessed else Color("dda0ff"))
		# Wait time is adjusted by the game's presentation speed. Draw the
		# body effects over the same interval so they complete cleanly
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
		await scene.wait_presentation(brand_body_interval,minimum_body_time)
		if not is_inside_tree(): return
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
		var flash := create_tween().set_speed_scale(scene.battle_tempo).set_parallel(true)
		flash.tween_property(dot, "modulate:a", 1.0, 0.065)
		flash.tween_property(dot, "scale", Vector2(1.22, 1.22), 0.095).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if brand_cue_interval >= 0.1:
			step(("축복 " if entry.bless else "저주 ") + str(entry.name), Color("ffe19a") if entry.bless else Color("b49acb"))
		await scene.wait_presentation(brand_cue_interval,0.045 if brand_cue_interval < 0.1 else 0.075)
		if not is_inside_tree(): return
	if is_instance_valid(indicator):
		var fade := create_tween().set_speed_scale(scene.battle_tempo)
		fade.tween_property(indicator, "modulate:a", 0.0, 0.16)
		fade.tween_callback(indicator.queue_free)

func _pulse_unit_card(unit_id: String, blessed: bool) -> void:
	# Card pulses after the resolved battlefield cue.
	# Presentation only: no changes to brand values, rules, or RNG.
	if scene == null or not scene.cards.has(unit_id): return
	var card: Control = scene.cards[unit_id]
	if not is_instance_valid(card): return
	var base_scale: Vector2 = card.scale
	var tween := create_tween().set_speed_scale(scene.battle_tempo)
	tween.tween_property(card, "scale", base_scale * (1.045 if blessed else 1.025), 0.075).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", base_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
	var upper_torso: float=clampf((visible_top+(visible_bottom-visible_top)*CHAIN_TORSO_FRACTION)/image_height,0.12,0.80)
	var canvas_point: Vector2=sprite.get_global_transform_with_canvas()*Vector2(sprite.size.x*0.5,sprite.size.y*upper_torso)
	return get_global_transform_with_canvas().affine_inverse()*canvas_point

func body_column_bounds(unit: Dictionary, t: float, descending: bool) -> Rect2:
	var sprite: TextureRect = scene.sprites[unit.id]
	var profile: Dictionary = scene.presentation_layout.metrics.get(str(unit.slug),{})
	var head_fraction := float(profile.get("top",0))/maxf(1.0,float(profile.get("height",320)))
	var into_cues := get_global_transform_with_canvas().affine_inverse()*sprite.get_global_transform_with_canvas()
	var foot := into_cues*sprite.pivot_offset
	var head := into_cues*Vector2(sprite.pivot_offset.x,sprite.size.y*head_fraction)
	var height := maxf(24.0,foot.y-head.y+8.0)
	var width := clampf(height*0.44,24.0,88.0)*lerpf(0.55,1.0,smoothstep(0.0,0.24,t))
	var span := lerpf(8.0,height,smoothstep(0.0,0.60,t))
	var tail := height*0.22*smoothstep(0.71,1.0,t)
	var top := foot.y-height+tail if descending else foot.y-span
	if descending: width *= 1.18
	return Rect2(foot.x-width*0.5,top,width,span-tail)

func _draw_body_column(bounds: Rect2, t: float, descending: bool) -> void:
	var strength := (0.55+0.45*smoothstep(0.0,0.18,t))*(1.0-smoothstep(0.58,1.0,t))
	var center_x := bounds.get_center().x
	var half_width := bounds.size.x*0.5
	var base := bounds.position.y if descending else bounds.end.y
	var tip := bounds.end.y if descending else bounds.position.y
	var offsets := [-1.0,-0.62,0.0,0.62,1.0] if descending else [-1.0,-0.42,0.0,0.42,1.0]
	var rim := Color("302639") if descending else Color(1.0,0.65,0.22)
	var core := Color("09060e") if descending else rim
	var tip_rim := Color("695878") if descending else Color(1.0,0.95,0.72)
	var tip_core := Color("140e1c") if descending else tip_rim
	var rim_alpha := (0.46 if descending else 0.20)*strength
	var core_alpha := (0.94 if descending else 0.58)*strength
	var origin_colors := PackedColorArray([
		Color(rim,0.0),Color(rim,rim_alpha),Color(core,core_alpha),Color(rim,rim_alpha),Color(rim,0.0)
	])
	var tip_colors := PackedColorArray([
		Color(tip_rim,0.0),Color(tip_rim,rim_alpha*0.74),Color(tip_core,core_alpha*0.74),
		Color(tip_rim,rim_alpha*0.74),Color(tip_rim,0.0)
	])
	for i in range(4):
		var left: float = offsets[i]*half_width
		var right: float = offsets[i+1]*half_width
		draw_polygon(PackedVector2Array([
			Vector2(center_x+left,base),Vector2(center_x+right,base),
			Vector2(center_x+right*0.58,tip),Vector2(center_x+left*0.58,tip)
		]),PackedColorArray([
			origin_colors[i],origin_colors[i+1],tip_colors[i+1],tip_colors[i]
		]))
	for i in range(5):
		var progress := fposmod(t*(1.15+0.08*i)+0.16*i,1.0)
		var x := center_x+(float(i)-2.0)*half_width*0.33
		var y := lerpf(base,tip,progress)
		var trail := minf(20.0,bounds.size.y*0.16)
		var trail_y := maxf(base,y-trail) if descending else minf(base,y+trail)
		var streak := Color("a590bd") if descending else Color(1.0,0.94,0.68)
		streak.a = sin(progress*PI)*strength*(0.70 if descending else 0.90)
		draw_line(Vector2(x,trail_y),Vector2(x,y),streak,1.5,true)

func _draw() -> void:
	if scene==null: return
	if not impact.is_empty() and scene.visuals.states.has(impact.id):
		var unit: Dictionary=scene.visuals.states[impact.id]
		var t: float=clampf((clock-float(impact.started))/maxf(0.01,float(impact.duration)),0.0,1.0)
		var split := Vector2(11.0,0.0) if impact.mode=="mixed" else Vector2.ZERO
		if impact.mode in ["curse","mixed"]:
			var shadow := body_column_bounds(unit,t,true)
			shadow.position -= split
			_draw_body_column(shadow,t,true)
		if impact.mode in ["bless","mixed"]:
			var light := body_column_bounds(unit,t,false)
			light.position += split
			_draw_body_column(light,t,false)
	if not chain_pulse.is_empty() and scene.visuals.states.has(chain_pulse.id):
		var pulse_unit: Dictionary = scene.visuals.states[chain_pulse.id]
		var progress: float = clampf((clock-float(chain_pulse.started))/float(chain_pulse.duration),0.0,1.0)
		var center: Vector2 = chest_anchor(pulse_unit)
		var opacity: float = sin(progress*PI)*0.42
		var radius: float = 22.0+progress*30.0
		draw_arc(center,radius,-PI*0.82,PI*0.82,28,Color(1.0,0.83,0.40,opacity),2.0,true)
	# Temporary captions use the center of the header, clear of the HP/status lanes.
	var font: Font = scene.get_theme_default_font()
	for mark in marks:
		var widths: Array[float] = []
		var total := -5.0
		for caption in mark.captions:
			var width := font.get_string_size(tr(caption.text),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+12.0
			widths.append(width)
			total += width+5.0
		var x := (size.x-total)*0.5
		for index in range(mark.captions.size()):
			var caption: Dictionary = mark.captions[index]
			var pos := Vector2(x,54.0)
			draw_style_box(pill(Color("17100fee"),caption.color.darkened(0.3),10,6),Rect2(pos,Vector2(widths[index],20)))
			draw_string(font,pos+Vector2(6,14),tr(caption.text),HORIZONTAL_ALIGNMENT_LEFT,-1,11,caption.color)
			x += widths[index]+5.0
