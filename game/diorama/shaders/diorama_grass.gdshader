shader_type spatial;
render_mode unshaded, cull_disabled;

// Seamless Gouache Painterly Grass Tufts (Self-lit to blend softly into meadow & campfire pool — ZERO harsh black comb shadows!)
uniform float night_mix : hint_range(0.0, 1.0) = 1.0;

varying float v_tip;
varying vec3 v_col;

void vertex() {
	v_tip = clamp(UV.y, 0.0, 1.0);
	v_col = COLOR.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 2.0 + wp.x * 0.72 + wp.z * 0.62) * 0.055 * v_tip * v_tip;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.40;
}

void fragment() {
	// Soft root-to-tip painterly gradient matching 06_29_51 & vC7OEC grass tufts
	vec3 col = v_col * mix(0.76, 1.18, v_tip);
	ALBEDO = clamp(col, 0.0, 1.0);
}
