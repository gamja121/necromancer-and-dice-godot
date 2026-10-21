extends Control
## Explicitly started, presentation-only final boss. Never reads/writes RunSession.
signal intro_finished
signal motion_finished(motion: String)
signal attack_impact

const BASE_SIZE := Vector2(1280, 720)
const ART_RECT := Rect2(56, 78, 1168, 504)
const DRAGON_RECT := Rect2(272, -28, 944, 590)
const FRAME_SIZE := Vector2i(1024, 640)
const INTRO_SECONDS := 5.2
const CACHE_LIMIT := 10
const COUNTS := {"idle": 6, "attack": 10, "hit": 4, "death": 8}
const DELAYS := {
	"idle": [0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
	"attack": [0.11, 0.10, 0.13, 0.16, 0.08, 0.08, 0.09, 0.09, 0.10, 0.13],
	"hit": [0.08, 0.07, 0.07, 0.10],
	"death": [0.12, 0.14, 0.17, 0.19, 0.22, 0.25, 0.29, 0.37]
}
const REVEAL_SHADER := "
shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.2) = 1.2;
uniform float pigment : hint_range(0.0, 1.0) = 1.0;
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }
void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	float grain = fract(sin(dot(floor(UV * vec2(260.0, 160.0)), vec2(12.9898, 78.233))) * 43758.5453);
	float edge = 1.0 - UV.y + (grain - 0.5) * 0.08;
	ink.a *= smoothstep(edge - 0.04, edge + 0.04, reveal);
	ink.rgb = mix(vec3(0.035, 0.042, 0.030), ink.rgb, pigment);
	COLOR = ink * canvas_tint;
}"

class Atmosphere:
	extends Control
	var presentation: Control
	func _draw() -> void:
		if is_instance_valid(presentation):
			presentation.draw_atmosphere(self)

var paused := false
var playback_speed := 1.0
var reduced_motion := false
var auto_advance := true
var current_motion := "idle"
var motion_time := 0.0
var intro_time := 0.0
var intro_active := false
var playing := false
var impact_sent := false
var assets_ready := false
var canvas: Control
var stage: Control
var dragon: TextureRect
var atmosphere: Atmosphere
var heading: Label
var caption: Label
var boss_title: Label
var reveal_material: ShaderMaterial
var _cache: Dictionary = {}
var _lru: Array[String] = []
var _high_water := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_layout)
	_layout()
	assets_ready = true
	for motion in COUNTS:
		for index in range(int(COUNTS[motion])):
			if not ResourceLoader.exists(frame_path(motion, index)):
				assets_ready = false
	set_process(false)

static func frame_path(motion: String, index: int) -> String:
	return "res://assets/battle/frames/final-dragon/%s-%02d.png" % [motion, index + 1]

static func duration(motion: String) -> float:
	var total := 0.0
	for delay in DELAYS.get(motion, []):
		total += float(delay)
	return total

static func frame_index(motion: String, seconds: float) -> int:
	var cursor := 0.0
	var delays: Array = DELAYS.get(motion, [])
	for index in range(delays.size()):
		cursor += float(delays[index])
		if seconds < cursor:
			return index
	return maxi(0, delays.size() - 1)

static func impact_seconds() -> float:
	var seconds := 0.0
	for index in range(5):
		seconds += float(DELAYS.attack[index])
	return seconds

func _label(text: String, location: Vector2, dimensions: Vector2, font_size: int, ink: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.position = location
	result.size = dimensions
	result.add_theme_font_override("font", load("res://assets/fonts/NanumBarunGothic.ttf"))
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", ink)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(result)
	return result

func _build() -> void:
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = BASE_SIZE
	add_child(canvas)
	stage = Control.new()
	stage.position = ART_RECT.position
	stage.size = ART_RECT.size
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(stage)
	var backdrop := TextureRect.new()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.texture = load("res://assets/battle/backgrounds/haunted-forest-ruins-battlefield.jpg")
	backdrop.size = ART_RECT.size
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.53, 0.58, 0.49)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(backdrop)
	var shade := ColorRect.new()
	shade.size = ART_RECT.size
	shade.color = Color(0.035, 0.045, 0.025, 0.23)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)
	# Crop only the ordinary frame\'s transparent padding through an atlas.
	var soldier_art := AtlasTexture.new()
	soldier_art.atlas = load("res://assets/battle/frames/skeleton-spear/attack-01.png")
	soldier_art.region = Rect2(293, 295, 252, 321)
	# Existing ordinary skeleton art establishes the colossal scale (about 5x).
	for index in range(3):
		var soldier := TextureRect.new()
		soldier.name = "ScaleSoldier%d" % index
		soldier.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		soldier.texture = soldier_art
		soldier.position = Vector2(78 + index * 76, 394 - index * 3)
		soldier.size = Vector2(76, 100)
		soldier.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		soldier.modulate = Color(0.68, 0.69, 0.57)
		soldier.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(soldier)
	dragon = TextureRect.new()
	dragon.position = DRAGON_RECT.position
	dragon.size = DRAGON_RECT.size
	dragon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dragon.stretch_mode = TextureRect.STRETCH_SCALE
	dragon.flip_h = true
	dragon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = REVEAL_SHADER
	reveal_material = ShaderMaterial.new()
	reveal_material.shader = shader
	dragon.material = reveal_material
	stage.add_child(dragon)
	atmosphere = Atmosphere.new()
	atmosphere.presentation = self
	atmosphere.size = ART_RECT.size
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(atmosphere)
	heading = _label("최후의 장     /     봉인된 유적", Vector2(61, 34), Vector2(900, 32), 20, Color("#493c2b"))
	boss_title = _label("드래곤", Vector2(76, 596), Vector2(250, 45), 34, Color("#342c21"))
	caption = _label("", Vector2(300, 605), Vector2(894, 60), 21, Color("#514632"))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _layout() -> void:
	if not is_instance_valid(canvas):
		return
	var factor := minf(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - BASE_SIZE * factor) * 0.5
	queue_redraw()

func _draw() -> void:
	var factor := minf(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	draw_set_transform((size - BASE_SIZE * factor) * 0.5, 0, Vector2.ONE * factor)
	draw_rect(Rect2(Vector2.ZERO, BASE_SIZE), Color("#171914"))
	draw_rect(Rect2(22, 18, 1236, 684), Color("#58432b"))
	draw_rect(Rect2(29, 23, 1222, 674), Color("#c7ac7d"))
	draw_rect(Rect2(36, 28, 1208, 662), Color("#e0c99a"))
	for line in range(7):
		draw_line(Vector2(42, 678 + line), Vector2(1238, 678 + line), Color(0.30, 0.23, 0.14, 0.14), 1)
	draw_rect(Rect2(51, 73, 1178, 514), Color("#68553a"), false, 2)
	draw_line(Vector2(76, 659), Vector2(1203, 659), Color("#b2986c"), 1)
	draw_set_transform(Vector2.ZERO)

func _texture(motion: String, index: int) -> Texture2D:
	var key := frame_path(motion, index)
	if _cache.has(key):
		_lru.erase(key)
		_lru.append(key)
		return _cache[key]
	while _cache.size() >= CACHE_LIMIT:
		_cache.erase(_lru.pop_front())
	var loaded := ResourceLoader.load(key, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if loaded != null:
		_cache[key] = loaded
		_lru.append(key)
		_high_water = maxi(_high_water, _cache.size())
	return loaded

func _prime(motion: String) -> void:
	for index in range(int(COUNTS[motion])):
		_texture(motion, index)

func play_intro(less_motion: bool = false) -> bool:
	if not assets_ready:
		return false
	reduced_motion = less_motion
	paused = false
	intro_time = 0.0
	motion_time = 0.0
	current_motion = "idle"
	intro_active = true
	playing = true
	impact_sent = false
	_prime("idle")
	_refresh()
	set_process(auto_advance)
	return true

func play_motion(motion: String) -> bool:
	if not assets_ready or not COUNTS.has(motion):
		return false
	intro_active = false
	current_motion = motion
	motion_time = 0.0
	impact_sent = false
	playing = true
	_prime(motion)
	_refresh()
	set_process(auto_advance)
	return true

func set_playback_speed(value: float) -> void:
	if is_finite(value):
		playback_speed = clampf(value, 0.25, 2.0)

func set_paused(value: bool) -> void:
	paused = value
	set_process(auto_advance and playing and not paused)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if paused or not playing or not is_finite(delta) or delta <= 0.0:
		return
	var step := delta * playback_speed
	if intro_active:
		intro_time += step
		motion_time = fmod(motion_time + step, duration("idle"))
		var end_time := 1.0 if reduced_motion else INTRO_SECONDS
		if intro_time >= end_time:
			intro_active = false
			intro_time = end_time
			motion_time = 0.0
			intro_finished.emit()
	else:
		motion_time += step
		if current_motion == "attack" and not impact_sent and motion_time >= impact_seconds():
			impact_sent = true
			attack_impact.emit()
		var end_time := duration(current_motion)
		if current_motion == "idle":
			motion_time = fmod(motion_time, end_time)
		elif motion_time >= end_time:
			var completed := current_motion
			if completed == "death":
				motion_time = end_time
				playing = false
				set_process(false)
			else:
				current_motion = "idle"
				motion_time = 0.0
			motion_finished.emit(completed)
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(dragon):
		return
	var motion := current_motion
	var frame := frame_index(motion, motion_time)
	var reveal := 1.2
	var pigment := 1.0
	if intro_active:
		if reduced_motion:
			reveal = minf(1.2, intro_time * 2.4)
		else:
			reveal = clampf((intro_time - 0.85) / 1.8, 0.0, 1.2)
			pigment = clampf((intro_time - 1.8) / 1.25, 0.0, 1.0)
			if intro_time >= 3.1 and intro_time < 4.2:
				motion = "attack"
				frame = frame_index("attack", intro_time - 3.1)
		if intro_time < 1.7:
			caption.text = "돌바닥 아래에서 묵직한 진동이 올라왔다."
		elif intro_time < 3.2:
			caption.text = "어둠 속에서 거대한 날개가 모습을 드러냈다."
		else:
			caption.text = "유적을 뒤덮는 그림자. 그 끝에서 드래곤이 우리를 내려다보았다."
	else:
		caption.text = "유적을 뒤덮는 그림자. 그 끝에서 드래곤이 우리를 내려다보았다."
	if reduced_motion and motion == "idle":
		frame = 0
	dragon.texture = _texture(motion, frame)
	dragon.modulate.a = 1.0
	if current_motion == "death":
		dragon.modulate.a = 1.0 - smoothstep(duration("death") * 0.53, duration("death"), motion_time)
	reveal_material.set_shader_parameter("reveal", reveal)
	reveal_material.set_shader_parameter("pigment", pigment)
	boss_title.modulate.a = clampf((intro_time - 3.6) / 0.8, 0.0, 1.0) if intro_active and not reduced_motion else 1.0
	stage.position = ART_RECT.position
	if not reduced_motion and intro_active and intro_time > 3.65 and intro_time < 4.05:
		var amount := 2.5 * (1.0 - (intro_time - 3.65) / 0.4)
		stage.position += Vector2(sin(intro_time * 73.0), cos(intro_time * 89.0)) * amount
	atmosphere.queue_redraw()

func draw_atmosphere(target: Control) -> void:
	if not playing and current_motion != "death":
		return
	var presence := clampf(intro_time / 1.5, 0.0, 1.0) if intro_active else 1.0
	if current_motion == "death":
		presence *= dragon.modulate.a
	# Ground shadow; explicit affine transform keeps it separate from the art.
	target.draw_set_transform(Vector2(768, 477), 0, Vector2(1.0, 0.10))
	target.draw_circle(Vector2.ZERO, 280, Color(0.02, 0.025, 0.015, 0.23 * presence))
	target.draw_set_transform(Vector2.ZERO)
	if reduced_motion:
		return
	var wave := -1.0
	if intro_active and intro_time > 0.8 and intro_time < 2.0:
		wave = (intro_time - 0.8) / 1.2
	elif intro_active and intro_time > 3.65 and intro_time < 4.7:
		wave = (intro_time - 3.65) / 1.05
	elif current_motion == "attack" and motion_time > impact_seconds():
		wave = (motion_time - impact_seconds()) / 0.45
	if wave >= 0.0 and wave < 1.0:
		target.draw_set_transform(Vector2(760, 478), 0, Vector2(1.0, 0.18))
		target.draw_arc(Vector2.ZERO, 75.0 + wave * 430.0, 0, TAU, 72, Color(0.77, 0.68, 0.45, (1.0 - wave) * 0.45), 3, true)
		target.draw_set_transform(Vector2.ZERO)
		for index in range(22):
			var angle := float(index) * 2.39996
			var point := Vector2(760, 475) + Vector2(cos(angle) * (40 + wave * 260), -sin(wave * PI) * (16 + index % 5 * 6))
			target.draw_circle(point, 2.0 + index % 3, Color(0.66, 0.57, 0.38, (1.0 - wave) * 0.48))

func snapshot() -> Dictionary:
	return {
		"motion": current_motion, "motion_time": motion_time,
		"intro_time": intro_time, "intro_active": intro_active,
		"playing": playing, "paused": paused, "speed": playback_speed,
		"cached_frames": _cache.size(), "cache_high_water": _high_water,
		# Cache plus one active TextureRect reference after an eviction.
		"resident_upper_bytes": (_cache.size() + 1) * FRAME_SIZE.x * FRAME_SIZE.y * 4,
		"alpha": dragon.modulate.a if is_instance_valid(dragon) else 0.0
	}

func stop() -> void:
	playing = false
	intro_active = false
	set_process(false)
	if is_instance_valid(dragon):
		dragon.texture = null
	_cache.clear()
	_lru.clear()

func _exit_tree() -> void:
	stop()
