extends "res://systems/reward_ui.gd"
signal closed
const Inheritance = preload("res://systems/brand_inheritance.gd")
var battle
var descriptions: Dictionary
var summary: Label
var closing = false

## HTML reference: v2-auto-battle-practice.html / .brand-reference-grid.
## Presentation-only: never change the incoming rules or the curse-first resolver.
const DICE_RESULT_PATH = "res://assets/battle/dice/result-%02d.png"
const FRAME_PATH = "res://assets/battle/ui/legion-info-window-hd.png"
const GRID_WIDTH = 938.0
const FIRST_COL = 230.0
const FACE_COL = 108.0
const CELL_GAP = 5

var dice_headers: Array[TextureRect] = []
var reference_rows: Array[HBoxContainer] = []
var face_cells: Array = []
var reference_scroll: ScrollContainer
var reference_grid: VBoxContainer
var detail_scroll: ScrollContainer
var frame_art: TextureRect

func setup(rules) -> void:
	battle = rules
	descriptions = JSON.parse_string(FileAccess.get_file_as_string("res://data/interface.json")).brands
	z_index = 205
	backdrop()
	# The HTML uses an 82%-wide / 78%-tall, centered parchment frame.
	frame_art = art(self,FRAME_PATH,Vector2(116,77),Vector2(1048,566))
	frame_art.stretch_mode = TextureRect.STRETCH_SCALE
	label_at(self,"BRAND REFERENCE",Vector2(174,99),Vector2(540,19),11)
	label_at(self,"낙인 정보판",Vector2(174,119),Vector2(710,34),23)
	var dismiss=button(self,"×",Vector2(1084,101),Vector2(35,35),close)
	dismiss.add_theme_font_size_override("font_size",21)
	dismiss.tooltip_text="낙인 정보판 닫기"
	var grid_frame=Panel.new()
	grid_frame.name="BrandReferenceGridFrame"
	grid_frame.position=Vector2(169,170)
	grid_frame.size=Vector2(943,391)
	grid_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var paper=StyleBoxFlat.new()
	paper.bg_color=Color("ead9bb66")
	paper.border_color=Color("6d5139")
	paper.set_border_width_all(1)
	grid_frame.add_theme_stylebox_override("panel",paper)
	add_child(grid_frame)
	reference_scroll=ScrollContainer.new()
	reference_scroll.name="BrandReferenceScroll"
	reference_scroll.position=Vector2(174,176)
	reference_scroll.size=Vector2(932,376)
	reference_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	reference_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	add_child(reference_scroll)
	reference_grid=VBoxContainer.new()
	reference_grid.name="BrandReferenceRows"
	reference_grid.add_theme_constant_override("separation",2)
	reference_scroll.add_child(reference_grid)
	var header=HBoxContainer.new()
	header.name="DiceFaceHeader"
	header.add_theme_constant_override("separation",CELL_GAP)
	reference_grid.add_child(header)
	var corner=PanelContainer.new()
	corner.custom_minimum_size=Vector2(FIRST_COL,40)
	corner.add_theme_stylebox_override("panel",header_style())
	var corner_title=Label.new()
	corner_title.text="마물"
	corner_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	corner_title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	corner_title.add_theme_color_override("font_color",Color("f0d6a6"))
	corner.add_child(corner_title)
	header.add_child(corner)
	dice_headers.clear()
	for face in range(1,7):
		var slot=PanelContainer.new()
		slot.name="DiceFace%02d" % face
		slot.custom_minimum_size=Vector2(FACE_COL,40)
		slot.add_theme_stylebox_override("panel",header_style())
		var die=TextureRect.new()
		die.name="DiceImage"
		die.texture=load(DICE_RESULT_PATH % face)
		die.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		die.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		die.custom_minimum_size=Vector2(35,35)
		die.mouse_filter=Control.MOUSE_FILTER_IGNORE
		slot.add_child(die)
		dice_headers.append(die)
		header.add_child(slot)
	reference_rows.clear()
	face_cells.clear()
	for team in ["ally","enemy"]:
		var ordered: Array = rules.units.filter(func(u): return u.team==team and u.alive and not u.is_summon and u.slot<4)
		ordered.sort_custom(func(x,y): return x.slot<y.slot)
		for u in ordered:
			var marks: Array = Inheritance.normalize(u,rules.definitions)
			var row=HBoxContainer.new()
			row.name="UnitBrandRow"
			row.set_meta("unit_id",str(u.id))
			row.set_meta("team",team)
			row.add_theme_constant_override("separation",CELL_GAP)
			reference_grid.add_child(row)
			reference_rows.append(row)
			var unit_button=Button.new()
			unit_button.name="UnitName"
			unit_button.text=("아군 · " if team=="ally" else "적군 · ")+str(u.name)
			unit_button.custom_minimum_size=Vector2(FIRST_COL,40)
			var portrait_path="res://assets/battle/ui/info-portraits/%s.png" % str(u.slug)
			if ResourceLoader.exists(portrait_path):
				unit_button.icon=load(portrait_path)
			unit_button.expand_icon=true
			unit_button.add_theme_constant_override("icon_max_width",30)
			unit_button.add_theme_color_override("font_color",Color("35502c") if team=="ally" else Color("752d25"))
			apply_cell_style(unit_button,Color("e5d1b3") if team=="ally" else Color("d9bba5"))
			unit_button.pressed.connect(func(): describe(u,marks))
			row.add_child(unit_button)
			var row_cells: Array=[]
			for face in range(1,7):
				var mode: String = face_mode(marks,face)
				var cell=Button.new()
				cell.name="BrandFace%02d" % face
				cell.set_meta("face",face)
				cell.set_meta("mode",mode)
				cell.text="✦" if mode=="blessing" else ("☠" if mode=="curse" else "")
				cell.custom_minimum_size=Vector2(FACE_COL,40)
				cell.disabled=mode=="normal"
				cell.tooltip_text="%s · %d번 · %s" % [str(u.name),face,"축복" if mode=="blessing" else ("저주" if mode=="curse" else "발동 없음")]
				cell.add_theme_color_override("font_color",Color("35692c") if mode=="blessing" else Color("752d25"))
				apply_cell_style(cell,Color("c6d0a1") if mode=="blessing" else (Color("d4afa2") if mode=="curse" else Color("dec9a9")))
				cell.pressed.connect(func(): describe(u,marks,face))
				row.add_child(cell)
				row_cells.append(cell)
			face_cells.append(row_cells)
	var note=label_at(self,"✦ 축복 · ☠ 저주 · 마물 이름이나 눈금을 누르면 효과를 볼 수 있습니다.",Vector2(171,566),Vector2(942,24),13)
	note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	detail_scroll=ScrollContainer.new()
	detail_scroll.name="BrandReferenceDescription"
	detail_scroll.position=Vector2(174,592)
	detail_scroll.size=Vector2(933,46)
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(detail_scroll)
	summary=Label.new()
	summary.name="BrandReferenceSummary"
	summary.text="마물 또는 낙인 눈금을 선택하세요."
	summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	summary.add_theme_color_override("font_color",Color("34251c"))
	summary.add_theme_font_size_override("font_size",13)
	detail_scroll.add_child(summary)

func header_style() -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=Color("4a3525")
	style.border_color=Color("795b40")
	style.set_border_width_all(1)
	return style

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
