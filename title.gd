extends Control

const MAP_SCENE := "res://map.tscn"
const BASE_SIZE := Vector2(1280.0, 720.0)
# 큰 패럴랙스 이동에도 빈 가장자리가 보이지 않도록 넉넉하게 확보.
# 1672x941 원화를 1520x860 정도로 축소 표시하므로 업스케일 없이 선명도를 유지한다.
const OVERSCAN := Vector2(120.0, 70.0)

@onready var sky_layer: TextureRect = $ParallaxArt/Sky
@onready var mountains_layer: TextureRect = $ParallaxArt/Mountains
@onready var fence_tree_layer: TextureRect = $ParallaxArt/FenceTree
@onready var ground_hand_layer: TextureRect = $ParallaxArt/GroundHand
@onready var graves_crows_layer: TextureRect = $ParallaxArt/GravesCrows
@onready var flying_crows_layer: Control = $ParallaxArt/FlyingCrows
@onready var new_run_button: Button = $TitleUI/MenuPanel/Menu/NewRun
@onready var continue_button: Button = $TitleUI/MenuPanel/Menu/Continue
@onready var exit_button: Button = $TitleUI/MenuPanel/Menu/Exit

var pointer_normalized := Vector2.ZERO
var touch_active := false
var pointer_seen := false
var idle_time := 0.0
var base_positions: Dictionary = {}

func _ready() -> void:
	get_viewport().size_changed.connect(_layout_layers)
	new_run_button.pressed.connect(_start_new_run)
	continue_button.pressed.connect(_continue_run)
	exit_button.pressed.connect(_exit_game)
	continue_button.disabled = not RunSession.has_save()
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
	var idle := Vector2(sin(idle_time * 0.24), cos(idle_time * 0.19))
	var pointer := pointer_normalized if pointer_seen or touch_active else Vector2.ZERO
	var smooth := 1.0 - exp(-delta * 5.5)

	# 사용자가 체감상 레이어가 확실히 떠 보이길 원해서 이전보다 깊이차를 크게 잡는다.
	_move_layer(sky_layer, pointer, idle, Vector2(8.0, 4.0), 1.5, smooth)
	_move_layer(mountains_layer, pointer, idle, Vector2(22.0, 11.0), 3.0, smooth)
	_move_layer(fence_tree_layer, pointer, idle, Vector2(40.0, 20.0), 4.5, smooth)
	_move_layer(ground_hand_layer, pointer, idle, Vector2(56.0, 28.0), 6.0, smooth)
	_move_layer(graves_crows_layer, pointer, idle, Vector2(72.0, 36.0), 7.5, smooth)

	# 공중 까마귀는 두 마리만 작게 유지하고, 배경보다 조금 크게 반응시킨다.
	var crow_idle := idle + Vector2(sin(idle_time * 0.41), cos(idle_time * 0.31)) * 0.8
	_move_layer(flying_crows_layer, pointer, crow_idle, Vector2(76.0, 36.0), 7.0, smooth)

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

func _start_new_run() -> void:
	RunSession.start_new_world()
	get_tree().change_scene_to_file(MAP_SCENE)

func _continue_run() -> void:
	if not RunSession.has_save():
		continue_button.disabled = true
		return
	RunSession.reload_world()
	get_tree().change_scene_to_file(MAP_SCENE)

func _exit_game() -> void:
	get_tree().quit()
