extends Node
## Own one active UI scope and route the four keyboard controls to real UI actions.
const Indicator = preload("res://systems/keyboard_focus_indicator.gd")
const Sound = preload("res://systems/game_audio.gd")
const DIRECTIONS = {KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN}
var keyboard_mode := false
var scope: Node
var controls: Array[Control] = []
var target: Control
var scene: Node
var window: Window
var indicator_layer: CanvasLayer
var indicator: Control
var remembered: Dictionary = {}
var last_focus_key := ""
var last_move_msec := 0
var pointer_sync_pending := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_indicator()
	get_tree().root.gui_focus_changed.connect(_focus_changed)
	get_tree().root.window_input.connect(_window_input)

func _create_indicator() -> void:
	if is_instance_valid(indicator): return
	indicator_layer = CanvasLayer.new()
	indicator_layer.name = "KeyboardFocusLayer"
	indicator_layer.layer = 2040
	add_child(indicator_layer)
	indicator = Indicator.new()
	indicator.name = "KeyboardFocusIndicator"
	indicator_layer.add_child(indicator)

func _process(_delta: float) -> void:
	refresh()
	if Window.get_focused_window() is PopupMenu:
		indicator.clear()
		return
	if is_instance_valid(indicator):
		if _available(target) and keyboard_mode:
			indicator.follow(target,_description(target))
		else:
			indicator.clear()

func active_scene() -> Node:
	if is_instance_valid(get_tree().current_scene): return get_tree().current_scene
	var children := get_tree().root.get_children()
	children.reverse()
	for child in children:
		if child is Control and child != indicator: return child
	return null

func refresh() -> void:
	_create_indicator()
	scene = active_scene()
	var focused_window := Window.get_focused_window()
	if focused_window == null: focused_window = get_tree().root
	# PopupMenu owns item navigation and its own acceptance/cancel contract.
	if focused_window is PopupMenu:
		indicator.clear()
		return
	window = focused_window
	var next_scope: Node
	if window != get_tree().root and window.visible:
		next_scope = window
	if next_scope == null and is_instance_valid(scene):
		if scene.has_method("keyboard_focus_scope"):
			next_scope = scene.keyboard_focus_scope()
		elif scene is Control:
			next_scope = scene
	var provider_scope: Node = next_scope
	if window==get_tree().root and is_instance_valid(scene):
		for candidate in get_tree().get_nodes_in_group("keyboard_modal_scope"):
			if candidate.is_visible_in_tree() and scene.is_ancestor_of(candidate): next_scope=candidate
	if is_instance_valid(next_scope):
		next_scope = _nested_scope(next_scope)
	if next_scope != scope:
		if is_instance_valid(scope) and is_instance_valid(target):
			remembered[scope.get_instance_id()] = {"control":weakref(target),"key":last_focus_key}
		scope = next_scope
		target = null
		last_focus_key = ""
		_prune_memory()
	controls.clear()
	if not is_instance_valid(scope): return
	if scope==provider_scope and is_instance_valid(scene) and scene.has_method("keyboard_focus_controls"):
		for control in scene.keyboard_focus_controls():
			if _available(control): controls.append(control)
	if controls.is_empty(): _gather(scope,controls)
	# Stage-space reward cards can sit outside their battlefield panel.
	if scope.has_meta("keyboard_external_controls"):
		for control in scope.get_meta("keyboard_external_controls"):
			if _available(control) and not control in controls: controls.append(control)
	for node in get_tree().get_nodes_in_group("keyboard_external_control"):
		if _belongs(node,scope) and _available(node) and not node in controls: controls.append(node)
	for control in controls:
		var parent := control.get_parent()
		while parent != null and not parent is Window:
			if parent is ScrollContainer: parent.follow_focus = true
			parent = parent.get_parent()
		if control is BaseButton and not control is OptionButton and not control.get_meta("keyboard_focus_styled",false):
			control.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
			control.set_meta("keyboard_focus_styled",true)
	var focused := window.gui_get_focus_owner()
	if focused in controls:
		target = focused
	elif not _available(target) or not target in controls:
		target = _initial_target()
		if keyboard_mode and is_instance_valid(target): target.grab_focus()
	if is_instance_valid(target):
		last_focus_key = str(target.get_meta("keyboard_focus_key",""))
		# Keep the ordinary indicator owned by this service through scene cleanup.
		var destination: Node = self if target.get_window()==get_tree().root else target.get_window()
		if destination != indicator_layer.get_parent():
			indicator_layer.reparent(destination)

func _nested_scope(base: Node) -> Node:
	var result := base
	for i in range(8):
		if result.has_method("keyboard_focus_scope"):
			var next: Control = result.keyboard_focus_scope()
			if is_instance_valid(next) and next != result:
				result = next
				continue
		var marked: Control
		var nodes := result.find_children("*","Control",true,false)
		for n in range(nodes.size()-1,-1,-1):
			var candidate := nodes[n] as Control
			if candidate.is_visible_in_tree() and bool(candidate.get_meta("keyboard_focus_scope",false)):
				marked = candidate
				break
		if marked == null: break
		result = marked
	return result

func _belongs(control: Variant, owner: Variant) -> bool:
	if not is_instance_valid(control) or not is_instance_valid(owner): return false
	var external: Variant = control.get_meta("keyboard_focus_owner",null)
	if external != null: return is_instance_valid(external) and external == owner
	return control == owner or owner.is_ancestor_of(control)

func _available(control: Variant) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree() or control.focus_mode==Control.FOCUS_NONE: return false
	if control is BaseButton and control.disabled: return false
	return control.size.x>0.0 and control.size.y>0.0 and control.get_window().visible

func _gather(root: Node, result: Array[Control]) -> void:
	if root is Control and _available(root):
		var full_backdrop: bool = root is Button and root.flat and root.text.is_empty() and root.size.x>=1000 and root.size.y>=500
		if not full_backdrop or bool(root.get_meta("keyboard_focus_default",false)):
			result.append(root)
	for child in root.get_children():
		if child is Window: continue
		_gather(child,result)

func _initial_target() -> Control:
	if controls.is_empty(): return null
	if not last_focus_key.is_empty():
		for control in controls:
			if str(control.get_meta("keyboard_focus_key","")) == last_focus_key: return control
	if is_instance_valid(scope) and remembered.has(scope.get_instance_id()):
		var memory: Dictionary = remembered[scope.get_instance_id()]
		var previous: Control = memory.control.get_ref()
		if previous in controls: return previous
		if not str(memory.key).is_empty():
			for control in controls:
				if str(control.get_meta("keyboard_focus_key",""))==str(memory.key): return control
	for control in controls:
		if bool(control.get_meta("keyboard_focus_default",false)): return control
	return controls[0]

func _prune_memory() -> void:
	for id in remembered.keys():
		if not is_instance_id_valid(id): remembered.erase(id)

func _use_keyboard() -> void:
	keyboard_mode = true
	pointer_sync_pending = false

func _window_input(event: InputEvent) -> void:
	# Esc is routed by QuitConfirmation before normal viewport input.
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE):
		_use_keyboard()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.relative.length_squared()<4.0: return
		keyboard_mode = false
		refresh()
		if not pointer_sync_pending:
			pointer_sync_pending = true
			_sync_pointer.call_deferred()
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		keyboard_mode = false
		# Native clicking owns focus and may open a different modal immediately.
		pointer_sync_pending = false
		refresh()
		return
	if not event is InputEventKey or event.alt_pressed or event.ctrl_pressed or event.meta_pressed: return
	var key: int = event.keycode if event.keycode!=KEY_NONE else event.physical_keycode
	if key not in DIRECTIONS and key not in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]: return
	refresh()
	if Window.get_focused_window() is PopupMenu:
		if event.pressed: _use_keyboard()
		return
	var edit := window.gui_get_focus_owner() if is_instance_valid(window) else null
	if edit is LineEdit or edit is TextEdit:
		if event.pressed: _use_keyboard()
		return
	if edit is Range and key in [KEY_LEFT,KEY_RIGHT]:
		if event.pressed: _use_keyboard()
		return
	if edit is OptionButton and key in [KEY_ENTER,KEY_KP_ENTER]:
		if event.pressed: _use_keyboard()
		if event.echo: get_viewport().set_input_as_handled()
		return
	if not is_instance_valid(scope): return
	# Intro retains its original narration handler and has no focusable actions.
	if controls.is_empty() and not scope.has_method("keyboard_accept"): return
	get_viewport().set_input_as_handled()
	if not event.pressed: return
	if key in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE] and event.echo: return
	if pointer_sync_pending and not keyboard_mode: _sync_pointer()
	_use_keyboard()
	if _available(target): target.grab_focus()
	if key in DIRECTIONS:
		if event.echo and Time.get_ticks_msec()-last_move_msec<130: return
		last_move_msec = Time.get_ticks_msec()
		move_focus(DIRECTIONS[key])
	elif key==KEY_SPACE:
		if _available(target) and target in controls:
			var secondary: Callable = target.get_meta("keyboard_secondary_action",Callable())
			if secondary.is_valid():
				secondary.call()
				return
		if is_instance_valid(scene) and scene.has_method("keyboard_roll_dice"): scene.keyboard_roll_dice()
	else:
		activate()

func move_focus(direction: Vector2) -> void:
	refresh()
	if controls.is_empty(): return
	var next: Control = neighbor(target,direction) if is_instance_valid(target) else _initial_target()
	if next != null: choose_focus(next)

func neighbor(origin_control: Control, direction: Vector2) -> Control:
	var property := "focus_neighbor_"
	property += ("left" if direction.x<0 else "right") if direction.x!=0 else ("top" if direction.y<0 else "bottom")
	var explicit_path: NodePath = origin_control.get(property)
	if not explicit_path.is_empty():
		var explicit := origin_control.get_node_or_null(explicit_path) as Control
		if explicit in controls: return explicit
	var origin := _center(origin_control)
	var result: Control
	var best := INF
	for candidate in controls:
		if candidate == origin_control: continue
		var offset := _center(candidate)-origin
		var forward := offset.dot(direction)
		if forward<=3.0: continue
		var perpendicular := absf(offset.cross(direction))
		var score := forward+perpendicular*3.0+offset.length()*0.20
		if score<best:
			best = score
			result = candidate
	return result

func choose_focus(control: Control, with_sound: bool = true) -> void:
	if not _available(control): return
	var changed := target != control
	target = control
	last_focus_key = str(control.get_meta("keyboard_focus_key",""))
	control.grab_focus()
	if changed and with_sound: Sound.cue(self,"ui_select")

func activate() -> void:
	refresh()
	if not is_instance_valid(scope): return
	if scope.has_method("keyboard_accept") and scope.keyboard_accept(): return
	if not _available(target): return
	if target is BaseButton:
		target.button_down.emit()
		if target.toggle_mode: target.button_pressed = not target.button_pressed
		target.button_up.emit()
		target.pressed.emit()

func _sync_pointer() -> void:
	if not pointer_sync_pending: return
	pointer_sync_pending = false
	if keyboard_mode: return
	refresh()
	if Window.get_focused_window() is PopupMenu or not is_instance_valid(window): return
	for candidate in controls:
		var drag := candidate.get_node_or_null("DiceCardDrag")
		if drag != null and drag.pointer!=-2: return
	# Read the native hit target after GUI delivery; card hands keep their
	# sibling order aligned with depth, while the engine handles clipping and transforms.
	var pointed: Control = window.gui_get_hovered_control()
	while is_instance_valid(pointed):
		if pointed in controls:
			choose_focus(pointed,false)
			return
		pointed = pointed.get_parent() as Control
	if is_instance_valid(target): target.release_focus()
	# Retain the last valid target so a keyboard press resumes there.
	indicator.clear()

func _center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5)

func _focus_changed(control: Control) -> void:
	if control in controls:
		target = control
		last_focus_key = str(control.get_meta("keyboard_focus_key",""))

func _description(control: Control) -> String:
	if control.has_meta("keyboard_action_hint"): return tr(str(control.get_meta("keyboard_action_hint")))
	var name: String = str(control.get_meta("keyboard_description",""))
	if name.is_empty() and control is Button: name = control.text
	if name.is_empty(): name = control.tooltip_text.split("\n")[0]
	if control is Range: return tr("← → 조절 · ↑ ↓ 이동")
	if control is LineEdit: return tr("Enter · 이름 저장")
	if control.has_node("DiceCardDrag"): return "" # The hand already shows its common Enter/drag guide.
	if name.is_empty(): name = tr("선택")
	return "Enter · "+tr(name)

func _exit_tree() -> void:
	if is_instance_valid(indicator): indicator.clear()
	if is_instance_valid(indicator_layer): indicator_layer.queue_free()
