extends RefCounted
## Stage 5U: frozen web v2-map-practice.css story board-drop and next-hint.
## Only the original graveyard child visual nodes move: no interaction, RNG,
## story flags or persistent state. Tweens belong to those nodes so closing
## their scene cancels them automatically.

const DROP_SECONDS: float = 0.66
const HINT_SECONDS: float = 0.9
const DROP_KEYS = [
	{"time":0.0,  "offset":Vector2(-0.048,-0.19),  "rotation":-7.0, "scale":0.94,  "alpha":0.48},
	{"time":0.45, "offset":Vector2(0.006,0.028),   "rotation":2.5,  "scale":1.018, "alpha":1.0},
	{"time":0.61, "offset":Vector2(-0.0055,-0.007),"rotation":-1.65,"scale":0.998, "alpha":1.0},
	{"time":0.75, "offset":Vector2(0.0032,0.0035),"rotation":0.82, "scale":1.003, "alpha":1.0},
	{"time":0.88, "offset":Vector2(-0.0012,-0.0012),"rotation":-0.28,"scale":1.0,  "alpha":1.0},
	{"time":1.0,  "offset":Vector2.ZERO,         "rotation":0.0,  "scale":1.0,   "alpha":1.0}
]

static func play_board_drop(art: TextureRect) -> void:
	if not is_instance_valid(art) or art.texture == null: return
	# PanelEffectsModule owns the ordinary +6 px slide. Opt out *only* this
	# artwork so its source -19% vertical entry cannot fight that tween.
	art.set_meta("ui_custom_open_motion",true)
	art.pivot_offset = art.size * Vector2(0.5,0.54)
	var original: Vector2 = art.position
	var beginning: Dictionary = DROP_KEYS[0]
	art.position = original + art.size * Vector2(beginning["offset"])
	art.rotation_degrees = float(beginning["rotation"])
	art.scale = Vector2.ONE * float(beginning["scale"])
	art.modulate.a = float(beginning["alpha"])
	var tween := art.create_tween()
	for i in range(1,DROP_KEYS.size()):
		var previous: Dictionary = DROP_KEYS[i-1]
		var next: Dictionary = DROP_KEYS[i]
		var duration: float = DROP_SECONDS * (float(next["time"])-float(previous["time"]))
		tween.tween_property(art,"position",original+art.size*Vector2(next["offset"]),duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(art,"rotation_degrees",float(next["rotation"]),duration)
		tween.parallel().tween_property(art,"scale",Vector2.ONE*float(next["scale"]),duration)
		tween.parallel().tween_property(art,"modulate:a",float(next["alpha"]),duration)

static func play_next_hint(hint: Label) -> void:
	if not is_instance_valid(hint): return
	# The animated source .graveyard-story-next is a display-only glyph.
	# Do not let the generic modal travel override its 4 px idle movement.
	hint.set_meta("ui_custom_open_motion",true)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var origin_y: float = hint.position.y
	hint.modulate.a = 0.45
	var tween := hint.create_tween().set_loops()
	tween.tween_property(hint,"position:y",origin_y+4.0,HINT_SECONDS/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(hint,"modulate:a",1.0,HINT_SECONDS/2.0)
	tween.tween_property(hint,"position:y",origin_y,HINT_SECONDS/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(hint,"modulate:a",0.45,HINT_SECONDS/2.0)
