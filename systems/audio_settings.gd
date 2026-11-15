extends Control

## Map settings popover with shared audio preferences.
## Always use the OS default output; Advanced retains only master volume.
const SAVE = "user://audio_settings.cfg"
# The popup sits BELOW the map's gear rather than covering the gear's
# own touch rectangle; the same icon can therefore close it again.
const PANEL_RECT = Rect2(912.0, 268.0, 296.0, 0.0)

var save_file_path: String = SAVE
var panel: PanelContainer
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
	row.custom_minimum_size.y = 38
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
	toggle.custom_minimum_size = Vector2(114, 36)
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


func setup(parent: Control) -> void:
	ensure_buses()
	parent.add_child(self)
	size = Vector2(1280,720)
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

	panel = PanelContainer.new()
	panel.name = "MapAudioOptionsPanel"
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.custom_minimum_size.x = PANEL_RECT.size.x
	panel.z_index = 40
	var style := surface(Color("241c16"), Color("a37e52"), 8)
	style.set_border_width_all(2)
	style.shadow_color = Color("150e0ace")
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 19
	style.content_margin_right = 19
	style.content_margin_top = 14
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.name = "AudioOptionsContent"
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.name = "MapAudioOptionsHeader"
	header.custom_minimum_size.y = 36
	column.add_child(header)
	var title := settings_label("설정", 23, Color("f5deaf"))
	title.name = "AudioOptionsTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.name = "MapAudioOptionsClose"
	close_button.text = "×"
	close_button.tooltip_text = "닫기"
	close_button.custom_minimum_size = Vector2(36,36)
	style_action(close_button, 21)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)
	separator(column)

	var language_row := add_row(column, "언어", "LanguageRow")
	language_picker = OptionButton.new()
	language_picker.name = "LanguagePicker"
	language_picker.custom_minimum_size = Vector2(114,36)
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
	advanced_button.text = "고급 설정 ▾"
	advanced_button.custom_minimum_size.y = 34
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
	panel.hide()
	refresh_controls()


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
	if blocked and is_instance_valid(panel): panel.hide()
	if is_instance_valid(options_button): options_button.disabled = blocked
	visible = not blocked

func toggle_panel() -> void:
	if modal_blocked or not visible: return
	if panel.visible:
		close_panel()
	else:
		refresh_controls()
		panel.show()

func close_panel() -> void:
	panel.hide()
	options_button.grab_focus()


func toggle_advanced() -> void:
	advanced_content.visible = not advanced_content.visible
	advanced_button.text = "고급 설정 ▴" if advanced_content.visible else "고급 설정 ▾"
	panel.reset_size()


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
