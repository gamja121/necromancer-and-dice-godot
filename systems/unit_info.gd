extends Control

signal closed
const PanelDepthMotion = preload("res://systems/panel_depth_motion.gd")
signal rename_submitted(candidate: String)

const GRADES = {"normal":"일반","advanced":"고급","hero":"영웅","special":"소환물"}
const ICONS = {"critical":Rect2(216,48,228,228),"vampire":Rect2(526,48,234,228),"guard":Rect2(841,48,228,228),"poison":Rect2(216,310,228,228),"summon":Rect2(526,310,234,228),"healing":Rect2(843,310,228,228),"combo":Rect2(222,50,220,220),"freeze":Rect2(850,50,220,220),"lightspeed":Rect2(222,316,220,220),"counter":Rect2(852,316,220,220)}
var closing_depth := false
var depth_panels: Array[Control] = []
var unit_id = ""
var effects: VBoxContainer
var interface_data: Dictionary
var portrait: TextureRect
var name_label: Label
var rename_button: Button
var rename_dialog: Control
var rename_input: LineEdit
var rename_error: Label
var current_name: String = ""
var allow_rename: bool = false

# The original left frame has room for three compact, independent marks.
const BRAND_ICON_TOP := 356.0
const BRAND_ICON_STEP := 51.0
const BRAND_ICON_SIZE := 40.0

# Display-only grouping: BattleRules keeps all three independent brands.
# When the same face occurs twice, retain stacking as "4×2" rather than
# losing the extra effect by removing duplicates.
static func merged_face_text(faces: Array) -> String:
	var counts: Dictionary={}
	for raw in faces:
		var face: int=int(raw)
		if face<1 or face>6: continue
		counts[face]=int(counts.get(face,0))+1
	var ordered: Array=counts.keys()
	ordered.sort()
	var display: PackedStringArray=PackedStringArray()
	for face in ordered:
		var count: int=int(counts[face])
		display.append(str(face) if count==1 else "%d×%d" % [face,count])
	return ", ".join(display)

static func grouped_brands(brands: Array) -> Array:
	var result: Array=[]
	var locations: Dictionary={}
	for mark in brands:
		if not mark is Dictionary: continue
		var kind: String=str(mark.get("type",""))
		if kind.is_empty(): continue
		if not locations.has(kind):
			locations[kind]=result.size()
			result.append({"type":kind,"bless":[],"curse":[]})
		var row: Dictionary=result[int(locations[kind])]
		var blessing: Array=row["bless"]
		var curse: Array=row["curse"]
		blessing.append_array(mark.get("bless",[]))
		curse.append_array(mark.get("curse",[]))
		row["bless"]=blessing
		row["curse"]=curse
		result[int(locations[kind])]=row
	return result

func label_at(parent: Control, value: String, pos: Vector2, dimensions: Vector2, font_size: int = 15, color: Color = Color("211712")) -> Label:
	var node = Label.new()
	node.text = value
	node.position = pos
	node.size = dimensions
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node

func artwork(parent: Control, path: String, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var node = TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = load(path)
	node.position = pos
	node.size = dimensions
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func effect_line(value: String, color: Color = Color("34251c"), font_size: int = 13) -> Label:
	var node = Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_color_override("font_color",color)
	node.add_theme_font_size_override("font_size",font_size)
	effects.add_child(node)
	return node

func section(value: String) -> void:
	var title = effect_line(value,Color("34251c"),14)
	title.add_theme_constant_override("outline_size",0)
	var rule = HSeparator.new()
	var style = StyleBoxLine.new()
	style.color = Color("6c504866")
	style.thickness = 1
	rule.add_theme_stylebox_override("separator",style)
	effects.add_child(rule)


# Existing hand-painted parchment; no new bitmap. Keep readable aligned rows,
# not bordered cards. Only major category changes get one thin ink separator.
const EFFECT_CONTENT_WIDTH := 571.0
const EFFECT_CONTENT_HEIGHT := 458.0
const PAPER_TOP := 76.32
const PAPER_MAX_HEIGHT := 567.36
const PAPER_MIN_HEIGHT := 250.0

func effect_section(label_text: String) -> void:
	var header := HBoxContainer.new()
	header.name="EffectSection_"+label_text.replace(" ","")
	header.add_theme_constant_override("separation",10)
	effects.add_child(header)
	var label := Label.new()
	label.text=label_text
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_color_override("font_color",Color("4a3225"))
	header.add_child(label)
	var line := HSeparator.new()
	line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var ink := StyleBoxLine.new()
	ink.thickness=1
	ink.color=Color(0.32,0.21,0.15,0.36)
	line.add_theme_stylebox_override("separator",ink)
	header.add_child(line)

func effect_row(parent: Container,key: String,heading: String,face: String,description: String,tint: Color = Color("38291e"),small: bool=false) -> void:
	var line := HBoxContainer.new()
	line.name=key
	line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation",7 if small else 10)
	parent.add_child(line)
	var title := Label.new()
	title.name="RowTitle"
	title.text=heading
	title.custom_minimum_size.x=59.0 if small else 87.0
	title.add_theme_font_size_override("font_size",14 if small else 15)
	title.add_theme_color_override("font_color",Color("37251a") if heading!="저주" else Color("832f2c"))
	line.add_child(title)
	if not face.is_empty():
		var eyes := Label.new()
		eyes.name="RowFaces"
		eyes.text=face
		eyes.custom_minimum_size.x=47.0 if small else 89.0
		eyes.add_theme_font_size_override("font_size",13 if small else 15)
		eyes.add_theme_color_override("font_color",tint)
		line.add_child(eyes)
	var detail := Label.new()
	detail.name="RowDetail"
	detail.text=description
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size",14 if small else 15)
	detail.add_theme_color_override("font_color",tint)
	line.add_child(detail)

func fit_effects_without_scrolling() -> void:
	if not is_instance_valid(effects) or not effects.is_inside_tree(): return
	# Use two-column legions to reduce vertical density BEFORE any scaling.
	var factor: float=1.0
	for i in range(3):
		if not is_instance_valid(effects): return
		var necessary: float=effects.get_combined_minimum_size().y
		factor=minf(1.0,EFFECT_CONTENT_HEIGHT/maxf(1.0,necessary))
		effects.scale=Vector2(factor,factor)
		var width: float=EFFECT_CONTENT_WIDTH/maxf(0.1,factor)
		effects.custom_minimum_size.x=width
		effects.size.x=width
		await get_tree().process_frame
	if not is_instance_valid(effects): return
	var final_height: float=effects.get_combined_minimum_size().y
	factor=minf(1.0,EFFECT_CONTENT_HEIGHT/maxf(1.0,final_height))
	effects.scale=Vector2(factor,factor)
	effects.set_meta("content_height",final_height)
	effects.set_meta("fit_scale",factor)
	# Reduce surplus parchment height when there are only a few active effects.
	# The title and content remain in the same position relative to its frame.
	var right: Control=get_node_or_null("UnitInfoEffectsPanel")
	if right!=null:
		var visible_height: float=final_height*factor
		var target: float=clampf(visible_height+111.0,PAPER_MIN_HEIGHT,PAPER_MAX_HEIGHT)
		right.size.y=target
		right.position.y=PAPER_TOP+(PAPER_MAX_HEIGHT-target)*0.5
		var paper: NinePatchRect=right.get_node("OriginalEffectsParchment")
		paper.size.y=target

func setup(u: Dictionary, battle, prophecy: Dictionary = {}, owned_rename: bool = false) -> void:
	u = u.duplicate(true)
	var hp_bonus = int(prophecy.get("ally_hp",0))
	var attack_bonus = int(prophecy.get("ally_attack",0))
	var speed_bonus = int(prophecy.get("ally_speed",0))
	u.hp += hp_bonus
	u.max_hp += hp_bonus
	u.attack += attack_bonus
	u.speed += speed_bonus
	unit_id = u.id
	current_name = str(u.name)
	allow_rename = owned_rename and str(u.get("team",""))=="ally" and not bool(u.get("is_summon",false))
	interface_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/interface.json"))
	size = Vector2(1280,720)
	z_index = 90
	var backdrop = Button.new()
	backdrop.flat = true
	backdrop.size = size
	backdrop.tooltip_text = "유닛 정보 닫기"
	backdrop.pressed.connect(close)
	add_child(backdrop)
	var shade = ColorRect.new()
	shade.size = size
	shade.color = Color("030201c4")
	var blur = Shader.new()
	blur.code = "shader_type canvas_item; uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap; void fragment(){ vec4 bg = textureLod(screen_tex, SCREEN_UV, 1.0); COLOR = vec4(mix(bg.rgb, vec3(0.012,0.008,0.004), 0.769), 1.0); }"
	var material = ShaderMaterial.new()
	material.shader = blur
	shade.material = material
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var left = Control.new()
	left.name = "UnitInfoPortraitPanel"
	left.position = Vector2(64,76.32)
	left.size = Vector2(474.65,567.36)
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(left)
	PanelDepthMotion.shadow(left)
	PanelDepthMotion.enter(left)
	depth_panels.append(left)
	artwork(left,"res://assets/battle/ui/unit-info-window-no-portrait.png",Vector2.ZERO,left.size)
	name_label = label_at(left,current_name,Vector2(90.18,2.84),Vector2(277,43.12),22)
	name_label.name = "UnitDisplayName"
	if u.has("nickname"): name_label.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if allow_rename:
		rename_button = Button.new()
		rename_button.name = "UnitRenameButton"
		rename_button.text = "개명"
		rename_button.tooltip_text = "이 마물에게 새 이름 붙이기"
		rename_button.position = Vector2(374,9)
		rename_button.size = Vector2(55,33)
		rename_button.pressed.connect(open_rename_editor)
		left.add_child(rename_button)
	var close_button = Button.new()
	close_button.name = "InfoClose"
	close_button.flat = true
	close_button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	close_button.position = Vector2(435.73,5.67)
	close_button.size = Vector2(36.55,36.55)
	close_button.tooltip_text = "유닛 정보 닫기"
	close_button.pressed.connect(close)
	left.add_child(close_button)
	close_button.grab_focus()
	var portrait_path: String = "res://assets/battle/frames/dragon/attack-01.png" if str(u.slug)=="dragon" else "res://assets/battle/ui/info-portraits/%s.png" % u.slug
	portrait = artwork(left,portrait_path,Vector2(23.73,54.47),Vector2(134.56,199.71))
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var legion_names: Array = []
	for key in u.legions: legion_names.append(interface_data.legions[key].name)
	var values = [["등급",GRADES.get(u.grade,"미지정"),78.0],["군단"," · ".join(legion_names),103.0],["체력","%d / %d" % [u.hp,u.max_hp],170.0],["공격력",str(u.attack),195.0],["속도",str(u.speed),220.0]]
	for row in values:
		label_at(left,row[0],Vector2(191,row[2]),Vector2(74,24),14)
		var value = label_at(left,row[1],Vector2(266,row[2]),Vector2(152,24),15)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if row[0]=="군단": value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var passive = interface_data.passives.get(u.passive,["패시브 없음",""])
	var boss_second: String = str(u.get("boss_extra_passive","")) if str(u.get("slug",""))=="dragon" and str(u.get("team",""))=="enemy" and bool(u.get("final_boss",false)) else ""
	var second_passive: Array = interface_data.passives.get(boss_second,[])
	# The whole empty-passive row vanishes, not just its effects description.
	if not str(u.passive).is_empty() or not second_passive.is_empty():
		label_at(left,"◇",Vector2(48,310),Vector2(34,42),21)
		var passive_title: String = str(passive[0]) if not str(u.passive).is_empty() else ""
		if not second_passive.is_empty():
			passive_title += (" · " if not passive_title.is_empty() else "")+str(second_passive[0])
		label_at(left,passive_title,Vector2(90,310),Vector2(335,42),15)
	for index in range(mini(3,u.brands.size())):
		var brand = u.brands[index]
		var icon = TextureRect.new()
		icon.name = "BrandInfoIcon"
		icon.set_meta("brand_slot",index)
		var atlas = AtlasTexture.new()
		var sheet = "brand-icons-extra-sheet.jpg" if brand.type in ["combo","freeze","lightspeed","counter"] else "brand-icons-sheet.jpg"
		atlas.atlas = load("res://assets/battle/ui/"+sheet)
		atlas.region = ICONS[brand.type]
		icon.texture = atlas
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(54,BRAND_ICON_TOP+index*BRAND_ICON_STEP)
		icon.size = Vector2(BRAND_ICON_SIZE,BRAND_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		left.add_child(icon)
		# Recessed socket and a short weighted settle, visual-only.
		var socket := Panel.new()
		socket.name = "BrandSocket"
		socket.position = icon.position + Vector2(-2.0, -2.0)
		socket.size = icon.size + Vector2(4.0, 4.0)
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var recess := StyleBoxFlat.new()
		recess.bg_color = Color(0.045, 0.035, 0.045, 0.36)
		recess.set_corner_radius_all(8)
		recess.set_border_width_all(1)
		recess.border_color = Color(0.07, 0.05, 0.045, 0.50)
		socket.add_theme_stylebox_override("panel", recess)
		left.add_child(socket)
		left.move_child(socket, icon.get_index())
		icon.pivot_offset = icon.size * 0.5
		icon.scale = Vector2(1.075, 1.075)
		icon.modulate.a = 0.85
		var settle := create_tween().set_parallel(true)
		settle.tween_property(icon, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(float(index) * 0.055)
		settle.tween_property(icon, "modulate:a", 1.0, 0.18).set_delay(float(index) * 0.055)
		var brand_name := label_at(left,interface_data.brands[brand.type].name,Vector2(106,BRAND_ICON_TOP+index*BRAND_ICON_STEP),Vector2(318,BRAND_ICON_SIZE),15)
		brand_name.name="BrandInfoName"
		brand_name.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	if u.brands.is_empty(): label_at(left,"낙인 없음",Vector2(150,385),Vector2(180,42),15)
	var right = Control.new()
	right.name = "UnitInfoEffectsPanel"
	right.position = Vector2(550,76.32)
	right.size = Vector2(655,567.36)
	right.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(right)
	PanelDepthMotion.shadow(right)
	PanelDepthMotion.enter(right)
	depth_panels.append(right)
	# NinePatchRect preserves hand-painted corner hardware when increasing the
	# original parchment area; no new artwork is generated or introduced.
	var paper := NinePatchRect.new()
	paper.name="OriginalEffectsParchment"
	paper.texture=load("res://assets/battle/ui/legion-info-window-hd.png")
	paper.patch_margin_left=36
	paper.patch_margin_right=36
	paper.patch_margin_top=42
	paper.patch_margin_bottom=40
	paper.region_rect=Rect2(Vector2.ZERO,paper.texture.get_size())
	paper.size=right.size
	paper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	right.add_child(paper)
	var title = label_at(right,"효과 정보",Vector2(42,22),Vector2(EFFECT_CONTENT_WIDTH,38),19)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effects = VBoxContainer.new()
	effects.name="EffectGrid"
	effects.position=Vector2(42,70)
	effects.size=Vector2(EFFECT_CONTENT_WIDTH,EFFECT_CONTENT_HEIGHT)
	effects.custom_minimum_size.x=EFFECT_CONTENT_WIDTH
	effects.add_theme_constant_override("separation",6)
	effects.mouse_filter=Control.MOUSE_FILTER_IGNORE
	right.add_child(effects)
	var count: int=0
	# Three brand slots become at most three aligned blessing rows, with
	# matching effects merged. No redundant "의 낙인" on every row.
	var groups: Array=grouped_brands(u.brands)
	if not groups.is_empty():
		effect_section("낙인 효과")
		for group in groups:
			var def: Dictionary=interface_data.brands.get(group.type,{})
			if def.is_empty(): continue
			var short_name: String=str(def.name).replace("의 낙인","")
			effect_row(effects,"Brand_"+str(group.type),short_name,merged_face_text(group.bless),str(def.blessing),Color("28573a"))
			count+=1
		# Curse eyes belong to their actual source mark, not to every new brand
		# type. Display the heading only once; preserve any legacy saved extras.
		var printed_curse: bool=false
		for group in groups:
			if group.curse.is_empty(): continue
			var def: Dictionary=interface_data.brands.get(group.type,{})
			if def.is_empty(): continue
			var short_name: String=str(def.name).replace("의 낙인","")
			var curse_desc: String=short_name+" · "+str(def.penalty) if groups.size()>1 else str(def.penalty)
			effect_row(effects,"Curse_"+str(group.type),"저주" if not printed_curse else "",merged_face_text(group.curse),curse_desc,Color("87372d"))
			printed_curse=true
			count+=1
	var passives: Array=[]
	if not str(u.passive).is_empty() and not passive.is_empty() and str(passive[0])!="패시브 없음":
		passives.append({"name":str(passive[0]),"text":str(passive[1])})
	if not second_passive.is_empty():
		passives.append({"name":str(second_passive[0]),"text":str(second_passive[1])})
	if not passives.is_empty():
		effect_section("패시브")
		for i in range(passives.size()):
			effect_row(effects,"Passive_"+str(i),str(passives[i].name),"",str(passives[i].text))
			count+=1
	var legions: Array=[]
	for key in interface_data.legions:
		if not battle.active(u.team,key): continue
		var rule: Dictionary=interface_data.legions[key]
		legions.append({"key":str(key),"name":str(rule.name),"count":"%d/%d" % [battle.legions[u.team].counts.get(key,0),rule.need],"text":str(rule.effect)})
	if not legions.is_empty():
		effect_section("군단 효과")
		if legions.size()>4:
			var legion_grid := GridContainer.new()
			legion_grid.name="ActiveLegionEffects"
			legion_grid.columns=2
			legion_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			legion_grid.add_theme_constant_override("h_separation",14)
			legion_grid.add_theme_constant_override("v_separation",4)
			effects.add_child(legion_grid)
			for info in legions:
				var col := VBoxContainer.new()
				col.custom_minimum_size.x=270
				col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				col.add_theme_constant_override("separation",0)
				legion_grid.add_child(col)
				var top := Label.new()
				top.text=str(info.name)+" · "+str(info.count)
				top.add_theme_font_size_override("font_size",13)
				top.add_theme_color_override("font_color",Color("3e291b"))
				col.add_child(top)
				var detail := Label.new()
				detail.text=str(info.text)
				detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				detail.add_theme_font_size_override("font_size",14)
				detail.add_theme_color_override("font_color",Color("38291e"))
				col.add_child(detail)
				count+=1
		else:
			var list := VBoxContainer.new()
			list.name="ActiveLegionEffects"
			list.add_theme_constant_override("separation",4)
			effects.add_child(list)
			for info in legions:
				effect_row(list,"Legion_"+str(info.key),str(info.name),str(info.count),str(info.text))
				count+=1
	var extras: Array=[]
	if hp_bonus>0 or attack_bonus>0 or speed_bonus>0:
		extras.append({"key":"ProphecyEffects","name":"점술","desc":"체력 +%d · 공격력 +%d · 속도 +%d" % [hp_bonus,attack_bonus,speed_bonus]})
	if u.base_hp != u.max_hp or u.base_attack != u.attack or u.base_speed != u.speed:
		extras.append({"key":"StatsChanged","name":"능력치","desc":"최대 체력 %d → %d · 공격력 %d → %d · 속도 %d → %d" % [u.base_hp,u.max_hp,u.base_attack,u.attack,u.base_speed,u.speed]})
	if u.slug=="guardian-seed":
		extras.append({"key":"BloomInfo","name":"개화","desc":"공격 불가 · 생성 다음 라운드를 마치면 자동 개화"})
	if not extras.is_empty():
		effect_section("기타 효과")
		for item in extras:
			effect_row(effects,str(item.key),str(item.name),"",str(item.desc))
			count+=1
	if count==0: effect_section("효과 없음")
	# Scrollbars and nested cards are never created.
	call_deferred("fit_effects_without_scrolling")

## A focused naming overlay instead of an extra screen. No direct save
## access lives in this view; the owning RunSession performs the transaction.
func open_rename_editor() -> void:
	if not allow_rename or is_instance_valid(rename_dialog): return
	rename_dialog = ColorRect.new()
	rename_dialog.name = "UnitRenameEditor"
	rename_dialog.size = size
	rename_dialog.color = Color("0a0708d6")
	rename_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	rename_dialog.z_index = 5
	add_child(rename_dialog)
	var body = PanelContainer.new()
	body.name = "RenameCard"
	body.position = Vector2(399,250)
	body.size = Vector2(482,222)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("e3ccab")
	style.border_color = Color("744a2c")
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
	body.add_theme_stylebox_override("panel",style)
	rename_dialog.add_child(body)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation",11)
	body.add_child(content)
	var title = Label.new()
	title.text = "마물에게 이름 붙이기"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("352014"))
	title.add_theme_font_size_override("font_size",21)
	content.add_child(title)
	rename_input = LineEdit.new()
	rename_input.name = "UnitRenameInput"
	rename_input.text = current_name
	rename_input.max_length = 12
	rename_input.placeholder_text = "새 이름 (1~12자)"
	rename_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	rename_input.add_theme_color_override("font_color",Color("302015"))
	rename_input.text_submitted.connect(func(_value: String): submit_rename())
	content.add_child(rename_input)
	rename_error = Label.new()
	rename_error.name = "UnitRenameFeedback"
	rename_error.text = "이름은 이 마물에게만 적용됩니다."
	rename_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rename_error.add_theme_color_override("font_color",Color("753d29"))
	content.add_child(rename_error)
	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(actions)
	var cancel = Button.new()
	cancel.name = "UnitRenameCancel"
	cancel.text = "취소"
	cancel.custom_minimum_size = Vector2(108,39)
	cancel.pressed.connect(cancel_rename)
	actions.add_child(cancel)
	var save = Button.new()
	save.name = "UnitRenameConfirm"
	save.text = "이름 저장"
	save.custom_minimum_size = Vector2(124,39)
	save.pressed.connect(submit_rename)
	actions.add_child(save)
	rename_input.grab_focus()
	rename_input.select_all()

func cancel_rename() -> void:
	if is_instance_valid(rename_dialog): rename_dialog.queue_free()
	rename_dialog = null
	rename_input = null
	rename_error = null

func submit_rename() -> void:
	if not allow_rename or not is_instance_valid(rename_input): return
	rename_submitted.emit(rename_input.text)

func apply_rename_result(result: Dictionary) -> void:
	if not bool(result.get("ok",false)):
		if is_instance_valid(rename_error):
			rename_error.text = str(result.get("reason","저장에 실패했습니다."))
		return
	current_name = str(result.get("name",current_name))
	if is_instance_valid(name_label):
		name_label.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
		name_label.text = current_name
	cancel_rename()

func close() -> void:
	if closing_depth: return
	closing_depth = true
	for panel in depth_panels:
		if is_instance_valid(panel): PanelDepthMotion.exit(panel, Callable())
	get_tree().create_timer(0.14).timeout.connect(func():
		if is_instance_valid(self):
			closed.emit()
			queue_free())

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
