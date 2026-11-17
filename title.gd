extends Control

const MAP_SCENE := "res://map.tscn"
const INTRO_SCENE := "res://intro.tscn"
const BASE_SIZE := Vector2(1280.0, 720.0)
const AudioSettings = preload("res://systems/audio_settings.gd")
const DemoEndingScreen = preload("res://systems/demo_ending_screen.gd")
const FinalDragonProgress = preload("res://systems/final_dragon_progress.gd")
const TITLE_MUSIC := "res://assets/title/music/title-theme.mp3"
const MENU_FRAME = preload("res://assets/title/menu/button_new_game.webp")
const Confirmation = preload("res://systems/quit_confirmation.gd")
# 큰 패럴랙스 이동에도 빈 가장자리가 보이지 않도록 넉넉하게 확보.
# 1672x941 원화를 1520x860 정도로 축소 표시하므로 업스케일 없이 선명도를 유지한다.
const OVERSCAN := Vector2(120.0, 70.0)

@onready var sky_layer: TextureRect = $ParallaxArt/Sky
@onready var mountains_layer: TextureRect = $ParallaxArt/Mountains
@onready var fence_tree_layer: TextureRect = $ParallaxArt/FenceTree
@onready var ground_hand_layer: TextureRect = $ParallaxArt/GroundHand
@onready var graves_crows_layer: TextureRect = $ParallaxArt/GravesCrows
@onready var flying_crows_layer: Control = $ParallaxArt/FlyingCrows
@onready var logo_art: TextureRect = $TitleUI/LogoArt
@onready var new_run_button: Button = $TitleUI/MenuPanel/Menu/NewRun
@onready var continue_button: Button = $TitleUI/MenuPanel/Menu/Continue
@onready var exit_button: Button = $TitleUI/MenuPanel/Menu/Exit
@onready var options_button: Button = $TitleUI/MenuPanel/Menu/Options
@onready var options_dialog: AcceptDialog = $TitleUI/OptionsDialog
@onready var volume_slider: HSlider = $TitleUI/OptionsDialog/OptionsContent/Volume
@onready var music_enabled: CheckButton = $TitleUI/OptionsDialog/OptionsContent/MusicEnabled
@onready var sfx_enabled: CheckButton = $TitleUI/OptionsDialog/OptionsContent/SfxEnabled
@onready var language_picker: OptionButton = $TitleUI/OptionsDialog/OptionsContent/LanguageRow/Language
@onready var title_music: AudioStreamPlayer = $TitleBgm

var pointer_normalized := Vector2.ZERO
var touch_active := false
var pointer_seen := false
var idle_time := 0.0
# Mobile Web forbids autoplay until a real user press/touch/key event.
var web_audio_started: bool = false
var base_positions: Dictionary = {}
# Production uses the same ConfigFile as map and battlefield. A test may
# assign an isolated save path before adding this scene to the tree.
var audio_save_path: String = AudioSettings.SAVE
var demo_record: Control
var overwrite_dialog: ConfirmationDialog
var starting_new_run := false

func _ready() -> void:
	# Match the same persistent Music/SFX bus preferences used on map and battlefield.
	AudioSettings.apply_saved(audio_save_path)
	get_viewport().size_changed.connect(_layout_layers)
	new_run_button.pressed.connect(_start_new_run)
	continue_button.pressed.connect(_continue_run)
	exit_button.pressed.connect(_exit_game)
	options_button.pressed.connect(_show_options)
	_sync_audio_controls()
	get_node("/root/GameLanguage").setup_picker(language_picker)
	volume_slider.value_changed.connect(_update_volume)
	music_enabled.toggled.connect(_set_music_enabled)
	sfx_enabled.toggled.connect(_set_sfx_enabled)
	continue_button.disabled = not get_node("/root/RunSession").has_save()
	_load_menu_art()
	_layout_layers()
	_start_title_music()

func _input(event: InputEvent) -> void:
	# Do not request Web audio during _ready: the browser may still have a
	# suspended AudioContext. Start it from the FIRST genuine tap/click/key.
	if should_unlock_web_audio(OS.has_feature("web"), web_audio_started, event):
		web_audio_started = true
		if title_music.stream != null:
			title_music.play()
	if event is InputEventMouseMotion:
		pointer_seen = true
		_set_pointer(event.position)
	elif event is InputEventScreenTouch:
		touch_active = event.pressed
		if event.pressed:
			pointer_seen = true
			_set_pointer(event.position)
	elif event is InputEventScreenDrag:
		touch_active = true
		pointer_seen = true
		_set_pointer(event.position)

## Pure gate: browsers need one user action, native and repeat events
## must not restart music or block existing title navigation.
static func should_unlock_web_audio(web: bool, started: bool, event: InputEvent) -> bool:
	return web and not started and is_audio_unlock_gesture(event)

## Separate pure gesture detection so mouse, touch and keyboard paths are
## testable on non-Web headless CI without faking the audio browser driver.
static func is_audio_unlock_gesture(event: InputEvent) -> bool:
	if event is InputEventScreenTouch: return event.pressed
	if event is InputEventMouseButton: return event.pressed
	if event is InputEventKey: return event.pressed and not event.echo
	return false

func _process(delta: float) -> void:
	idle_time += delta
	var idle := Vector2(sin(idle_time * 0.24), cos(idle_time * 0.19))
	var pointer := pointer_normalized if pointer_seen or touch_active else Vector2.ZERO
	var smooth := 1.0 - exp(-delta * 5.5)

	# 사용자가 체감상 레이어가 확실히 떠 보이길 원해서 이전보다 깊이차를 크게 잡는다.
	_move_layer(sky_layer, pointer, idle, Vector2(8.0, 4.0), 1.5, smooth)
	_move_layer(mountains_layer, pointer, idle, Vector2(22.0, 11.0), 3.0, smooth)
	_move_layer(fence_tree_layer, pointer, idle, Vector2(40.0, 20.0), 4.5, smooth)
	_move_layer(ground_hand_layer, pointer, idle, Vector2(56.0, 28.0), 6.0, smooth)
	_move_layer(graves_crows_layer, pointer, idle, Vector2(72.0, 36.0), 7.5, smooth)

	# 공중 까마귀는 로고 양옆 여백 안에서 움직인다.
	var crow_idle := idle + Vector2(sin(idle_time * 0.41), cos(idle_time * 0.31)) * 0.8
	_move_layer(flying_crows_layer, pointer, crow_idle, Vector2(28.0, 14.0), 7.0, smooth)

func _set_pointer(position: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var center := viewport_size * 0.5
	pointer_normalized = Vector2(
		clampf((position.x - center.x) / center.x, -1.0, 1.0),
		clampf((position.y - center.y) / center.y, -1.0, 1.0)
	)

func _move_layer(
	layer: Control,
	pointer: Vector2,
	idle: Vector2,
	strength: Vector2,
	idle_weight: float,
	smooth: float
) -> void:
	var base: Vector2 = base_positions.get(layer, Vector2.ZERO)
	var target := base - pointer * strength + idle * idle_weight
	layer.position = layer.position.lerp(target, smooth)

func _layout_layers() -> void:
	var layer_size := BASE_SIZE + OVERSCAN * 2.0
	var base := -OVERSCAN
	for layer in [
		sky_layer,
		mountains_layer,
		fence_tree_layer,
		ground_hand_layer,
		graves_crows_layer,
		flying_crows_layer
	]:
		if not is_instance_valid(layer):
			continue
		layer.position = base
		layer.size = layer_size
		base_positions[layer] = base


func _load_menu_art() -> void:
	var logo_path := "res://assets/title/menu/title_logo.webp"
	if ResourceLoader.exists(logo_path):
		logo_art.texture = load(logo_path)
		logo_art.show()
		$TitleUI/Logo.hide()
		$TitleUI/LogoShadow.hide()
		$TitleUI/Subtitle.hide()
		$TitleUI/MenuPanel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if get_node("/root/RunSession").has_demo_record():
		continue_button.text = "원정 기록"
	var parchment := AtlasTexture.new()
	parchment.atlas = MENU_FRAME
	parchment.region = Rect2(250,116,37,128)
	parchment.filter_clip = true
	for button: Button in [new_run_button, continue_button, options_button, exit_button]:
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
			button.add_theme_color_override(state,Color.TRANSPARENT)
		var focus_style := StyleBoxFlat.new()
		focus_style.draw_center = false
		focus_style.border_color = Color("ffe6a0")
		focus_style.set_border_width_all(2)
		focus_style.set_corner_radius_all(7)
		button.add_theme_stylebox_override("focus",focus_style)
		var face := TextureRect.new()
		face.name = "MenuFrame"
		face.texture = MENU_FRAME
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(face)
		var patch := TextureRect.new()
		patch.texture = parchment
		patch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(patch)
		# Sample the unlettered parchment of the same painted button. Native
		# translated text fits inside it while the original skulls remain visible.
		patch.anchor_left = 0.258
		patch.anchor_top = 0.382
		patch.anchor_right = 0.750
		patch.anchor_bottom = 0.817
		var caption := Label.new()
		caption.text = button.text
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_override("font",preload("res://assets/fonts/nanum_gothic_bold.ttf"))
		caption.add_theme_font_size_override("font_size",17)
		caption.add_theme_color_override("font_color",Color("271b13"))
		caption.set_meta("ui_font_preserve",true)
		patch.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_layout_menu_button(button,face)
		face.modulate.a = 0.45 if button.disabled else 1.0
		button.resized.connect(_layout_menu_button.bind(button,face))
		button.mouse_entered.connect(_highlight_menu_button.bind(button, true))
		button.mouse_exited.connect(_highlight_menu_button.bind(button, false))
		button.button_down.connect(_wiggle_menu_button.bind(button))

func _layout_menu_button(button: Button, face: TextureRect) -> void:
	button.pivot_offset = button.size*0.5
	var art_size := MENU_FRAME.get_size()
	face.size = art_size * minf(button.size.x/art_size.x,button.size.y/art_size.y)
	face.position = (button.size-face.size)*0.5

func _highlight_menu_button(button: Button, highlight: bool) -> void:
	if button.disabled:
		return
	button.modulate = Color(1.12, 1.03, 0.82) if highlight else Color.WHITE
	if highlight:
		_wiggle_menu_button(button)

func _wiggle_menu_button(button: Button) -> void:
	if button.disabled or not is_instance_valid(button):
		return
	# Rotate in place around the button center; the VBox layout and TitleUI
	# never move. The cemetery parallax keeps reacting independently.
	if button.has_meta("wiggle_tween"):
		var previous: Variant = button.get_meta("wiggle_tween")
		if previous is Tween and previous.is_running():
			previous.kill()
	button.pivot_offset = button.size * 0.5
	button.rotation_degrees = 0.0
	var wiggle := create_tween()
	button.set_meta("wiggle_tween", wiggle)
	wiggle.tween_property(button, "rotation_degrees", -2.0, 0.055)
	wiggle.tween_property(button, "rotation_degrees", 1.6, 0.075)
	wiggle.tween_property(button, "rotation_degrees", -0.8, 0.070)
	wiggle.tween_property(button, "rotation_degrees", 0.0, 0.090)

func _sync_audio_controls() -> void:
	volume_slider.set_value_no_signal(0.0 if AudioServer.is_bus_mute(0) else db_to_linear(AudioServer.get_bus_volume_db(0)))
	music_enabled.set_pressed_no_signal(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	sfx_enabled.set_pressed_no_signal(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))

func _start_title_music() -> void:
	# Only local imported assets are allowed; never stream music from the old web repo.
	if not ResourceLoader.exists(TITLE_MUSIC):
		push_warning("Title BGM asset is missing: " + TITLE_MUSIC)
		return
	title_music.bus = "Music"
	title_music.stream = load(TITLE_MUSIC)
	title_music.volume_db = linear_to_db(0.34)
	title_music.finished.connect(title_music.play)
	# Native can play immediately. Browsers must wait until _input()
	# receives a real user activation; otherwise the first audio stream may
	# be blocked permanently on Android Chrome / mobile embedded browsers.
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		title_music.play()

func _show_options() -> void:
	_sync_audio_controls()
	options_dialog.popup_centered()

func _save_audio() -> void:
	var settings = AudioSettings.new()
	settings.save_settings("",audio_save_path)
	settings.free()

func _update_volume(value: float) -> void:
	AudioServer.set_bus_mute(0,value<=0)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value,0.001)))
	_save_audio()

func _set_music_enabled(enabled: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),not enabled)
	_save_audio()

func _set_sfx_enabled(enabled: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"),not enabled)
	_save_audio()

func _start_new_run() -> void:
	if starting_new_run: return
	if not get_node("/root/RunSession").has_save():
		_commit_new_run()
		return
	if not is_instance_valid(overwrite_dialog):
		overwrite_dialog = ConfirmationDialog.new()
		overwrite_dialog.name = "OverwriteExpedition"
		overwrite_dialog.title = "기존 원정을 덮어쓸까요?"
		overwrite_dialog.ok_button_text = "새로 시작"
		overwrite_dialog.cancel_button_text = "취소"
		overwrite_dialog.dialog_autowrap = true
		overwrite_dialog.unresizable = true
		overwrite_dialog.borderless = true
		overwrite_dialog.transparent_bg = true
		overwrite_dialog.transient = true
		overwrite_dialog.exclusive = true
		add_child(overwrite_dialog)
		Confirmation.style_parchment_confirmation(overwrite_dialog)
		overwrite_dialog.confirmed.connect(_commit_new_run)
		overwrite_dialog.canceled.connect(new_run_button.grab_focus)
	overwrite_dialog.dialog_text = tr("기존 원정을 덮어쓸까요?") + "\n\n" + tr("새 원정을 시작하면 저장된 진행과 원정 기록이 사라집니다.")
	overwrite_dialog.popup_centered(Vector2i(640,320))
	overwrite_dialog.get_cancel_button().grab_focus()
	overwrite_dialog.get_cancel_button().grab_focus.call_deferred()

func _commit_new_run() -> void:
	if starting_new_run: return
	starting_new_run = true
	var session := get_node("/root/RunSession")
	if not session.start_new_world():
		starting_new_run = false
		_show_save_error(session.notice)
		return
	get_tree().change_scene_to_file(INTRO_SCENE)

func handle_cancel() -> bool:
	if starting_new_run: return true
	if is_instance_valid(overwrite_dialog) and overwrite_dialog.visible:
		overwrite_dialog.hide()
		new_run_button.grab_focus()
	elif options_dialog.visible:
		options_dialog.hide()
		options_button.grab_focus()
	elif is_instance_valid(demo_record):
		demo_record.title_requested.emit()
	else:
		_show_options()
	return true

func _continue_run() -> void:
	var session := get_node("/root/RunSession")
	if not session.has_save():
		continue_button.disabled = true
		var frame := continue_button.get_node_or_null("MenuFrame") as TextureRect
		if is_instance_valid(frame): frame.modulate.a = 0.45
		return
	if not session.reload_world():
		_show_save_error(session.notice)
		return
	if session.demo_mode and session.event_flag_is_set(FinalDragonProgress.DEMO_ENDING_ACK):
		if not is_instance_valid(demo_record):
			demo_record = DemoEndingScreen.new()
			$TitleUI.add_child(demo_record)
			$TitleUI/MenuPanel.hide()
			demo_record.show_demo_ending(session.world, true)
			demo_record.title_requested.connect(func():
				demo_record.queue_free()
				demo_record = null
				$TitleUI/MenuPanel.show()
				continue_button.grab_focus())
		return
	get_tree().change_scene_to_file(MAP_SCENE)

func _show_save_error(message: String) -> void:
	var dialog := get_node_or_null("SaveErrorDialog") as AcceptDialog
	if dialog == null:
		dialog = AcceptDialog.new()
		dialog.name = "SaveErrorDialog"
		dialog.title = tr("저장 오류")
		dialog.ok_button_text = tr("확인")
		dialog.add_theme_font_override("font", preload("res://assets/fonts/nanum_gothic_regular.ttf"))
		add_child(dialog)
	dialog.dialog_text = tr(message if not message.is_empty() else "저장에 실패했습니다.")
	dialog.popup_centered()

func _exit_game() -> void:
	get_node("/root/QuitConfirmation").request_quit()
