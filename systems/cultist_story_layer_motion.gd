extends RefCounted
## Frozen web v2-map-practice.css cultist-rumor-layer / cultist-altar-layer.
## Deliberately visual-only; existing story flags, choice and save stay owned
## by CultistRumorEntry/CultistAltarEntry.
const RUMOR_FRACTIONS = Rect2(0.10,0.20,0.80,0.80) # left 10%, bottom 0%
const ALTAR_FRACTIONS = Rect2(0.20,0.33,0.60,0.60) # left 20%, bottom 7%
const RUMOR_SECONDS = 0.50
const ALTAR_SECONDS = 0.48
const START_OFFSET_FRACTION = Vector2(0.0,0.02)
const RUMOR_START_SCALE = 0.985
const ALTAR_START_SCALE = 0.985

static func source_rect(scene_rect: Rect2, altar: bool) -> Rect2:
	var f: Rect2 = ALTAR_FRACTIONS if altar else RUMOR_FRACTIONS
	return Rect2(scene_rect.position+scene_rect.size*f.position,scene_rect.size*f.size)

static func play(layer: TextureRect, altar: bool, animate: bool) -> void:
	if not is_instance_valid(layer): return
	# Avoid competing with the generic modal 6 px slide. Its alpha fade
	# still governs the outer panel, and this image keeps its source WebP.
	layer.set_meta("ui_custom_open_motion",true)
	layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.pivot_offset=Vector2(layer.size.x/2.0,layer.size.y)
	if not animate:
		layer.modulate.a=1.0
		return
	var resting: Vector2=layer.position
	layer.position=resting+layer.size*START_OFFSET_FRACTION
	layer.scale=Vector2.ONE*(ALTAR_START_SCALE if altar else RUMOR_START_SCALE)
	layer.modulate.a=0.0
	var duration: float=ALTAR_SECONDS if altar else RUMOR_SECONDS
	var tween=layer.create_tween().set_parallel(true)
	tween.tween_property(layer,"position",resting,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(layer,"scale",Vector2.ONE,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(layer,"modulate:a",1.0,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
