extends "res://systems/reward_ui.gd"
signal closed
const Inheritance = preload("res://systems/brand_inheritance.gd")
const FateIcon = preload("res://systems/battle_fate_icon.gd")
var battle
var descriptions: Dictionary
var summary: Label
var closing = false

## HTML reference: v2-auto-battle-practice.html / .brand-reference-grid.
## Presentation-only: never change the incoming rules or the curse-first resolver.
const DICE_RESULT_PATH = "res://assets/battle/dice/result-%02d.png"
# Cell icons reuse the exact blessing/curse vector artwork shown above battle HP bars.
# Show readable descriptions in a compact popup only after a unit or die is selected.
const BLESSING_GLYPH = "축"
const CURSE_GLYPH = "저"
const LEGEND_TEXT = "초록 별: 축복 · 보라색 선: 저주 · 마물 이름이나 눈금을 누르면 효과를 볼 수 있습니다."
const FRAME_PATH = "res://assets/map/ui/inheritance_info.webp"
const GRID_WIDTH = 938.0
const FIRST_COL = 230.0
const FACE_COL = 108.0
const CELL_GAP = 5
const HEADER_HEIGHT = 36.0
const ROW_HEIGHT = 34.0

var dice_headers: Array[TextureRect] = []
var reference_rows: Array[HBoxContainer] = []
var face_cells: Array = []
var reference_scroll: ScrollContainer
var reference_grid: VBoxContainer
var detail_scroll: ScrollContainer
var detail_popup: PanelContainer
var popup_title: Label
var selected_unit_id: String = ""
var selected_face: int = 0
var frame_art: TextureRect

func setup(rules) -> void:
	battle = rules
	descriptions = JSON.parse_string(FileAccess.get_file_as_string("res://data/interface.json")).brands
	z_index = 205
	backdrop()
	# Keep the frame compact: no permanently empty description footer.
	var visible_rows: int = 0
	for unit in rules.units:
		if unit.alive and not unit.is_summon and unit.slot < 4 and unit.team in ["ally", "enemy"]:
			visible_rows += 1
	var grid_height: float = minf(345.0, 12.0 + HEADER_HEIGHT + float(visible_rows) * (ROW_HEIGHT + 2.0))
	var frame_height: float = 170.0 + grid_height
	frame_art = art(self,FRAME_PATH,Vector2(116,77),Vector2(1048,frame_height))
	frame_art.stretch_mode = TextureRect.STRETCH_SCALE
	label_at(self,"BRAND REFERENCE",Vector2(174,99),Vector2(540,19),11)
	label_at(self,"낙인 정보판",Vector2(174,119),Vector2(710,34),23)
	var dismiss=button(self,"×",Vector2(1076,96),Vector2(46,44),close)
	dismiss.add_theme_font_size_override("font_size",21)
	dismiss.tooltip_text="낙인 정보판 닫기"
	var grid_frame=Panel.new()
	grid_frame.name="BrandReferenceGridFrame"
	grid_frame.position=Vector2(169,170)
	grid_frame.size=Vector2(943,grid_height)
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
	reference_scroll.size=Vector2(932,grid_height-13.0)
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
	corner.custom_minimum_size=Vector2(FIRST_COL,HEADER_HEIGHT)
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
		slot.custom_minimum_size=Vector2(FACE_COL,HEADER_HEIGHT)
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
			unit_button.custom_minimum_size=Vector2(FIRST_COL,ROW_HEIGHT)
			unit_button.clip_text=true
			unit_button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			unit_button.tooltip_text=str(u.name)
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
				cell.text=""  # Symbol belongs to the shared HP-bar FateIcon artwork.
				cell.custom_minimum_size=Vector2(FACE_COL,ROW_HEIGHT)
				cell.disabled=mode=="normal"
				cell.tooltip_text="%s · %d번 · %s" % [str(u.name),face,"축복" if mode=="blessing" else ("저주" if mode=="curse" else "발동 없음")]
				apply_cell_style(cell,Color("c6d0a1") if mode=="blessing" else (Color("d4afa2") if mode=="curse" else Color("dec9a9")))
				cell.pressed.connect(func(): describe(u,marks,face))
				row.add_child(cell)
				if mode!="normal":
					# Use the very same drawn symbols as Battlefield's FateIcon:
					# asymmetrical green triple-stars or violet descending lines.
					# Normal cells remain empty, preserving quick dice-face scanning.
					var symbol = FateIcon.new()
					symbol.name="BrandFaceFateIcon"
					cell.add_child(symbol)
					symbol.set_mode("bless" if mode=="blessing" else "curse",false)
					symbol.scale=Vector2.ONE*1.15
					symbol.position=(Vector2(FACE_COL,ROW_HEIGHT)-symbol.size*symbol.scale)*0.5
				row_cells.append(cell)
			face_cells.append(row_cells)
	var note=label_at(self,LEGEND_TEXT,Vector2(171,176+grid_height),Vector2(942,23),13)
	note.name="BrandReferenceLegend"
	note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	# Compact, initially hidden popup replaces the empty full-width footer.
	detail_popup=PanelContainer.new()
	detail_popup.name="BrandReferenceDetailPopup"
	detail_popup.position=Vector2(340,204)
	detail_popup.custom_minimum_size=Vector2(600,0)
	detail_popup.size=Vector2(600,0)
	detail_popup.visible=false
	detail_popup.z_index=10
	var popup_style=StyleBoxFlat.new()
	popup_style.bg_color=Color("f2e4cc")
	popup_style.border_color=Color("6d5139")
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(8)
	popup_style.set_content_margin_all(12)
	detail_popup.add_theme_stylebox_override("panel",popup_style)
	add_child(detail_popup)
	var popup_content=VBoxContainer.new()
	popup_content.add_theme_constant_override("separation",5)
	detail_popup.add_child(popup_content)
	var popup_header=HBoxContainer.new()
	popup_content.add_child(popup_header)
	popup_title=Label.new()
	popup_title.text="낙인 효과"
	popup_title.add_theme_color_override("font_color",Color("34251c"))
	popup_title.add_theme_font_size_override("font_size",17)
	popup_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	popup_header.add_child(popup_title)
	var popup_close=Button.new()
	popup_close.text="×"
	popup_close.custom_minimum_size=Vector2(42,40)
	popup_close.tooltip_text="효과 설명 닫기"
	popup_close.pressed.connect(hide_detail)
	popup_header.add_child(popup_close)
	detail_scroll=ScrollContainer.new()
	detail_scroll.name="BrandReferenceDescription"
	detail_scroll.custom_minimum_size=Vector2(570,65)
	detail_scroll.size=Vector2(570,145)
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	popup_content.add_child(detail_scroll)
	summary=Label.new()
	summary.name="BrandReferenceSummary"
	summary.text=""
	summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size=Vector2(550,0)
	summary.custom_maximum_size=Vector2(550,0)
	summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	summary.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	summary.add_theme_color_override("font_color",Color("34251c"))
	summary.add_theme_font_size_override("font_size",14)
	summary.add_theme_constant_override("line_spacing",3)
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
			lines.append("%s %s · %s" % [tr(CURSE_GLYPH),definition.name,definition.penalty])
		elif mode=="blessing" and face in mark.bless:
			lines.append("%s %s · %s" % [tr(BLESSING_GLYPH),definition.name,definition.blessing])
	if lines.size()==1: lines.append("낙인 없음" if face==0 else "발동 없음")
	selected_unit_id=str(u.id)
	selected_face=face
	popup_title.text="%s · %s" % [str(u.name),"전체 낙인" if face==0 else "%d번 눈금" % face]
	# Preserve the full eight-monster/six-face board; only de-emphasize
	# unrelated rows while the selected unit's effect is open.
	for row in reference_rows:
		row.modulate=Color.WHITE if str(row.get_meta("unit_id"))==selected_unit_id else Color(0.76,0.76,0.76,1.0)
	summary.text = "\n".join(lines)
	detail_popup.show()
	# Always start at the selected mark name rather than retaining the previous scroll offset.
	detail_scroll.set_deferred("scroll_vertical",0)

func hide_detail() -> void:
	if is_instance_valid(detail_popup): detail_popup.hide()
	selected_unit_id=""
	selected_face=0
	for row in reference_rows: row.modulate=Color.WHITE

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
