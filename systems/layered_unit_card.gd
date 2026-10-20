extends RefCounted
## In-game layered cards use the same live background / separate portrait / ribbon / brands.
## Gameplay and TextureButton inputs stay unchanged. Character pose/size can vary.
## Each layer is an independent TextureRect so portrait zoom never enlarges the UI.

const UnitInfo = preload("res://systems/unit_info.gd")
const ROOT := "res://assets/cards/layered/"
const BACKGROUND := ROOT + "base_skeleton.webp"
const NAMEPLATE := ROOT + "scroll_nameplate.webp"
const PORTRAITS := {
	"skeleton-spear": ROOT + "skeleton_spear.webp",
	"skeleton-archer": ROOT + "skeleton_archer.webp",
	"corpse-slime": ROOT + "corpse_slime.webp",
	"dracula": ROOT + "dracula.webp",
	"ice-lord": ROOT + "ice_lord.webp",
	"grave-worm": ROOT + "grave_worm.webp",
	"skeleton-cavalry": ROOT + "skeleton_cavalry.webp",
	"mummy-guardian": ROOT + "mummy_guardian.webp",
	"soul-reaper": ROOT + "soul_reaper.webp",
	"bone-hound": ROOT + "bone_hound.webp",
	"mimic": ROOT + "mimic.webp",
	"ice-princess": ROOT + "ice_princess.webp",
	"hydra": ROOT + "hydra.webp",
	"flesh-golem": ROOT + "flesh_golem.webp",
	"forest-fairy": ROOT + "forest_fairy.webp",
	"bone-golem": ROOT + "bone_golem.webp",
	"abyss-harpy": ROOT + "abyss_harpy.webp",
	"boulder-ogre": ROOT + "boulder_ogre.webp",
	"orc-warrior": ROOT + "orc_warrior.webp",
}

# Legion scenery stays clipped to the paper card; the character is independent
# and can protrude beyond the frame. The two existing skeleton cards keep their
# already-approved background and layout.
const BACKGROUNDS := {
	"corpse-slime": ROOT + "base_corpse.webp",
	"dracula": ROOT + "base_demon.webp",
	"ice-lord": ROOT + "base_ice.webp",
	"grave-worm": ROOT + "base_plague.webp",
	"skeleton-cavalry": ROOT + "base_skeleton_mist.webp",
	"mummy-guardian": ROOT + "base_corpse.webp",
	"soul-reaper": ROOT + "base_skeleton_mist.webp",
	"bone-hound": ROOT + "base_corpse.webp",
	"mimic": ROOT + "base_summon.webp",
	"ice-princess": ROOT + "base_ice.webp",
	"hydra": ROOT + "base_plague.webp",
	"flesh-golem": ROOT + "base_corpse.webp",
	"forest-fairy": ROOT + "base_plant.webp",
	"bone-golem": ROOT + "base_skeleton_mist.webp",
	"abyss-harpy": ROOT + "base_demon.webp",
	"boulder-ogre": ROOT + "base_beast.webp",
	"orc-warrior": ROOT + "base_beast.webp",
}

const WIDE_PORTRAITS := [
	"skeleton-archer", "corpse-slime", "grave-worm",
	"skeleton-cavalry", "bone-hound", "mimic",
	"hydra", "flesh-golem", "bone-golem", "abyss-harpy",
	"boulder-ogre", "orc-warrior",
]
const BASE_NAME := "LayeredCardBase"
const ACTOR_NAME := "LayeredCardCharacter"
const BANNER_NAME := "LayeredCardRibbon"
const TEXT_NAME := "LayeredCardTitle"
const BRAND_ROW_NAME := "LayeredCardBrands"
const BRAND_ICON_SHEET = preload("res://assets/battle/ui/brand-icons-sheet.jpg")
const BRAND_ICON_EXTRA = preload("res://assets/battle/ui/brand-icons-extra-sheet.jpg")

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

static func install(card: TextureButton, slug: String, title: String, selected: bool = false, brands: Array = []) -> bool:
	if not supports(slug) or card.has_node(BASE_NAME):
		return false
	var background_path: String = str(BACKGROUNDS.get(slug, BACKGROUND))
	if not (ResourceLoader.exists(background_path) and ResourceLoader.exists(NAMEPLATE) and ResourceLoader.exists(PORTRAITS[slug])):
		return false
	var original_texture := card.texture_normal
	# Keep the original TextureButton texture identity for existing card
	# presentations/tests and hit-area sizing; render ONLY the live layers.
	# self_modulate affects this CanvasItem, not its TextureRect children.
	card.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	card.ignore_texture_size = true
	card.clip_contents = false # spear/bow/skull can extend beyond the card edge
	card.set_meta("layered_original_texture", original_texture)
	card.set_meta("layered_slug", slug)
	card.set_meta("layered_selected", selected)
	card.set_meta("layered_hover", false)
	_art(card, BASE_NAME, load(background_path))
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
	sync_brands(card, brands)
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
	var wide := slug in WIDE_PORTRAITS
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
	# Left-aligned engraved brands in the lower parchment panel.
	var brand_row := card.get_node_or_null(BRAND_ROW_NAME) as Control
	if brand_row != null:
		brand_row.position = rect.position + Vector2(extent.x * 0.105, extent.y * 0.775)
		brand_row.size = Vector2(extent.x * 0.79, extent.y * 0.105)
		var side := minf(extent.x * 0.19, extent.y * 0.098)
		var gap := extent.x * 0.025
		for i in range(brand_row.get_child_count()):
			var icon := brand_row.get_child(i) as TextureRect
			if icon != null:
				icon.position = Vector2(i * (side + gap), 0.0)
				icon.size = Vector2(side, side)


## Same icon atlas coordinates as the original unit information window.
## All this state is transient visual data; do not modify the roster.
static func sync_brands(card: TextureButton, brands: Array) -> void:
	if not card.has_node(BASE_NAME): return
	var row := card.get_node_or_null(BRAND_ROW_NAME) as Control
	if row == null:
		row = Control.new()
		row.name = BRAND_ROW_NAME
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.clip_contents = false
		card.add_child(row)
	var keys: Array[String] = []
	for brand in brands:
		if keys.size() >= 3: break
		if not (brand is Dictionary): continue
		var kind := str(brand.get("type", ""))
		if UnitInfo.ICONS.has(kind): keys.append(kind)
	var signature := ",".join(keys)
	if card.get_meta("layered_brand_signature", "#new") == signature: return
	card.set_meta("layered_brand_signature", signature)
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for kind in keys:
		var atlas := AtlasTexture.new()
		atlas.atlas = BRAND_ICON_EXTRA if kind in ["combo", "freeze", "lightspeed", "counter"] else BRAND_ICON_SHEET
		atlas.region = UnitInfo.ICONS[kind]
		var icon := TextureRect.new()
		icon.name = "BrandIcon_%d" % row.get_child_count()
		icon.texture = atlas
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.material = card.material
		row.add_child(icon)
	relayout(card)

## Copy the current composited card for animations, not the obsolete
## flattened unit-card image kept for compatibility with existing tests.
static func flight_visual_copy(card: TextureButton) -> Control:
	if not card.has_node(BASE_NAME): return null
	var flyer := Control.new()
	flyer.name = "LayeredCardFlight"
	flyer.size = card.size
	flyer.clip_contents = false
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.modulate = card.modulate
	for child in card.get_children():
		if child.name in [BASE_NAME, ACTOR_NAME, BANNER_NAME, TEXT_NAME, BRAND_ROW_NAME, "BrandFrameOverlay", "AltarUpgradeBadge"]:
			var copied := child.duplicate(0) as Control
			if copied != null:
				copied.mouse_filter = Control.MOUSE_FILTER_IGNORE
				flyer.add_child(copied)
	return flyer

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