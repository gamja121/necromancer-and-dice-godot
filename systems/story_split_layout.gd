extends RefCounted
## Visual-only 1280x720 two-column story layout. The original art stays
## 16:9 and authored event dialogue/choices/save transitions never change.
const SOURCE_ART = Rect2(243.2, 136.8, 793.6, 446.4)
const LEFT_ART = Rect2(55.0, 176.0, 650.0, 365.625)
const RIGHT_PANEL = Rect2(743.0, 72.0, 486.0, 622.0)
const STORY_TITLE = Rect2(772.0, 103.0, 427.0, 48.0)
const NARRATION_FULL = Rect2(758.0, 164.0, 456.0, 365.0)
const NARRATION_WITH_SPEECH = Rect2(758.0, 164.0, 456.0, 233.0)
const SPEECH_PANEL = Rect2(758.0, 403.0, 456.0, 132.0)
const NARRATION_COPY = Rect2(782.0, 209.0, 408.0, 291.0)
const NARRATION_SHORT = Rect2(782.0, 209.0, 408.0, 160.0)
const SPEECH_COPY = Rect2(782.0, 434.0, 408.0, 79.0)
const SPEAKER_COPY = Rect2(782.0, 431.0, 408.0, 25.0)
const SPEAKER_LINE = Rect2(782.0, 456.0, 408.0, 62.0)

static func map_art_rect(source: Rect2) -> Rect2:
	var relative_pos := (source.position - SOURCE_ART.position) / SOURCE_ART.size
	var relative_size := source.size / SOURCE_ART.size
	return Rect2(LEFT_ART.position + relative_pos * LEFT_ART.size, relative_size * LEFT_ART.size)

static func is_source_art_rect(position: Vector2, dimensions: Vector2) -> bool:
	var bounds := Rect2(position, dimensions)
	return bounds.position.x >= SOURCE_ART.position.x - 0.5 and bounds.position.y >= SOURCE_ART.position.y - 0.5 and bounds.end.x <= SOURCE_ART.end.x + 0.5 and bounds.end.y <= SOURCE_ART.end.y + 0.5

static func _box(parent: Control, bounds: Rect2, fill: Color, outline: Color, border: int) -> Panel:
	var panel := Panel.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = fill
	skin.border_color = outline
	skin.set_border_width_all(border)
	skin.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel",skin)
	parent.add_child(panel)
	return panel

static func section_title(parent: Control, label: String, where: Vector2) -> Label:
	var result := Label.new()
	result.text = label
	result.position = where
	result.size = Vector2(390.0, 27.0)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_color_override("font_color", Color("654321"))
	result.add_theme_font_size_override("font_size",17)
	result.add_theme_font_override("font",preload("res://assets/fonts/nanum_gothic_regular.ttf"))
	parent.add_child(result)
	return result

static func install_shell(parent: Control) -> void:
	_box(parent, RIGHT_PANEL, Color("201710ee"), Color("99744f"), 3).name = "StorySplitSidebar"
	_box(parent, Rect2(LEFT_ART.position - Vector2(5,5), LEFT_ART.size + Vector2(10,10)), Color("080605"), Color("9c754a"), 3).name = "StorySplitArtBorder"

static func action_rect(index: int, count: int, secondary: bool) -> Rect2:
	var column_count := maxi(1,mini(count,3))
	var gap := 10.0
	var width := minf(208.0,(456.0 - gap * float(column_count - 1)) / float(column_count))
	var total_width := width * float(column_count) + gap * float(column_count - 1)
	var origin_x := 758.0 + (456.0 - total_width) * 0.5
	return Rect2(origin_x + float(index % column_count) * (width + gap), 622.0 if secondary else 551.0 + float(index / column_count) * 62.0, width, 49.0)
