class_name PanelEffectsModule
extends Control
## Attach to a modal Control. Visual feedback only; no persistent state.
@export_range(0.05,0.5,0.01) var open_duration: float = 0.20
@export_range(0.05,0.5,0.01) var close_duration: float = 0.12
@export_range(0.0,16.0,1.0) var travel: float = 6.0
var _panel: Control
var _tween: Tween
var _base_color: Color
var _positions: Dictionary = {}
var _colors: Dictionary = {}
var closing := false

static func attach(panel: Control) -> PanelEffectsModule:
	var existing = panel.get_node_or_null("PanelEffectsModule")
	if existing is PanelEffectsModule: return existing
	var effect = PanelEffectsModule.new()
	effect.name = "PanelEffectsModule"
	panel.add_child(effect)
	return effect

static func pin_background(panel: Control, artwork: Control, frame: Control) -> void:
	panel.set_meta("ui_fixed_background",true)
	artwork.set_meta("ui_fixed_background",true)
	frame.set_meta("ui_fixed_background",true)
	var effect:=attach(panel)
	# setup() runs before the deferred open, so the replacement painting
	# never renders the zero alpha initially used by the generic effect.
	panel.modulate=effect._base_color

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = get_parent() as Control
	if _panel == null:
		push_warning("PanelEffectsModule requires a Control parent.")
		return
	_base_color = _panel.modulate
	_panel.modulate.a = 0.0
	call_deferred("_open")

func _open() -> void:
	if closing or not is_instance_valid(_panel): return
	_reset_tween()
	var fixed_background:bool=bool(_panel.get_meta("ui_fixed_background",false))
	for child in _panel.get_children():
		if child == self or not child is Control or child.has_meta("ui_backdrop") or bool(child.get_meta("ui_custom_open_motion",false)) or bool(child.get_meta("ui_fixed_background",false)): continue
		_positions[child] = child.position
		child.position.y += travel
		_tween.tween_property(child,"position",_positions[child],open_duration)
		if fixed_background:
			_colors[child]=child.modulate
			child.modulate.a=0.0
			_tween.tween_property(child,"modulate",_colors[child],open_duration)
	if not fixed_background: _tween.tween_property(_panel,"modulate",_base_color,open_duration)

func play_close(done: Callable) -> void:
	if closing or not is_instance_valid(_panel): return
	closing = true
	_reset_tween()
	# Block both mouse/touch and keyboard activation while the panel dismisses.
	_disable_buttons(_panel)
	var blocker = Control.new()
	blocker.size = _panel.size
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.z_index = 4096
	_panel.add_child(blocker)
	for child in _positions:
		if is_instance_valid(child) and child.get_parent() == _panel:
			_tween.tween_property(child,"position",_positions[child]+Vector2(0,travel*0.5),close_duration)
	if bool(_panel.get_meta("ui_fixed_background",false)):
		for child in _colors:
			if is_instance_valid(child) and child.get_parent()==_panel:
				_tween.tween_property(child,"modulate:a",0.0,close_duration)
	else:
		_tween.tween_property(_panel,"modulate:a",0.0,close_duration)
	_tween.chain().tween_callback(func(): if done.is_valid(): done.call())

func _disable_buttons(node: Node) -> void:
	if node is BaseButton: node.disabled = true
	for child in node.get_children(): _disable_buttons(child)

func _reset_tween() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _exit_tree() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	if not is_instance_valid(_panel): return
	_panel.modulate = _base_color
	for child in _positions:
		if is_instance_valid(child): child.position = _positions[child]
	for child in _colors:
		if is_instance_valid(child): child.modulate = _colors[child]
