extends Control
## Pure presentation of the saved 0..100 world contamination value. Never
## modifies RunSession, source RNG, tiles, receipts, or save state.
const LABELS = ["안정","확산","침식","재앙","임계"]
const FRAME_PATH = "res://assets/map/ui/contamination_crow_tile_10.webp"
const SOURCE_SIZE = Vector2(2172.0,724.0)
# The exact alpha-cutout positions were measured on the *chosen* crow / skull
# art (2172x724). Exactly 10 equally-valued, separately outlined slots.
const SLOT_X = [682.0,786.0,890.0,994.0,1097.0,1202.0,1305.0,1409.0,1513.0,1618.0]
const SLOT_WIDTH = 74.0
const SLOT_Y = 339.0
const SLOT_HEIGHT = 137.0
const COLORS = [
	Color("275d3e"),Color("4b7b44"),Color("7b853a"),Color("a49a41"),
	Color("b17a31"),Color("b66232"),Color("aa492e"),Color("9b3935"),
	Color("88405e"),Color("74336e")
]
# Colour anchors follow the entire ten-slot bar, rather than snapping one
# flat colour per segment. The original stone/crow art stays untouched.
var target_value: float = 0.0
var display_value: float = 0.0
var frame: Texture2D
var uses_approved_art: bool = false
var last_art_error: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 7
	# Match the accepted bottom-centre board mockup without overlapping tile input.
	# 3:1 aspect ratio retained; the compact meter stays centred on the board.
	size = Vector2(480,160)
	position = Vector2(400,395)
	_load_approved_frame()
	if not uses_approved_art:
		# Safe release fallback for any damaged embedded visual resource.
		frame = load("res://assets/map/ui/contamination_hud.png")
		size = Vector2(576,115.2)
		position = Vector2(352,435.6)

func _load_approved_frame() -> void:
	# User-selected crow/bar artwork is shipped as an imported Godot WebP.
	if not ResourceLoader.exists(FRAME_PATH):
		last_art_error = "selected crow WebP unavailable"
		return
	frame = load(FRAME_PATH)
	if frame == null:
		last_art_error = "selected crow WebP image failed to load"
		return
	if frame.get_width() != 1152 or frame.get_height() != 384:
		last_art_error = "wrong size on selected crow image"
		frame = null
		return
	uses_approved_art = true

## Stage-space physical obstacle for the map die. The rectangle only
## covers the solid visible face (not the raven's high transparent surround).
## It is not a Control mouse blocker: map clicks/overlays stay unchanged.
func dice_wall_rect() -> Rect2:
	if not visible or not is_inside_tree(): return Rect2()
	return Rect2(
		position + Vector2(size.x*0.028,size.y*0.32),
		Vector2(size.x*0.944,size.y*0.57)
	)

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

## Continuous green-to-yellow-to-red-to-purple blend over the entire meter.
## Driven only by the current position within the ten slots, never by RNG/save.
func gradient_color(progress: float) -> Color:
	var coordinate: float = clampf(progress,0.0,1.0)*float(COLORS.size()-1)
	var left_index: int = mini(int(coordinate),COLORS.size()-1)
	var right_index: int = mini(left_index+1,COLORS.size()-1)
	return COLORS[left_index].lerp(COLORS[right_index],coordinate-float(left_index))

## Fine strips blend *within* each transparent art window, including the
## partially filled leading slot; stone dividers remain drawn over the fill.
func _paint_gradient_slot(cell: Rect2, slot: int, fraction: float) -> void:
	var filled_width: float = cell.size.x*clampf(fraction,0.0,1.0)
	if filled_width <= 0.0: return
	var strips: int = maxi(1,ceili(filled_width/1.5))
	for stripe in range(strips):
		var start_x: float = filled_width*float(stripe)/float(strips)
		var end_x: float = filled_width*float(stripe+1)/float(strips)
		var position_on_bar: float = (float(slot)+(start_x+end_x)*0.5/cell.size.x)/10.0
		draw_rect(Rect2(cell.position+Vector2(start_x,0.0),Vector2(end_x-start_x,cell.size.y)),gradient_color(position_on_bar))


func _draw() -> void:
	if frame == null: return
	if uses_approved_art: _draw_ten_slot_hud()
	else: _draw_legacy_safe_hud()

func _draw_ten_slot_hud() -> void:
	var fractions := segment_fractions(display_value)
	var scale: Vector2 = size/SOURCE_SIZE
	var top: float = SLOT_Y*scale.y
	var height: float = SLOT_HEIGHT*scale.y
	# Paint *under* truly transparent slot holes; the stone dividers above
	# remain intact. No dot overlay or fictional extra segment boundaries.
	for i in range(10):
		var left: float = SLOT_X[i]*scale.x
		var span: float = SLOT_WIDTH*scale.x
		var cutout := Rect2(Vector2(left,top),Vector2(span,height))
		draw_rect(cutout,Color("171914",0.84))
		if fractions[i] <= 0.0: continue
		var fill := Rect2(cutout.position,Vector2(maxf(0.0,span*fractions[i]),height))
		_paint_gradient_slot(cutout,i,fractions[i])
		# Flat hand-painted highlights echo the selected board tile style,
		# leaving transparent boundaries and animation room above the fill.
		var highlight := Rect2(fill.position+Vector2(0,2*scale.y),Vector2(fill.size.x,maxf(1,height*0.16)))
		draw_rect(highlight,Color(1.0,0.88,0.65,0.13))
	draw_texture_rect(frame,Rect2(Vector2.ZERO,size),false)
	var font: Font = get_theme_default_font()
	var title: String = "오염도"
	var title_size: int = 31
	var center_x: float = 332.0*scale.x
	var tw: float = font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x
	var title_at := Vector2(center_x-tw/2.0,428.0*scale.y)
	draw_string_outline(font,title_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size,2,Color("211711"))
	draw_string(font,title_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size,Color("251b15"))
	# The fill shows actual 0–100 progress; no secondary numerical readout.

func _draw_legacy_safe_hud() -> void:
	draw_rect(Rect2(size*Vector2(0.015,0.13),size*Vector2(0.97,0.74)),Color("211811"))
	draw_texture_rect(frame,Rect2(Vector2.ZERO,size),false)
	var meter := Rect2(size*Vector2(0.2455,0.405),size*Vector2(0.4975,0.195))
	draw_rect(meter,Color("160d09"))
	var fractions := segment_fractions(display_value)
	for i in range(10):
		if fractions[i]<=0: continue
		var x: float = meter.position.x+meter.size.x*float(i)/10.0
		_paint_gradient_slot(Rect2(x,meter.position.y,meter.size.x/10.0,meter.size.y),i,fractions[i])
	for i in range(1,10):
		var x: float = meter.position.x+meter.size.x*i/10.0
		draw_line(Vector2(x,meter.position.y),Vector2(x,meter.end.y),Color("100c09aa"),1.0)
	var font: Font = get_theme_default_font()
	draw_string(font,size*Vector2(0.28,0.49),"오염도",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("39251c"))
