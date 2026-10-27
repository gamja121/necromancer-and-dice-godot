extends Control
## Reusable event/discovery card presented inside the real Godot map overlay.
## Content is UI-only: tile discovery eligibility and persistence belong to RunSession.
signal closed
var dismissed: bool = false
var reveal_tween: Tween

func dismiss() -> void:
	if dismissed: return
	dismissed = true
	if is_instance_valid(reveal_tween): reveal_tween.kill()
	closed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		dismiss()
	elif event is InputEventScreenTouch and event.pressed:
		accept_event()
		dismiss()


const DEFAULT_ART = "res://assets/map/events/ordinary_event_preview.png"
const CUSTOM_ART = "res://assets/map/events/discovery_hill.png"
const ROUTINE_BASE = "res://assets/map/ui/routine_event_card_base_v2.png"
const SIDE_PLAQUE_ART = "res://assets/map/ui/routine_choice_button_v1.png"
const TILE_ART = "res://assets/map/tiles/forest.png"

func _label(text_value: String, pos: Vector2, dimensions: Vector2, points: int, title: bool = false) -> Label:
	var result := Label.new()
	# Enable wrapping before width, so imported/native font minimums cannot enlarge the label.
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.text = text_value
	result.position = pos
	result.size = dimensions
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if title else HORIZONTAL_ALIGNMENT_LEFT
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		illustration: String = CUSTOM_ART, tile_image: String = TILE_ART, show_reward: bool = true) -> void:
	name = "EventDiscoveryCard"
	dismissed = false
	position = Vector2(268,80)
	size = Vector2(452,560)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_picture(ROUTINE_BASE, Vector2.ZERO, size, TextureRect.STRETCH_SCALE).name="EventDiscoveryBase"
	var art = illustration if ResourceLoader.exists(illustration) else DEFAULT_ART
	# Keep full manuscript borders inside the ordinary card's art aperture.
	var art_rect: Rect2 = Rect2(45,112,362,259)
	var visual = _picture(art,art_rect.position,art_rect.size,TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	visual.name = "EventDiscoveryIllustration"
	var outline := Panel.new()
	outline.position = visual.position
	outline.size = visual.size
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.set_border_width_all(1)
	border_style.border_color = Color("#5a3d23")
	outline.add_theme_stylebox_override("panel", border_style)
	add_child(outline)
	var category_label: Label = _label(category, Vector2(104, 44), Vector2(246, 42), 22, true)
	category_label.name = "EventDiscoveryCategory"
	_label(heading, Vector2(50,400), Vector2(352,40),25,true).name = "EventDiscoveryTitle"
	_label(description,Vector2(42,459),Vector2(368,64),16,true).name="EventDiscoveryDescription"
	if show_reward:
		var plaque = _picture(SIDE_PLAQUE_ART,Vector2(500,213),Vector2(250,58),TextureRect.STRETCH_SCALE)
		plaque.name = "EventDiscoveryRewardPlate"
		var face := AtlasTexture.new()
		face.atlas = plaque.texture
		face.region = Rect2(29,221,2131,273)
		face.filter_clip = true
		plaque.texture = face
		_picture(tile_image,Vector2(507,220),Vector2(44,44),TextureRect.STRETCH_KEEP_ASPECT_CENTERED).name="EventDiscoveryTile"
		_label(reward,Vector2(560,213),Vector2(182,58),18,true).name="EventDiscoveryReward"
	# There is deliberately NO confirmation button. The entire parchment
	# is one tap/click-to-close surface, including touch on the artwork/text.
	var hint: Label = _label("화면을 누르면 닫힙니다",Vector2(500,289),Vector2(250,58),14,true)
	hint.name = "EventDiscoveryDismissHint"
	hint.add_theme_color_override("font_color",Color("#efdbb5"))
	# Settle onto the parchment plane, with no overshoot or input delay.
	# A slight lift is enough; the original illustration is never warped.
	pivot_offset = size*0.5
	var resting_y: float=position.y
	position.y += 12.0
	scale = Vector2.ONE*0.985
	modulate.a = 0.0
	reveal_tween = create_tween().set_parallel(true)
	reveal_tween.tween_property(self,"position:y",resting_y,0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(self,"scale",Vector2.ONE,0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(self,"modulate:a",1.0,0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
