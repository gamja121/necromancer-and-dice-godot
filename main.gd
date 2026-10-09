extends Control

const ExpeditionModel = preload("res://systems/expedition.gd")
const SAVE_PATH = "user://expedition_v1.json"
const LEGION_NAMES = {"skeleton":"언데드","beast":"야수","corpse":"시체","plague":"역병","ice":"얼음","summon":"소환","demon":"악마","plant":"식물","insect":"벌레","element":"원소"}
const BRAND_NAMES = {"critical":"치명타","vampire":"흡혈","combo":"연격","freeze":"빙결","poison":"독","guard":"수호","summon":"소환","counter":"반격","healing":"회복","lightspeed":"광속"}
var save_path = SAVE_PATH
var passive_data: Dictionary
var model
var data: Dictionary
var root_box: VBoxContainer
var content: VBoxContainer
var notice: Label
var busy = false
var save_error = ""
var texture_cache: Dictionary = {}

func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json"))
	data = parsed.units
	passive_data = parsed.passives
	var game_theme = Theme.new()
	var korean_font = SystemFont.new()
	korean_font.fallbacks = [preload("res://assets/fonts/nanum_gothic_regular.ttf")]
	korean_font.font_names = PackedStringArray(["Malgun Gothic","맑은 고딕","sans-serif"])
	game_theme.default_font = korean_font
	game_theme.default_font_size = 17
	game_theme.set_color("font_color","Label",Color("e9e4d5"))
	theme = game_theme
	for child in get_children(): child.queue_free()
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	add_child(margin)
	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation",12)
	margin.add_child(root_box)
	var header = HBoxContainer.new()
	root_box.add_child(header)
	var title = label("NECROMANCER & DICE",28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color",Color("c5dda3"))
	header.add_child(title)
	add_button(header,"전장 연습",func(): get_tree().change_scene_to_file("res://battlefield.tscn"))
	add_button(header,"새 원정",confirm_new)
	add_button(header,"이어하기",load_game)
	add_button(header,"규칙·조작",show_help)
	root_box.add_child(label("GODOT 첫 플레이 버전 · 기존 V2 전투 규칙 / 짧은 원정 시험 경로",13))
	notice = label("",16)
	root_box.add_child(notice)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	scroll.add_child(content)
	new_game()
	var args = OS.get_cmdline_user_args()
	if "--capture" in args:
		var index = args.find("--capture")
		if "--board-preview" in args:
			model.depart()
			render()
		if "--battle-preview" in args:
			model.depart()
			model.position = 2
			model.start_battle()
			render()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var error = get_viewport().get_texture().get_image().save_png(args[index+1])
		print("CAPTURE_RESULT ",error)
		get_tree().quit(error)

func label(text: String, size: int = 17) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size)
	return node

func add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func new_game() -> void:
	model = ExpeditionModel.new(data,int(Time.get_unix_time_from_system()*1000))
	save_error = ""
	render()

func confirm_new() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "현재 진행을 새 원정으로 바꿉니다. 계속하면 기존 자동 저장도 교체됩니다."
	dialog.title = "새 원정"
	dialog.confirmed.connect(func(): new_game(); persist())
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func load_game() -> void:
	var candidate = ExpeditionModel.new(data,1)
	if candidate.load_from(save_path):
		model = candidate
		save_error = ""
	else:
		save_error = "저장 파일을 읽을 수 없습니다. 현재 진행은 유지됩니다."
	render()

func persist() -> void:
	var error = model.save_to(save_path)
	save_error = "" if error == OK else "저장 실패: %s" % error_string(error)

func action(callback: Callable) -> void:
	if busy: return
	busy = true
	callback.call()
	persist()
	render()
	# One logical action per frame, so rapid duplicate inputs cannot double rewards.
	await get_tree().process_frame
	busy = false

func render() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	notice.text = "영혼 %d   ·   보유 %d   ·   편성 %d/4   ·   위치 %d/11   |   %s" % [model.souls,model.roster.size(),model.formation.size(),model.position,model.message]
	if not save_error.is_empty(): notice.text += "\n"+save_error
	match model.phase:
		"formation": render_formation()
		"board","event","ended": render_board()
		"battle","reward": render_battle()

func panel() -> PanelContainer:
	var node = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("142321")
	style.border_color = Color("56644b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	node.add_theme_stylebox_override("panel",style)
	return node

func render_formation() -> void:
	var row = HBoxContainer.new()
	content.add_child(row)
	var text = label("군단 편성 · 카드 선택 순서가 아니라 보유 목록 순서로 슬롯에 배치됩니다.",16)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	add_button(row,"편성 완료 · 출발",func(): action(model.depart)).disabled = model.formation.is_empty()
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	content.add_child(grid)
	for u in model.roster:
		card(grid,u,110,func(): action(func(): model.toggle(u.id)),u.id in model.formation)

func render_board() -> void:
	content.add_child(label("안개 숲 원정 · 시험 경로",23))
	content.add_child(label("첫 버전에서는 주요 사건을 통과할 때 멈춥니다. 전체 보드 규칙은 다음 이식 단계에서 연결합니다.",14))
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	content.add_child(grid)
	for i in range(ExpeditionModel.NODES.size()):
		var tile = panel()
		tile.custom_minimum_size = Vector2(175,80)
		grid.add_child(tile)
		var marker = "▶ " if i == model.position else "✓ " if i in model.completed else ""
		var text = label("%02d  %s\n%s" % [i,ExpeditionModel.NODES[i],marker+ ("네크로멘서" if i==model.position else "")],18)
		if i == model.position: text.add_theme_color_override("font_color",Color("c5dda3"))
		tile.add_child(text)
	var actions = HBoxContainer.new()
	content.add_child(actions)
	if model.phase == "board":
		add_button(actions,"주사위 굴리기",func(): action(model.roll_move))
		add_button(actions,"군단 재편성",func(): action(model.edit_formation))
	elif model.phase == "event":
		add_button(actions,"계약: 첫 편성 마물 최대 체력 +2",func(): action(func(): model.choose_event(true)))
		add_button(actions,"영혼 +3 받기",func(): action(func(): model.choose_event(false)))
	else:
		content.add_child(label(model.message,26))
		add_button(actions,"새 원정",confirm_new)
	content.add_child(label("현재 군단",19))
	var row = HBoxContainer.new()
	content.add_child(row)
	for u in model.selected(): card(row,u,70,func(): show_unit(u))

func render_battle() -> void:
	var bar = HBoxContainer.new()
	content.add_child(bar)
	var heading = label("%s · %d라운드" % ["보스 전투" if model.position==11 else "전투",model.battle.round_number],22)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(heading)
	if model.phase == "battle":
		add_button(bar,"주사위 · 다음 라운드",func(): action(model.battle_round))
	else:
		var r = model.reward
		add_button(bar,"영혼 수확 (주사위 %d 이상 · %d회)" % [r.threshold,r.attempts],func(): action(model.harvest)).disabled = r.done
		add_button(bar,"보상 종료 · 보드 복귀",func(): action(model.leave_reward))
	for team in ["enemy","ally"]:
		var names = []
		for kind in model.battle.legions[team].active:
			if model.battle.active(team,kind): names.append(LEGION_NAMES[kind])
		content.add_child(label("%s · 활성 군단: %s" % ["적 군단" if team=="enemy" else "내 군단",", ".join(names) if not names.is_empty() else "없음"],14))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		content.add_child(row)
		for slot in range(5):
			var candidates = model.battle.units.filter(func(u): return u.team==team and u.slot==slot)
			if not candidates.is_empty():
				var u = candidates.back()
				card(row,u,65,func(): show_unit(u))
			else:
				var empty = panel()
				empty.custom_minimum_size = Vector2(190,160)
				row.add_child(empty)
				empty.add_child(label("%d번 · %s" % [slot+1,"소환 대기" if slot==4 else "빈 슬롯"],16))
	var log_box = RichTextLabel.new()
	log_box.bbcode_enabled = false
	log_box.custom_minimum_size.y = 65
	log_box.fit_content = false
	log_box.scroll_following = true
	log_box.text = "\n".join(model.log_lines.slice(-12))
	content.add_child(log_box)

func card(parent: Node, u: Dictionary, image_height: int, callback: Callable, selected_card: bool = false) -> void:
	var container = panel()
	container.custom_minimum_size.x = 190
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.tooltip_text = "%s · 군단 %s · 패시브 %s" % [u.name,", ".join(u.legions.map(func(kind): return LEGION_NAMES[kind])),"없음" if u.passive.is_empty() else passive_data[u.passive][0]]
	if not u.get("alive",true): container.modulate = Color(0.48,0.48,0.48)
	parent.add_child(container)
	var box = VBoxContainer.new()
	container.add_child(box)
	var path = "res://assets/cards/unit-card-%s.png" % u.slug
	if ResourceLoader.exists(path):
		if not texture_cache.has(path): texture_cache[path] = load(path)
		var art = TextureRect.new()
		art.texture = texture_cache[path]
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size.y = image_height
		box.add_child(art)
	box.add_child(label(u.name + ("  ✓" if selected_card else ""),18))
	box.add_child(label("체력 %d/%d · 공격 %d · 속도 %d" % [u.get("hp",u.max_hp),u.max_hp,u.attack,u.speed],13))
	if u.has("frozen"):
		var status_text = "%s%s%s" % ["전사 " if not u.alive else "","빙결 " if u.frozen else "","중독 %d" % u.poison.size() if not u.poison.is_empty() else ""]
		if not status_text.is_empty(): box.add_child(label(status_text,12))
	add_button(box,"편성 해제" if selected_card else "편성 선택" if model.phase=="formation" else "상세 정보",callback)

func show_unit(u: Dictionary) -> void:
	var passive_text = "없음" if u.passive.is_empty() else passive_data[u.passive][0]+" · "+passive_data[u.passive][1]
	var text = "%s\n군단: %s\n패시브: %s\n" % [u.name,", ".join(u.legions.map(func(kind): return LEGION_NAMES[kind])),passive_text]
	for b in u.brands:
		text += "%s의 낙인 · 축복 %s / 저주 %s\n" % [BRAND_NAMES[b.type],str(b.bless),str(b.curse)]
	show_dialog(u.name,text)

func show_help() -> void:
	show_dialog("첫 버전 조작 안내","1. 마물 1~4마리 선택 후 출발\n2. 주사위로 이동하고 사건 선택\n3. 전투에서 버튼을 눌러 라운드 진행\n4. 승리 후 영입 주사위 → 보드 복귀\n\n행동 완료 시 자동 저장됩니다. 전투는 라운드 경계에서 이어집니다.\n전사한 원정 마물은 영구 손실됩니다. 전투 한정 보정은 종료 후 초기화됩니다.\n현재 경로·적 배치·사건 보상은 개발용 시험 구성입니다.")

func show_dialog(title_text: String, text: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title_text
	dialog.dialog_text = text
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(600,320))
