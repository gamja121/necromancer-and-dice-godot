extends RefCounted
## Uses the saved altar enhancement count to decorate the card's nameplate.

const LayeredUnitCard = preload("res://systems/layered_unit_card.gd")
const BADGE_ATLAS = preload("res://assets/cards/altar_upgrade_stickers.png")
const BADGE_REGIONS := [
	Rect2(132, 242, 473, 244),
	Rect2(846, 242, 477, 244),
	Rect2(1559, 242, 479, 244),
]
const NODE_NAME := "AltarUpgradeBadge"

static var _stickers: Array[AtlasTexture] = []

static func _sticker(level: int) -> AtlasTexture:
	if _stickers.is_empty():
		for region in BADGE_REGIONS:
			var sticker := AtlasTexture.new()
			sticker.atlas = BADGE_ATLAS
			sticker.region = region
			sticker.filter_clip = true
			_stickers.append(sticker)
	return _stickers[level - 1]

static func _art_rect(card: Control) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, card.size)
	var picture: Texture2D
	var keep_aspect := false
	if card is TextureButton:
		picture = card.texture_normal
		keep_aspect = card.stretch_mode == TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	elif card is TextureRect:
		picture = card.texture
		keep_aspect = card.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if picture == null or not keep_aspect:
		return bounds
	var original := picture.get_size()
	if original.x <= 0.0 or original.y <= 0.0:
		return bounds
	var fit := minf(card.size.x / original.x, card.size.y / original.y)
	var drawn := original * fit
	return Rect2((card.size - drawn) * 0.5, drawn)

static func _ribbon_rect(card: Control) -> Rect2:
	var preview := card.get_node_or_null("LayeredCardPreview") as Control
	var artwork := preview if preview != null else card
	var ribbon := artwork.get_node_or_null(LayeredUnitCard.BANNER_NAME) as Control
	if ribbon == null:
		return LayeredUnitCard.nameplate_rect(_art_rect(card))
	var rect := ribbon.get_rect()
	if preview != null:
		rect.position += preview.position
	return rect

static func sync(card: Control, unit: Dictionary) -> void:
	var level := clampi(int(unit.get("altar_enhancements", 0)), 0, BADGE_REGIONS.size())
	var badge := card.get_node_or_null(NODE_NAME) as TextureRect
	if level == 0:
		if badge != null:
			card.remove_child(badge)
			badge.queue_free()
		return
	if badge == null:
		badge = TextureRect.new()
		badge.name = NODE_NAME
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.focus_mode = Control.FOCUS_NONE
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_SCALE
		card.add_child(badge)
	var sticker := _sticker(level)
	badge.texture = sticker
	# Redrawing a material/target preview can append a new layer over its previous badge.
	if card.get_node_or_null("LayeredCardPreview") != null:
		card.move_child(badge, card.get_child_count() - 1)
	var ribbon := _ribbon_rect(card)
	var width := roundf(ribbon.size.x * 0.27)
	var height := roundf(width * sticker.region.size.y / sticker.region.size.x)
	badge.size = Vector2(width, height)
	badge.position = Vector2(
		roundf(ribbon.end.x - width - ribbon.size.x * 0.065),
		roundf(ribbon.position.y - height * 0.68)
	)
