extends RefCounted
## Frozen web graveyard ghoul: v2-map-practice.css:2029-2055,2260-2280.
## Only the child sprite animates. Its positioned StoryCharacterLayer frame is
## left to PanelEffectsModule, preventing two tweens from moving one Control.
## Every tween is bound to the sprite and dies with its story overlay.
const REVEAL_SECONDS = 0.82
const IDLE_SECONDS = 3.2
const FINAL_ALPHA = 0.96
const ENTRY_OFFSET = Vector2(0.18,0.04)
const IDLE_OFFSET = Vector2(-0.012,-0.006)

static func play(sprite: TextureRect, entering: bool) -> void:
	sprite.pivot_offset = sprite.size * Vector2(0.58,0.82)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not entering:
		sprite.modulate.a = FINAL_ALPHA
		sprite.rotation_degrees = -0.2
		_start_idle(sprite)
		return
	sprite.position = sprite.size * ENTRY_OFFSET
	sprite.scale = Vector2.ONE * 0.86
	sprite.rotation_degrees = 2.0
	sprite.modulate.a = 0.0
	var reveal = sprite.create_tween().set_parallel(true)
	reveal.tween_property(sprite,"position",Vector2.ZERO,REVEAL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(sprite,"scale",Vector2.ONE,REVEAL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(sprite,"rotation_degrees",0.0,REVEAL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(sprite,"modulate:a",FINAL_ALPHA,REVEAL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.finished.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.rotation_degrees = -0.2
			_start_idle(sprite)
	)

static func _start_idle(sprite: TextureRect) -> void:
	# The source CSS drifts toward (-1.2%, -.6%) halfway through each
	# 3.2-second cycle and returns, with a subtle -0.2 to +0.25 degree tilt.
	var idle = sprite.create_tween().set_loops()
	idle.tween_property(sprite,"position",sprite.size * IDLE_OFFSET,IDLE_SECONDS/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle.parallel().tween_property(sprite,"rotation_degrees",0.25,IDLE_SECONDS/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle.chain().tween_property(sprite,"position",Vector2.ZERO,IDLE_SECONDS/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle.parallel().tween_property(sprite,"rotation_degrees",-0.2,IDLE_SECONDS/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
