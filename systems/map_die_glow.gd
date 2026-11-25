extends Node2D
## Cosmetic, non-interactive highlight for the resting map die.
## The die itself keeps its existing button, input, save and bounce behavior.
var die: TextureButton
var map_scene: Control
var elapsed: float = 0.0

func setup(target: TextureButton, owner: Control) -> void:
	die = target
	map_scene = owner
	name = "MapDieGlow"
	position = target.size * 0.5
	show_behind_parent = true
	hide()
	target.add_child(self)

func _process(delta: float) -> void:
	if not is_instance_valid(die) or not is_instance_valid(map_scene): return
	# Only guide the next BOARD roll; never glow over a battle or location UI.
	var active: bool = not get_tree().paused and die.is_visible_in_tree() and not die.disabled and not map_scene.shared_die_busy and not map_scene.moving and not map_scene.battle_returning and not is_instance_valid(map_scene.overlay) and not is_instance_valid(map_scene.embedded_battle) and not is_instance_valid(map_scene.game_over_screen) and not is_instance_valid(map_scene.final_chapter_screen) and (not is_instance_valid(map_scene.map_audio) or not map_scene.map_audio.is_open())
	if visible != active: visible = active
	if not active: return
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var breath: float = 0.5 + 0.5 * sin(elapsed * TAU / 1.8)
	var strength: float = (0.18 + 0.15 * breath) * (1.35 if die.is_hovered() else 1.0)
	var radius: float = die.size.x * 0.59
	# Hand-painted, soft gold strokes behind the die. No collision/input area.
	for i in range(4):
		var alpha: float = strength * (1.0 - float(i) * 0.21)
		draw_arc(Vector2.ZERO, radius + float(i) * 3.5, 0.0, TAU, 48, Color(0.96, 0.73, 0.34, alpha), 2.0 + float(i) * 0.4, true)
