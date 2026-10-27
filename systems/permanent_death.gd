extends Control
const AltarUpgradeBadge = preload("res://systems/altar_upgrade_badge.gd")
const LayeredUnitCard = preload("res://systems/layered_unit_card.gd")

var scene
var souls: Array = []
var elapsed = 0.0
var dissolving = false
var capture_dissolve_duration: float = 0.65

# The same ash-and-soul dissolve is also used when a defeated enemy's soul
# cannot be harvested. This is a presentation-only effect; no roster edits.
const DISSOLVE_SHADER_SOURCE = """
shader_type canvas_item;
uniform float dissolve : hint_range(0.0,1.0) = 0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
float noise(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	vec4 source = texture(TEXTURE,UV)*vertex_tint;
	float field = noise(floor(UV*160.0))*0.55+(1.0-UV.y)*0.45;
	float edge = smoothstep(dissolve,dissolve+0.065,field);
	float glow = (1.0-smoothstep(dissolve+0.065,dissolve+0.14,field))*edge;
	COLOR = vec4(mix(source.rgb,vec3(0.87,0.70,1.0),glow),source.a*edge);
}
"""

func _apply_material_to_capture_layers(parent: Node, mat: ShaderMaterial) -> void:
	for child in parent.get_children():
		if child is CanvasItem:
			(child as CanvasItem).material = mat
		_apply_material_to_capture_layers(child, mat)

func play_failed_capture(battle_scene, failed_cards: Array, duration: float = 0.65, with_sound: bool = true) -> void:
	scene = battle_scene
	capture_dissolve_duration = maxf(duration,0.05)
	# Parent lives in the same coordinates as candidate cards: the map stage
	# for embedded battles, or the ordinary battle layer otherwise.
	size = get_parent().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	var dissolve_shader = Shader.new()
	dissolve_shader.code = DISSOLVE_SHADER_SOURCE
	for card in failed_cards:
		if not is_instance_valid(card): continue
		# A separate material per card is essential for independent card state.
		var mat = ShaderMaterial.new()
		mat.shader = dissolve_shader
		card.material = mat
		# Layered cards have a transparent original TextureButton and draw
		# the portrait, banner and brands as children. Dissolve the visible
		# layers too; shading the old flattened texture alone is invisible.
		if card.has_node("LayeredCardBase"):
			_apply_material_to_capture_layers(card, mat)
		card.disabled = true
		souls.append({"card":card,"center":card.position+card.size*0.5})
	if souls.is_empty(): return
	if with_sound: scene.sound("permanent-death")
	dissolving = true
	elapsed = 0.0
	var remaining: float = capture_dissolve_duration
	while remaining>0.0:
		await get_tree().process_frame
		if not scene.paused:
			remaining -= get_process_delta_time()*scene.speed_values[scene.speed_index]*scene.battle_tempo
		var t = clampf(1.0-remaining/capture_dissolve_duration,0.0,1.0)
		for soul in souls:
			if is_instance_valid(soul.card):
				soul.card.material.set_shader_parameter("dissolve",t)
	for soul in souls:
		if is_instance_valid(soul.card):
			soul.card.hide()
	dissolving = false
	queue_redraw()

func _process(delta: float) -> void:
	if scene == null: return
	if not scene.paused: elapsed += delta*scene.speed_values[scene.speed_index]*scene.battle_tempo
	queue_redraw()

func _draw() -> void:
	if not dissolving: return
	var t = clampf(elapsed/capture_dissolve_duration,0,1)
	for soul in souls:
		var p: Vector2 = soul.center+Vector2(sin(t*5)*8,-90*t)
		for ring in range(4):
			draw_circle(p,15-ring*3,Color(0.72,0.62,1.0,(1-t)*0.12))
		draw_circle(p,3.5,Color(0.92,0.86,1.0,(1-t)*0.9))
		for i in range(36):
			var angle = float(i)*2.39996
			var offset = Vector2(cos(angle),sin(angle))*float(15+i%9*4)*t
			var ash: Vector2 = soul.center+offset+Vector2(sin(i*1.4)*20*t,-(25+i%7*8)*t)
			draw_circle(ash,1.0+i%3*0.5,Color(0.72,0.65,0.85,(1-t)*0.75))

func _apply_card_dissolve(node: Node, shader_material: ShaderMaterial) -> void:
	for child in node.get_children():
		if child is CanvasItem: child.material = shader_material
		_apply_card_dissolve(child,shader_material)

func play(battle_scene, fallen: Array) -> void:
	scene = battle_scene
	size = scene.surface_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	var permanent = fallen.filter(func(u): return u.team=="ally" and not u.is_summon)
	var ordinary = fallen.filter(func(u): return u.team!="ally" or u.is_summon)
	for u in ordinary:
		scene.sound("dragon_death" if str(u.slug)=="dragon" else "death")
		# The dragon frames already darken, rot and collapse progressively.
		# Do not pre-dim them to the generic 35% corpse opacity.
		if str(u.slug)=="dragon": scene.sprites[u.id].modulate=Color.WHITE
	if not permanent.is_empty():
		scene.visuals.presentation_hold = true
		await scene.wait_time(0.10)
		scene.visuals.presentation_hold = false
		var veil = ColorRect.new()
		veil.show_behind_parent = true
		veil.size = size
		veil.color = Color(0.015,0.008,0.035,0.74)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(veil)
		scene.sound("permanent-death")
		scene.visuals.duck_until = scene.visuals.clock+1.5
		for u in permanent:
			var source: TextureRect = scene.sprites[u.id]
			var focus = TextureRect.new()
			focus.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			focus.stretch_mode = source.stretch_mode
			focus.size = source.size
			focus.position = source.position
			focus.texture = source.texture
			focus.flip_h = source.flip_h
			focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(focus)
			# Dissolve the same layered artwork the player fought with.
			var card: Control = LayeredUnitCard.flight_visual_copy(scene.cards[u.id])
			if card == null:
				card = LayeredUnitCard.make_preview(self,u,Vector2.ZERO,scene.cards[u.id].size)
			else:
				add_child(card)
			card.size = scene.cards[u.id].size
			card.position = Vector2(scene.cards[u.id].position.x,scene.card_rest_y()-18.8)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			AltarUpgradeBadge.sync(card,u)
			source.visible = false
			scene.bars[u.id].visible = false
			scene.cards[u.id].visible = false
			var title = Label.new()
			title.text = u.name+" · 영구사망"
			title.position = Vector2(clampf(scene.unit_x(u)-100,12,1068),card.position.y-30)
			title.size = Vector2(200,30)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			title.add_theme_color_override("font_color",Color("e0c8ee"))
			title.add_theme_font_size_override("font_size",16)
			add_child(title)
			souls.append({"unit":u,"focus":focus,"card":card,"title":title,"center":focus.position+focus.size*Vector2(0.5,0.55)})
	var frame_count = 1
	for u in fallen: frame_count = maxi(frame_count,scene.motion_frames(u,"death").size())
	for index in range(frame_count):
		for u in ordinary:
			var tex = scene.texture(scene.frame_path(u,"death",int(scene.motion_frames(u,"death")[mini(index,scene.motion_frames(u,"death").size()-1)])))
			if tex!=null: scene.sprites[u.id].texture = tex
		for soul in souls:
			var tex = scene.texture(scene.frame_path(soul.unit,"death",int(scene.motion_frames(soul.unit,"death")[mini(index,scene.motion_frames(soul.unit,"death").size()-1)])))
			if tex!=null: soul.focus.texture = tex
		var frame_delay = 0.065 if permanent.is_empty() else 0.08
		for u in fallen:
			var profile: Dictionary = scene.presentation_layout.metrics.get(u.slug,{})
			var delays: Array = profile.get("death_delays",[])
			if index<delays.size(): frame_delay = maxf(frame_delay,float(delays[index]))
		await scene.wait_time(frame_delay)
	if not souls.is_empty():
		var shader = Shader.new()
		shader.code = DISSOLVE_SHADER_SOURCE
		for soul in souls:
			var material = ShaderMaterial.new()
			material.shader = shader
			soul.focus.material = material
			var card_material = ShaderMaterial.new()
			card_material.shader = shader
			soul.card.material = card_material
			_apply_card_dissolve(soul.card,card_material)
		dissolving = true
		elapsed = 0
		var remaining = 0.65
		while remaining>0:
			await get_tree().process_frame
			if not scene.paused: remaining -= get_process_delta_time()*scene.speed_values[scene.speed_index]*scene.battle_tempo
			var t = clampf(1-remaining/0.65,0,1)
			for soul in souls:
				soul.focus.material.set_shader_parameter("dissolve",t)
				soul.card.material.set_shader_parameter("dissolve",t)
				soul.card.position.y = scene.card_rest_y()-18.8+t*24
				soul.title.modulate.a = 1-t*0.5
		for soul in souls:
			scene.visuals.removed[soul.unit.id] = true
		var remaining_fade = 0.18
		while remaining_fade>0:
			await get_tree().process_frame
			if not scene.paused: remaining_fade -= get_process_delta_time()*scene.speed_values[scene.speed_index]*scene.battle_tempo
			modulate.a = maxf(0,remaining_fade/0.18)
	for u in ordinary:
		if u.is_summon:
			scene.visuals.removed[u.id] = true
			scene.sprites[u.id].visible = false
			scene.bars[u.id].visible = false
			scene.cards[u.id].visible = false
	queue_free()
