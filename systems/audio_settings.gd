extends Control

const SAVE = "user://audio_settings.cfg"
static var output_devices: PackedStringArray

static func outputs(refresh: bool = false) -> PackedStringArray:
	if refresh or output_devices.is_empty():
		output_devices = AudioServer.get_output_device_list()
	return output_devices

var panel: PanelContainer
var output_selector: OptionButton

static func ensure_buses() -> void:
	for name in ["Music","SFX"]:
		if AudioServer.get_bus_index(name)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,name)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")

static func apply_saved() -> void:
	ensure_buses()
	var preferences = ConfigFile.new()
	preferences.load(SAVE)
	for name in ["Music","SFX"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(name),not bool(preferences.get_value("audio",name.to_lower()+"_enabled",true)))
	if DisplayServer.get_name()=="headless": return
	var settings = ConfigFile.new()
	settings.load(SAVE)
	var desired: String = settings.get_value("audio","output","Default")
	var devices = outputs()
	var chosen = "Default"
	for device in devices:
		if device==desired or (desired=="Realtek" and "realtek" in device.to_lower()):
			chosen = device
			break
	# Re-selecting the same WASAPI device can stall each battle transition.
	if AudioServer.output_device != chosen: AudioServer.output_device = chosen
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,float(settings.get_value("audio","volume",1.0)))))
	AudioServer.set_bus_mute(0,float(settings.get_value("audio","volume",1.0))<=0)
	print("Game audio requested: ",AudioServer.get_driver_name()," / ",chosen)

func setup(parent: Control) -> void:
	parent.add_child(self)
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	var button = Button.new()
	button.text = "오디오"
	button.position = Vector2(896,18)
	button.size = Vector2(82,32)
	button.pressed.connect(func():
		panel.visible = not panel.visible
		if panel.visible:
			var devices = outputs(true)
			output_selector.clear()
			for device in devices: output_selector.add_item(device)
			output_selector.select(maxi(0,devices.find(AudioServer.output_device))))
	add_child(button)
	panel = PanelContainer.new()
	panel.position = Vector2(790,60)
	panel.size = Vector2(450,170)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("241b2e")
	style.border_color = Color("b49a6d")
	style.set_border_width_all(1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	var title = Label.new()
	title.text = "소리 출력 장치"
	column.add_child(title)
	var output = OptionButton.new()
	output_selector = output
	var devices = outputs()
	for device in devices: output.add_item(device)
	output.select(maxi(0,devices.find(AudioServer.output_device)))
	column.add_child(output)
	output.item_selected.connect(func(index):
		var current = outputs()
		if index<0 or index>=current.size(): return
		AudioServer.output_device = current[index]
		save_settings(current[index]))
	var label = Label.new()
	label.text = "전체 음량"
	column.add_child(label)
	var volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = 0 if AudioServer.is_bus_mute(0) else db_to_linear(AudioServer.get_bus_volume_db(0))*100
	column.add_child(volume)
	volume.value_changed.connect(func(value):
		AudioServer.set_bus_mute(0,value<=0)
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,value/100)))
		save_settings())
	var categories = HBoxContainer.new()
	column.add_child(categories)
	for category in ["Music","SFX"]:
		var toggle = CheckButton.new()
		toggle.text = "배경음악" if category=="Music" else "효과음"
		toggle.button_pressed = not AudioServer.is_bus_mute(AudioServer.get_bus_index(category))
		categories.add_child(toggle)
		toggle.toggled.connect(func(enabled: bool):
			AudioServer.set_bus_mute(AudioServer.get_bus_index(category),not enabled)
			save_settings())
	panel.hide()

func save_settings(output_name: String = "") -> void:
	var settings = ConfigFile.new()
	settings.load(SAVE)
	settings.set_value("audio","output",AudioServer.output_device if output_name.is_empty() else output_name)
	settings.set_value("audio","volume",0.0 if AudioServer.is_bus_mute(0) else db_to_linear(AudioServer.get_bus_volume_db(0)))
	for category in ["Music","SFX"]:
		settings.set_value("audio",category.to_lower()+"_enabled",not AudioServer.is_bus_mute(AudioServer.get_bus_index(category)))
	settings.save(SAVE)

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		output_selector.select(maxi(0,outputs().find(AudioServer.output_device)))
		print("Game audio active: ",AudioServer.output_device)