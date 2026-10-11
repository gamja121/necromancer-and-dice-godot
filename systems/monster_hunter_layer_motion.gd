extends RefCounted
## Frozen v2-map-practice.css: hunter-story-scene-layer and
## hunter-story-portrait-layer; player uses the shared Stage 5V source
## portrait geometry. No save, RNG or story mutations.
const SCENE_FRACTIONS = Rect2(0.13,0.06,0.74,0.92) # left 13%, bottom 2%
const PORTRAIT_FRACTIONS = Rect2(0.40,-0.03,0.58,0.78) # right 2%, bottom 25%
const SCENE_ENTRY_SECONDS = 0.52
const PORTRAIT_ENTRY_SECONDS = 0.48
const SCENE_START_OFFSET = Vector2(0.0,0.03)
const PORTRAIT_START_OFFSET = Vector2(0.07,0.02)
const SCENE_START_SCALE = 0.965
const PORTRAIT_START_SCALE = 0.96
const PORTRAIT_OPACITY = 0.94

static func source_rect(scene_rect: Rect2, portrait_layer: bool) -> Rect2:
	var fractions: Rect2 = PORTRAIT_FRACTIONS if portrait_layer else SCENE_FRACTIONS
	return Rect2(scene_rect.position+scene_rect.size*fractions.position,scene_rect.size*fractions.size)

static func play(layer: TextureRect, portrait_layer: bool, animated: bool) -> void:
	if not is_instance_valid(layer): return
	# The original imported WebP stays on a direct child TextureRect.
	# Exclude this layer only from the generic 6px modal slide to prevent
	# competition with its own source-matched independent movement.
	layer.set_meta("ui_custom_open_motion",true)
	layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.pivot_offset=Vector2(layer.size.x/2.0,layer.size.y)
	var opacity: float=PORTRAIT_OPACITY if portrait_layer else 1.0
	if not animated:
		layer.modulate.a=opacity
		return
	var end_position: Vector2=layer.position
	var start_offset: Vector2=PORTRAIT_START_OFFSET if portrait_layer else SCENE_START_OFFSET
	var start_scale: float=PORTRAIT_START_SCALE if portrait_layer else SCENE_START_SCALE
	var duration: float=PORTRAIT_ENTRY_SECONDS if portrait_layer else SCENE_ENTRY_SECONDS
	layer.position=end_position+layer.size*start_offset
	layer.scale=Vector2.ONE*start_scale
	layer.modulate.a=0.0
	var animation=layer.create_tween().set_parallel(true)
	animation.tween_property(layer,"position",end_position,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animation.tween_property(layer,"scale",Vector2.ONE,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animation.tween_property(layer,"modulate:a",opacity,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
