extends Control
# Source CSS: 45% width, center at 50%/68.5%, five contamination thresholds.
const LABELS = ["안정","확산","침식","재앙","임계"]
var target_value = 0.0
var display_value = 0.0
var frame: Texture2D
var gradient: GradientTexture2D
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 7
	size = Vector2(576,115.2)
	position = Vector2(352,435.6)
	frame = load("res://assets/map/ui/contamination_hud.png")
	var colors = Gradient.new()
	colors.colors = PackedColorArray([Color("6f6b62"),Color("77734f"),Color("725b32"),Color("873124"),Color("c51d17")])
	colors.offsets = PackedFloat32Array([0.0,0.24,0.43,0.67,1.0])
	gradient = GradientTexture2D.new()
	gradient.gradient = colors
	gradient.width = 512
	gradient.height = 24
func set_value(value: int, instant: bool = false) -> void:
	target_value = clampf(value,0,100)
	if instant: display_value = target_value
	queue_redraw()
func _process(delta: float) -> void:
	if absf(display_value-target_value)>0.01:
		display_value = move_toward(display_value,target_value,delta*100.0/0.28)
		queue_redraw()
func _draw() -> void:
	if frame==null: return
	var backing = StyleBoxFlat.new()
	backing.bg_color = Color("211811")
	backing.set_corner_radius_all(8)
	draw_style_box(backing,Rect2(size*Vector2(0.015,0.13),size*Vector2(0.97,0.74)))
	draw_texture_rect(frame,Rect2(Vector2.ZERO,size),false)
	var meter = Rect2(size*Vector2(0.2455,0.405),size*Vector2(0.4975,0.195))
	draw_rect(meter,Color("160d09"))
	if display_value>0:
		draw_texture_rect(gradient,Rect2(meter.position,Vector2(meter.size.x*display_value/100.0,meter.size.y)),false)
	for i in range(1,5):
		var x = meter.position.x+meter.size.x*i/5.0
		draw_line(Vector2(x,meter.position.y),Vector2(x,meter.end.y),Color("100c09aa"),1)
	var font = get_theme_default_font()
	draw_string(font,size*Vector2(0.25,0.34),"오염도",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("39251c"))
	var stage_index = mini(int(target_value)/20,4)
	var stage_color = [Color("302118"),Color("5f5a2f"),Color("744726"),Color("821e18"),Color("821e18")][stage_index]
	var caption = LABELS[stage_index]
	var text_x = size.x*0.881-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x/2.0
	draw_string(font,Vector2(text_x,size.y*0.48),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,stage_color)
	caption = "%d / 100" % int(target_value)
	text_x = size.x*0.881-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x/2.0
	draw_string(font,Vector2(text_x,size.y*0.67),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("302118"))
