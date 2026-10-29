extends RefCounted
## Native controls stay independent of the blank painted window frame.
const FRAME_PATH = "res://assets/map/ui/shop_window_frame.png"
const FRAME_RECT = Rect2(96,36,1088,648)
const FRAME_SOURCE_RECT = Rect2(17,25,1633,896)
const GOLD = Color("b58a4e")

class SelectionEffect extends Control:
	var card:Control
	var glow:TextureRect
	var motion:Tween
	var selected:bool=false
	var initialized:bool=false

	func setup(owner_card:Control) -> void:
		card=owner_card
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		show_behind_parent=true
		# Draw before this card, while staying above the opaque shop window.
		z_index=0
		var gradient=Gradient.new()
		gradient.offsets=PackedFloat32Array([0.0,0.60,0.84,1.0])
		gradient.colors=PackedColorArray([Color(1.0,0.87,0.61,0.26),Color(1.0,0.84,0.53,0.22),Color(1.0,0.80,0.46,0.08),Color(1.0,0.80,0.46,0.0)])
		var light=GradientTexture2D.new()
		light.gradient=gradient
		light.width=128
		light.height=192
		light.fill=GradientTexture2D.FILL_RADIAL
		light.fill_from=Vector2(0.5,0.5)
		light.fill_to=Vector2(1.0,0.5)
		glow=TextureRect.new()
		glow.name="ShopSelectionGlow"
		glow.texture=light
		glow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode=TextureRect.STRETCH_SCALE
		glow.mouse_filter=Control.MOUSE_FILTER_IGNORE
		glow.modulate.a=0.0
		add_child(glow)
		var footprint=Rect2(Vector2.ZERO,card.size)
		var parchment=card.get_node_or_null("LayeredCardBase") as Control
		if parchment!=null:
			footprint=parchment.get_rect()
		elif card is TextureButton and card.texture_normal!=null:
			var source:Vector2=card.texture_normal.get_size()
			var extent:Vector2=source*minf(card.size.x/source.x,card.size.y/source.y)
			footprint=Rect2((card.size-extent)*0.5,extent)
		var halo=Vector2(26,8) if card.size.y>150 else Vector2(14,4)
		glow.position=footprint.position-halo
		glow.size=footprint.size+halo*2.0
		card.pivot_offset=card.size*0.5
		card.pivot_offset_ratio=Vector2.ZERO

	func set_selected(value:bool) -> void:
		if initialized and selected==value: return
		selected=value
		initialized=true
		if motion!=null and motion.is_valid(): motion.kill()
		var target=Vector2.ONE*(1.04 if selected else 1.0)
		if not is_inside_tree():
			card.scale=target
			glow.modulate.a=1.0 if selected else 0.0
			return
		motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		motion.tween_property(card,"scale",target,0.16)
		motion.tween_property(glow,"modulate:a",1.0 if selected else 0.0,0.16)

	func _exit_tree() -> void:
		if motion!=null and motion.is_valid(): motion.kill()

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
	var effect=control.get_node_or_null("ShopSelectionEffect") as SelectionEffect
	if effect==null:
		effect=SelectionEffect.new()
		effect.name="ShopSelectionEffect"
		control.add_child(effect)
		effect.setup(control)
	control.modulate=Color.WHITE
	effect.set_selected(selected)

static func hide_duplicate_caption(control: Control) -> void:
	for child in control.get_children():
		if child is Label and child.name!="LayeredCardTitle":
			child.text=""
			child.hide()
