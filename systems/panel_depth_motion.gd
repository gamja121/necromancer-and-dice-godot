extends RefCounted
## Cosmetic depth for existing fixed-layout panels. Animates their contents only.
static func enter(panel: Control) -> void:
	if not is_instance_valid(panel): return
	var rest: Vector2 = panel.position
	panel.pivot_offset = panel.size * 0.5
	panel.position = rest + Vector2(0.0, 8.0)
	panel.scale = Vector2(0.985, 0.985)
	panel.modulate.a = 0.0
	var tween := panel.create_tween().set_parallel(true)
	tween.tween_property(panel, "position", rest, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)

static func exit(panel: Control, finished: Callable) -> void:
	if not is_instance_valid(panel):
		if finished.is_valid(): finished.call()
		return
	var tween := panel.create_tween().set_parallel(true)
	tween.tween_property(panel, "position", panel.position + Vector2(0.0, 5.0), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "scale", Vector2(0.99, 0.99), 0.14)
	tween.tween_property(panel, "modulate:a", 0.0, 0.14)
	tween.chain().tween_callback(finished)

## A soft offset silhouette behind an existing panel; no input interception.
static func shadow(panel: Control) -> void:
	if not is_instance_valid(panel) or panel.has_node("PanelContactShadow"): return
	var backing := Panel.new()
	backing.name = "PanelContactShadow"
	backing.position = Vector2(5.0, 7.0)
	backing.size = panel.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.show_behind_parent = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.018, 0.015, 0.22)
	style.set_corner_radius_all(9)
	backing.add_theme_stylebox_override("panel", style)
	panel.add_child(backing)
	panel.move_child(backing, 0)
