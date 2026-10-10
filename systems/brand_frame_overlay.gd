extends RefCounted
## Visual-only monster-card frame. Draw in the card's own local coordinate space.
## The frame must stay behind later overlapping cards, not jump above its siblings.

const WOOD_FRAME = preload("res://assets/cards/brand_frame_2.webp")
const IRON_FRAME = preload("res://assets/cards/brand_frame_3.webp")
const NODE_NAME = "BrandFrameOverlay"

# The two aligned overlay images use the same source canvas and painted bounds.
# Keep the 2-brand wood and 3-brand iron frame on one identical outer-card rect.
const FRAME_WIDTH_FACTOR = 0.96
const FRAME_HEIGHT_FACTOR = 0.99

static func _card_art_rect(card: Control) -> Rect2:
	var region = Rect2(Vector2.ZERO,card.size)
	var picture: Texture2D = null
	var keep_aspect = false
	if card is TextureButton:
		var button: TextureButton = card
		picture = button.texture_normal
		keep_aspect = button.stretch_mode == TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	elif card is TextureRect:
		var art: TextureRect = card
		picture = art.texture
		keep_aspect = art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if picture == null or not keep_aspect: return region
	var native_size: Vector2 = picture.get_size()
	if native_size.x <= 0 or native_size.y <= 0 or card.size.x <= 0 or card.size.y <= 0: return region
	var fit: float = minf(card.size.x/native_size.x,card.size.y/native_size.y)
	var drawn_size: Vector2 = native_size*fit
	return Rect2((card.size-drawn_size)*0.5,drawn_size)

static func _align(card: Control, frame: TextureRect) -> void:
	var art_rect: Rect2 = _card_art_rect(card)
	var drawn_size = Vector2(art_rect.size.x*FRAME_WIDTH_FACTOR,art_rect.size.y*FRAME_HEIGHT_FACTOR)
	frame.position = art_rect.position+(art_rect.size-drawn_size)*0.5
	frame.size = drawn_size

static func sync(card: Control, unit: Dictionary) -> void:
	var brands = unit.get("brands",[])
	var count: int = brands.size() if brands is Array else 0
	var texture: Texture2D = null
	if count >= 3:
		texture = IRON_FRAME
	elif count == 2:
		texture = WOOD_FRAME
	var frame := card.get_node_or_null(NODE_NAME) as TextureRect
	if texture == null:
		if frame != null:
			card.remove_child(frame)
			frame.queue_free()
		return
	if frame == null:
		frame = TextureRect.new()
		frame.name = NODE_NAME
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.focus_mode = Control.FOCUS_NONE
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		# Zero relative Z keeps each frame with its card in an overlapping fan.
		frame.z_index = 0
		card.add_child(frame)
	frame.texture = texture
	_align(card,frame)
