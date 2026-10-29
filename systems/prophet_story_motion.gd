extends RefCounted
## Presentation only: the reference orb breathes softly; RNG and story state
## are never consulted. The portrait entrance runs only at the reveal beat.
const ORB_SHADER = """shader_type canvas_item;
varying vec4 portrait_tint;
void vertex() {
	portrait_tint = COLOR;
}
void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	vec2 delta = (UV - vec2(0.794, 0.660)) * vec2(0.83, 1.0);
	float orb = 1.0 - smoothstep(0.105, 0.155, length(delta));
	float violet = smoothstep(0.03, 0.22, ink.b - ink.g);
	float pulse = 0.5 + 0.5 * sin(TIME * 1.65);
	ink.rgb += vec3(0.05, 0.015, 0.09) * orb * violet * pulse;
	COLOR = ink * portrait_tint;
}
"""

static func play(portrait: TextureRect, entering: bool) -> void:
	portrait.set_meta("ui_custom_open_motion",true)
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code=ORB_SHADER
	var material:=ShaderMaterial.new()
	material.shader=shader
	portrait.material=material
	if not entering: return
	var final_position: Vector2=portrait.position
	portrait.position+=Vector2(8,3)
	portrait.modulate.a=0.0
	var tween:=portrait.create_tween().set_parallel(true)
	tween.tween_property(portrait,"position",final_position,0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait,"modulate:a",1.0,0.48)
