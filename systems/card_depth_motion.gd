extends RefCounted
## Lightweight physical feedback for 2D card buttons. No gameplay state.
## The shadow is drawn behind its own card, so fan and scroll layouts stay intact.

static func install(card: TextureButton, selected: bool = false, shadow_only: bool = false) -> void:
	if card.has_node("CardContactShadow"): return
	var shadow := TextureRect.new()
	shadow.name = "CardContactShadow"
	shadow.texture = card.texture_normal
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.size = card.size
	shadow.position = Vector2(3.0, 5.0)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.show_behind_parent = true
	shadow.modulate = Color(0.045, 0.032, 0.035, 0.31)
	card.add_child(shadow)
	card.set_meta("card_depth_home", card.position)
	card.set_meta("card_depth_rotation", card.rotation_degrees)
	card.set_meta("card_depth_selected", selected)
	if selected:
		card.position.y -= 7.0
		shadow.position = Vector2(5.0, 9.0)
		shadow.modulate.a = 0.22
	if shadow_only: return
	card.mouse_entered.connect(func(): _animate(card, true))
	card.mouse_exited.connect(func(): _animate(card, false))
	card.focus_entered.connect(func(): _animate(card, true))
	card.focus_exited.connect(func(): _animate(card, false))

static func _animate(card: TextureButton, raised: bool) -> void:
	if not is_instance_valid(card) or bool(card.get_meta("card_in_transfer",false)): return
	var home: Vector2 = card.get_meta("card_depth_home", card.position)
	var angle: float = float(card.get_meta("card_depth_rotation", 0.0))
	var selected: bool = bool(card.get_meta("card_depth_selected", false))
	var lift: float = 9.0 if raised else (7.0 if selected else 0.0)
	var direction: float = -1.0 if angle >= 0.0 else 1.0
	var tween: Tween = card.create_tween().set_parallel(true)
	tween.tween_property(card, "position", home + Vector2(0.0, -lift), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "rotation_degrees", angle + (direction * 1.4 if raised else 0.0), 0.15)
	var shadow: TextureRect = card.get_node_or_null("CardContactShadow")
	if shadow != null:
		tween.tween_property(shadow, "position", Vector2(5.0, 10.0) if raised else (Vector2(5.0, 9.0) if selected else Vector2(3.0, 5.0)), 0.15)
		tween.tween_property(shadow, "modulate:a", 0.20 if raised or selected else 0.31, 0.15)

## For cards already animated by a fan controller: change only the shadow.
static func set_shadow_lift(card: TextureButton, raised: bool) -> void:
	if not is_instance_valid(card): return
	var shadow: TextureRect = card.get_node_or_null("CardContactShadow")
	if shadow == null: return
	var old: Tween = card.get_meta("card_shadow_tween", null)
	if old != null and old.is_valid(): old.kill()
	var tween: Tween = card.create_tween().set_parallel(true)
	card.set_meta("card_shadow_tween", tween)
	tween.tween_property(shadow, "position", Vector2(5.0, 10.0) if raised else Vector2(3.0, 5.0), 0.15)
	tween.tween_property(shadow, "modulate:a", 0.20 if raised else 0.31, 0.15)
