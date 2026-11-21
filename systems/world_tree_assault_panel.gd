extends "res://systems/main_story_book.gd"
## The book displays the saved assault; RunSession commits all choices.

signal choice_requested(choice: String, card_instance_id: String)
signal continue_requested

const TREE_ART = preload("res://assets/map/events/world-tree.jpg")
const CUT_ART = preload("res://assets/map/events/world-tree-assault-cut.jpg")
const BURN_ART = preload("res://assets/map/events/world-tree-assault-burn.jpg")
const WorldTreeArt = preload("res://systems/world_tree_art.gd")

var _error: Label
var _cards: OptionButton
var _safe: Button
var _buttons: Array[Button] = []
var _submitting := false
var _card_id := ""

func setup(record: Dictionary, dice_cards: Array, safe_cost: int) -> void:
	set_heading("세계수 습격")
	copy("세계수 습격",Rect2(702,156,444,48),29)
	_error = copy("",Rect2(702,527,432,48),16,RED_INK)
	if record.phase == "result":
		_show_result(record)
	else:
		_show_choices(record.attack,dice_cards,safe_cost)

func _show_choices(attack: String, dice_cards: Array, safe_cost: int) -> void:
	var attack_art: Texture2D = CUT_ART if attack == "cut" else BURN_ART
	add_source_image(attack_art.resource_path,SOURCE_ART,attack_art).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var warning := "도끼를 든 광신도들이 세계수로 향한다.\n세계수가 쓰러지면 겨울이 찾아온다." if attack == "cut" else "광신도들이 세계수에 불을 놓으려 한다.\n불길이 뿌리에 닿으면 이 땅은 지옥이 된다."
	copy(warning,Rect2(702,213,434,106),21)
	_safe = _action("확실하게 저지","AssaultSafe",316,func(): _request_choice("safe"))
	copy("카드 1장 소모 · 오염도 +%d" % safe_cost,Rect2(735,355,390,36),16,RED_INK)
	_action("위험하게 저지","AssaultRisk",394,func(): _request_choice("risk"))
	copy("카드 소모 없음 · 4~6 성공 (50%)",Rect2(735,433,390,34),16,RED_INK)
	_action("개입하지 않는다","AssaultIgnore",469,func(): _request_choice("ignore"))
	_add_card_picker(dice_cards)
	_sync_controls()

func _add_card_picker(dice_cards: Array) -> void:
	copy("확실한 저지에 쓸 카드",Rect2(178,473,360,26),16,RED_INK)
	_cards = OptionButton.new()
	_cards.name = "AssaultCardPicker"
	_cards.position = Vector2(178,505)
	_cards.size = Vector2(360,42)
	_cards.focus_mode = Control.FOCUS_ALL
	_cards.add_theme_font_override("font",FONT)
	_cards.add_theme_font_size_override("font_size",17)
	_cards.add_theme_color_override("font_color",INK)
	_cards.add_theme_color_override("font_hover_color",RED_INK)
	_cards.add_theme_color_override("font_focus_color",RED_INK)
	_cards.add_theme_color_override("font_disabled_color",Color("775b3d"))
	var field := StyleBoxFlat.new()
	field.bg_color = Color("ead8b4")
	field.border_color = Color("987854")
	field.set_border_width_all(1)
	field.content_margin_left = 10
	_cards.add_theme_stylebox_override("normal",field)
	_cards.add_theme_stylebox_override("disabled",field)
	var focus := field.duplicate() as StyleBoxFlat
	focus.bg_color = Color("f6e8c6")
	focus.border_color = RED_INK
	for state in ["hover","focus","pressed"]:
		_cards.add_theme_stylebox_override(state,focus)
	var menu := _cards.get_popup()
	menu.add_theme_stylebox_override("panel",field)
	menu.add_theme_stylebox_override("hover",focus)
	menu.add_theme_font_override("font",FONT)
	menu.add_theme_color_override("font_color",INK)
	menu.add_theme_color_override("font_hover_color",RED_INK)
	menu.add_theme_color_override("font_disabled_color",Color("927552"))
	_cards.add_item("카드 고르기" if not dice_cards.is_empty() else "보유한 카드 없음")
	_cards.set_item_disabled(0,true)
	for card: Dictionary in dice_cards:
		_cards.add_item(str(card.get("label","주사위 제어 카드")))
		_cards.set_item_metadata(_cards.item_count-1,str(card.id))
	_cards.select(0)
	add_child(_cards)
	_cards.item_selected.connect(func(index: int):
		_card_id = str(_cards.get_item_metadata(index)) if index > 0 else ""
		_sync_controls())

func _show_result(record: Dictionary) -> void:
	var region: String = record.region
	var ruins: Texture2D = WorldTreeArt.ruins(region)
	var outcome_art: Texture2D = ruins if ruins != null else TREE_ART
	var result := "광신도들을 물리쳤다. 세계수는 살아남았고 원정은 계속된다."
	if region == "winter":
		result = "세계수가 쓰러졌다.\n눈보라가 원정지를 뒤덮는다."
	elif region == "hell":
		result = "세계수가 불탔다.\n불길이 원정지 전역으로 번진다."
	var painting := add_source_image(outcome_art.resource_path,SOURCE_ART,outcome_art)
	if ruins != null: painting.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	copy(result,Rect2(702,213,434,95),21)
	if record.choice == "safe":
		copy("카드 1장 소모 · 오염도 +%d" % int(record.corruption_cost),Rect2(702,322,432,44),18,RED_INK)
	elif record.choice == "risk":
		var face := int(record.face)
		var die := TextureRect.new()
		die.texture = load("res://assets/battle/dice/result-%02d.png" % face)
		die.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		die.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		die.mouse_filter = Control.MOUSE_FILTER_IGNORE
		die.position = Vector2(702,309)
		die.size = Vector2(56,56)
		add_child(die)
		copy("주사위 %d · 저지 성공" % face if region == "default" else "주사위 %d · 저지 실패" % face,
			Rect2(771,326,358,42),20,RED_INK)
	_action("원정 계속","AssaultContinue",457,func():
		if _submitting: return
		_submitting = true
		_sync_controls()
		continue_requested.emit())

func _action(label: String, node_name: String, y: float, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	style_action(button,Rect2(700,y,438,40),22)
	add_child(button)
	button.pressed.connect(action)
	_buttons.append(button)
	return button

func _request_choice(choice: String) -> void:
	if _submitting or (choice == "safe" and _card_id.is_empty()): return
	_submitting = true
	_sync_controls()
	choice_requested.emit(choice,_card_id if choice == "safe" else "")

func _sync_controls() -> void:
	for button in _buttons:
		button.disabled = _submitting or (button == _safe and _card_id.is_empty())
	if is_instance_valid(_cards): _cards.disabled = _submitting or _cards.item_count <= 1

func show_error(reason: String) -> void:
	_error.text = reason
	_submitting = false
	_sync_controls()