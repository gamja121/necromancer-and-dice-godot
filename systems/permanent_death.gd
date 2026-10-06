extends Control

var scene
var souls: Array = []
var elapsed = 0.0
var dissolving = false

func _process(delta: float) -> void:
	if scene == null: return
	if not scene.paused: elapsed += delta*scene.speed_values[scene.speed_index]
	queue_redraw()

func _draw() -> void:
	if not dissolving: return
	var t = clampf(elapsed/0.65,0,1)
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

func play(battle_scene, fallen: Array) -> void:
	scene = battle_scene
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	var permanent = fallen.filter(func(u): return u.team=="ally" and not u.is_summon)
	var ordinary = fallen.filter(func(u): return u.team!="ally" or u.is_summon)
	for u in ordinary: scene.sound("death")
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
			var card = TextureRect.new()
			card.texture = scene.cards[u.id].texture_normal
			card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			card.size = scene.cards[u.id].size
			card.position = Vector2(scene.cards[u.id].position.x,594)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(card)
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
	for frame in range(1,11):
		for u in ordinary:
			var tex = scene.texture(scene.frame_path(u,"death",frame))
			if tex!=null: scene.sprites[u.id].texture = tex
		for soul in souls:
			var tex = scene.texture(scene.frame_path(soul.unit,"death",frame))
			if tex!=null: soul.focus.texture = tex
		await scene.wait_time(0.065 if permanent.is_empty() else 0.08)
	if not souls.is_empty():
		var shader = Shader.new()
		shader.code = """
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
		for soul in souls:
			var material = ShaderMaterial.new()
			material.shader = shader
			soul.focus.material = material
			var card_material = ShaderMaterial.new()
			card_material.shader = shader
			soul.card.material = card_material
		dissolving = true
		elapsed = 0
		var remaining = 0.65
		while remaining>0:
			await get_tree().process_frame
			if not scene.paused: remaining -= get_process_delta_time()*scene.speed_values[scene.speed_index]
			var t = clampf(1-remaining/0.65,0,1)
			for soul in souls:
				soul.focus.material.set_shader_parameter("dissolve",t)
				soul.card.material.set_shader_parameter("dissolve",t)
				soul.card.position.y = 594+t*24
				soul.title.modulate.a = 1-t*0.5
		for soul in souls:
			scene.visuals.removed[soul.unit.id] = true
		var remaining_fade = 0.18
		while remaining_fade>0:
			await get_tree().process_frame
			if not scene.paused: remaining_fade -= get_process_delta_time()*scene.speed_values[scene.speed_index]
			modulate.a = maxf(0,remaining_fade/0.18)
	for u in ordinary:
		if u.is_summon:
			scene.visuals.removed[u.id] = true
			scene.sprites[u.id].visible = false
			scene.bars[u.id].visible = false
			scene.cards[u.id].visible = false
	queue_free()
