extends Control
## A shared ink pointer and alpha-shaped halo, outside gameplay controls.
const FONT = preload("res://assets/fonts/nanum_gothic_regular.ttf")
const HALO_SHADER = """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 padding = vec2(0.10);
void fragment() {
	vec2 p = UV * (vec2(1.0) + padding * 2.0) - padding;
	float inside = step(0.0,p.x)*step(p.x,1.0)*step(0.0,p.y)*step(p.y,1.0);
	float original = texture(TEXTURE,clamp(p,vec2(0.0),vec2(1.0))).a*inside;
	float halo = 0.0;
	for (int i = 0; i < 12; i++) {
		float angle = float(i)*0.52359878;
		vec2 q = p + vec2(cos(angle),sin(angle))*padding*0.70;
		float valid = step(0.0,q.x)*step(q.x,1.0)*step(0.0,q.y)*step(q.y,1.0);
		halo += texture(TEXTURE,clamp(q,vec2(0.0),vec2(1.0))).a*valid/12.0;
	}
	COLOR = vec4(1.0,0.77,0.34,halo*(1.0-original)*0.90);
}
"""
var target: Control
var halo_root: Node2D
var halo: Sprite2D
var hint: Label
var clock := 0.0
var marker_bounds := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	halo_root = Node2D.new()
	add_child(halo_root)
	halo = Sprite2D.new()
	halo.centered = false
	var shader := Shader.new()
	shader.code = HALO_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	halo.material = material
	halo_root.add_child(halo)
	hint = Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("font",FONT)
	hint.add_theme_font_size_override("font_size",14)
	hint.add_theme_color_override("font_color",Color("ffe4ab"))
	hint.add_theme_color_override("font_outline_color",Color("281b12"))
	hint.add_theme_constant_override("outline_size",5)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.clip_text = true
	add_child(hint)
	hide()

func follow(control: Control, description: String) -> void:
	target = control
	hint.text = description
	hint.visible = not description.is_empty()
	show()

func clear() -> void:
	target = null
	if is_instance_valid(halo): halo.texture = null
	hide()

func _process(delta: float) -> void:
	clock += delta
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		clear()
		return
	if not visible: return
	var transform_to_here := get_global_transform_with_canvas().affine_inverse()*target.get_global_transform_with_canvas()
	marker_bounds = transform_to_here*Rect2(Vector2.ZERO,target.size)
	var art: Texture2D
	var visual: Control = target
	if target is TextureButton: art = target.texture_normal
	if art == null:
		var base := target.get_node_or_null("LayeredCardBase") as TextureRect
		if base != null:
			art = base.texture
			visual = base
	if art == null:
		for child in target.get_children():
			if child is TextureRect and child.texture!=null and child.visible:
				art = child.texture
				visual = child
				break
	if art == null and target is Button:
		var paper := target.get_theme_stylebox("normal") as StyleBoxTexture
		if paper != null: art = paper.texture
	halo.visible = art != null
	if art != null:
		halo.texture = art
		halo_root.transform = get_global_transform_with_canvas().affine_inverse()*visual.get_global_transform_with_canvas()
		var padding := visual.size*0.10
		halo.position = -padding
		halo.scale = (visual.size+padding*2.0)/art.get_size()
		halo.modulate.a = 0.86+sin(clock*2.0)*0.10
	var screen := get_viewport_rect()
	var width := minf(360.0,screen.size.x-24.0)
	hint.size = Vector2(width,46)
	var hint_y := marker_bounds.end.y+8.0
	if hint_y+hint.size.y > screen.end.y-10.0:
		hint_y = marker_bounds.position.y-hint.size.y-26.0
	hint.position = Vector2(clampf(marker_bounds.get_center().x-width*0.5,12.0,screen.end.x-width-12.0),maxf(12.0,hint_y))
	queue_redraw()

func _draw() -> void:
	if not visible or not is_instance_valid(target): return
	if bool(target.get_meta("keyboard_focus_hide_arrow",false)): return
	var center := marker_bounds.get_center()
	var y := maxf(18.0,marker_bounds.position.y-13.0-(1.0-cos(clock*TAU/1.36))*1.75)
	var arrow := PackedVector2Array([
		Vector2(center.x-10,y-8),Vector2(center.x-3,y-7),
		Vector2(center.x-1,y-16),Vector2(center.x+4,y-15),
		Vector2(center.x+4,y-7),Vector2(center.x+11,y-8),
		Vector2(center.x+1,y+3)])
	draw_colored_polygon(arrow,Color("e7bd74"))
	var edge := arrow.duplicate()
	edge.append(arrow[0])
	draw_polyline(edge,Color("392417"),1.7,true)
	draw_line(Vector2(center.x,y-10),Vector2(center.x,y-3),Color("ffedbb"),1.0,true)
