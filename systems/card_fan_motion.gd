extends Control
## Small shared book/deck transfer animation. No gameplay or saved state.
var entries: Array = []
var motion: Tween
var closing = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func register_card(card: BaseButton) -> void:
	entries.append({"card":card,"home":card.position,"scale":card.scale,"rotation":card.rotation,"disabled":card.disabled})

func animate(outward: bool, origin_global: Vector2) -> void:
	if motion != null and motion.is_valid(): motion.kill()
	motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if outward else Tween.EASE_IN)
	var count = entries.size()
	for i in range(count):
		var entry: Dictionary = entries[i]
		var card: BaseButton = entry.card
		if not is_instance_valid(card): continue
		card.disabled = true
		var tucked: Vector2 = card.get_parent().get_global_transform_with_canvas().affine_inverse()*origin_global-card.size*0.5
		var delay = (i if outward else count-1-i)*0.055
		if outward:
			card.position = tucked
			card.scale = Vector2(0.35,0.35)
			card.modulate.a = 0
		motion.tween_property(card,"position",entry.home if outward else tucked,0.32).set_delay(delay)
		motion.tween_property(card,"scale",entry.scale if outward else Vector2(0.35,0.35),0.32).set_delay(delay)
		motion.tween_property(card,"rotation",entry.rotation if outward else 0.0,0.32).set_delay(delay)
		motion.tween_property(card,"modulate:a",1.0 if outward else 0.0,0.32).set_delay(delay)
	if count == 0:
		motion.kill()
		return
	await motion.finished
	if outward and not closing:
		for entry in entries:
			if is_instance_valid(entry.card): entry.card.disabled = entry.disabled

func _exit_tree() -> void:
	if motion != null and motion.is_valid(): motion.kill()
