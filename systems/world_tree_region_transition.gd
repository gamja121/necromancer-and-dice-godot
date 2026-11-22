extends Control
## Covers the old map, swaps its art at full coverage, then clears the new map.

const COVER_TIME := 0.58
const CLEAR_TIME := 0.74

const CURTAIN_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0);
uniform bool winter = true;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float paper_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float flecks(vec2 p, float threshold, float radius) {
	vec2 cell = floor(p);
	float seed = hash21(cell);
	vec2 center = 0.23 + 0.54 * vec2(seed, hash21(cell + vec2(3.0, 9.0)));
	float distance_to_center = length(fract(p) - center);
	return step(threshold, seed) * (1.0 - smoothstep(radius * 0.25, radius, distance_to_center));
}

void fragment() {
	vec2 uv = UV;
	vec2 paper = vec2(uv.x * 1.778, uv.y);
	float broad = paper_noise(paper * vec2(7.0, 9.0));
	float fibers = paper_noise(paper * vec2(51.0, 33.0));
	float tooth = hash21(floor(uv * vec2(1280.0, 720.0)));
	float slant = winter ? mix(uv.x, uv.y, 0.35) : mix(uv.x, 1.0 - uv.y, 0.69);
	float front = slant + (broad - 0.5) * 0.31 + (fibers - 0.5) * 0.08;
	float sweep = progress < 0.5 ? progress * 2.0 : (1.0 - progress) * 2.0;
	float edge = mix(-0.45, 1.45, sweep);
	float depth = edge - front;
	float cover = smoothstep(-0.1, 0.19, depth);
	float lip = (1.0 - smoothstep(0.015, 0.16, abs(depth))) * (0.52 + fibers * 0.48);
	float mist = (1.0 - smoothstep(0.05, 0.29, abs(depth))) * broad;
	float grain = (tooth - 0.5) * 0.055 + (fibers - 0.5) * 0.14;
	vec3 color;
	float drifting;

	if (winter) {
		float needle = abs(paper_noise(paper * vec2(80.0, 16.0) + vec2(uv.y * 30.0, 0.0)) - 0.5);
		float ice = (1.0 - smoothstep(0.009, 0.055, needle)) * broad;
		color = mix(vec3(0.15, 0.22, 0.27), vec3(0.51, 0.63, 0.67), broad * 0.88);
		color += grain + ice * 0.09;
		color = mix(color, vec3(0.8, 0.89, 0.9), lip * 0.73);
		drifting = flecks((paper + progress * vec2(-0.16, -0.25)) * 43.0, 0.80, 0.11);
		drifting += flecks((paper + progress * vec2(-0.30, -0.12)) * 28.0, 0.86, 0.10);
		color = mix(color, vec3(0.91, 0.95, 0.94), drifting * mist * 0.85);
	} else {
		float flame = paper_noise(vec2(paper.x * 26.0, paper.y * 6.0 + progress * 3.3));
		float burn = lip * smoothstep(0.23, 0.76, flame) + mist * flame * 0.24;
		color = mix(vec3(0.14, 0.11, 0.11), vec3(0.32, 0.21, 0.17), broad);
		color += grain * 0.65;
		color = mix(color, vec3(0.91, 0.37, 0.10), burn);
		color += vec3(0.17, 0.10, 0.035) * burn * flame;
		drifting = flecks((paper + progress * vec2(-0.09, 0.50)) * 35.0, 0.82, 0.11);
		drifting += flecks((paper + progress * vec2(-0.05, 0.26)) * 24.0, 0.86, 0.09);
		color = mix(color, vec3(0.98, 0.55, 0.24), drifting * mist * 0.9);
	}

	float alpha = max(cover, max(lip * 0.35, mist * (0.20 + drifting * 0.46)));
	COLOR = vec4(color, alpha);
}
"""

var progress := 0.0
var board_revealed := false
var _material: ShaderMaterial


func _ready() -> void:
	name = "WorldTreeRegionTransition"
	z_index = 185
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false

	var shader := Shader.new()
	shader.code = CURTAIN_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	var curtain := ColorRect.new()
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.material = _material
	add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func play(region: String, reveal_board: Callable) -> void:
	_material.set_shader_parameter("winter", region == "winter")
	var animation := create_tween()
	animation.tween_method(_set_progress, 0.0, 0.5, COVER_TIME)
	animation.tween_callback(func():
		board_revealed = true
		reveal_board.call())
	animation.tween_method(_set_progress, 0.5, 1.0, CLEAR_TIME)
	await animation.finished
	hide()


func _set_progress(value: float) -> void:
	progress = value
	_material.set_shader_parameter("progress", value)
