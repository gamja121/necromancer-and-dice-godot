extends Control
## A board-only lead-in to the saved first page of the home arson event.

const PAWNS = preload("res://assets/map/hero/witch_hunt_villager_pawns.png")
const PAWN_SIZE := Vector2(84, 84)
const STEP_SECONDS := 0.25
const STEP_DELAY := 0.07
const FORMATION := [Vector2(-39, 4), Vector2(0, -12), Vector2(39, 5)]


func play(route: PackedVector2Array) -> void:
	var pawns: Array[TextureRect] = []
	var motion := create_tween().set_parallel()
	var frame_width: int = PAWNS.get_width() / FORMATION.size()
	for i in range(FORMATION.size()):
		var sprite := AtlasTexture.new()
		sprite.atlas = PAWNS
		sprite.region = Rect2(i * frame_width, 0, frame_width, PAWNS.get_height())
		sprite.filter_clip = true

		var pawn := TextureRect.new()
		pawn.name = "Villager%d" % (i + 1)
		pawn.texture = sprite
		pawn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pawn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pawn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pawn.size = PAWN_SIZE
		pawn.position = route[0] + FORMATION[i] - PAWN_SIZE * Vector2(0.5, 1.0)
		pawn.flip_h = i == 0
		pawn.modulate.a = 0.0
		add_child(pawn)
		pawns.append(pawn)
		motion.tween_property(pawn, "modulate:a", 1.0, 0.16).set_delay(i * 0.09)

	motion.chain().tween_interval(0.18)
	for step in range(1, route.size()):
		for i in range(pawns.size()):
			var start: Vector2 = route[step - 1] + FORMATION[i]
			var finish: Vector2 = route[step] + FORMATION[i]
			if i == 0:
				motion.chain()
			motion.tween_method(_hop.bind(pawns[i], start, finish), 0.0, 1.0, STEP_SECONDS).set_delay(i * STEP_DELAY)
	motion.chain().tween_interval(0.45)
	await motion.finished


func _hop(weight: float, pawn: TextureRect, start: Vector2, finish: Vector2) -> void:
	var foot := start.lerp(finish, weight)
	foot.y -= sin(weight * PI) * 10.0
	pawn.position = foot - PAWN_SIZE * Vector2(0.5, 1.0)
