extends Control
const ButtonEffects = preload("res://systems/button_effects_module.gd")
const PanelEffects = preload("res://systems/panel_effects_module.gd")
const Catalog = preload("res://systems/reward_catalog.gd")
const BrandFrameOverlay = preload("res://systems/brand_frame_overlay.gd")

func label_at(parent: Control, value: String, pos: Vector2, dimensions: Vector2, font_size: int = 16) -> Label:
	var node = Label.new()
	node.text = value
	node.position = pos
	node.size = dimensions
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("f2dfb5"))
	node.add_theme_color_override("font_shadow_color",Color.BLACK)
	node.add_theme_constant_override("shadow_offset_y",2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func art(parent: Control, path: String, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var node = TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = pos
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Control, title: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var node = Button.new()
	node.text = title
	node.position = pos
	node.size = dimensions
	node.pressed.connect(callback)
	parent.add_child(node)
	add_button_effect(node)
	return node

func add_button_effect(node: BaseButton) -> void:
	if node.has_node("ButtonEffectsModule"): return
	var effect = ButtonEffects.new()
	effect.name = "ButtonEffectsModule"
	effect.hover_scale = Vector2(1.04,1.04)
	effect.hover_rotation_degrees = 0.6
	node.add_child(effect)

func card(parent: Control, kind: String, item: Dictionary, pos: Vector2, dimensions: Vector2, callback: Callable) -> TextureButton:
	var node = TextureButton.new()
	node.texture_normal = load(Catalog.image(kind,item))
	node.ignore_texture_size = true
	node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	node.position = pos
	node.size = dimensions
	node.pivot_offset = dimensions*0.5
	node.tooltip_text = Catalog.label(kind,item)
	if callback.is_valid(): node.pressed.connect(callback)
	parent.add_child(node)
	var caption = label_at(node,Catalog.label(kind,item),Vector2(-12,dimensions.y+8),Vector2(dimensions.x+24,50),13)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if kind=="unit": BrandFrameOverlay.sync(node,item)
	return node

func backdrop() -> void:
	size = Vector2(1280,720)
	var shade = ColorRect.new()
	shade.size = size
	shade.color = Color("030201d9")
	shade.set_meta("ui_backdrop",true)
	add_child(shade)
	PanelEffects.attach(self)

func scroll_row(pos: Vector2, dimensions: Vector2) -> HBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.position = pos
	scroll.size = dimensions
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",22)
	scroll.add_child(row)
	return row
