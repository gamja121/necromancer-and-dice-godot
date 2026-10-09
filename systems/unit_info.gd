extends Control

signal closed

const GRADES = {"normal":"일반","advanced":"고급","hero":"영웅","special":"소환물"}
const ICONS = {"critical":Rect2(216,48,228,228),"vampire":Rect2(526,48,234,228),"guard":Rect2(841,48,228,228),"poison":Rect2(216,310,228,228),"summon":Rect2(526,310,234,228),"healing":Rect2(843,310,228,228),"combo":Rect2(222,50,220,220),"freeze":Rect2(850,50,220,220),"lightspeed":Rect2(222,316,220,220),"counter":Rect2(852,316,220,220)}
var unit_id = ""
var effects: VBoxContainer
var interface_data: Dictionary
var portrait: TextureRect

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

func setup(u: Dictionary, battle, prophecy: Dictionary = {}) -> void:
	u = u.duplicate(true)
	var hp_bonus = int(prophecy.get("ally_hp",0))
	var attack_bonus = int(prophecy.get("ally_attack",0))
	var speed_bonus = int(prophecy.get("ally_speed",0))
	u.hp += hp_bonus
	u.max_hp += hp_bonus
	u.attack += attack_bonus
	u.speed += speed_bonus
	unit_id = u.id
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
	artwork(left,"res://assets/battle/ui/unit-info-window-no-portrait.png",Vector2.ZERO,left.size)
	var name_label = label_at(left,u.name,Vector2(90.18,2.84),Vector2(294.28,43.12),22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
		label_at(left,interface_data.brands[brand.type].name,Vector2(106,373+index*64),Vector2(318,44),15)
	if u.brands.is_empty(): label_at(left,"낙인 없음",Vector2(150,385),Vector2(180,42),15)
	var right = Control.new()
	right.position = Vector2(559.39,183.17)
	right.size = Vector2(483.84,353.67)
	right.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(right)
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
		effect_line("저주 [%s] · %s" % [", ".join(brand.curse.map(func(n): return str(n))),definition.penalty],Color("782622"))
	if u.brands.is_empty(): effect_line("낙인 없음")
	if u.base_hp != u.max_hp or u.base_attack != u.attack or u.base_speed != u.speed:
		section("능력치 변화")
		effect_line("최대 체력 %d → %d · 공격력 %d → %d · 속도 %d → %d" % [u.base_hp,u.max_hp,u.base_attack,u.attack,u.base_speed,u.speed])
	if u.slug == "guardian-seed":
		section("개화")
		effect_line("공격 불가 · 생성 다음 라운드를 마치면 자동 개화")

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
