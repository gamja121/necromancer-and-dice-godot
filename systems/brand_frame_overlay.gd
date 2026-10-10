extends RefCounted
## Visual-only monster-card border, derived from the number of brands.
## The original card artwork, selection, and save data are unchanged.

const WOOD_FRAME = preload("res://assets/cards/brand_frame_2.webp")
const IRON_FRAME = preload("res://assets/cards/brand_frame_3.webp")
const NODE_NAME = "BrandFrameOverlay"

static func sync(card: Control, unit: Dictionary) -> void:
	var brands = unit.get("brands", [])
	var brand_count: int = brands.size() if brands is Array else 0
	var texture: Texture2D = null
	if brand_count >= 3:
		texture = IRON_FRAME
	elif brand_count == 2:
		texture = WOOD_FRAME
	var overlay := card.get_node_or_null(NODE_NAME) as TextureRect
	if texture == null:
		if overlay != null:
			card.remove_child(overlay)
			overlay.queue_free()
		return
	if overlay == null:
		overlay = TextureRect.new()
		overlay.name = NODE_NAME
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.focus_mode = Control.FOCUS_NONE
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Match the parent TextureButton's card-art sizing and centering.
		overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.z_index = 1
	overlay.texture = texture
