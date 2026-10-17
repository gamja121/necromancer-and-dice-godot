extends Control
# Minimal, transparent 2D mark above each HP bar. No text and no gameplay logic.
# Manga-style taresen (drooping lines) for curse; a four-point star for blessing.
var mode: String = ""
var reveal: float = 1.0:
	set(next):
		reveal = next
		queue_redraw()
var reveal_tween: Tween

func set_mode(next_mode: String) -> void:
	if mode == next_mode: return
	mode = next_mode
	visible = not mode.is_empty()
	if is_instance_valid(reveal_tween): reveal_tween.kill()
	reveal = 0.0 if visible else 1.0
	if visible:
		reveal_tween = create_tween()
		reveal_tween.tween_property(self, "reveal", 1.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(23, 21)
	visible = false

func _draw() -> void:
	if mode == "curse":
		# Five long, uneven, downward-growing violet strokes. Keep the silhouette
		# legible at 17-23 px without a face, text, gradients or tiny ornaments.
		var xs := [3.0, 7.0, 11.0, 15.0, 19.0]
		var lengths := [13.0, 19.0, 15.0, 18.0, 11.0]
		for i in range(xs.size()):
			var tip: float = 2.0 + lengths[i] * reveal
			draw_line(Vector2(xs[i], 2), Vector2(xs[i], tip), Color("9184c3"), 2.3, true)
	elif mode == "bless":
		var center := Vector2(11.5, 10.5)
		var points := PackedVector2Array([
			center + Vector2(0,-10*reveal),
			center + Vector2(3,-3),
			center + Vector2(10*reveal,0),
			center + Vector2(3,3),
			center + Vector2(0,10*reveal),
			center + Vector2(-3,3),
			center + Vector2(-10*reveal,0),
			center + Vector2(-3,-3)])
		draw_colored_polygon(points, Color("4bfa8b"))
		draw_line(center + Vector2(0,-6*reveal), center + Vector2(0,6*reveal), Color("baffd1"), 1.5)
