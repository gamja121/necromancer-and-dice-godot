extends "res://systems/reward_ui.gd"
signal closed
const Inheritance = preload("res://systems/brand_inheritance.gd")
var battle
var descriptions: Dictionary
var summary: Label
var closing = false

func setup(rules) -> void:
	battle = rules
	descriptions = JSON.parse_string(FileAccess.get_file_as_string("res://data/interface.json")).brands
	z_index = 205
	backdrop()
	var frame = art(self,"res://assets/battle/ui/legion-info-window-hd.png",Vector2(128,28),Vector2(1024,662))
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	label_at(self,"낙인 확인표 · 주사위 눈금별 효과",Vector2(170,76),Vector2(940,42),24)
	button(self,"닫기",Vector2(1040,53),Vector2(82,36),close)
	label_at(self,"축복 ✦ · 저주 ☠ · 빈 칸은 발동 없음 / 마물 이름이나 눈금을 눌러 상세 확인",Vector2(175,122),Vector2(930,30),15)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(180,170)
	scroll.size = Vector2(920,370)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",5)
	scroll.add_child(rows)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation",6)
	rows.add_child(header)
	column_label(header,"마물",Vector2(284,32))
	for face in range(1,7): column_label(header,str(face),Vector2(96,32))
	for team in ["ally","enemy"]:
		var ordered: Array = rules.units.filter(func(u): return u.team==team and u.alive and not u.is_summon and u.slot<4)
		ordered.sort_custom(func(a,b): return a.slot>b.slot)
		for u in ordered:
			var marks = Inheritance.normalize(u,rules.definitions)
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation",6)
			rows.add_child(row)
			var unit_button = Button.new()
			unit_button.text = ("아군 · " if team=="ally" else "적군 · ")+str(u.name)
			unit_button.custom_minimum_size = Vector2(284,36)
			unit_button.icon = load("res://assets/battle/ui/info-portraits/%s.png" % u.slug)
			unit_button.expand_icon = true
			unit_button.add_theme_constant_override("icon_max_width",30)
			unit_button.add_theme_color_override("font_color",Color("35502c") if team=="ally" else Color("752d25"))
			apply_cell_style(unit_button,Color("e5d1b3") if team=="ally" else Color("d9bba5"))
			unit_button.pressed.connect(func(): describe(u,marks))
			row.add_child(unit_button)
			for face in range(1,7):
				var mode = face_mode(marks,face)
				var cell = Button.new()
				cell.text = "✦" if mode=="blessing" else ("☠" if mode=="curse" else "")
				cell.custom_minimum_size = Vector2(96,36)
				cell.disabled = mode=="normal"
				cell.tooltip_text = "%s · %d번 · %s" % [u.name,face,"축복" if mode=="blessing" else ("저주" if mode=="curse" else "발동 없음")]
				cell.add_theme_color_override("font_color",Color("35692c") if mode=="blessing" else Color("752d25"))
				apply_cell_style(cell,Color("c6d0a1") if mode=="blessing" else (Color("d4afa2") if mode=="curse" else Color("dec9a9")))
				cell.pressed.connect(func(): describe(u,marks,face))
				row.add_child(cell)
	var detail_scroll = ScrollContainer.new()
	detail_scroll.position = Vector2(188,550)
	detail_scroll.size = Vector2(904,94)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(detail_scroll)
	summary = Label.new()
	summary.text = "마물 또는 낙인 눈금을 선택하세요."
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_color_override("font_color",Color("34251c"))
	summary.add_theme_font_size_override("font_size",15)
	detail_scroll.add_child(summary)

func column_label(parent: Control, value: String, dimensions: Vector2) -> void:
	var label = Label.new()
	label.text = value
	label.custom_minimum_size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color",Color("35271d"))
	parent.add_child(label)

static func face_mode(marks: Array, face: int) -> String:
	if marks.any(func(mark): return face in mark.curse): return "curse"
	if marks.any(func(mark): return face in mark.bless): return "blessing"
	return "normal"

func describe(u: Dictionary, marks: Array, face: int = 0) -> void:
	var lines: Array[String] = [str(u.name)+(" · %d번" % face if face>0 else "")]
	var mode = face_mode(marks,face)
	for mark in marks:
		var definition: Dictionary = descriptions.get(mark.type,{})
		if definition.is_empty(): continue
		if face==0:
			lines.append("%s · 축복 [%s] / 저주 [%s]" % [definition.name,", ".join(mark.bless.map(func(n): return str(n))),", ".join(mark.curse.map(func(n): return str(n)))])
		elif mode=="curse" and face in mark.curse:
			lines.append("☠ %s · %s" % [definition.name,definition.penalty])
		elif mode=="blessing" and face in mark.bless:
			lines.append("✦ %s · %s" % [definition.name,definition.blessing])
	if lines.size()==1: lines.append("낙인 없음" if face==0 else "발동 없음")
	summary.text = "\n".join(lines)

func close() -> void:
	if closing: return
	closing = true
	PanelEffects.attach(self).play_close(func(): closed.emit())

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func label_at(parent: Control, value: String, pos: Vector2, dimensions: Vector2, font_size: int = 16) -> Label:
	var label = super.label_at(parent,value,pos,dimensions,font_size)
	label.add_theme_color_override("font_color",Color("35271d"))
	label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	return label

func apply_cell_style(cell: Button, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("8b705366")
	style.set_border_width_all(1)
	style.content_margin_left = 5
	style.content_margin_right = 5
	cell.add_theme_stylebox_override("normal",style)
	cell.add_theme_stylebox_override("disabled",style)
	var hover = style.duplicate()
	hover.bg_color = color.lightened(0.08)
	cell.add_theme_stylebox_override("hover",hover)
	cell.add_theme_stylebox_override("pressed",hover)
