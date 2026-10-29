extends RefCounted
## Native controls stay independent of the blank painted window frame.
const FRAME_PATH = "res://assets/map/ui/shop_window_frame.png"
const FRAME_RECT = Rect2(96,36,1088,648)
const FRAME_SOURCE_RECT = Rect2(17,25,1633,896)
const GOLD = Color("b58a4e")

static func line(parent: Control, rect: Rect2) -> void:
	var ink=ColorRect.new()
	ink.position=rect.position
	ink.size=rect.size
	ink.color=Color("a47a416b")
	ink.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(ink)

static func style_button(control: Button, primary: bool = false) -> void:
	for state in ["normal","hover","pressed","focus","disabled"]:
		var panel=StyleBoxFlat.new()
		panel.bg_color=Color("a77a3b") if primary else Color("24201a")
		panel.border_color=Color("dbb575") if primary else GOLD
		if state=="hover": panel.bg_color=Color("c2934e") if primary else Color("393025")
		if state=="pressed": panel.bg_color=Color("8b632f") if primary else Color("181613")
		if state=="disabled":
			panel.bg_color=Color("343027")
			panel.border_color=Color("635440")
		panel.set_border_width_all(2 if state=="focus" else 1)
		panel.set_corner_radius_all(3)
		control.add_theme_stylebox_override(state,panel)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		control.add_theme_color_override(state,Color("20170f") if primary else Color("f2dfb5"))
	control.add_theme_color_override("font_disabled_color",Color("8c816d"))
	control.add_theme_font_size_override("font_size",17)
	var effect=control.get_node_or_null("ButtonEffectsModule")
	if effect!=null:
		effect.hover_scale=Vector2.ONE
		effect.hover_rotation_degrees=0.0

static func select_card(control: Control, selected: bool) -> void:
	var edge=control.get_node_or_null("ShopSelectionEdge") as Panel
	if edge==null:
		edge=Panel.new()
		edge.name="ShopSelectionEdge"
		edge.position=Vector2(-5,-5)
		edge.size=control.size+Vector2(10,10)
		edge.mouse_filter=Control.MOUSE_FILTER_IGNORE
		edge.z_index=3
		var panel=StyleBoxFlat.new()
		panel.bg_color=Color.TRANSPARENT
		panel.border_color=Color("e3bb71")
		panel.set_border_width_all(2)
		panel.set_corner_radius_all(3)
		edge.add_theme_stylebox_override("panel",panel)
		control.add_child(edge)
	control.modulate=Color.WHITE
	edge.visible=selected

static func hide_duplicate_caption(control: Control) -> void:
	for child in control.get_children():
		if child is Label and child.name!="LayeredCardTitle":
			child.text=""
			child.hide()
