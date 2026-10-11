extends RefCounted
## Stage 5Y: frozen web v2-map-practice.css ritual-portal-layer
## and v2-map-practice.js renderRitualPortalBeat visibility/animation.
## Visual-only, with no quest flags, RNG, rewards or save fields.
const PORTAL_FRACTIONS = Rect2(0.02,0.03,0.75,0.75) # left 2%, bottom 22%
const ENTRY_SECONDS = 0.50
const ENTRY_OFFSET_FRACTION = Vector2(0.0,0.02)
const ENTRY_SCALE = 0.985

static func source_rect(scene_rect: Rect2) -> Rect2:
	return Rect2(scene_rect.position+scene_rect.size*PORTAL_FRACTIONS.position,scene_rect.size*PORTAL_FRACTIONS.size)

static func play(layer: TextureRect, animate: bool) -> void:
	if not is_instance_valid(layer): return
	# Keep the real WebP on a direct child TextureRect. Only this
	# decorative layer opts out of generic modal 6 px travel, otherwise
	# the source -/2% reveal and default tween would compete.
	layer.set_meta("ui_custom_open_motion",true)
	layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.pivot_offset=Vector2(layer.size.x*0.5,layer.size.y)
	if not animate:
		layer.modulate.a=1.0
		return
	var base: Vector2=layer.position
	layer.position=base+layer.size*ENTRY_OFFSET_FRACTION
	layer.scale=Vector2.ONE*ENTRY_SCALE
	layer.modulate.a=0.0
	var tween=layer.create_tween().set_parallel(true)
	tween.tween_property(layer,"position",base,ENTRY_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(layer,"scale",Vector2.ONE,ENTRY_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(layer,"modulate:a",1.0,ENTRY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
