extends RefCounted
## Optional in-game card layers for the approved skeleton card-art pilot.
## Gameplay/card buttons stay unchanged; only skeleton-spear/archer use these assets.
## Each layer is an independent TextureRect so portrait zoom never enlarges the UI.

const ROOT := "res://assets/cards/layered/"
const BACKGROUND := ROOT + "base_skeleton.webp"
const NAMEPLATE := ROOT + "scroll_nameplate.webp"
const PORTRAITS := {
	"skeleton-spear": ROOT + "skeleton_spear.webp",
	"skeleton-archer": ROOT + "skeleton_archer.webp",
}
const BASE_NAME := "LayeredCardBase"
const ACTOR_NAME := "LayeredCardCharacter"
const BANNER_NAME := "LayeredCardRibbon"
const TEXT_NAME := "LayeredCardTitle"

static func supports(slug: String) -> bool:
	return PORTRAITS.has(slug)

static func _art(parent: Control, name: String, texture: Texture2D) -> TextureRect:
	var item := TextureRect.new()
	item.name = name
	item.texture = texture
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.focus_mode = Control.FOCUS_NONE
	# The parent's hover/death shader should shade the visible layers, not
	# only the transparent TextureButton hit area.
	item.material = parent.material
	parent.add_child(item)
	return item

static func install(card: TextureButton, slug: String, title: String, selected: bool = false) -> bool:
	if not supports(slug) or card.has_node(BASE_NAME):
		return false
	if not (ResourceLoader.exists(BACKGROUND) and ResourceLoader.exists(NAMEPLATE) and ResourceLoader.exists(PORTRAITS[slug])):
		return false
	var original_texture := card.texture_normal
	# Transparent 2:3 hit target. Do NOT bake the character into this texture.
	var empty := Image.create(2, 3, false, Image.FORMAT_RGBA8)
	empty.fill(Color.TRANSPARENT)
	card.texture_normal = ImageTexture.create_from_image(empty)
	card.ignore_texture_size = true
	card.clip_contents = false # spear/bow/skull can extend beyond the card edge
	card.set_meta("layered_original_texture", original_texture)
	card.set_meta("layered_slug", slug)
	card.set_meta("layered_selected", selected)
	card.set_meta("layered_hover", false)
	_art(card, BASE_NAME, load(BACKGROUND))
	var actor := _art(card, ACTOR_NAME, load(PORTRAITS[slug]))
	actor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art(card, BANNER_NAME, load(NAMEPLATE))
	var caption := Label.new()
	caption.name = TEXT_NAME
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Color("24160e"))
	caption.add_theme_color_override("font_shadow_color", Color("dfb98b82"))
	caption.add_theme_constant_override("shadow_offset_y", 1)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(caption)
	card.resized.connect(func(): relayout(card))
	card.mouse_entered.connect(func(): _focus(card, true))
	card.mouse_exited.connect(func(): _focus(card, false))
	card.focus_entered.connect(func(): _focus(card, true))
	card.focus_exited.connect(func(): _focus(card, false))
	relayout(card)
	_apply_scale(card, false)
	return true

static func relayout(card: TextureButton) -> void:
	if not is_instance_valid(card):
		return
	var base := card.get_node_or_null(BASE_NAME) as TextureRect
	var actor := card.get_node_or_null(ACTOR_NAME) as TextureRect
	var ribbon := card.get_node_or_null(BANNER_NAME) as TextureRect
	var caption := card.get_node_or_null(TEXT_NAME) as Label
	if base == null or actor == null or ribbon == null or caption == null:
		return
	var source := base.texture.get_size()
	var factor := minf(card.size.x / source.x, card.size.y / source.y)
	var extent := source * factor
	var rect := Rect2((card.size - extent) * 0.5, extent)
	base.position = rect.position
	base.size = extent
	# Widen only the independent character: its top, spear and arrow can
	# overlap the frame without stretching the background or bottom label.
	var slug := str(card.get_meta("layered_slug", ""))
	var wide := slug == "skeleton-archer"
	var portrait_width := 1.20 if wide else 1.13
	var portrait_height := 0.76 if wide else 0.78
	actor.position = rect.position + Vector2(-extent.x * (0.10 if wide else 0.07), -extent.y * 0.07)
	actor.size = Vector2(extent.x * portrait_width, extent.y * portrait_height)
	actor.pivot_offset = actor.size * 0.5
	ribbon.position = rect.position + Vector2(-extent.x * 0.055, extent.y * 0.592)
	ribbon.size = Vector2(extent.x * 1.11, extent.y * 0.175)
	caption.position = ribbon.position + Vector2(ribbon.size.x * 0.10, ribbon.size.y * 0.17)
	caption.size = Vector2(ribbon.size.x * 0.80, ribbon.size.y * 0.63)
	caption.add_theme_font_size_override("font_size", maxi(8, int(extent.y * 0.077)))

static func _apply_scale(card: TextureButton, animate: bool) -> void:
	var actor := card.get_node_or_null(ACTOR_NAME) as TextureRect
	if actor == null: return
	var raised := bool(card.get_meta("layered_selected", false)) or bool(card.get_meta("layered_hover", false))
	var target := Vector2.ONE * (1.10 if raised else 1.0)
	if animate and actor.is_inside_tree():
		var active: Tween = card.get_meta("layered_actor_tween") if card.has_meta("layered_actor_tween") else null
		if active != null and active.is_valid(): active.kill()
		var motion := actor.create_tween()
		card.set_meta("layered_actor_tween", motion)
		motion.tween_property(actor, "scale", target, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		actor.scale = target

static func _focus(card: TextureButton, focused: bool) -> void:
	if not is_instance_valid(card) or bool(card.get_meta("card_in_transfer", false)):
		return
	card.set_meta("layered_hover", focused)
	_apply_scale(card, true)

static func set_selected(card: TextureButton, selected: bool) -> void:
	if not is_instance_valid(card) or not card.has_node(ACTOR_NAME): return
	card.set_meta("layered_selected", selected)
	_apply_scale(card, true)