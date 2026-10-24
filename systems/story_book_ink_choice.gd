extends Button
## Text-only action, keyboard/mouse triangle and selected ink stamp.
var chosen := false
func _notification(what: int) -> void:
	if what in [NOTIFICATION_MOUSE_ENTER,NOTIFICATION_MOUSE_EXIT,NOTIFICATION_FOCUS_ENTER,NOTIFICATION_FOCUS_EXIT]: queue_redraw()
func _draw() -> void:
	if disabled: return
	if chosen:
		draw_arc(Vector2(14,22),12,0,TAU,40,Color("943b2f"),1.8,true)
		draw_line(Vector2(9,22),Vector2(13,27),Color("943b2f"),1.8,true)
		draw_line(Vector2(13,27),Vector2(21,16),Color("943b2f"),1.8,true)
	elif has_focus() or is_hovered():
		draw_colored_polygon(PackedVector2Array([Vector2(8,16),Vector2(18,22),Vector2(8,28)]),Color("813b2b"))
