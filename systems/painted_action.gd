extends RefCounted
## Paint a native action button with the game's parchment artwork.

const PAPERS: Array[Texture2D] = [
	preload("res://assets/map/ui/parchment_button_variant_01.png"),
	preload("res://assets/map/ui/parchment_button_variant_02.png"),
	preload("res://assets/map/ui/parchment_button_variant_03.png"),
	preload("res://assets/map/ui/parchment_button_variant_04.png"),
]
const INK := Color("412819")
const TINTS := {
	"normal": Color.WHITE,
	"hover": Color(1.10, 1.07, 1.02),
	"pressed": Color(0.88, 0.81, 0.72),
	"disabled": Color(0.72, 0.68, 0.64, 0.74),
}

static func style(control: Button, variant: int = 1, font_size: int = 16) -> void:
	var art := PAPERS[variant - 1]
	for state in TINTS:
		var paper := StyleBoxTexture.new()
		paper.texture = art
		paper.modulate_color = TINTS[state]
		paper.content_margin_left = 22
		paper.content_margin_right = 12
		control.add_theme_stylebox_override(state, paper)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, INK)
	control.add_theme_color_override("font_disabled_color", Color("6c5946"))
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.clip_text = true
	# The painted sprite already has its own shading and transparent edges.
	var effect := control.get_node_or_null("ButtonEffectsModule") as ButtonEffectsModule
	if effect != null: effect.contact_shadow_enabled = false
	var shadow := control.get_node_or_null("ButtonContactShadow") as Control
	if shadow != null: shadow.hide()
