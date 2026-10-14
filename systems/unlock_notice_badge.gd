extends RefCounted
## Shared, non-interactive indicator for newly unlocked location tiles
## and their action buttons. Does not intercept presses or use art files.
const REST_TILE_PENDING = "ui:unlock:rest:tile_pending"
const REST_ACTION_PENDING = "ui:unlock:rest:action_pending"

static func attach(target: Control, caption: String = "신규", wide: bool = false) -> Panel:
	var existing := target.get_node_or_null("UnlockNewBadge")
	if existing is Panel:
		return existing
	var badge := Panel.new()
	badge.name = "UnlockNewBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = Vector2(66,24) if wide else Vector2(46,22)
	badge.position = Vector2(target.size.x-badge.size.x+5,-9)
	badge.z_index = 25
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#51251f")
	style.border_color = Color("#d9ac66")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.10,0.05,0.02,0.68)
	style.shadow_size = 3
	badge.add_theme_stylebox_override("panel",style)
	target.add_child(badge)
	var label := Label.new()
	label.name = "Caption"
	label.text = caption
	label.size = badge.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",preload("res://assets/fonts/nanum_gothic_regular.ttf"))
	label.add_theme_font_size_override("font_size",14 if wide else 12)
	label.add_theme_color_override("font_color",Color("#ffe4aa"))
	badge.add_child(label)
	return badge
