extends RefCounted
## Source-guided three-layer cloud fog from the frozen HTML map transition.
## CSS blur is approximated with soft radial falloffs, not an exact pixel copy.
const FOG_SHADER: String = """
shader_type canvas_item;
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform int bank_kind = 0;
float soft_ellipse(vec2 uv, vec2 center, vec2 radii, float core, float edge) {
    float d = length((uv - center) / radii);
    return 1.0 - smoothstep(core, edge, d);
}
void fragment() {
    vec2 uv = UV;
    float opacity = 0.0;
    vec3 fog_color = vec3(0.955, 0.963, 0.955);
    if (bank_kind == 0) {
        // CSS ::before, radial spots at 24% 36% and 76% 58%.
        float a = soft_ellipse(uv, vec2(0.24,0.36), vec2(0.56,0.53),0.15,1.0);
        float b = soft_ellipse(uv, vec2(0.76,0.58), vec2(0.53,0.53),0.16,1.0);
        opacity = max(a*0.86,b*0.84);
        fog_color = vec3(0.95,0.96,0.95);
    } else if (bank_kind == 1) {
        // CSS ::after, central white veil.
        float d = soft_ellipse(uv,vec2(0.5,0.5),vec2(0.66,0.62),0.32,1.28);
        opacity = 0.96*d;
        fog_color = vec3(0.96,0.97,0.96);
    } else {
        // CSS .map-cloud-mist; light top-to-bottom blend and two white spots.
        float a = soft_ellipse(uv,vec2(0.14,0.32),vec2(0.48,0.48),0.10,0.95);
        float b = soft_ellipse(uv,vec2(0.84,0.61),vec2(0.48,0.48),0.13,1.02);
        fog_color = mix(vec3(0.949,0.953,0.941),vec3(0.835,0.851,0.835),uv.y);
        fog_color = mix(fog_color,vec3(1.0),clamp(max(a*0.44,b*0.43),0.0,0.45));
        opacity = min(1.0,mix(0.96,0.98,uv.y)+max(a,b)*0.02);
    }
    COLOR = vec4(fog_color,opacity*coverage);
}
"""

static func create(parent: Control, kind: int) -> ColorRect:
	var fog = ColorRect.new()
	fog.name = ["CloudFrontBank","CloudCentralVeil","CloudCenterMist"][kind]
	var inset: float = 0.08 if kind==2 else 0.12
	fog.position = Vector2(-1280.0*inset,-720.0*inset)
	fog.size = Vector2(1280.0*(1.0+2.0*inset),720.0*(1.0+2.0*inset))
	fog.pivot_offset = fog.size*0.5
	fog.scale = Vector2.ONE*([0.84,0.68,0.92][kind])
	fog.color = Color.WHITE
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = FOG_SHADER
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("bank_kind",kind)
	shader_material.set_shader_parameter("coverage",0.0)
	fog.material = shader_material
	parent.add_child(fog)
	return fog
