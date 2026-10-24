extends RefCounted
## Presentation-only: the donor's permanent removal is already committed
## by RunSession.inherit_at_home() BEFORE this is called.
## Uses native Godot Tweens and lightweight procedural glow flecks; no assets,
## rule changes, resource drops, RNG or save edits.
const DURATION := 0.68
const SHARD_COUNT := 18

static func _consume(tween: Tween, card: Control, tilt: float) -> void:
	if not is_instance_valid(card): return
	card.pivot_offset = card.size * 0.5
	# Collapse inward like a card turning to dust. Card children inherit the
	# same transform, so altar badges and labels cannot be left floating.
	tween.tween_property(card, "scale", Vector2(0.12, 0.12), DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "rotation_degrees", tilt, DURATION)
	tween.tween_property(card, "modulate:a", 0.0, DURATION * 0.66).set_delay(DURATION * 0.28)

static func play(preview: TextureRect, hand_card: Control = null) -> void:
	if not is_instance_valid(preview) or not preview.is_inside_tree(): return
	var holder: Control = preview.get_parent() as Control
	var particles: Array[ColorRect] = []
	var center: Vector2 = preview.position + preview.size * 0.5
	var tween: Tween = preview.create_tween().set_parallel(true)
	_consume(tween, preview, -11.0)
	if is_instance_valid(hand_card):
		_consume(tween, hand_card, 8.0)
	if holder != null:
		for i in range(SHARD_COUNT):
			var mote := ColorRect.new()
			mote.name = "SacrificeAsh_%02d" % i
			mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mote.focus_mode = Control.FOCUS_NONE
			mote.z_index = 3
			mote.color = Color("ffd991") if i % 3 == 0 else Color("c1a0f5") if i % 3 == 1 else Color("f4efcf")
			var side: float = 3.0 + float(i % 3) * 1.4
			mote.size = Vector2(side, side)
			mote.pivot_offset = mote.size * 0.5
			var angle: float = TAU * float(i) / float(SHARD_COUNT)
			var direction := Vector2(cos(angle), sin(angle))
			var origin := center + direction * (8.0 + float(i % 4) * 6.0)
			mote.position = origin
			mote.modulate.a = 0.0
			holder.add_child(mote)
			particles.append(mote)
			# An upward-floating spiral with small warm/cold fragments.
			var end: Vector2 = origin + direction.rotated(0.37) * (44.0 + float(i % 5) * 10.0) + Vector2(0.0, -31.0)
			tween.tween_property(mote, "position", end, 0.52).set_delay(0.08)
			tween.tween_property(mote, "modulate:a", 0.95, 0.11).set_delay(0.04)
			tween.tween_property(mote, "modulate:a", 0.0, 0.34).set_delay(0.31)
			tween.tween_property(mote, "rotation_degrees", float(i % 2 * 2 - 1) * 120.0, 0.55).set_delay(0.06)
	await tween.finished
	for mote in particles:
		if is_instance_valid(mote): mote.queue_free()
