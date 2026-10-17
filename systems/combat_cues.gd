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
	brand_body_interval = minf(0.18, MAX_BRAND_PRESENTATION_SECONDS / float(maxi(1, triggered_units))) if dense else 0.26
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
		var effect_color = Color("ffe4a3") if is_blessed else Color("80628d")
		impact = {"id":unit.id,"mode":"bless" if is_blessed else "curse","started":clock,"duration":0.17 if is_blessed else 0.20}
		# Reveal the HP-bar icon in the exact same frame as the body impact.
		# Both animations now share their start; never reveal at round resolution.
		if scene.bars.has(unit.id):
			var fate_icon = scene.bars[unit.id].get_node_or_null("FateIcon")
			if fate_icon != null:
				fate_icon.set_mode("curse" if is_cursed else "bless")
		step(("축복 " if is_blessed else "저주 ")+str(unit.name),effect_color)
		# Upward gold column for blessing; descending dark veil for curse.
		var tween = create_tween()
		tween.tween_property(sprite,"modulate",effect_color if is_blessed else Color("81738a"),0.075)
		tween.tween_property(sprite,"modulate",base_modulate,0.17)
		await scene.wait_presentation(brand_body_interval,0.12 if dense else 0.23)
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

func _draw() -> void:
	if scene==null: return
	if not impact.is_empty() and scene.visuals.states.has(impact.id):
		var unit: Dictionary = scene.visuals.states[impact.id]
		var t: float = clampf((clock-float(impact.started))/float(impact.duration),0.0,1.0)
		var center: Vector2 = scene.presentation_layout.geometry(unit,scene.surface_size).effect
		if impact.mode=="bless":
			# Narrow upward light column: distinct from radial attack-hit bursts.
			var alpha: float = sin(t*PI)*0.85
			var rise: float = 155.0*t
			var half_width: float = 29.0*(1.0-0.22*t)
			var foot: Vector2 = center+Vector2(0,62)
			draw_colored_polygon(PackedVector2Array([
				foot+Vector2(-half_width,0),foot+Vector2(half_width,0),
				foot+Vector2(half_width*0.54,-90.0-rise),
				foot+Vector2(-half_width*0.54,-90.0-rise)
			]),Color(1.0,0.75,0.24,0.24*alpha))
			draw_line(foot+Vector2(0,-4),foot+Vector2(0,-95.0-rise),Color(1.0,0.95,0.70,0.8*alpha),10.0,true)
			for i in range(5):
				var dx: float = (float(i)-2.0)*11.0
				var y: float = 42.0-float(i%3)*24.0-rise*(0.6+float(i)*0.09)
				draw_circle(center+Vector2(dx,y),2.5+float(i%2),Color(1.0,0.9,0.5,alpha))
		else:
			# A localized veil settles DOWN over the monster; no expanding blast.
			var alpha: float = sin(t*PI)
			var descent: float = 55.0*t
			var shade_top: float = -104.0+descent
			draw_colored_polygon(PackedVector2Array([
				center+Vector2(-39,shade_top),center+Vector2(39,shade_top),
				center+Vector2(35,70),center+Vector2(-35,70)
			]),Color(0.09,0.045,0.15,0.29*alpha))
			for i in range(5):
				var dx: float = (float(i)-2.0)*16.0
				var top: Vector2 = center+Vector2(dx,shade_top+float(i%2)*10.0)
				draw_line(top,top+Vector2(dx*0.12,48.0+25.0*t),Color(0.36,0.22,0.47,0.50*alpha),4.0,true)
	if not chain_pulse.is_empty() and scene.visuals.states.has(chain_pulse.id):
		var pulse_unit: Dictionary = scene.visuals.states[chain_pulse.id]
		var progress: float = clampf((clock-float(chain_pulse.started))/float(chain_pulse.duration),0.0,1.0)
		var center: Vector2 = scene.presentation_layout.geometry(pulse_unit,scene.surface_size).effect
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
