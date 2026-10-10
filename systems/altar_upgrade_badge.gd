extends RefCounted
## Visual-only altar enhancements (+1/+2/+3), fully independent of brand count.
## Uses the saved unit.altar_enhancements; it does not alter stats or inventory.

const BADGE_1 = preload("res://assets/cards/altar_upgrade_badge_1.webp")
const BADGE_2 = preload("res://assets/cards/altar_upgrade_badge_2.webp")
const BADGE_3 = preload("res://assets/cards/altar_upgrade_badge_3.webp")
const NODE_NAME = "AltarUpgradeBadge"

static func _art_rect(card: Control) -> Rect2:
	var bounds := Rect2(Vector2.ZERO,card.size)
	var picture: Texture2D = null
	var keep_aspect := false
	if card is TextureButton:
		var button := card as TextureButton
		picture = button.texture_normal
		keep_aspect = button.stretch_mode == TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	elif card is TextureRect:
		var image := card as TextureRect
		picture = image.texture
		keep_aspect = image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if picture == null or not keep_aspect:
		return bounds
	var original := picture.get_size()
	if original.x <= 0 or original.y <= 0 or card.size.x <= 0 or card.size.y <= 0:
		return bounds
	var fit := minf(card.size.x/original.x,card.size.y/original.y)
	var drawn := original*fit
	return Rect2((card.size-drawn)*0.5,drawn)

static func sync(card: Control, unit: Dictionary) -> void:
	var level := clampi(int(unit.get("altar_enhancements",0)),0,3)
	var icon: Texture2D = null
	match level:
		1: icon = BADGE_1
		2: icon = BADGE_2
		3: icon = BADGE_3
	var badge := card.get_node_or_null(NODE_NAME) as TextureRect
	if icon == null:
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
		# Keep card, brand frame and altar badge in the same overlap order.
		badge.z_index = 0
		card.add_child(badge)
	badge.texture = icon
	var art := _art_rect(card)
	var width := art.size.x*0.54
	var height := width*float(icon.get_height())/float(icon.get_width())
	badge.size = Vector2(width,height)
	# Align the plaque across the top card line; slightly above the previous inset.
	# Use the same local art rectangle for every monster-card presentation.
	badge.position = Vector2(art.position.x+(art.size.x-width)*0.5,art.position.y+art.size.y*0.01)
