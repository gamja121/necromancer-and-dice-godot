extends Control

const PaintedAction = preload("res://systems/painted_action.gd")

## Centered map settings with shared audio preferences.
signal open_changed(opened: bool)
## Always use the OS default output; Advanced retains only master volume.
const SAVE = "user://audio_settings.cfg"
const PANEL_WIDTH := 526.0

var save_file_path: String = SAVE
var panel: PanelContainer
var dimmer: ColorRect
var resume_button: Button
var quit_button: Button
var can_open: Callable
var modal_blocked: bool = false
var options_button: Button
var close_button: Button
var music_toggle: Button
var sfx_toggle: Button
var advanced_button: Button
var advanced_content: VBoxContainer
var output_label: Label
var language_picker: OptionButton
var volume_slider: HSlider
var volume_value: Label

## Godot's "Default" device tracks the host OS's preferred speakers/headset.
## Browsers route Web audio themselves; headless CI has no physical output.
static func use_system_default_output() -> void:
	if DisplayServer.get_name() in ["headless","web"]:
		return
	if AudioServer.output_device != "Default":
		AudioServer.output_device = "Default"

static func ensure_buses() -> void:
	# Godot 4.7.x web/Sample regression: AudioServer.add_bus() forwards
	# an append index of -1 to JS Bus.addAt(), which may disconnect the
	# Master bus from the actual browser audio destination. Result: entire
	# web game is silent even though players report playing=true.
	# Growing bus_count directly avoids the broken Web addAt(-1) route.
	# Ref: godotengine/godot#119026 (4.7.2 web confirmed).
	for name in ["Music","SFX"]:
		if AudioServer.get_bus_index(name) < 0:
			var new_index: int = AudioServer.bus_count
			AudioServer.bus_count = new_index + 1
			AudioServer.set_bus_name(new_index,name)
			AudioServer.set_bus_send(new_index,"Master")

static func apply_saved(save_path: String = SAVE) -> void:
	ensure_buses()
	var settings = ConfigFile.new()
	settings.load(save_path)
	for name in ["Music","SFX"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(name),not bool(settings.get_value("audio",name.to_lower()+"_enabled",true)))
	var volume: float = clampf(float(settings.get_value("audio","volume",1.0)),0.0,1.0)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,volume)))
	AudioServer.set_bus_mute(0,volume<=0)
	# Ignore any machine-specific audio.output left in existing user saves.
	# "Default" follows the host system's current preferred output device.
	use_system_default_output()

func surface(fill: Color, edge: Color, radius: int = 4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box

func style_action(node: Button, font_size: int = 15) -> void:
	var idle := surface(Color("31251c"), Color("665039"))
	idle.content_margin_left = 12
	idle.content_margin_right = 12
	idle.content_margin_top = 4
	idle.content_margin_bottom = 4
	var hover: StyleBoxFlat = idle.duplicate()
	hover.bg_color = Color("443321")
	hover.border_color = Color("a88958")
	var pressed: StyleBoxFlat = idle.duplicate()
	pressed.bg_color = Color("514028")
	pressed.border_color = Color("c09a62")
	var focus := surface(Color.TRANSPARENT, Color("eac690"))
	focus.draw_center = false
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("normal", idle)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("hover_pressed", pressed)
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_color_override("font_color", Color("e6d4b5"))
	node.add_theme_color_override("font_hover_color", Color("ffebc7"))
	node.add_theme_color_override("font_pressed_color", Color("ffe6ac"))
	node.add_theme_color_override("font_hover_pressed_color", Color("ffe6ac"))
	node.add_theme_font_size_override("font_size", font_size)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func settings_label(copy: String, points: int, color: Color = Color("e6d4b5")) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", points)
	return label

func add_row(column: VBoxContainer, label_text: String, row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.custom_minimum_size.y = 46
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var caption := settings_label(label_text, 16)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	return row

func add_toggle_row(column: VBoxContainer, label_text: String, category: String) -> Button:
	var row := add_row(column, label_text, category + "AudioRow")
	var toggle := Button.new()
	toggle.name = category + "AudioToggle"
	toggle.set_meta("keyboard_description",label_text)
	toggle.custom_minimum_size = Vector2(168, 42)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.toggle_mode = true
	style_action(toggle)
	toggle.pressed.connect(func(): toggle_category(category))
	row.add_child(toggle)
	return toggle

func separator(parent: VBoxContainer) -> void:
	var rule := HSeparator.new()
	var ink := StyleBoxLine.new()
	ink.color = Color("6b553e")
	ink.thickness = 1
	rule.add_theme_stylebox_override("separator", ink)
	parent.add_child(rule)


func setup(parent: Control, opening_allowed: Callable = Callable()) -> void:
	can_open = opening_allowed
	ensure_buses()
	parent.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90

	# Keep this as the first child: the map owns its exact original image.
	options_button = Button.new()
	options_button.name = "MapOptionsButton"
	options_button.text = "오디오"
	options_button.position = Vector2(896,18)
	options_button.size = Vector2(82,32)
	options_button.pressed.connect(toggle_panel)
	add_child(options_button)

	dimmer = ColorRect.new()
	dimmer.name = "MapSettingsDimmer"
	dimmer.color = Color("100c09bd")
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.z_index = 42
	add_child(dimmer)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.hide()

	panel = PanelContainer.new()
	panel.name = "MapAudioOptionsPanel"
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.z_index = 43
	var style := surface(Color("241c16"), Color("a37e52"), 9)
	style.set_border_width_all(2)
	style.shadow_color = Color("150e0ace")
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 22
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.resized.connect(center_panel)
	resized.connect(center_panel)

	var column := VBoxContainer.new()
	column.name = "AudioOptionsContent"
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.name = "MapAudioOptionsHeader"
	header.custom_minimum_size.y = 44
	column.add_child(header)
	var title := settings_label("설정", 29, Color("f5deaf"))
	title.name = "AudioOptionsTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.name = "MapAudioOptionsClose"
	close_button.text = "×"
	close_button.tooltip_text = "닫기"
	close_button.custom_minimum_size = Vector2(44,42)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_action(close_button, 22)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)
	separator(column)

	var language_row := add_row(column, "언어", "LanguageRow")
	language_picker = OptionButton.new()
	language_picker.name = "LanguagePicker"
	language_picker.custom_minimum_size = Vector2(168,42)
	language_picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	language_picker.add_theme_constant_override("arrow_margin", 10)
	style_action(language_picker)
	language_row.add_child(language_picker)
	get_node("/root/GameLanguage").setup_picker(language_picker)
	var language_menu := language_picker.get_popup()
	var menu_style: StyleBoxFlat = style.duplicate()
	menu_style.set_content_margin_all(6)
	menu_style.shadow_size = 3
	language_menu.add_theme_stylebox_override("panel", menu_style)
	language_menu.add_theme_stylebox_override("hover", surface(Color("443321"), Color("a88958")))
	language_menu.add_theme_color_override("font_color", Color("e6d4b5"))
	language_menu.add_theme_color_override("font_hover_color", Color("ffebc7"))
	language_menu.add_theme_font_override("font", preload("res://assets/fonts/NanumSquareRoundR.ttf"))
	language_menu.add_theme_font_size_override("font_size", 15)
	language_menu.add_theme_constant_override("v_separation", 10)

	music_toggle = add_toggle_row(column, "배경음악", "Music")
	sfx_toggle = add_toggle_row(column, "효과음", "SFX")

	separator(column)
	advanced_button = Button.new()
	advanced_button.name = "MapAudioAdvancedButton"
	advanced_button.text = "고급 설정 ▼"
	advanced_button.custom_minimum_size.y = 38
	advanced_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	advanced_button.pressed.connect(toggle_advanced)
	column.add_child(advanced_button)
	style_action(advanced_button, 14)

	advanced_content = VBoxContainer.new()
	advanced_content.name = "MapAudioAdvancedContent"
	advanced_content.add_theme_constant_override("separation", 7)
	advanced_content.hide()
	column.add_child(advanced_content)
	var volume_row := HBoxContainer.new()
	advanced_content.add_child(volume_row)
	var volume_label := settings_label("전체 음량", 15)
	volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_row.add_child(volume_label)
	volume_value = settings_label("100%", 15, Color("efc889"))
	volume_value.name = "MapAudioVolumeValue"
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_row.add_child(volume_value)

	volume_slider = HSlider.new()
	volume_slider.focus_mode = Control.FOCUS_ALL
	volume_slider.name = "MapAudioMasterVolume"
	volume_slider.custom_minimum_size.y = 24
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 1
	var track := surface(Color("37291e"), Color("73583c"))
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := surface(Color("b88d51"), Color("d7ac71"))
	volume_slider.add_theme_stylebox_override("slider", track)
	volume_slider.add_theme_stylebox_override("grabber_area", fill)
	volume_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	advanced_content.add_child(volume_slider)
	volume_slider.value_changed.connect(func(value: float):
		AudioServer.set_bus_mute(0, value <= 0)
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, value / 100.0)))
		volume_value.text = "%d%%" % roundi(value)
		save_settings())

	output_label = settings_label("출력: 시스템 기본 장치 (자동)", 13, Color("b9a588"))
	output_label.name = "MapAudioSystemDefaultOutput"
	advanced_content.add_child(output_label)
	separator(column)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	quit_button = footer_action(footer, "MapSettingsQuit", "그만하기", false)
	quit_button.pressed.connect(request_quit)
	resume_button = footer_action(footer, "MapSettingsResume", "이어서 하기", true)
	resume_button.pressed.connect(close_panel)
	update_focus_order()
	panel.reset_size()
	center_panel()
	panel.hide()
	refresh_controls()

func footer_action(footer: HBoxContainer, node_name: String, label_text: String, primary: bool) -> Button:
	var action := Button.new()
	action.name = node_name
	action.text = label_text
	action.custom_minimum_size = Vector2(192, 48)
	PaintedAction.style(action, 2 if primary else 4, 17)
	footer.add_child(action)
	return action

func center_panel() -> void:
	if is_instance_valid(panel):
		panel.position = ((size - panel.size) * 0.5).round()

func update_focus_order() -> void:
	var controls: Array[Control] = [close_button, language_picker, music_toggle, sfx_toggle, advanced_button]
	if advanced_content.visible: controls.append(volume_slider)
	controls.append_array([quit_button, resume_button])
	for i in range(controls.size()):
		var control := controls[i]
		control.focus_previous = control.get_path_to(controls[posmod(i - 1, controls.size())])
		control.focus_next = control.get_path_to(controls[(i + 1) % controls.size()])
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_bottom = control.focus_next
		control.focus_neighbor_left = NodePath(".")
		control.focus_neighbor_right = NodePath(".")
	quit_button.focus_neighbor_right = quit_button.get_path_to(resume_button)
	resume_button.focus_neighbor_left = resume_button.get_path_to(quit_button)

func is_open() -> bool:
	return is_instance_valid(panel) and panel.visible

func request_quit() -> void:
	get_node("/root/QuitConfirmation").request_quit()


func refresh_controls() -> void:
	for item in [{"node":music_toggle,"category":"Music"},{"node":sfx_toggle,"category":"SFX"}]:
		var toggle: Button = item.node
		if toggle==null: continue
		var enabled: bool = not AudioServer.is_bus_mute(AudioServer.get_bus_index(str(item.category)))
		toggle.text = "ON" if enabled else "OFF"
		toggle.set_pressed_no_signal(enabled)
	if volume_slider!=null:
		volume_slider.set_value_no_signal(0 if AudioServer.is_bus_mute(0) else db_to_linear(AudioServer.get_bus_volume_db(0))*100.0)
		volume_value.text = "%d%%" % roundi(volume_slider.value)

# The frozen map CSS hides both the option icon and open popup while a
# location/story overlay owns the board. Do not change audio buses or the
# user's persistent config merely because a modal opens.
func set_modal_blocked(blocked: bool) -> void:
	if modal_blocked == blocked: return
	modal_blocked = blocked
	if blocked and is_open():
		panel.hide()
		dimmer.hide()
	if is_instance_valid(options_button): options_button.disabled = blocked
	visible = not blocked

func toggle_panel() -> void:
	if modal_blocked or not visible: return
	if is_open():
		close_panel()
		return
	if can_open.is_valid() and not can_open.call(): return
	refresh_controls()
	# Input follows sibling order. The map shares the die above other overlays.
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	dimmer.show()
	panel.show()
	panel.set_meta("keyboard_focus_scope",true)
	resume_button.set_meta("keyboard_focus_default",true)
	resume_button.grab_focus()
	open_changed.emit(true)

func close_panel() -> void:
	panel.hide()
	dimmer.hide()
	options_button.grab_focus()
	open_changed.emit(false)


func toggle_advanced() -> void:
	advanced_content.visible = not advanced_content.visible
	advanced_button.text = "고급 설정 ▲" if advanced_content.visible else "고급 설정 ▼"
	panel.reset_size()
	update_focus_order()


func toggle_category(category: String) -> void:
	if not category in ["Music","SFX"]: return
	var bus = AudioServer.get_bus_index(category)
	AudioServer.set_bus_mute(bus,not AudioServer.is_bus_mute(bus))
	save_settings()
	refresh_controls()

func save_settings(_legacy_output_name: String = "", save_path: String = "") -> void:
	var target = save_file_path if save_path.is_empty() else save_path
	var settings = ConfigFile.new()
	settings.load(target)
	# Migrate old per-PC output values away on the next settings save.
	if settings.has_section_key("audio","output"):
		settings.erase_section_key("audio","output")
	use_system_default_output()
	settings.set_value("audio","volume",0.0 if AudioServer.is_bus_mute(0) else db_to_linear(AudioServer.get_bus_volume_db(0)))
	for category in ["Music","SFX"]:
		settings.set_value("audio",category.to_lower()+"_enabled",not AudioServer.is_bus_mute(AudioServer.get_bus_index(category)))
	settings.save(target)
