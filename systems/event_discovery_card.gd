extends Control
## Reusable event/discovery card presented inside the real Godot map overlay.
## Content is UI-only: tile discovery eligibility and persistence belong to RunSession.
signal closed
var dismissed: bool = false

func dismiss() -> void:
	if dismissed: return
	dismissed = true
	closed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		dismiss()
	elif event is InputEventScreenTouch and event.pressed:
		accept_event()
		dismiss()


const DEFAULT_ART = "res://assets/map/events/forest.jpg"
const CUSTOM_ART = "res://" + "assets/map/events/" + "discovery_hill.png" # Optional HD art: fallback until installed
const BASE_SVG = "res://assets/map/ui/event_discovery_card_base.svg"
const CUSTOM_BASE = "res://" + "assets/map/ui/" + "discovery_card_base.png" # Optional approved template
const TILE_ART = "res://assets/map/tiles/forest.png"

func _label(text_value: String, pos: Vector2, dimensions: Vector2, points: int, title: bool = false) -> Label:
	var result := Label.new()
	result.text = text_value
	result.position = pos
	result.size = dimensions
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if title else HORIZONTAL_ALIGNMENT_LEFT
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_override("font", preload("res://assets/fonts/nanum_gothic_regular.ttf"))
	result.add_theme_font_size_override("font_size", points)
	result.add_theme_color_override("font_color", Color("#291d14"))
	add_child(result)
	return result

func _picture(path: String, pos: Vector2, dimensions: Vector2, mode: TextureRect.StretchMode) -> TextureRect:
	var picture := TextureRect.new()
	picture.position = pos
	picture.size = dimensions
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = mode
	picture.texture = load(path)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.clip_contents = true
	add_child(picture)
	return picture

func setup(category: String, heading: String, description: String, reward: String,
		illustration: String = CUSTOM_ART, tile_image: String = TILE_ART) -> void:
	name = "EventDiscoveryCard"
	dismissed = false
	position = Vector2(414, 36)
	size = Vector2(452, 630)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var template = CUSTOM_BASE if ResourceLoader.exists(CUSTOM_BASE) else BASE_SVG
	_picture(template, Vector2.ZERO, size, TextureRect.STRETCH_SCALE)
	var art = illustration if ResourceLoader.exists(illustration) else DEFAULT_ART
	var visual = _picture(art, Vector2(34, 113), Vector2(384, 259), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	visual.name = "EventDiscoveryIllustration"
	# Thin on-top outline keeps the crop inside the parchment card's art window.
	var outline := Panel.new()
	outline.position = visual.position
	outline.size = visual.size
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.set_border_width_all(3)
	border_style.border_color = Color("#281c11")
	outline.add_theme_stylebox_override("panel", border_style)
	add_child(outline)
	_label(category, Vector2(104, 44), Vector2(246, 42), 22, true).name = "EventDiscoveryCategory"
	_label(heading, Vector2(50, 400), Vector2(352, 40), 25, true).name = "EventDiscoveryTitle"
	_label(description, Vector2(54, 459), Vector2(344, 47), 17, true).name = "EventDiscoveryDescription"
	_picture(tile_image, Vector2(47, 524), Vector2(58, 58), TextureRect.STRETCH_KEEP_ASPECT_CENTERED).name = "EventDiscoveryTile"
	_label(reward, Vector2(135, 529), Vector2(264, 50), 20).name = "EventDiscoveryReward"
	# There is deliberately NO confirmation button. The entire parchment
	# is one tap/click-to-close surface, including touch on the artwork/text.
	_label("화면을 누르면 닫힙니다", Vector2(109, 579), Vector2(242, 30), 14, true).name = "EventDiscoveryDismissHint"
