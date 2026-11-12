extends Control
## A board-only lead-in to the saved first page of the home arson event.

const CROWD_PAWN = preload("res://assets/map/hero/witch_hunt_villager_pawns.png")
const STEP_SECONDS := 0.39


func play(route: PackedVector2Array, pawn_size: Vector2) -> void:
	var pawn := TextureRect.new()
	pawn.name = "VillagerCrowdPawn"
	pawn.texture = CROWD_PAWN
	pawn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pawn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pawn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pawn.size = pawn_size
	pawn.position = route[0] - pawn_size * Vector2(0.5, 1.0)
	pawn.modulate.a = 0.0
	add_child(pawn)

	var motion := create_tween()
	motion.tween_property(pawn, "modulate:a", 1.0, 0.16)
	motion.tween_interval(0.18)
	for step in range(1, route.size()):
		motion.tween_method(_hop.bind(pawn, route[step - 1], route[step]), 0.0, 1.0, STEP_SECONDS)
	motion.tween_interval(0.45)
	await motion.finished


func _hop(weight: float, pawn: TextureRect, start: Vector2, finish: Vector2) -> void:
	var foot := start.lerp(finish, weight)
	foot.y -= sin(weight * PI) * 10.0
	pawn.position = foot - pawn.size * Vector2(0.5, 1.0)
