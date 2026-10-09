extends Control

const BASE_SIZE := Vector2(1280.0, 720.0)
const OVERSCAN := Vector2(48.0, 28.0)

@onready var background_layer: TextureRect = $ParallaxArt/Background
@onready var board_layer: TextureRect = $ParallaxArt/Board
@onready var foreground_layer: TextureRect = $ParallaxArt/Foreground

var pointer_normalized := Vector2.ZERO
var touch_active := false
var pointer_seen := false
var idle_time := 0.0
var base_positions: Dictionary = {}

func _ready() -> void:
	get_viewport().size_changed.connect(_layout_layers)
	_layout_layers()

func _input(event: InputEvent) -> void:
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

func _process(delta: float) -> void:
	idle_time += delta
	var idle := Vector2(sin(idle_time * 0.23), cos(idle_time * 0.19)) * 0.55
	var pointer := pointer_normalized if pointer_seen or touch_active else Vector2.ZERO
	var smooth := 1.0 - exp(-delta * 5.2)

	_move_layer(background_layer, pointer, idle, Vector2(4.0, 2.5), 0.30, smooth)
	_move_layer(board_layer, pointer, idle, Vector2(11.0, 6.0), 0.62, smooth)
	_move_layer(foreground_layer, pointer, idle, Vector2(20.0, 11.0), 1.00, smooth)

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
	for layer in [background_layer, board_layer, foreground_layer]:
		if not is_instance_valid(layer):
			continue
		layer.position = base
		layer.size = layer_size
		base_positions[layer] = base
