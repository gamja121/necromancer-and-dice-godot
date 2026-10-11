extends Control

## Frozen web map audio options: compact OPTION panel and separate ON/OFF rows.
## Godot-only output-device and master-volume controls remain under Advanced.
const SAVE = "user://audio_settings.cfg"
const PANEL_RECT = Rect2(995.84, 82.8, 256.0, 170.0)
static var output_devices: PackedStringArray

var save_file_path: String = SAVE
var panel: PanelContainer
var options_button: Button
var close_button: Button
var music_toggle: Button
var sfx_toggle: Button
var advanced_button: Button
var advanced_content: VBoxContainer
var output_selector: OptionButton
var volume_slider: HSlider

static func outputs(refresh: bool = false) -> PackedStringArray:
	if refresh or output_devices.is_empty():
		output_devices = AudioServer.get_output_device_list()
	return output_devices

static func ensure_buses() -> void:
	for name in ["Music","SFX"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,name)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")

static func apply_saved(save_path: String = SAVE) -> void:
	ensure_buses()
	var settings = ConfigFile.new()
	settings.load(save_path)
	for name in ["Music","SFX"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(name),not bool(settings.get_value("audio",name.to_lower()+"_enabled",true)))
	var volume: float = clampf(float(settings.get_value("audio","volume",1.0)),0.0,1.0)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,volume)))
	AudioServer.set_bus_mute(0,volume<=0)
	if DisplayServer.get_name()=="headless": return
	var desired: String = settings.get_value("audio","output","Default")
	var devices = outputs()
	var chosen = "Default"
	for device in devices:
		if device==desired or (desired=="Realtek" and "realtek" in device.to_lower()):
			chosen = device
			break
	if AudioServer.output_device != chosen: AudioServer.output_device = chosen
	print("Game audio requested: ",AudioServer.get_driver_name()," / ",chosen)

func style_action(node: Button, compact: bool = false) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("35261a")
	normal.border_color = Color("866943")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	var highlight = normal.duplicate()
	highlight.bg_color = Color("4d3523")
	for state in ["normal","disabled"]:
		node.add_theme_stylebox_override(state,normal)
	for state in ["hover","pressed","focus"]:
		node.add_theme_stylebox_override(state,highlight)
	node.add_theme_color_override("font_color",Color("f0ddb9"))
	node.add_theme_color_override("font_hover_color",Color("f6e8c8"))
	node.add_theme_font_size_override("font_size",12 if compact else 13)

func add_toggle_row(column: VBoxContainer, label_text: String, category: String) -> Button:
	var row = HBoxContainer.new()
	row.name = category+"AudioRow"
	row.custom_minimum_size = Vector2(0,38)
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	var caption = Label.new()
	caption.text = label_text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_color_override("font_color",Color("ead9bb"))
	caption.add_theme_font_size_override("font_size",13)
	row.add_child(caption)
	var toggle = Button.new()
	toggle.name = category+"AudioToggle"
	toggle.custom_minimum_size = Vector2(54,30)
	toggle.pressed.connect(func(): toggle_category(category))
	row.add_child(toggle)
	style_action(toggle)
	return toggle

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
	panel.custom_minimum_size = Vector2(PANEL_RECT.size.x,0)
	panel.z_index = 40
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10,0.075,0.055,0.98)
	style.border_color = Color("786048")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	style.shadow_color = Color(0,0,0,0.60)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)

	var column = VBoxContainer.new()
	column.name = "AudioOptionsContent"
	column.add_theme_constant_override("separation",5)
	panel.add_child(column)
	var header = HBoxContainer.new()
	header.name = "MapAudioOptionsHeader"
	header.custom_minimum_size = Vector2(0,28)
	column.add_child(header)
	var title = Label.new()
	title.text = "OPTION"
	title.name = "AudioOptionsTitle"
	title.add_theme_color_override("font_color",Color("cbb68f"))
	title.add_theme_font_size_override("font_size",13)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.name = "MapAudioOptionsClose"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(28,28)
	close_button.pressed.connect(func(): panel.hide())
	header.add_child(close_button)
	style_action(close_button,true)
	var rule = HSeparator.new()
	column.add_child(rule)
	music_toggle = add_toggle_row(column,"배경음악","Music")
	sfx_toggle = add_toggle_row(column,"효과음","SFX")

	# Keep the extended native features without overwhelming the source
	# two-toggle panel; they are intentionally absent from the frozen web.
	advanced_button = Button.new()
	advanced_button.name = "MapAudioAdvancedButton"
	advanced_button.text = "고급 설정 ▾"
	advanced_button.custom_minimum_size = Vector2(0,30)
	advanced_button.pressed.connect(toggle_advanced)
	column.add_child(advanced_button)
	style_action(advanced_button,true)
	advanced_content = VBoxContainer.new()
	advanced_content.name = "MapAudioAdvancedContent"
	advanced_content.add_theme_constant_override("separation",5)
	advanced_content.visible = false
	column.add_child(advanced_content)
	var output_label = Label.new()
	output_label.text = "소리 출력 장치"
	output_label.add_theme_font_size_override("font_size",12)
	advanced_content.add_child(output_label)
	output_selector = OptionButton.new()
	output_selector.name = "MapAudioOutputDevice"
	advanced_content.add_child(output_selector)
	output_selector.item_selected.connect(func(index):
		var current = outputs()
		if index<0 or index>=current.size(): return
		AudioServer.output_device = current[index]
		save_settings(current[index]))
	var volume_label = Label.new()
	volume_label.text = "전체 음량"
	volume_label.add_theme_font_size_override("font_size",12)
	advanced_content.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.name = "MapAudioMasterVolume"
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 1
	advanced_content.add_child(volume_slider)
	volume_slider.value_changed.connect(func(value):
		AudioServer.set_bus_mute(0,value<=0)
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,value/100.0)))
		save_settings())
	panel.hide()
	refresh_controls()

func refresh_controls() -> void:
	for item in [{"node":music_toggle,"category":"Music"},{"node":sfx_toggle,"category":"SFX"}]:
		var toggle: Button = item.node
		if toggle==null: continue
		var enabled: bool = not AudioServer.is_bus_mute(AudioServer.get_bus_index(str(item.category)))
		toggle.text = "ON" if enabled else "OFF"
		toggle.modulate = Color.WHITE if enabled else Color(0.62,0.60,0.56,0.68)
	if volume_slider!=null:
		volume_slider.set_value_no_signal(0 if AudioServer.is_bus_mute(0) else db_to_linear(AudioServer.get_bus_volume_db(0))*100.0)

func toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		refresh_controls()
		if advanced_content.visible: refresh_output_devices()

func toggle_advanced() -> void:
	advanced_content.visible = not advanced_content.visible
	advanced_button.text = "고급 설정 ▴" if advanced_content.visible else "고급 설정 ▾"
	if advanced_content.visible: refresh_output_devices()

func refresh_output_devices() -> void:
	var devices = outputs(true)
	output_selector.clear()
	if devices.is_empty():
		output_selector.add_item("Default")
		output_selector.select(0)
		return
	for device in devices: output_selector.add_item(device)
	output_selector.select(maxi(0,devices.find(AudioServer.output_device)))

func toggle_category(category: String) -> void:
	if not category in ["Music","SFX"]: return
	var bus = AudioServer.get_bus_index(category)
	AudioServer.set_bus_mute(bus,not AudioServer.is_bus_mute(bus))
	save_settings()
	refresh_controls()

func save_settings(output_name: String = "", save_path: String = "") -> void:
	var target = save_file_path if save_path.is_empty() else save_path
	var settings = ConfigFile.new()
	settings.load(target)
	settings.set_value("audio","output",AudioServer.output_device if output_name.is_empty() else output_name)
	settings.set_value("audio","volume",0.0 if AudioServer.is_bus_mute(0) else db_to_linear(AudioServer.get_bus_volume_db(0)))
	for category in ["Music","SFX"]:
		settings.set_value("audio",category.to_lower()+"_enabled",not AudioServer.is_bus_mute(AudioServer.get_bus_index(category)))
	settings.save(target)

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless" and output_selector!=null and advanced_content.visible:
		output_selector.select(maxi(0,outputs().find(AudioServer.output_device)))
		print("Game audio active: ",AudioServer.output_device)
