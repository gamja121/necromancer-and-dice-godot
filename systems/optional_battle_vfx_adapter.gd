extends Control
## Optional procedural CanvasItem VFX, designed for the GL Compatibility renderer.
## Does not use gameplay RNG, mutate sprites, or change combat resolution.
const Preferences = preload("res://systems/optional_battle_vfx_settings.gd")
const MAX_EVENTS = 18
var preferences: Dictionary = {}
var battle_scene: Control
var events: Array[Dictionary] = []
var clock: float = 0.0

func setup(owner_scene: Control) -> void:
	battle_scene = owner_scene
	preferences = Preferences.load_preferences()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = owner_scene.surface_size
	z_index = 55

func reload_preferences() -> void:
	preferences = Preferences.load_preferences()
	if not bool(preferences.get("enabled", false)):
		events.clear()
		queue_redraw()

func effect_enabled(effect_name: String) -> bool:
	return Preferences.active(preferences, effect_name)

func spawn_event(unit_id: String, kind: String, lifetime: float) -> void:
	if not effect_enabled(kind) or battle_scene == null:
		return
	if not is_instance_valid(battle_scene.visuals):
		return
	if not battle_scene.visuals.layouts.has(unit_id):
		return
	if events.size() >= MAX_EVENTS:
		events.pop_front()
	events.append({"kind": kind, "center": battle_scene.visuals.center_of(unit_id), "start": clock, "life": lifetime})
	queue_redraw()

func attack_started(unit_id: String) -> void:
	spawn_event(unit_id, "shadow_particle", 0.38)

func impact_confirmed(target_id: String) -> void:
	spawn_event(target_id, "energy_burst", 0.34)

func death_confirmed(unit_id: String) -> void:
	spawn_event(unit_id, "dissolve", 0.7)

func _process(delta: float) -> void:
	if battle_scene == null or not is_instance_valid(battle_scene):
		return
	if battle_scene.paused or battle_scene.visuals.presentation_hold:
		return
	clock += delta * battle_scene.speed_values[battle_scene.speed_index]
	for i in range(events.size() - 1, -1, -1):
		if clock - float(events[i].start) >= float(events[i].life):
			events.remove_at(i)
	if not events.is_empty():
		queue_redraw()

func _draw() -> void:
	for item in events:
		if not effect_enabled(str(item.kind)):
			continue
		var t: float = clampf((clock - float(item.start)) / float(item.life), 0.0, 1.0)
		var center: Vector2 = item.center
		var fade: float = 1.0 - t
		match str(item.kind):
			"shadow_particle":
				for i in range(10):
					var angle: float = TAU * float(i) / 10.0
					var drift: Vector2 = Vector2.from_angle(angle) * (12.0 + 64.0 * t)
					var p: Vector2 = center + drift + Vector2(0, -24.0 * t)
					draw_circle(p, (4.0 + float(i % 3)) * fade, Color(0.53, 0.28, 0.84, 0.75 * fade))
					draw_line(p, p - drift.normalized() * 13.0, Color(0.19, 0.09, 0.35, 0.65 * fade), 2.0, true)
			"energy_burst":
				draw_arc(center, 15.0 + 68.0 * t, 0.0, TAU, 40, Color(0.87, 0.72, 1.0, 0.75 * fade), 3.0, true)
				for i in range(12):
					var angle: float = TAU * float(i) / 12.0
					var direction: Vector2 = Vector2.from_angle(angle)
					var start: Vector2 = center + direction * (12.0 + 48.0 * t)
					draw_line(start, start + direction * (19.0 * fade + 4.0), Color(0.78, 0.91, 1.0, fade), 2.5, true)
			"dissolve":
				for i in range(18):
					var angle: float = TAU * float(i) / 18.0
					var offset: Vector2 = Vector2(cos(angle) * 38.0, sin(angle) * 44.0)
					var p: Vector2 = center + offset * (0.6 + 0.7 * t) + Vector2(0, -68.0 * t)
					draw_rect(Rect2(p, Vector2.ONE * (2.0 + float(i % 3)) * fade), Color(0.45, 0.36, 0.63, 0.6 * fade))
