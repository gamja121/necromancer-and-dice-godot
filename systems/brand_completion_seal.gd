extends RefCounted
## Small, visual-only seal on a monster card whose three brand slots are full.
## Brand data remains the single source of truth; no click or save side effects.

const SEAL = preload("res://assets/cards/wax_skull_seal.webp")
const MARKER_NAME = "BrandCompletionSeal"

static func sync(card: Control, unit: Dictionary) -> void:
	var brands = unit.get("brands",[])
	var complete: bool = brands is Array and brands.size() >= 3
	var previous := card.get_node_or_null(MARKER_NAME) as TextureRect
	if not complete:
		if previous != null:
			card.remove_child(previous)
			previous.queue_free()
		return
	if previous != null: return
	var marker := TextureRect.new()
	marker.name = MARKER_NAME
	marker.texture = SEAL
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.focus_mode = Control.FOCUS_NONE
	# Larger, inset wax stamp: overlap the illustration instead of sitting on the edge.
	var seal_size: float = clampf(card.size.x * 0.38,30.0,60.0)
	marker.size = Vector2.ONE * seal_size
	marker.position = Vector2(card.size.x-seal_size-card.size.x*0.05,card.size.y*0.095)
	marker.z_index = 1
	card.add_child(marker)
