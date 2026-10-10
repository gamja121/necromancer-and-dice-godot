extends RefCounted
## Reusable pen-and-ink reveal for a single location illustration.
## Applies to the art TextureRect only; does not move the artwork or UI.
## No external mask image or persistent state is required.

const INK_SHADER := """
shader_type canvas_item;

uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;

float stroke_random(float seed) {
    return fract(sin(seed * 127.1) * 43758.5453);
}

void fragment() {
    // The sweep's irregular left-to-right nib edge is made of thick brush
    // variation plus tightly spaced cross-pen strokes, not dotted noise.
    float band = floor(UV.y * 57.0);
    float coarse = (stroke_random(band) - 0.5) * 0.11;
    float flowing = sin(UV.y * 32.0 + sin(UV.y * 8.0) * 3.0) * 0.029;
    float pen_hatch = sin(UV.y * 235.0 + UV.x * 18.0) * 0.011;
    float tip = UV.x + coarse + flowing + pen_hatch;

    float leading_edge = reveal_progress * 1.29 - 0.14;
    float uncovered = 1.0 - smoothstep(leading_edge - 0.027, leading_edge + 0.025, tip);
    float dark_ink = (1.0 - smoothstep(0.002, 0.026, abs(tip - leading_edge))) * uncovered;

    // Preserve the original TextureRect sampled color and alpha.
    COLOR.rgb = mix(COLOR.rgb, vec3(0.045, 0.035, 0.031), dark_ink * 0.85);
    COLOR.a *= uncovered;
}
"""

static func play(artwork: TextureRect, duration: float = 0.65) -> void:
    if not is_instance_valid(artwork) or artwork.texture == null:
        return
    var shader := Shader.new()
    shader.code = INK_SHADER
    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("reveal_progress", 0.0)
    artwork.material = material

    # create_tween() is bound to the artwork; removing the modal cancels it.
    var tween := artwork.create_tween()
    tween.tween_property(material, "shader_parameter/reveal_progress", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_callback(func() -> void:
        if is_instance_valid(artwork) and artwork.material == material:
            artwork.material = null
    )
