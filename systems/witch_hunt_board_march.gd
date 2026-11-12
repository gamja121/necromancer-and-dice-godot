extends Control
## Board presentation for the live riot and the older saved arson introduction.

const CROWD_PAWN = preload("res://assets/map/hero/witch_hunt_villager_pawns.png")
const DIE_FACES := [
	preload("res://assets/battle/dice/result-01.png"),
	preload("res://assets/battle/dice/result-02.png"),
	preload("res://assets/battle/dice/result-03.png"),
]
const STEP_SECONDS := 0.39
var pawn: TextureRect
var die: TextureRect


func setup(pawn_size: Vector2, foot: Vector2, face: int = 0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_pawn(pawn_size, foot)
	die = TextureRect.new()
	die.name = "VillagerCrowdDie"
	die.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	die.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	die.mouse_filter = Control.MOUSE_FILTER_IGNORE
	die.size = Vector2(26, 26)
	die.position = Vector2((pawn_size.x - die.size.x) * 0.5, -22)
	pawn.add_child(die)
	_show_face(maxi(1, face))


func _create_pawn(pawn_size: Vector2, foot: Vector2) -> void:
	pawn = TextureRect.new()
	pawn.name = "VillagerCrowdPawn"
	pawn.texture = CROWD_PAWN
	pawn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pawn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pawn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pawn.size = pawn_size
	pawn.position = foot - pawn_size * Vector2(0.5, 1.0)
	add_child(pawn)


func play_turn(face: int, route: PackedVector2Array) -> void:
	var motion := create_tween()
	for cycle in range(8):
		motion.tween_callback(_show_face.bind(cycle % 3 + 1))
		motion.tween_interval(0.065)
	motion.tween_callback(_show_face.bind(face))
	motion.tween_interval(0.22)
	_append_steps(motion, route)
	await motion.finished


func play(route: PackedVector2Array, pawn_size: Vector2) -> void:
	_create_pawn(pawn_size, route[0])
	pawn.modulate.a = 0.0
	var motion := create_tween()
	motion.tween_property(pawn, "modulate:a", 1.0, 0.16)
	motion.tween_interval(0.18)
	_append_steps(motion, route)
	motion.tween_interval(0.45)
	await motion.finished


func _append_steps(motion: Tween, route: PackedVector2Array) -> void:
	for step in range(1, route.size()):
		motion.tween_method(_hop.bind(route[step - 1], route[step]), 0.0, 1.0, STEP_SECONDS)


func _show_face(face: int) -> void:
	die.texture = DIE_FACES[face - 1]


func _hop(weight: float, start: Vector2, finish: Vector2) -> void:
	var foot := start.lerp(finish, weight)
	foot.y -= sin(weight * PI) * 10.0
	pawn.position = foot - pawn.size * Vector2(0.5, 1.0)
