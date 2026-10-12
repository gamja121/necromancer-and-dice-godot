extends Control
## Pure presentation of the saved 0..100 world contamination value. Never
## modifies RunSession, source RNG, tiles, receipts, or save state.
const LABELS = ["안정","확산","침식","재앙","임계"]
const FRAME_PATH = "res://assets/map/ui/contamination_frame_10.webp"
const SOURCE_SIZE = Vector2(2172.0,724.0)
# Cut-out source coordinates: nine separators mean *ten* physical windows.
# The end recesses are narrower in the original approved illustration;
# each logical window always represents exactly ten contamination points.
const EDGES = [582.0,675.0,821.0,969.0,1118.0,1266.0,1413.0,1559.0,1703.0,1802.0,1836.0]
const COLORS = [
	Color("275d3e"),Color("4b7b44"),Color("7b853a"),Color("a49a41"),
	Color("b17a31"),Color("b66232"),Color("aa492e"),Color("9b3935"),
	Color("88405e"),Color("74336e")
]
var target_value: float = 0.0
var display_value: float = 0.0
var frame: Texture2D
var uses_approved_art: bool = false
var last_art_error: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 7
	# Keep the lower-center stone board meter, with natural 3:1 source ratio.
	size = Vector2(576,192)
	position = Vector2(352,379)
	_load_approved_frame()
	if not uses_approved_art:
		# Safe release fallback for any damaged embedded visual resource.
		frame = load("res://assets/map/ui/contamination_hud.png")
		size = Vector2(576,115.2)
		position = Vector2(352,435.6)

func _load_approved_frame() -> void:
	# Approved high-quality WebP is a normal Godot imported texture.
	if not ResourceLoader.exists(FRAME_PATH):
		last_art_error = "approved WebP asset unavailable"
		return
	frame = load(FRAME_PATH)
	if frame == null:
		last_art_error = "approved WebP image failed to load"
		return
	if frame.get_width() != 1440 or frame.get_height() != 480:
		last_art_error = "wrong size on approved image"
		frame = null
		return
	uses_approved_art = true

func set_value(value: int, instant: bool = false) -> void:
	target_value = clampf(float(value),0.0,100.0)
	if instant: display_value = target_value
	queue_redraw()

func _process(delta: float) -> void:
	if absf(display_value-target_value)>0.01:
		display_value = move_toward(display_value,target_value,delta*100.0/0.28)
		queue_redraw()

## Percentage -> 10 independent 0..1 stages, including a partial current
## stage. Exposed for actual 0/1/9/10/12/50/99/100 regression tests.
func segment_fractions(value: float) -> PackedFloat32Array:
	var fractions := PackedFloat32Array()
	var stage: float = clampf(value,0.0,100.0)/10.0
	for i in range(10):
		fractions.append(clampf(stage-float(i),0.0,1.0))
	return fractions

func _draw() -> void:
	if frame == null: return
	if uses_approved_art: _draw_ten_slot_hud()
	else: _draw_legacy_safe_hud()

func _draw_ten_slot_hud() -> void:
	var fractions := segment_fractions(display_value)
	var scale: Vector2 = size/SOURCE_SIZE
	var top: float = 350.0*scale.y
	var height: float = 97.0*scale.y
	# The original approved frame has real transparency in each window.
	# Draw dark glass + dynamic progress *behind* gold diamonds and stone.
	for i in range(10):
		var left: float = EDGES[i]*scale.x
		var span: float = (EDGES[i+1]-EDGES[i])*scale.x
		var cutout := Rect2(Vector2(left,top),Vector2(span,height))
		draw_rect(cutout,Color("171914",0.84))
		if fractions[i] <= 0.0: continue
		var fill := Rect2(cutout.position,Vector2(maxf(0.0,span*fractions[i]),height))
		draw_rect(fill,COLORS[i])
		# Flat hand-painted highlights echo the selected board tile style,
		# leaving transparent boundaries and animation room above the fill.
		var highlight := Rect2(fill.position+Vector2(0,2*scale.y),Vector2(fill.size.x,maxf(1,height*0.16)))
		draw_rect(highlight,Color(1.0,0.88,0.65,0.13))
	draw_texture_rect(frame,Rect2(Vector2.ZERO,size),false)
	var font: Font = get_theme_default_font()
	var title: String = "오염도"
	var title_size: int = 22
	var center_x: float = 350.0*scale.x
	var tw: float = font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x
	var title_at := Vector2(center_x-tw/2.0,382.0*scale.y)
	draw_string_outline(font,title_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size,2,Color("211711"))
	draw_string(font,title_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size,Color("251b15"))
	var value_text: String = "%d / 100" % int(target_value)
	var size_px: int = 17
	var vw: float = font.get_string_size(value_text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
	var value_at := Vector2(center_x-vw/2.0,462.0*scale.y)
	draw_string_outline(font,value_at,value_text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,1,Color("211811"))
	draw_string(font,value_at,value_text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,Color("38251b"))

func _draw_legacy_safe_hud() -> void:
	draw_rect(Rect2(size*Vector2(0.015,0.13),size*Vector2(0.97,0.74)),Color("211811"))
	draw_texture_rect(frame,Rect2(Vector2.ZERO,size),false)
	var meter := Rect2(size*Vector2(0.2455,0.405),size*Vector2(0.4975,0.195))
	draw_rect(meter,Color("160d09"))
	var fractions := segment_fractions(display_value)
	for i in range(10):
		if fractions[i]<=0: continue
		var x: float = meter.position.x+meter.size.x*float(i)/10.0
		draw_rect(Rect2(x,meter.position.y,meter.size.x/10.0*fractions[i],meter.size.y),COLORS[i])
	for i in range(1,10):
		var x: float = meter.position.x+meter.size.x*i/10.0
		draw_line(Vector2(x,meter.position.y),Vector2(x,meter.end.y),Color("100c09aa"),1.0)
	var font: Font = get_theme_default_font()
	draw_string(font,size*Vector2(0.25,0.34),"오염도",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("39251c"))
	var stage_index: int = mini(int(target_value)/20,4)
	var caption: String = LABELS[stage_index]
	var text_x: float = size.x*0.881-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x/2.0
	draw_string(font,Vector2(text_x,size.y*0.48),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("302118"))
	caption = "%d / 100" % int(target_value)
	text_x = size.x*0.881-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x/2.0
	draw_string(font,Vector2(text_x,size.y*0.67),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("302118"))
