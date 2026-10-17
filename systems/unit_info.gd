extends Control

signal closed
const PanelDepthMotion = preload("res://systems/panel_depth_motion.gd")
signal rename_submitted(candidate: String)

const GRADES = {"normal":"일반","advanced":"고급","hero":"영웅","special":"소환물"}
const ICONS = {"critical":Rect2(216,48,228,228),"vampire":Rect2(526,48,234,228),"guard":Rect2(841,48,228,228),"poison":Rect2(216,310,228,228),"summon":Rect2(526,310,234,228),"healing":Rect2(843,310,228,228),"combo":Rect2(222,50,220,220),"freeze":Rect2(850,50,220,220),"lightspeed":Rect2(222,316,220,220),"counter":Rect2(852,316,220,220)}
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
	left.position = Vector2(64,76.32)
	left.size = Vector2(474.65,567.36)
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(left)
	PanelDepthMotion.enter(left)
	artwork(left,"res://assets/battle/ui/unit-info-window-no-portrait.png",Vector2.ZERO,left.size)
	name_label = label_at(left,current_name,Vector2(90.18,2.84),Vector2(277,43.12),22)
	name_label.name = "UnitDisplayName"
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
	portrait = artwork(left,"res://assets/battle/ui/info-portraits/%s.png" % u.slug,Vector2(23.73,54.47),Vector2(134.56,199.71))
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
	label_at(left,"◇",Vector2(48,310),Vector2(34,42),21)
	label_at(left,passive[0],Vector2(90,310),Vector2(335,42),15)
	for index in range(mini(3,u.brands.size())):
		var brand = u.brands[index]
		var icon = TextureRect.new()
		var atlas = AtlasTexture.new()
		var sheet = "brand-icons-extra-sheet.jpg" if brand.type in ["combo","freeze","lightspeed","counter"] else "brand-icons-sheet.jpg"
		atlas.atlas = load("res://assets/battle/ui/"+sheet)
		atlas.region = ICONS[brand.type]
		icon.texture = atlas
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(54,373+index*64)
		icon.size = Vector2(44,44)
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
		label_at(left,interface_data.brands[brand.type].name,Vector2(106,373+index*64),Vector2(318,44),15)
	if u.brands.is_empty(): label_at(left,"낙인 없음",Vector2(150,385),Vector2(180,42),15)
	var right = Control.new()
	right.position = Vector2(559.39,183.17)
	right.size = Vector2(483.84,353.67)
	right.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(right)
	PanelDepthMotion.enter(right)
	artwork(right,"res://assets/battle/ui/legion-info-window-hd.png",Vector2.ZERO,right.size)
	var title = label_at(right,"효과 정보",Vector2(33.87,28.29),Vector2(416.1,35.22),17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll = ScrollContainer.new()
	scroll.name = "EffectScroll"
	scroll.position = Vector2(33.87,68)
	scroll.size = Vector2(416.1,253.84)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	effects = VBoxContainer.new()
	effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects.add_theme_constant_override("separation",4)
	scroll.add_child(effects)
	section("군단 효과")
	var any_active = false
	for key in interface_data.legions:
		if not battle.active(u.team,key): continue
		any_active = true
		var rule = interface_data.legions[key]
		effect_line("%s %d/%d · %s" % [rule.name,battle.legions[u.team].counts.get(key,0),rule.need,rule.effect])
	if not any_active: effect_line("활성 군단 없음")
	var opposite = "enemy" if u.team == "ally" else "ally"
	if "element" in battle.legions[opposite].active: effect_line("상대 원소: 군단 효과 억제")
	effect_line("군단 활성은 전투 시작 시 고정")
	if hp_bonus>0 or attack_bonus>0 or speed_bonus>0:
		section("점술 · 다음 전투에 적용")
		effect_line("체력 +%d · 공격력 +%d · 속도 +%d" % [hp_bonus,attack_bonus,speed_bonus],Color("244e2c"))
		effect_line("위 능력치에 포함 · 전투 진입 시 적용 후 소모")
	section("패시브 효과")
	effect_line(passive[0]+(" · "+passive[1] if not passive[1].is_empty() else ""))
	section("낙인 눈금과 효과")
	for brand in u.brands:
		var definition = interface_data.brands[brand.type]
		effect_line(definition.name,Color("281a12"),14)
		effect_line("축복 [%s] · %s" % [", ".join(brand.bless.map(func(n): return str(n))),definition.blessing],Color("244e2c"))
		if not brand.curse.is_empty():
			effect_line("저주 [%s] · %s" % [", ".join(brand.curse.map(func(n): return str(n))),definition.penalty],Color("782622"))
	if u.brands.is_empty(): effect_line("낙인 없음")
	if u.base_hp != u.max_hp or u.base_attack != u.attack or u.base_speed != u.speed:
		section("능력치 변화")
		effect_line("최대 체력 %d → %d · 공격력 %d → %d · 속도 %d → %d" % [u.base_hp,u.max_hp,u.base_attack,u.attack,u.base_speed,u.speed])
	if u.slug == "guardian-seed":
		section("개화")
		effect_line("공격 불가 · 생성 다음 라운드를 마치면 자동 개화")

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
	if is_instance_valid(name_label): name_label.text = current_name
	cancel_rename()

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
