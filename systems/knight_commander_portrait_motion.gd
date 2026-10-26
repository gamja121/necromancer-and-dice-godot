extends RefCounted
## Frozen v2-map-practice.css: commander-story-layer/player-story-layer,
## commander-story-enter/player-story-enter. Visual only, never saved.
const COMMANDER_FRACTIONS = Rect2(0.45,0.01,0.52,0.74) # right 3%, bottom 25%
const PLAYER_FRACTIONS = Rect2(0.04,0.12,0.41,0.63) # left 4%, bottom 25%
const COMMANDER_ENTRY_SECONDS = 0.52
const PLAYER_ENTRY_SECONDS = 0.48
const START_OFFSET_FRACTION = Vector2(-0.07,0.02)
const START_SCALE = 0.96

static func source_rect(scene_rect: Rect2, player_reply: bool) -> Rect2:
	var fractions: Rect2 = PLAYER_FRACTIONS if player_reply else COMMANDER_FRACTIONS
	return Rect2(scene_rect.position + scene_rect.size * fractions.position,scene_rect.size * fractions.size)

static func play(portrait: TextureRect, player_reply: bool, animate: bool) -> void:
	if not is_instance_valid(portrait): return
	# This direct child still carries the actual source texture; preserve P5
	# runtime asset wiring. Suppress just its generic 6 px modal slide.
	portrait.set_meta("ui_custom_open_motion",true)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Approved manuscript actors already face the intended side. The player
	# cutout comes from the right of the rumor painting and moves to the left.
	var aligned: bool = portrait.texture != null and portrait.texture.resource_path.get_file().begins_with("manuscript_")
	portrait.flip_h = player_reply if aligned else not player_reply
	portrait.pivot_offset = Vector2(portrait.size.x/2.0,portrait.size.y)
	if not animate:
		portrait.modulate.a = 1.0
		return
	var destination: Vector2 = portrait.position
	portrait.position = destination + portrait.size * START_OFFSET_FRACTION
	portrait.scale = Vector2.ONE * START_SCALE
	portrait.modulate.a = 0.0
	var duration: float = PLAYER_ENTRY_SECONDS if player_reply else COMMANDER_ENTRY_SECONDS
	var tween := portrait.create_tween().set_parallel(true)
	tween.tween_property(portrait,"position",destination,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait,"scale",Vector2.ONE,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait,"modulate:a",1.0,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
