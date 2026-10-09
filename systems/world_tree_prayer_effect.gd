extends Control
## Original three-row prayer digit sheet: great blessing, blessing, failure.
const DIGITS = preload("res://assets/map/ui/world_tree_prayer_digits.png")
var motion: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func play(delta: int) -> void:
	if delta == 0: return
	if motion != null and motion.is_valid(): motion.kill()
	for child in get_children(): child.queue_free()
	var image = TextureRect.new()
	var atlas = AtlasTexture.new()
	atlas.atlas = DIGITS
	var row = 0 if delta<=-5 else (1 if delta<0 else 2)
	var height = DIGITS.get_height()/3.0
	atlas.region = Rect2(0,row*height,DIGITS.get_width(),height)
	image.texture = atlas
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size = Vector2(168,130.2)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.tooltip_text = "오염도 %s %d" % ["감소" if delta<0 else "증가",absi(delta)]
	image.pivot_offset = image.size*0.5
	image.position = Vector2(0,23.4)
	image.scale = Vector2(0.82,0.82)
	image.modulate.a = 0
	add_child(image)

	motion = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(image,"position:y",0.0,0.207)
	motion.parallel().tween_property(image,"scale",Vector2(1.08,1.08),0.207)
	motion.parallel().tween_property(image,"modulate:a",1.0,0.207)
	motion.tween_property(image,"position:y",-13.0,0.621)
	motion.parallel().tween_property(image,"scale",Vector2.ONE,0.621)
	motion.tween_property(image,"position:y",-31.2,0.322)
	motion.parallel().tween_property(image,"scale",Vector2(0.94,0.94),0.322)
	motion.parallel().tween_property(image,"modulate:a",0.0,0.322)
	motion.tween_callback(queue_free)

func _exit_tree() -> void:
	if motion != null and motion.is_valid(): motion.kill()
