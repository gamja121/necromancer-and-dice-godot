extends Control
## Lightweight deterministic stone contact dust. One CanvasItem draws all
## moving slabs' impact motes; no textures, particles, timers or extra audio.
## Visual only: the actual board and save never depend on this.
const PUFF_DURATION = 0.16
const MAX_PUFFS = 21
const MAX_SPECKS = 3
const RIM_SPREAD = 21.0
const DUST_COLOR = Color(0.72, 0.67, 0.58, 0.27)
const SHADOW_COLOR = Color(0.24, 0.21, 0.18, 0.13)

var puffs: Array[Dictionary] = []
var total_emitted: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	set_process(false)


func emit_at(ground_point: Vector2, slab_index: int) -> void:
	if puffs.size() >= MAX_PUFFS:
		return
	puffs.append({"center": ground_point, "age": 0.0, "seed": slab_index})
	total_emitted += 1
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	for i in range(puffs.size() - 1, -1, -1):
		puffs[i]["age"] = float(puffs[i]["age"]) + delta
		if float(puffs[i]["age"]) >= PUFF_DURATION:
			puffs.remove_at(i)
	if puffs.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for puff in puffs:
		var t: float = clampf(float(puff["age"]) / PUFF_DURATION, 0.0, 1.0)
		var alpha: float = (1.0 - t) * (1.0 - t)
		var center: Vector2 = puff["center"]
		var seed: int = int(puff["seed"])
		# A short dark contact line expands along the floor, never shaking
		# the camera or popping the actual stone tile out of its slot.
		var width: float = RIM_SPREAD * (0.6 + 0.4 * t)
		draw_line(center + Vector2(-width, 0), center + Vector2(width, 0), Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, SHADOW_COLOR.a * alpha), 1.4, true)
		# Only three small rock-dust flecks per tile. Their fixed offsets
		# prevent noisy random particle explosions and keep mobile cost low.
		for part in range(MAX_SPECKS):
			var direction: float = -1.0 if part == 0 else (1.0 if part == 1 else 0.35)
			var spread: float = (8.0 + 3.0 * float((seed + part) % 3)) * (0.35 + 0.65 * t)
			var rise: float = (5.0 + float((seed + part * 2) % 4)) * sin(PI * t)
			var fleck: Vector2 = center + Vector2(direction * spread, -3.0 - rise)
			draw_circle(fleck, 1.0 + float((seed + part) % 2) * 0.35, Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, DUST_COLOR.a * alpha))


func clear_puffs() -> void:
	puffs.clear()
	total_emitted = 0
	set_process(false)
	queue_redraw()
