extends Control
## The selected face is UI state. Round preparation runs on a disposable copy.

const Rules = preload("res://systems/battlefield_rules.gd")
const UnitInfo = preload("res://systems/unit_info.gd")
const Cards = preload("res://systems/layered_unit_card.gd")
const ORDER_FONT = preload("res://assets/fonts/nanum_gothic_bold.ttf")
const CURSE_SHADER = """
	shader_type canvas_item;
	void fragment() {
		float grey = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		COLOR.rgb = vec3(clamp((grey - 0.5) * 1.12 + 0.54, 0.0, 1.0));
	}
"""

var battle: Control
var face_buttons: Array[Control] = []
var selected_face: int = 0
var markers: Dictionary = {}
var rail: Panel
var brand_data: Dictionary
var curse_material := ShaderMaterial.new()
var hidden_fates: Array[Control] = []
var die_bounds := Rect2()
var layout_dirty := true


func setup(owner_battle: Control) -> void:
	battle = owner_battle
	size = battle.surface_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 78
	brand_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/interface.json")).brands
	var shader := Shader.new()
	shader.code = CURSE_SHADER
	curse_material.shader = shader
	rail = panel(self, Rect2(0, 59, 326, 35), Color("211813ed"), Color("89663f"))
	rail.name = "FaceRail"
	caption(rail, "예상", Rect2(10, 0, 58, 35), Color("e5c185"), 16)
	for face in range(1, 7):
		var digit := Button.new()
		digit.name = "Face%d" % face
		digit.position = Vector2(76+40*(face-1), 4)
		digit.size = Vector2(34, 27)
		digit.text = str(face)
		digit.toggle_mode = true
		digit.set_meta("keyboard_focus_key", "battle-forecast-%d" % face)
		digit.set_meta("keyboard_description", tr("주사위 %d 예측") % face)
		digit.tooltip_text = tr("주사위 %d 예측") % face
		digit.add_theme_font_size_override("font_size", 18)
		digit.add_theme_color_override("font_color", Color("e2d2b7"))
		digit.add_theme_color_override("font_pressed_color", Color("fff1cb"))
		digit.add_theme_stylebox_override("normal", border(Color("2e2219"), Color("654a32"), 3))
		digit.add_theme_stylebox_override("hover", border(Color("463122"), Color("bd8e50"), 3))
		digit.add_theme_stylebox_override("pressed", border(Color("765027"), Color("e4b16a"), 3))
		rail.add_child(digit)
		face_buttons.append(digit)
		digit.pressed.connect(select_face.bind(face))


func set_available(available: bool) -> void:
	if visible != available:
		visible = available
		if not available:
			clear_selection()
	if available:
		update_layout()


func clear_selection() -> void:
	selected_face = 0
	for digit: Button in face_buttons:
		digit.set_pressed_no_signal(false)
	clear_markers()


func clear_markers() -> void:
	for mark: Control in markers.values():
		remove_child(mark)
		mark.queue_free()
	markers.clear()
	for fate in hidden_fates:
		if is_instance_valid(fate) and not fate.get("mode").is_empty():
			fate.show()
	hidden_fates.clear()


func select_face(face: int) -> void:
	if not is_visible_in_tree() or not battle.can_preview_battle() or face < 1 or face > 6:
		clear_selection()
		return
	var next_face := 0 if selected_face == face else face
	clear_selection()
	selected_face = next_face
	if selected_face == 0:
		return
	face_buttons[face-1].set_pressed_no_signal(true)
	var prediction := Rules.new(battle.definitions, 0)
	if not prediction.restore(battle.rules.snapshot()):
		clear_selection()
		return
	prediction.begin_round(face)
	var places: Dictionary = {}
	var counts: Dictionary = {}
	if prediction.winner().is_empty():
		var actors := prediction.queue.filter(func(unit): return battle.bars.has(unit.id) and Rules.can_attack(unit))
		var previous := Vector3i.ZERO
		var place := 0
		for index in range(actors.size()):
			var unit: Dictionary = actors[index]
			var key := Vector3i(prediction.rank(unit), unit.speed, unit.slot)
			# The engine uses RNG only when priority, speed and slot all tie.
			if index == 0 or key != previous:
				place = index+1
			places[unit.id] = place
			counts[place] = int(counts.get(place, 0))+1
			previous = key

	for live in battle.rules.units:
		if not live.alive or not battle.bars.has(live.id):
			continue
		var unit := prediction.find_id(live.id)
		var place: int = places.get(live.id, 0)
		var effects: Dictionary = unit.curse if not unit.curse.is_empty() else unit.bless
		var fate := battle.bars[live.id].get_node("FateIcon") as Control
		# Ready-phase impact marks from the last roll share this screen area.
		if fate.visible:
			hidden_fates.append(fate)
			fate.hide()
		if place > 0 or not effects.is_empty():
			add_marker(live.id, place, counts.get(place, 0)>1, effects, not unit.curse.is_empty())
	layout_dirty = true
	update_layout()


func add_marker(id: String, place: int, tied: bool, effects: Dictionary, cursed: bool) -> void:
	var effect_x := 37 if place > 0 else 4
	var effect_width := 70 if cursed else effects.size()*26-2
	var width := 38 if effects.is_empty() else effect_x+effect_width+5
	var mark := panel(self, Rect2(0, 0, width, 32), Color("211813f8"), Color("86663f"))
	mark.mouse_filter = Control.MOUSE_FILTER_STOP
	var details := PackedStringArray()
	if place > 0:
		var number := panel(mark, Rect2(3, -4, 31, 40), Color("e1bd80"), Color("f7d9a1"), 5)
		number.name = "Order"
		number.set_meta("ui_font_preserve", true)
		var label := caption(number, str(place), Rect2(0, 0, 31, 40), Color("291a13"), 31, true)
		label.add_theme_font_override("font", ORDER_FONT)
		details.append(tr("공동 순번 %d" if tied else "예상 순번 %d") % place)
	else:
		details.append(tr("이번 행동 쉼"))
	var index := 0
	for kind in effects:
		add_brand(mark, kind, effect_x+index*26, cursed)
		var brand: Dictionary = brand_data[kind]
		var count: int = effects[kind]
		var stack := " ×%d" % count if count>1 else ""
		details.append(tr(str(brand.name))+stack+" · "+tr(str(brand.penalty if cursed else brand.blessing)))
		index += 1
	mark.tooltip_text = "\n".join(details)
	markers[id] = mark


func add_brand(parent: Control, kind: String, x: int, cursed: bool) -> void:
	var line := Color("bc9be2") if cursed else Color("92b873")
	var fill := Color("252029") if cursed else Color("252d1d")
	var holder := panel(parent, Rect2(x, 4, 70 if cursed else 24, 24), fill, line, 3)
	holder.name = "Brand_"+kind
	var atlas := AtlasTexture.new()
	atlas.atlas = Cards.BRAND_ICON_EXTRA if kind in ["combo", "freeze", "lightspeed", "counter"] else Cards.BRAND_ICON_SHEET
	atlas.region = UnitInfo.ICONS[kind]
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(3, 3)
	icon.size = Vector2(18, 18)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	if cursed:
		icon.material = curse_material
		caption(holder, "저주", Rect2(25, 0, 41, 24), Color("f0f0f0"), 16, true)


func update_layout() -> void:
	var die: Control = battle.dice
	var transform := get_global_transform_with_canvas().affine_inverse()*die.get_global_transform_with_canvas()
	var current := transform * Rect2(Vector2.ZERO, die.size) if die.is_visible_in_tree() else Rect2()
	if current == die_bounds and not layout_dirty:
		return
	layout_dirty = false
	die_bounds = current
	var obstruction := die_bounds.grow(7) if die_bounds.has_area() else Rect2()
	var centered := (size.x-rail.size.x)*0.5
	var rail_pos := Vector2(centered, 59)
	if obstruction.intersects(Rect2(rail_pos, rail.size)):
		# The embedded die has both paint and click priority. Move the controls
		# out of its rendered bounds, without changing the die's saved pose.
		var left := minf(centered, obstruction.position.x-rail.size.x)
		var right := maxf(centered, obstruction.end.x)
		if left >= 252 and (right+rail.size.x > size.x-328 or centered-left <= right-centered):
			rail_pos.x = left
		else:
			rail_pos.x = right
			if right+rail.size.x > size.x-328:
				rail_pos.y = 50
	rail.position = rail_pos
	var rail_bounds := Rect2(rail.position, rail.size).grow(3)
	for id in markers:
		var mark: Control = markers[id]
		var bar: Control = battle.bars[id]
		var passive: Control = bar.get_node("PassiveLabel")
		var x := clampf(bar.position.x+(bar.size.x-mark.size.x)*0.5, 2, size.x-mark.size.x-2)
		var y := bar.position.y-42-(15 if passive.visible else 0)
		var extent := Rect2(x, y-4, mark.size.x, 40)
		var boss: bool = battle.presentation_layout.is_boss_bar(battle.rules.find_id(id))
		if boss or extent.intersects(rail_bounds) or extent.intersects(obstruction):
			var statuses: bool = ["Status_freeze", "Status_poison", "Status_shield"].any(func(key): return bar.get_node(key).visible)
			y = bar.position.y+bar.size.y+(26 if statuses else 10)
			extent.position.y = y-4
			if extent.intersects(obstruction):
				y = obstruction.end.y+4
		mark.position = Vector2(x, y)


static func border(fill: Color, line: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = line
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box


static func panel(parent: Control, bounds: Rect2, fill: Color, line: Color, radius: int = 4) -> Panel:
	var result := Panel.new()
	result.position = bounds.position
	result.size = bounds.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel", border(fill, line, radius))
	parent.add_child(result)
	return result


static func caption(parent: Control, value: String, bounds: Rect2, tint: Color, font_size: int, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = bounds.position
	label.size = bounds.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label
