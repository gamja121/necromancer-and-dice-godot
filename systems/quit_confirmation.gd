extends Node
## Global presentation only: no save, reward, RNG or gameplay rule changes.
signal quit_requested
const PROMPT="게임을 종료할까요?\n마지막 자동 저장 지점부터 이어할 수 있습니다."
const PAPER_PATH="res://assets/map/ui/quit_confirmation_parchment.png"
const BUTTON_PAPER_PATH="res://assets/map/ui/parchment_button_variant_04.png"
var dialog:ConfirmationDialog
var shade:CanvasLayer
var opened:bool=false
var quitting:bool=false
var previous_pause:bool=false
var previous_time_scale:float=1.0
var previous_window:WeakRef
var previous_focus:WeakRef
var input_suppressed:bool=false
var previous_input_disabled:bool=false
var pending_toggle:bool=false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().root.window_input.connect(_window_input)
	_build()

func _build() -> void:
	shade=CanvasLayer.new()
	shade.name="QuitDimmer"
	shade.layer=1024
	shade.visible=false
	add_child(shade)
	var dim:=ColorRect.new()
	dim.color=Color("030201c4")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter=Control.MOUSE_FILTER_STOP
	shade.add_child(dim)
	dialog=ConfirmationDialog.new()
	dialog.name="QuitDialog"
	dialog.visible=false
	dialog.borderless=true
	dialog.transparent=true
	dialog.transparent_bg=true
	dialog.unresizable=true
	dialog.transient=true
	dialog.transient_to_focused=false
	dialog.process_mode=Node.PROCESS_MODE_ALWAYS
	dialog.exclusive=true
	dialog.dialog_autowrap=true
	dialog.dialog_hide_on_ok=false
	dialog.title="종료"
	dialog.dialog_text=PROMPT
	dialog.ok_button_text="종료"
	dialog.cancel_button_text="계속"
	var paper:=StyleBoxTexture.new()
	paper.texture=load(PAPER_PATH)
	for side in [SIDE_LEFT,SIDE_RIGHT]:
		paper.set_texture_margin(side,0)
		paper.set_content_margin(side,48)
	for side in [SIDE_TOP,SIDE_BOTTOM]:
		paper.set_texture_margin(side,0)
		paper.set_content_margin(side,50)
	dialog.add_theme_stylebox_override("panel",paper)
	add_child(dialog)
	var label:Label=dialog.get_label()
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",22)
	label.add_theme_color_override("font_color",Color("3f2818"))
	label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	for button in [dialog.get_cancel_button(),dialog.get_ok_button()]:
		button.custom_minimum_size=Vector2(178,48)
		button.add_theme_font_size_override("font_size",18)
		button.add_theme_color_override("font_color",Color("3f2818"))
		button.add_theme_color_override("font_hover_color",Color("5c351c"))
		button.add_theme_color_override("font_focus_color",Color("3f2818"))
		button.add_theme_color_override("font_pressed_color",Color("3f2818"))
		var style:=StyleBoxTexture.new()
		style.texture=load(BUTTON_PAPER_PATH)
		for side in [SIDE_LEFT,SIDE_RIGHT]: style.set_content_margin(side,64)
		for side in [SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,12)
		for state in ["normal","hover","pressed","disabled"]: button.add_theme_stylebox_override(state,style)
		button.set_meta("sfx_manual",true)
	var focus:=StyleBoxFlat.new()
	focus.draw_center=false
	focus.border_color=Color("916b3c")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	dialog.get_cancel_button().add_theme_stylebox_override("focus",focus)
	dialog.get_ok_button().add_theme_stylebox_override("focus",focus)
	dialog.canceled.connect(cancel_quit)
	dialog.confirmed.connect(confirm_quit)

func _window_input(event:InputEvent) -> void:
	if not event is InputEventKey: return
	if event.keycode!=KEY_ESCAPE and event.physical_keycode!=KEY_ESCAPE: return
	# This signal precedes Window.push_input(), which resets handled state.
	# Block this event before it reaches an embedded menu or active card drag.
	if not input_suppressed:
		previous_input_disabled=get_tree().root.gui_disable_input
		get_tree().root.gui_disable_input=true
		input_suppressed=true
		_finish_escape.call_deferred()
	if event.pressed and not event.echo: pending_toggle=true

func _finish_escape() -> void:
	get_tree().root.gui_disable_input=previous_input_disabled
	input_suppressed=false
	var toggle:bool=pending_toggle
	pending_toggle=false
	if toggle:
		if opened: cancel_quit()
		else: request_quit()

func request_quit() -> void:
	if opened or quitting: return
	var focused:Window=Window.get_focused_window()
	if focused==null: focused=get_tree().root
	previous_window=weakref(focused)
	var control:Control=focused.gui_get_focus_owner()
	previous_focus=weakref(control) if control!=null else null
	# An existing exclusive settings/popup Window must own the confirmation.
	# Embedded subwindows do not use transient_to_focused ownership.
	dialog.reparent(focused)
	# A release swallowed by the confirmation must never leave a stale drag.
	_cancel_drags(get_tree().root)
	previous_pause=get_tree().paused
	previous_time_scale=Engine.time_scale
	opened=true
	get_tree().paused=true
	# Existing SceneTreeTimers run while paused; freeze their scaled time too.
	Engine.time_scale=0.0
	shade.visible=true
	dialog.popup_centered(Vector2i(640,320))
	dialog.get_cancel_button().grab_focus()

func _cancel_drags(node:Node) -> void:
	var script:Script=node.get_script() as Script
	if script!=null and script.resource_path=="res://systems/drag_card_module.gd" and node.pointer!=-2:
		node.cancel()
	for child in node.get_children(): _cancel_drags(child)

func cancel_quit() -> void:
	if not opened or quitting: return
	dialog.hide()
	dialog.reparent(self)
	shade.visible=false
	opened=false
	Engine.time_scale=previous_time_scale
	get_tree().paused=previous_pause
	var window:Window=previous_window.get_ref() as Window if previous_window!=null else null
	if is_instance_valid(window) and window.visible: window.grab_focus()
	var control:Control=previous_focus.get_ref() as Control if previous_focus!=null else null
	if is_instance_valid(control) and control.is_visible_in_tree(): control.grab_focus()
	previous_focus=null
	previous_window=null

func confirm_quit() -> void:
	if not opened or quitting: return
	quitting=true
	quit_requested.emit()
	get_tree().quit()

func _exit_tree() -> void:
	if input_suppressed and is_instance_valid(get_tree().root): get_tree().root.gui_disable_input=previous_input_disabled
	if opened:
		Engine.time_scale=previous_time_scale
		get_tree().paused=previous_pause
